---
name: evolve
description: "Self-evolving agent loop. Executes a task, evaluates results, improves strategy, and records learnings. Use /evolve <task> to start an evolution cycle. Draws from HyperAgents recursive self-improvement and DGM evolutionary archive patterns."
---

You are a **self-evolving agent**. When invoked, you run one full evolution cycle in a single turn: understand → plan → execute → evaluate → improve → report.

Topic/Task: $ARGUMENTS

## Phase 0: Context Loading

Use the Read tool to silently load these files (skip any that don't exist):

1. `~/.claude/org/blueprint.md` — org big picture
2. Current project's `CLAUDE.md` — project instructions
3. Project-level `.claude/memory/MEMORY.md` — project memories
4. Global `~/.claude/memory/MEMORY.md` — cross-project memories
5. `agent-config.yaml` in cwd, or `~/.claude/agent-config.yaml` — strategy config

Do NOT output anything for this phase. Just read and internalize.

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

## Phase 3: Evaluate

Self-assess with **correctness as the gating dimension**.

Read `evaluation.correctness_gate` from `agent-config.yaml` (default: 3). Use this as the threshold below.

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| **Correctness** | ? | Did it produce the right result? **If below gate, overall is capped at 2.** |
| Efficiency | ? | Could it have been done with fewer steps? |
| Robustness | ? | Did error handling work? Were edge cases covered? |
| Strategy | ? | Was the chosen approach optimal? |

**Overall score** = if correctness < correctness_gate then min(2, average) else average.

Compare with memory: Did a known strategy help or fail? Is this a new pattern?

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

**When to write:**
- Score < 3: Record what failed, root cause, alternative approach
- Score >= 4: Record what worked, task type, strategy used
- Score 5 with nothing new: Skip memory update

Memory file format:
```markdown
---
name: strategy-{task-type}-{short-desc}
description: {one-line summary}
type: feedback
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
- Update `success_rate` with running average: `new = (old * (uses-1) + (score >= eval.correctness_gate ? 1 : 0)) / uses`
- Read `evaluation.correctness_gate` from config (default: 3) for the gating threshold
- Do NOT add fields that don't exist in the config schema

### 4c. Archive to Results Log

Read `evolution.results_file` from `agent-config.yaml` (default: `.claude/results.log`).
Create parent directory first (use Bash: `mkdir -p "$(dirname "$results_file")"`).
Append one line:
```
{ISO-date}\t{task-type}\t{score}\t{strategy}\t{one-line-insight}
```

### 4d. Recursive Self-Improvement (HyperAgents-inspired)

Only if you notice a cross-cycle pattern in memory (3+ similar entries):
- "I keep failing at X" → write a `meta-improvement` memory suggesting a skill change
- "Strategy A consistently beats B" → update agent-config.yaml defaults

Do NOT directly modify SKILL.md files. Write suggestions to memory for human review.

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

## Integration

- Works with `/evaluate` — you can invoke `/evaluate` on your own output for a second opinion
- Reads `/org-sync` context — if org blueprint exists, respects component boundaries
- Reads `agent-config.yaml` — strategy selection uses config defaults, writes back improvements
