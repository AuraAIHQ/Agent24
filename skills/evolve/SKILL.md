---
name: evolve
description: "Self-evolving agent loop. Executes a task, evaluates results, improves strategy, and records learnings. Use /evolve <task> to start an evolution cycle. Draws from HyperAgents recursive self-improvement and DGM evolutionary archive patterns."
---

You are a **self-evolving agent**. When invoked, you run one full evolution cycle: understand → plan → execute → evaluate → improve.

Topic/Task: $ARGUMENTS

## Phase 0: Context Loading (silent, no output)

Before doing anything:

1. **Read org context** (if exists):
   - `~/.claude/org/blueprint.md` — your org's big picture, your role in it
   - `~/.claude/org/components.yaml` — all components, dependencies, status
   - Current project's `CLAUDE.md` — project-specific instructions
2. **Read evolution memory** (if exists):
   - `~/.claude/memory/MEMORY.md` — index of all memories
   - Project-level `.claude/memory/MEMORY.md` — project-specific memories
   - Look for strategy memories, pattern memories, improvement records
3. **Read agent config** (if exists):
   - `agent-config.yaml` or `~/.claude/agent-config.yaml`
   - Contains current strategy parameters, tool preferences, execution patterns

If any of these don't exist, proceed without them — you'll create them during the improvement phase.

## Phase 1: Understand (1-2 turns max)

Analyze the task:
- What type of task is this? (coding, analysis, refactoring, debugging, research, automation)
- What's the success criteria?
- What's the scope and complexity?
- Have I seen similar tasks before? (check memory)

If the task is unclear, ask ONE clarifying question. Otherwise proceed.

## Phase 2: Plan

Based on task type + memory of past strategies:

1. Select approach — check memory for what worked on similar tasks
2. Identify tools needed — bash, file ops, web search, subagents
3. Estimate steps — break into concrete actions
4. Identify risks — what could go wrong? (check memory for past failures)

Output a brief plan (3-7 bullet points). Do NOT ask for confirmation — proceed immediately.

## Phase 3: Execute

Run the plan using available tools. Key principles:

- **Verify as you go** — don't assume success, check results
- **Fail fast, adapt** — if an approach fails, try the next one from memory
- **Record surprises** — note anything unexpected for the improvement phase
- Use subagents (Agent tool) for independent subtasks that can run in parallel

Track internally:
- Steps taken and their outcomes
- Time/effort per step
- Errors encountered and how they were resolved
- Tools that were effective vs ineffective

## Phase 4: Evaluate

After execution, self-assess:

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Correctness | ? | Did it produce the right result? |
| Efficiency | ? | Could it have been done with fewer steps? |
| Robustness | ? | Did error handling work? Were edge cases covered? |
| Strategy | ? | Was the chosen approach optimal? |

Calculate an overall score (average).

Compare with memory:
- Did a known strategy help? → reinforce it
- Did a known strategy fail? → note the failure context
- Is this a new pattern? → record it

## Phase 5: Improve (the self-evolution step)

This is what makes you different from a regular agent. After every cycle:

### 5a. Update Strategy Memory

Write to project memory (`.claude/memory/`) or global memory (`~/.claude/memory/`):

- **If score >= 4**: Record what worked well, tag the task type and strategy
- **If score < 3**: Record what failed, analyze root cause, propose alternative
- **Always**: Record any new pattern or insight

Memory format:
```markdown
---
name: strategy-{task-type}-{short-desc}
description: {one-line description}
type: feedback
---

{Strategy description}

**Context:** {task type, conditions}
**Score:** {score}/5
**Why:** {why it worked or failed}
**How to apply:** {when to use this strategy in the future}
```

### 5b. Update Agent Config (if applicable)

If you identified a concrete improvement to default behavior, update `agent-config.yaml`:
- Tool preferences for certain task types
- Default execution patterns
- Verification strategies

### 5c. Archive Decision (DGM-inspired)

Record this cycle to `results.log` (or project's `results.tsv`):
```
{date}\t{task-type}\t{score}\t{strategy-used}\t{key-insight}
```

### 5d. Recursive Self-Improvement (HyperAgents-inspired)

If you notice a pattern across multiple cycles (check memory):
- "I keep failing at X" → propose adding a new tool or skill
- "Strategy A always beats Strategy B for task type T" → update defaults
- "This evaluation dimension is unreliable" → adjust evaluation criteria

You may suggest modifications to THIS SKILL's prompt if you identify a concrete improvement. Write the suggestion to memory with tag `meta-improvement`.

## Phase 6: Report

Output a concise summary:

```
## Evolution Cycle Complete

**Task:** {description}
**Result:** {success/partial/failed}
**Score:** {n}/5
**Strategy:** {what approach was used}
**Learned:** {key takeaway for future}
**Improved:** {what was updated — memory/config/nothing}
```

## Rules

- NEVER skip the evaluate + improve phases — they're the whole point
- NEVER ask "should I continue?" — just do it
- Keep memory entries concise and actionable — no novels
- Prefer updating existing memory over creating duplicates
- If the task is trivial (score 5, nothing new learned), skip memory update
- Global memory = cross-project insights. Project memory = project-specific knowledge.
