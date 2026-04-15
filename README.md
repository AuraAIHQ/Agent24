# Agent24

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
> Self-evolving agent framework for Claude Code. No API key needed — runs entirely on your Claude Code subscription.

Agent24 gives Claude Code **persistent memory, self-evaluation, and cross-project organization awareness**. It learns from every task cycle, improves its strategies over time, and keeps all your projects aligned under one shared blueprint.

## What It Does

- **/evolve `<task>`** — Execute a task with a full evolution cycle: plan → execute → evaluate → improve → record. The agent updates its own strategy success rates and writes reusable learnings to memory.
- **/evaluate `[target]`** — Deep multi-dimension assessment of code, commits, or PRs. Correctness-gated scoring prevents inflated scores on broken work.
- **/org-sync** — Organization-level shared context. Every project knows the big picture: architecture, dependencies, component status.
- **/init** — Interactive onboarding. Guided Q&A to set up your organization, projects, tech stack, and preferences.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/jhfnetboy/Agent24.git
cd Agent24

# 2. Install globally (copies skills to ~/.claude/)
bash install.sh

# 3. Open any project and start using
cd your-project/
claude
> /init                    # first time: guided setup
> /evolve fix the auth bug # run a self-evolving cycle
> /evaluate                # evaluate recent work
> /org-sync                # check org context
```

## How Self-Evolution Works

```
 /evolve <task>
    │
    ├── Phase 0: Load context (org blueprint, memory, config)
    ├── Phase 1: Understand + Plan (infer task type, pick strategy)
    ├── Phase 2: Execute (tools, verification, adaptation)
    ├── Phase 3: Staged Evaluation
    │     ├── Stage 1: Quick correctness gate
    │     ├── Stage 2: Full multi-dimension eval (if passed)
    │     └── Stage 3: History comparison (if passed)
    ├── Phase 4: Improve
    │     ├── Write strategy memory (what worked / failed)
    │     ├── Update agent-config.yaml (success rates)
    │     ├── Append to results archive
    │     └── Detect cross-cycle patterns → meta-improvement
    └── Phase 5: Report
```

Each cycle makes the agent slightly better. Strategy success rates converge. Failed approaches get deprioritized. Winning patterns get reinforced.

## Organization Context

For teams with multiple repos forming a larger system:

```bash
> /org-sync init      # set up org blueprint + component registry
> /org-sync add       # register a new component/repo
> /org-sync update    # refresh status across all components
> /org-sync check X   # deep health check on one component
```

Every project's agent knows:
- The big picture (architecture, vision)
- Its own role and dependencies
- Upstream/downstream component status

Blueprint lives in `~/.claude/org/` — never committed to repos, always available locally.

## Project Structure

```
skills/
  evolve/SKILL.md        # self-evolution cycle skill
  evaluate/SKILL.md      # multi-dimension evaluation skill
  org-sync/SKILL.md      # organization context skill
  init/SKILL.md          # interactive onboarding skill
agent-config.yaml        # agent "DNA" — strategies, thresholds, evolution params
install.sh               # global installer
docs/                    # design docs, vendor analysis
vendor/                  # reference framework submodules (read-only)
```

## Agent Config

`agent-config.yaml` is the agent's DNA. It tracks:

- **Strategies** with success rates and usage counts (updated automatically)
- **Evaluation thresholds** (correctness gate, memory write triggers)
- **Evolution parameters** (meta-review interval, memory scope)

The agent reads this before every cycle and writes back improvements after.

## Design Principles

- **No API key required.** Everything runs as Claude Code skills — just a subscription.
- **Learn from reference frameworks.** Borrows from HyperAgents (recursive self-improvement), DGM (evolutionary archive), SWE-agent (harness design), GPTSwarm (strategy optimization), MetaBot (memory systems).
- **Correctness gates everything.** Wrong output can't score high, no matter how elegant.
- **Memory is selective.** Only novel, reusable learnings get saved. Trivial wins are skipped.
- **Org context is read-only.** Never injected into committed files. No path leaks.

## Vendor Research

See [docs/vendor-analysis.md](docs/vendor-analysis.md) for detailed analysis of 8 reference frameworks and what Agent24 borrows from each.

## Global vs Project Install

- **Global install** (`bash install.sh`): Skills available in every project. Config at `~/.claude/`.
- **Project-level**: Clone this repo, use skills directly. Config at `./agent-config.yaml`.

See [docs/usage-scope.md](docs/usage-scope.md) for details.

## License

Licensed under the [Apache License, Version 2.0](https://opensource.org/licenses/Apache-2.0). See [LICENSE](./LICENSE) for details.
