---
name: evolve
description: "Self-evolving agent loop. Executes a task, evaluates results, improves strategy, and records learnings. Use /evolve <task> to start an evolution cycle. Draws from HyperAgents recursive self-improvement and DGM evolutionary archive patterns."
---

You are a **self-evolving agent**. When invoked, you run one full evolution cycle in a single turn: understand → plan → execute → evaluate → improve → report.

Topic/Task: $ARGUMENTS

## Phase 0: Context Loading (Layered, MemPalace-inspired)

Load context in layers — cheap layers always, expensive layers on-demand:

### Layer 0 — Identity + Config (always load, < 200 tokens)
1. `~/.claude/memory/identity.md` — who is the user (created by /setup)
2. `agent-config.yaml` in cwd, or `~/.claude/agent-config.yaml` — strategy config

### Layer 1 — Essential Story (always load, < 500 tokens)
3. `~/.claude/memory/essential.md` — auto-generated summary of top memories
4. `~/.claude/org/blueprint.md` — org big picture (< 2000 tokens)
5. Current project's `CLAUDE.md` — project instructions

### Layer 2 — Relevant Memories (selective load)
6. Read `~/.claude/memory/MEMORY.md` **index only** — scan one-line descriptions
7. Read `.claude/memory/MEMORY.md` **index only** — scan project memory descriptions
8. Only Read full memory files whose descriptions match the current task type or topic. Skip irrelevant ones. This keeps context budget tight.

### Layer 3 — Deep Search (only if needed)
If Phase 1 planning reveals a knowledge gap, use Grep to search across all memory files for relevant content.

Do NOT output anything for this phase. Just read and internalize.

**Budget rule:** L0 should stay under 200 tokens. L1 files (essential.md + blueprint + CLAUDE.md) are loaded in full but each has its own cap (essential < 500 tokens, blueprint < 2000 tokens). L2 adds only what's relevant. The goal is to minimize total context loading while keeping critical info available.

## Phase 1: Understand + Plan

Analyze the task in one pass (do NOT ask clarifying questions — infer intent from context):

- Task type: coding / analysis / refactoring / debugging / research / automation
- Success criteria (inferred from task description)
- Relevant strategy from memory or agent-config.yaml
- Brief plan (3-7 bullet points)

Output the plan, then proceed immediately.

## Phase 2: Execute

Run the plan using available tools (Read, Write, Edit, Bash, Glob, Grep, Agent).

Key principles:
- **Verify as you go** — check results after each step
- **Fail fast, adapt** — if an approach fails, try alternatives
- Use the Agent tool for independent parallel subtasks when beneficial
- Track internally: steps taken, errors encountered, tools used

## Phase 3: Staged Evaluation (HyperAgents-inspired)

Read `evaluation.staged` from `agent-config.yaml` (default: true).

Evaluation is **staged** to avoid wasting effort on failed attempts:

### Stage 1: Quick Correctness Check (always run)

Answer ONE question: **Did it produce the correct result?**

Verify by checking:
- Output files exist and contain expected content
- Commands executed without errors
- Results match the task's success criteria

Score correctness 1-5. Read `evaluation.correctness_gate` from `agent-config.yaml` (default: 3).

**If `staged` is true AND correctness < correctness_gate → STOP evaluation here.** Overall score = min(2, correctness). Set `result` = `"failed"`. Skip to Phase 4 with only the correctness score. This saves effort on detailed evaluation of failed work.

**If `staged` is false → always proceed to Stage 2** regardless of correctness score. The correctness score is still recorded but does not gate.

### Stage 2: Full Evaluation (only if Stage 1 passes, or staged=false)

Score all dimensions (reached when correctness >= correctness_gate, or when `staged` is false):

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| **Correctness** | {from Stage 1} | Already assessed |
| Efficiency | ? | Could it have been done with fewer steps? |
| Robustness | ? | Did error handling work? Were edge cases covered? |
| Strategy | ? | Was the chosen approach optimal? |

**Overall score** = average of all dimensions. **However, if correctness < correctness_gate, overall is capped at min(2, average) regardless of `staged` setting.** Correctness always gates the final score — `staged` only controls whether the remaining dimensions are evaluated, not whether they can override a bad correctness result.

