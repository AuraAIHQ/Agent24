---
name: org-sync
description: "Sync and display organization-level context: blueprint, components, dependencies, and cross-repo status. Use /org-sync to check org status, or /org-sync update to refresh from repos."
---

You manage the **organization-level shared context** system. This ensures every project's agent knows:
- The big picture (blueprint)
- Its own role and responsibility
- Upstream/downstream dependencies
- Cross-repo progress and status

Command: $ARGUMENTS

## What This System Does

Your open-source org has multiple repos/products that form a larger system. Instead of explaining context every time you work on a component, this system maintains a shared "org brain" at `~/.claude/org/`.

## File Structure

```
~/.claude/org/
├── blueprint.md          ← The big picture: vision, architecture, how pieces fit together
├── components.yaml       ← Registry of all components: repos, owners, status, dependencies
└── status.md             ← Live status: what's passing, what's blocked, recent changes
```

## Commands

### `/org-sync` (no args) — Show Current Context

1. Read `~/.claude/org/blueprint.md` and summarize the big picture
2. Read `~/.claude/org/components.yaml` and show component map
3. Identify current project's role (match cwd to component registry)
4. Show this project's upstream/downstream dependencies and their status
5. Highlight any blockers or cross-repo issues

Output format:
```
## Org Context: {org name}

**Blueprint:** {one-line vision}
**You are in:** {component name} — {role description}

### Dependencies
| Direction | Component | Repo | Status | Notes |
|-----------|-----------|------|--------|-------|
| ⬆ upstream | ... | ... | ✅/⚠️/❌ | ... |
| ⬇ downstream | ... | ... | ✅/⚠️/❌ | ... |

### Cross-Repo Status
- {component}: {status summary}
- ...

### Blockers
- {any cross-repo blockers affecting this project}
```

### `/org-sync update` — Refresh Status

For each component in `components.yaml` that has a local path:
1. Check if the repo exists locally
2. Run `git -C {path} log --oneline -3` to see recent activity
3. Check for CI status if available (gh CLI)
4. Update `status.md` with findings

### `/org-sync init` — Initialize Org Context

Interactive setup:
1. Ask for org name and vision (one sentence)
2. Ask for the first component (this repo)
3. Create `blueprint.md` and `components.yaml` with initial content
4. Guide user to add more components

### `/org-sync add {component}` — Add a Component

Add a new component to the registry:
1. Ask for: name, repo URL, local path, description, role
2. Ask for: upstream dependencies, downstream dependents
3. Update `components.yaml`
4. Update `blueprint.md` if the architecture description needs adjustment

### `/org-sync check {component}` — Deep Check a Component

1. Go to the component's local path
2. Read its CLAUDE.md, README.md, package.json/pyproject.toml
3. Check test status, recent commits, open issues
4. Report back with health assessment

## Blueprint Format (`blueprint.md`)

```markdown
# {Org Name} Blueprint

## Vision
{One paragraph: what the org is building overall}

## Architecture
{How the pieces fit together — data flow, dependency layers}

## Components
{Brief description of each component's role — NOT duplicating components.yaml}

## Shared Conventions
{Common patterns across repos: language, framework, deploy, testing}

## Key Resources
- Contracts repo: {url}
- SDK repo: {url}
- Docs: {url}
- CI Dashboard: {url}
```

## Components Registry Format (`components.yaml`)

```yaml
org: "{org name}"

components:
  component-name:
    repo: "https://github.com/org/repo"
    local_path: "~/Dev/org/repo"       # optional, for local checks
    description: "What this component does"
    role: "Brief role in the system"
    owner: "team or person"
    status: "active"                    # active | wip | planned | deprecated
    upstream:                           # what this depends on
      - component-a
      - component-b
    downstream:                         # what depends on this
      - component-c
    shared_resources:                   # resources other components should know about
      contracts: "src/contracts/"
      sdk: "packages/sdk/"
      api_docs: "docs/api.md"

shared:
  contracts_repo: "https://github.com/org/contracts"
  sdk_repo: "https://github.com/org/sdk"
  test_infra: "https://github.com/org/test-infra"
  ci_dashboard: "https://..."
```

## How Other Skills Use This

The `/evolve` skill reads org context in Phase 0. This means when you run `/evolve` in any project:
- It knows the project's role in the larger system
- It knows what upstream components it depends on
- It can check if upstream components recently changed (potential breakage)
- It can avoid changes that would break downstream consumers

## Auto-injection into CLAUDE.md

When `/org-sync init` runs, it adds a reference to the current project's CLAUDE.md:

```markdown
## Org Context
This project is part of {org name}. See `~/.claude/org/blueprint.md` for the full architecture.
Role: {role}. Upstream: {list}. Downstream: {list}.
```

This ensures every Claude Code session in this project automatically knows its place.

## Rules

- NEVER overwrite user edits to blueprint.md — merge carefully
- Components.yaml is the source of truth for structure
- Status.md is ephemeral and can be regenerated anytime
- Keep blueprint concise — it's injected into every session's context
- If a component's local repo doesn't exist, skip it gracefully
