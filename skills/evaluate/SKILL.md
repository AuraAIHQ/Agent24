---
name: evaluate
description: "Deep evaluation of recent work or a specific file/commit/PR. Scores across multiple dimensions, compares with historical performance, and records insights. Use /evaluate [target] to assess work quality."
---

You are a **self-evaluation agent**. Perform a deep assessment of the specified target.

Target: $ARGUMENTS

If no target specified, evaluate the most recent work (last commit, or current uncommitted changes).

## Step 1: Identify What to Evaluate

Determine the target:
- If a file path → evaluate that file's quality
- If "last commit" or empty → `git diff HEAD~1` and evaluate the changes
- If a PR number → fetch PR diff and evaluate
- If "project" → evaluate overall project health
- If a task description → evaluate how well it was completed

## Step 2: Multi-Dimension Assessment

Score each dimension 1-5:

| Dimension | What to Check |
|-----------|---------------|
| **Correctness** | Does it do what it's supposed to? Logic errors? Edge cases? |
| **Code Quality** | Clean, readable, maintainable? Follows project conventions? |
| **Security** | OWASP top 10? Input validation? Secrets exposed? |
| **Performance** | Obvious bottlenecks? N+1 queries? Unnecessary computation? |
| **Completeness** | Missing error handling? Untested paths? TODO items? |
| **Architecture** | Fits the larger system? Right abstraction level? |

For non-code targets, adapt dimensions:
- Documentation: Accuracy, Clarity, Completeness, Up-to-date, Actionable
- Config: Correctness, Security, Portability, Documentation, Defaults

## Step 3: Compare with History

Check memory for:
- Previous evaluations of similar work → is quality trending up or down?
- Known project-specific issues → are they being addressed or repeated?
- Strategies that improved quality in the past → are they being applied?

## Step 4: Actionable Findings

List findings in priority order:

```
### Critical (must fix)
- ...

### Important (should fix)
- ...

### Suggestions (nice to have)
- ...

### Strengths (keep doing)
- ...
```

## Step 5: Record to Memory

If this evaluation revealed something new and reusable:
- A recurring quality issue → save as feedback memory
- A pattern that consistently scores high → save as strategy memory
- A project-specific convention discovered → save as project memory

Only save genuinely useful insights. Don't save if the evaluation was routine and unsurprising.

## Step 6: Output Summary

```
## Evaluation: {target}

**Overall Score:** {n}/5
**Verdict:** {excellent / good / needs work / concerning}

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| ... | .../5 | ... |

**Top Action Items:**
1. ...
2. ...
3. ...

**Compared to History:** {improving / stable / declining / first evaluation}
```

## Rules

- Be honest and specific — vague praise is useless
- Always give actionable items, not just scores
- Compare with history when possible — trends matter more than snapshots
- Don't evaluate your own evaluation (no recursion here)
