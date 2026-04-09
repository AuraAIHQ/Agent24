---
name: evaluate
description: "Deep evaluation of recent work or a specific file/commit/PR. Scores across multiple dimensions with correctness-gated scoring, compares with historical performance, and records insights. Use /evaluate [target] to assess work quality."
---

You are a **self-evaluation agent**. Perform a thorough assessment of the specified target in a single turn.

Target: $ARGUMENTS

## Step 1: Identify What to Evaluate

Determine the target (in priority order):
- If a file path is given → verify it exists with the Read tool (not `ls`), then evaluate the file
- If "last commit" is given → check `git rev-list --count HEAD`:
  - If >= 2: use `git diff HEAD~1`
  - If == 1: use `git show HEAD` (only commit, can't diff against parent)
  - If 0 or not a git repo: evaluate the working directory
- If a PR number is given → validate it is digits only (reject anything with non-digit chars); check `which gh`; if available, run `gh pr diff -- "$n"` (the `--` prevents option injection); if gh unavailable, say so and skip
- If "project" is given → evaluate overall project health (read key files)
- If nothing is given → first check `git rev-parse --is-inside-work-tree` to detect if in a git repo:
  - **Not a git repo:** evaluate the working directory (read key files)
  - **In a git repo**, use this fallback chain:
    1. `git diff --cached` — if non-empty, evaluate staged changes
    2. `git diff` — if non-empty, evaluate unstaged changes
    3. `git rev-list --count HEAD` >= 2 → `git diff HEAD~1` (last commit)
    4. `git rev-list --count HEAD` == 1 → `git show HEAD`
    5. Clean repo with nothing to evaluate → report "nothing to evaluate"

**Always verify the target exists before proceeding.** If it doesn't, report that clearly and stop.

## Step 2: Multi-Dimension Assessment

Score each dimension 1-5 with concrete evidence:

| Dimension | What to Check | Evidence Required |
|-----------|---------------|-------------------|
| **Correctness** | Logic errors, edge cases, wrong output | Cite specific lines/functions |
| **Code Quality** | Readability, conventions, maintainability | Reference project style |
| **Security** | Injection, secrets, input validation | Name the vulnerability class |
| **Performance** | Bottlenecks, N+1, unnecessary work | Identify the hot path |
| **Completeness** | Missing error handling, TODO items | List what's missing |
| **Architecture** | Fits larger system, right abstraction | Reference project structure |

For non-code targets, adapt:
- Documentation: Accuracy, Clarity, Completeness, Freshness, Actionability
- Config: Correctness, Security, Portability, Documentation, Defaults

**Correctness gates the overall score:** if correctness < 3, overall is capped at 2 regardless of other dimensions.

## Step 3: Compare with History

Read `.claude/memory/MEMORY.md` and `~/.claude/memory/MEMORY.md` (if they exist).
Look for:
- Previous evaluation memories → trend (improving / stable / declining)
- Known project issues → being addressed or repeated?
- Relevant strategy memories → being applied?

If no history exists, note "first evaluation" and move on.

## Step 4: Actionable Findings

List findings grouped by severity with **specific file:line references**:

### Critical (must fix)
- {file:line} — {issue description}

### Important (should fix)
- {file:line} — {issue description}

### Suggestions (nice to have)
- {description}

### Strengths (keep doing)
- {description}

## Step 5: Record to Memory (selective)

Only write to memory if this evaluation revealed something **new and reusable**:
- A recurring quality issue → save as feedback memory
- A project convention discovered → save as project memory
- Nothing new → skip (most evaluations should skip this step)

Storage contract (same as `/evolve`):
- Create dir: `mkdir -p .claude/memory` (or `~/.claude/memory/` for global)
- File naming: `eval-{sanitized-topic}.md` (alphanumeric + hyphens only)
- Front-matter: standard memory format with `type: feedback` or `type: project`
- After writing, append to `MEMORY.md` index using this exact format:
  ```
  - [{name}]({filename}) — {one-line description}
  ```

## Step 6: Output Summary

```
## Evaluation: {target}

**Overall Score:** {n}/5
**Verdict:** {excellent / good / needs work / concerning}

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Correctness | {n}/5 | {one line} |
| Code Quality | {n}/5 | {one line} |
| Security | {n}/5 | {one line} |
| Performance | {n}/5 | {one line} |
| Completeness | {n}/5 | {one line} |
| Architecture | {n}/5 | {one line} |

**Top Action Items:**
1. {most critical fix}
2. {second priority}
3. {third priority}

**Compared to History:** {improving / stable / declining / first evaluation}
```

## Gotchas

- **Don't give vague praise.** "Code looks good" is useless. Cite specific strengths.
- **Don't let high scores mask bad correctness.** Elegant wrong code is still wrong. Correctness < 3 caps overall at 2.
- **Don't assume gh CLI is available.** Check with `which gh` before using it. Fall back to git commands.
- **Don't evaluate your own evaluation.** No recursion. If /evolve calls you, just return the result.
- **Don't write memory for routine evaluations.** Only write if you discovered something genuinely reusable.
- **Always verify target exists.** `git log`, `ls`, or `gh` before analyzing. Don't evaluate phantom diffs.

## Integration

- Called by `/evolve` in Phase 3 for deeper second-opinion evaluation
- Reads the same memory system as `/evolve` for history comparison
- Respects org context from `/org-sync` for architecture dimension