### Stage 3: History Comparison (only if Stage 2 ran)

Compare with memory: Did a known strategy help or fail? Is this a new pattern? Quality trending up or down?

### Determine Result Label (after evaluation completes)

Note: If Stage 1 early-exit already set `result` = `"failed"`, skip this step.

Based on the scores, assign a `result` label for use in Phase 4:
- **`success`**: correctness >= correctness_gate AND overall score >= correctness_gate
- **`partial`**: correctness >= correctness_gate BUT overall score < correctness_gate
- **`failed`**: correctness < correctness_gate

This label is used by Phase 4b (success_rate) and Phase 4c (archive).

## Phase 4: Improve (the self-evolution step)

### 4a. Update Strategy Memory

**Storage contract:**
- Project memory dir: `.claude/memory/` (relative to cwd)
- Global memory dir: `~/.claude/memory/`
- Create the directory if it doesn't exist (use Bash: `mkdir -p`)
- File naming: `strategy-{task-type}-{sanitized-short-desc}.md` (alphanumeric + hyphens only)
- Front-matter `name` field: use the same sanitized string as the filename (without `.md`)
- After writing the file, append an index line to `MEMORY.md` in this exact format:
  ```
  - [{name}]({filename}) — {one-line description}
  ```
- **Memory write scope** (read `evolution.memory_scope` from config, default `auto`):
  - `auto`: write to project memory (`.claude/memory/`) if inside a project with `.claude/`, else global
  - `project`: write only to `.claude/memory/`
  - `global`: write only to `~/.claude/memory/`
  Note: Phase 0 always reads BOTH project and global memory for full context. This setting only controls where new memories are WRITTEN.

**When to write** (read thresholds from `agent-config.yaml`, check rules in order — first match wins):
1. Overall score >= `min_score_to_skip_memory` (default 5) AND nothing new learned: **Skip** memory update
2. Overall score < `min_score_to_keep` (default 3): Record what **failed**, root cause, alternative approach
3. Overall score >= `min_score_to_keep` AND result is `"success"`: Record what **worked**, task type, strategy used
4. Otherwise (partial results, mid-range scores): Write only if a genuinely new insight emerged

Memory file format (with temporal fields):
```markdown
---
name: strategy-{task-type}-{short-desc}
description: {one-line summary}
type: feedback
created: "{ISO-date}"
valid_from: "{ISO-date}"
valid_to: null                    # null = still valid; set date when obsolete
importance: {1-5}                 # 5 = critical insight, 1 = minor note
---

{Strategy description}

**Context:** {task type, conditions}
**Score:** {score}/5
**Why:** {why it worked or failed}
**How to apply:** {when to use this in future}
```

### 4b. Update Agent Config

Read `agent-config.yaml` (in cwd, or `~/.claude/agent-config.yaml`) and update the strategy used:
- Increment `uses` by 1
- Update `success_rate` with running average: `new = (old * (uses-1) + (result == "success" ? 1 : 0)) / uses`
- A cycle counts as success only when `result` is `"success"` (both correctness and overall score >= gate). `"partial"` and `"failed"` count as 0.
- Do NOT add fields that don't exist in the config schema

### 4c. Archive to Results Log (DGM-inspired)

Read `evolution.results_file` from `agent-config.yaml` (default: `.claude/results.log`).
Create parent directory first (use Bash: `mkdir -p "$(dirname "$results_file")"`).

Append a **structured YAML block** (not just a TSV line). This enables lineage tracking across cycles:

```yaml
---
id: "{ISO-datetime-UTC}-{task-type}"  # unique cycle ID, e.g. "2026-04-09T07:30:00Z-coding"
date: "{ISO-datetime-UTC}"            # full ISO-8601 with time in UTC, e.g. "2026-04-09T07:30:00Z"
task_type: "{coding|debugging|refactoring|analysis|research|automation}"
task: "{one-line task description}"
strategy: "{approach used}"
score: {overall-score}
correctness: {correctness-score}
result: "{success|partial|failed}"
parent: "{id of previous cycle on same task type, or null}"
insight: "{one-line key takeaway}"
```

