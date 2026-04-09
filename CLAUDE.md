# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

AutoAgent is an autonomous agent-engineering framework. A **meta-agent** (you, Claude Code) iterates on an AI agent harness (`agent.py`) by running benchmarks, diagnosing failures, editing the harness, and repeating — hill-climbing on task pass rate. The human steers via `program.md`; the meta-agent edits `agent.py`.

## Key Files

- **`agent.py`** — single-file agent harness under test. Split into two sections:
  - **Editable section** (above `FIXED ADAPTER BOUNDARY`): system prompt, tools, agent construction, orchestration. This is the meta-agent's edit surface.
  - **Fixed adapter section** (below boundary): Harbor integration + ATIF trajectory serialization. Do not modify unless the human explicitly asks.
- **`agent-claude.py`** — alternative harness using `claude_agent_sdk` (Claude Agent SDK) instead of OpenAI Agents SDK. Same editable/fixed split. Runs inside Docker container.
- **`program.md`** — meta-agent instructions + directive. Edited by the human, read by the meta-agent. Start here when beginning an experiment.
- **`tasks/`** — benchmark tasks in Harbor format (gitignored, added per branch).
- **`jobs/`** — Harbor job outputs (gitignored).
- **`results.tsv`** — experiment log tracking commit, score, pass rate, cost (gitignored).
- **`.agent/`** — optional workspace for reusable instructions/notes/prompts.

## Common Commands

```bash
# Install dependencies
uv sync

# Build base Docker image (required before running tasks)
docker build -f Dockerfile.base -t autoagent-base .

# Run a single benchmark task
rm -rf jobs; mkdir -p jobs && uv run harbor run -p tasks/ --task-name "<task-name>" -l 1 -n 1 --agent-import-path agent:AutoAgent -o jobs --job-name latest > run.log 2>&1

# Run all tasks in parallel (n=concurrency)
rm -rf jobs; mkdir -p jobs && uv run harbor run -p tasks/ -n 100 --agent-import-path agent:AutoAgent -o jobs --job-name latest > run.log 2>&1

# Clean Harbor cache
uv run harbor cache clean -f

# Docker cleanup
docker system prune -a -f
```

## Architecture

- **Two harness variants**: `agent.py` uses OpenAI Agents SDK (`openai-agents` package, `agents` module); `agent-claude.py` uses Claude Agent SDK (`claude_agent_sdk`). Both expose `AutoAgent(BaseAgent)` for Harbor.
- **Harbor framework**: provides `BaseAgent`, `BaseEnvironment`, `AgentContext`. Tasks run in Docker containers. The agent harness runs host-side and proxies shell commands into the container via `environment.exec()`.
- **ATIF trajectory format**: both harnesses serialize agent execution into ATIF JSON (`trajectory.json`) for evaluation. Scores (0.0–1.0) are written by task verifiers.
- **Registry-driven**: tools are created via `create_tools()` (OpenAI variant) or config dicts (Claude variant). Agent construction is in `create_agent()` / `get_options()`.

## Dependencies

- Python 3.12+ (`.python-version` says 3.13, Docker uses 3.12)
- Package manager: **uv** (not pip, not npm)
- Key packages: `openai-agents`, `harbor`, `pandas`, `openpyxl`, `numpy`
- Claude variant additionally uses: `claude_agent_sdk`, `python-dotenv`
- Docker required for running benchmarks

## Experiment Workflow (from program.md)

1. Establish unmodified baseline first
2. Diagnose failures from trajectories and verifier logs
3. Group by root cause, choose one general harness improvement
4. Edit harness, commit, rebuild Docker, rerun suite
5. Keep if `passed` improved; discard otherwise
6. Log every run to `results.tsv`
7. Never add task-specific hacks — improvements must generalize

## Self-Evolving Agent (Claude Code Skills)

AutoAgent also ships as a set of **Claude Code skills** that work without API keys (Claude Code subscription only):

- `/evolve <task>` — self-evolving cycle: execute → evaluate → improve → record
- `/evaluate [target]` — deep quality assessment with scoring and history
- `/org-sync` — organization-level shared context across multiple repos

Install globally: `./install.sh` → skills available in any project directory.

Config: `agent-config.yaml` — the agent's "DNA", modified by `/evolve` as it learns.

See `docs/autoagent-plan.md` and `docs/usage-scope.md` for full design docs.