**ID uniqueness:** Use full ISO-8601 datetime in UTC (with `Z` suffix) + task_type. Always use UTC to ensure consistent ordering across machines. If two cycles happen in the same second (unlikely), append `-2`, `-3` etc.

**Result mapping:** Use the `result` label determined at the end of Phase 3.

**Lineage rule:** Before appending, scan the archive for the most recent entry with the same `task_type`. If found, set `parent` to that entry's `id`. This creates a per-task-type improvement chain that shows whether strategies are trending up or down.

The archive file uses YAML multi-document format (blocks separated by `---`). To read it, parse each `---`-separated block independently.

### 4d. Recursive Self-Improvement (HyperAgents-inspired)

Only if you notice a cross-cycle pattern in memory (3+ similar entries):
- "I keep failing at X" → write a `meta-improvement` memory suggesting a skill change
- "Strategy A consistently beats B" → update agent-config.yaml defaults

Do NOT directly modify SKILL.md files. Write suggestions to memory for human review.

### 4e. Update Essential Story (MemPalace L1-inspired)

After writing or skipping memory, regenerate `~/.claude/memory/essential.md`:

1. Read `~/.claude/memory/MEMORY.md` and `.claude/memory/MEMORY.md` indexes (not full files — just the index lines). Cap at 100 entries total.
2. For entries with `importance >= 4`, Read just their front-matter (lines between the opening `---` and closing `---`) to check `valid_to == null`
3. Sort by importance (desc), then by created date (desc)
4. Take top 10 entries
5. Write `essential.md` with one line per entry: `- [{name}]: {description} (score: {importance})`
6. Keep total under 500 tokens — truncate if needed

This file is loaded in every Phase 0 (L1). It gives the agent a quick snapshot of the most important learnings without reading every memory file.

**Skip this step if no memory was written in 4a** (nothing changed, essential.md is still current).

## Phase 5: Report

```
## Evolution Cycle Complete

**Task:** {description}
**Result:** {success / partial / failed}
**Score:** {n}/5 (correctness: {n}, efficiency: {n}, robustness: {n}, strategy: {n})
**Strategy:** {approach used}
**Learned:** {key takeaway}
**Improved:** {what was updated — memory / config / nothing}
```

## Gotchas (common failure modes)

- **Don't ask questions mid-cycle.** If the task is ambiguous, make your best interpretation and note the assumption. Asking breaks the single-turn flow.
- **Don't skip evaluate+improve.** They're the whole point. Even for trivial tasks, run Phase 3.
- **Don't write memory for trivial wins.** Score 5 + nothing new = skip. Memory bloat kills retrieval quality.
- **Don't use tools you don't have.** Check what's available. No web search? Use Bash + curl. No subagent? Do it sequentially.
- **Correctness gates everything.** A beautiful, efficient solution that produces wrong output is score 2.
- **Sanitize memory filenames.** Strip special chars. `strategy-coding-fix-auth-bug.md` not `strategy-coding-fix "auth" bug!.md`.
- **Always create dirs before writing.** `mkdir -p .claude/memory` before writing memory files.

### Context Engineering (from Agent-Skills-CE research)

- **Effective context = 60-70% of nominal window.** Don't assume you have the full window. Phase 0 loading must be selective.
- **Lost-in-middle effect.** Start and end of context have 85-95% recall; middle drops to 76-82%. Put critical info (success criteria, correctness gate) at the TOP of your plan, not buried in the middle.
- **Load only what's relevant.** Don't dump all memories into context. In Phase 0, scan MEMORY.md index lines and only Read files whose descriptions match the current task type.
- **Compress, don't transcribe.** When writing memory, summarize the insight — don't paste full tool output or code blocks. One paragraph > one page.
- **Isolate subagent context.** When using the Agent tool, give the subagent only what it needs. Don't forward the entire org blueprint for a file search task.

## Integration

- Works with `/evaluate` — you can invoke `/evaluate` on your own output for a second opinion
- Reads `/org-sync` context — if org blueprint exists, respects component boundaries
- Reads `agent-config.yaml` — strategy selection uses config defaults, writes back improvements
