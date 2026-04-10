---
name: org-sync
description: "Sync and display organization-level context: blueprint, components, dependencies, and cross-repo status. Use /org-sync to check org status, or /org-sync init to set up your org."
---

You manage the **organization-level shared context** system. This ensures every project's agent knows the big picture, its role, and its dependencies.

Command: $ARGUMENTS

## File Locations

All org context lives in `~/.claude/org/` (global, not committed to any repo):

```
~/.claude/org/
├── blueprint.md          ← Vision, architecture, how pieces fit together (< 2000 tokens)
├── components.yaml       ← Registry of all components with dependencies
└── status.md             ← Auto-generated status snapshot (ephemeral, regeneratable)
```

**Important:** Org context is NEVER injected into project CLAUDE.md files. It's read on-demand by skills that need it. This avoids leaking local paths into committed files.

## Commands

### `/org-sync` (no args) — Show Current Context

1. Read `~/.claude/org/blueprint.md` — summarize big picture
2. Read `~/.claude/org/components.yaml` — parse component registry
3. Match current working directory to a component (compare `cwd` with `local_path` values)
4. Show this project's upstream/downstream and their status

Output:
```
## Org Context: {org name}

**Blueprint:** {one-line vision}
**Current component:** {name} — {role}

| Direction | Component | Status | Notes |
|-----------|-----------|--------|-------|
| upstream | {name} | {status} | {notes} |
| downstream | {name} | {status} | {notes} |
```

If org context doesn't exist, suggest running `/org-sync init`.

### `/org-sync init` — Initialize Org Context

1. Ask for: org name, one-sentence vision
2. Ask for: first component (this repo) — name, role, description
3. Create `~/.claude/org/` directory (use Bash: `mkdir -p ~/.claude/org`)
4. Write `blueprint.md` and `components.yaml` with initial content
5. Guide user to add more components with `/org-sync add`

### `/org-sync add` — Add a Component

1. Ask for: component name, repo URL, local path (optional), description, role
2. Ask for: upstream dependencies (list of component names), downstream dependents
3. Read existing `components.yaml`, append the new component
4. Update `blueprint.md` component list if needed

**Path validation:** If `local_path` is provided:
- It MUST be an absolute path starting with `/`
- Reject paths containing `$`, backticks, `"`, `'`, `\`, or newlines (these enable injection)
- Verify it exists using the Read tool or `test -d` with the path passed as a variable, not interpolated
- If validation fails, report the issue and do not add the component

### `/org-sync update` — Refresh Status

For each component in `components.yaml` that has a `local_path`:
1. Read the path from YAML using the Read tool (never parse YAML with shell)
2. Validate: must start with `/`, must not contain `$`, backticks, `"`, `'`, or `\`
3. Verify it's a git repo: use Bash with path stored in a shell variable:
   ```bash
   path='/absolute/path/here'
   test -e "$path/.git" && git -C "$path" log --oneline -3
   ```
4. If `.git` doesn't exist (not a file or directory), skip it and note in status.md
5. Write findings to `~/.claude/org/status.md`

**Security:** NEVER interpolate paths directly into command strings. Always assign to a shell variable first and reference with `"$var"`. This prevents command injection even with adversarial paths.

### `/org-sync check {component}` — Deep Check One Component

1. Find component in `components.yaml`
2. If `local_path` exists, read its CLAUDE.md, README.md, and check recent git activity
3. Report health: recent commits, test status, open issues

### `/org-sync repo {url}` — Connect Org Context to a Shared Git Repo

**Problem:** `~/.claude/org/` is local-only. Team members need to share blueprint and components.

**Solution:** Use a shared git repo as the source of truth for org context.

1. Validate URL: must start with `https://` or `git@`. Reject URLs containing `$`, backticks, `"`, `'`, `\`, newlines, `;`, `&`, `|`, or whitespace (except in `git@host:path` format).
2. If `~/.claude/org/` already has `.git`: assign URL to variable, then update remote: `url='validated-url'; git -C ~/.claude/org remote set-url origin "$url"`
3. If `~/.claude/org/` exists but is NOT a git repo:
   - Generate unique backup name: `backup_dir="$HOME/.claude/org.bak.$(date +%s)"`
   - Back up: `mv ~/.claude/org/ "$backup_dir"`
   - Clone: assign URL to variable first: `url='...'; git clone "$url" ~/.claude/org/`
   - If clone fails: `rm -rf ~/.claude/org/ ; mv "$backup_dir" ~/.claude/org/` and report error
   - If clone succeeds: `cp -rn "$backup_dir"/. ~/.claude/org/ 2>/dev/null && rm -rf "$backup_dir"` (copies dotfiles too; only deletes backup if copy succeeds)
4. If `~/.claude/org/` doesn't exist: `url='validated-url'; git clone "$url" ~/.claude/org/`
5. Report: "Org context now synced to {url}"

### `/org-sync pull` — Pull Latest Org Context from Shared Repo

1. Check `~/.claude/org/` is a git repo (`test -e ~/.claude/org/.git`)
2. If not: report "Org context is not connected to a repo. Run `/org-sync repo {url}` first."
3. If yes: `git -C ~/.claude/org pull --rebase`
4. Report changes: what files were updated

### `/org-sync push` — Push Local Changes to Shared Repo

1. Check `~/.claude/org/` is a git repo
2. Check for uncommitted changes: `git -C ~/.claude/org status --porcelain`
3. If changes exist:
   - Stage: `git -C ~/.claude/org add -A`
   - Commit (safe quoting): `host=$(hostname); git -C ~/.claude/org commit -m "org-sync: update from $host"`
   - Push: `git -C ~/.claude/org push`
4. Report what was pushed

**Security:**
- URL must start with `https://` or `git@` — reject all other schemes
- Reject URLs containing: `$`, backticks, `"`, `'`, `\`, newlines, `;`, `&`, `|`, or spaces
- Always assign URL to a shell variable and quote it: `url='...'; git clone "$url" ...`
- Commit message uses a fixed format — hostname is passed via variable, never interpolated:
  ```bash
  host=$(hostname)
  git -C ~/.claude/org commit -m "org-sync: update from $host"
  ```

### Team Workflow

```
Founder:
  /org-sync init          → create blueprint + components.yaml
  /org-sync repo {url}    → push to shared repo

New member:
  /org-sync repo {url}    → clone shared org context
  /setup                  → personal setup (identity, preferences)
  /org-sync add           → register their component

Any member:
  /org-sync pull          → get latest from team
  /org-sync update        → refresh status
  /org-sync push          → share changes back
```

## Blueprint Format

**Hard limit: < 2000 tokens.** This is loaded into context by /evolve on every cycle (Phase 0). Brevity is critical — every extra token here competes with task context.

**Context Engineering rules for blueprint:**
- Vision: 1-2 sentences max
- Architecture: ASCII diagram preferred over prose (higher info density)
- Components: one line each — `name: role` format. Role = what it does in the system (e.g. "API gateway"). Description = how it works (lives in components.yaml, NOT here)
- Put the most frequently referenced info at the TOP (high recall position)

```markdown
# {Org Name}

## Vision
{1-2 sentences — what the org is building and why}

## Architecture
{ASCII diagram showing data flow / dependency layers}
{Example:}
{  frontend → api-gateway → [auth, data-service] → database }

## Components
- **{current-project}**: {role in 5-10 words}  ← always list current project first
- {name}: {role in 5-10 words}

## Shared Resources
- Contracts: {repo url}
- SDK: {repo url}
- Docs: {url}
```

**Anti-patterns to avoid:**
- Don't put component descriptions here (use components.yaml)
- Don't put status here (use status.md)
- Don't put dependency details here (use components.yaml upstream/downstream)
- Don't use paragraphs where a bullet point suffices

## Components Registry Format

```yaml
org: "{org name}"
schema_version: 1

components:
  component-name:
    repo: "https://github.com/org/repo"
    local_path: "/absolute/path/to/repo"   # optional, must be absolute
    description: "What this component does"
    role: "Brief role in the system"
    status: "active"                        # active | wip | planned | deprecated
    upstream:                               # component names this depends on
      - other-component
    downstream:                             # component names that depend on this
      - another-component

shared:
  contracts_repo: "https://github.com/org/contracts"
  sdk_repo: "https://github.com/org/sdk"
```

## Gotchas

- **Don't inject org context into CLAUDE.md.** Org data is local/global only. Committing it leaks paths and creates merge conflicts across team members.
- **Don't use `~` in local_path.** Use absolute paths (`/Users/...` or `/home/...`). Tilde expansion is unreliable in many contexts.
- **Reject dangerous path characters.** Paths containing `$`, backticks, `"`, `'`, or `\` must be rejected at write-time. These enable command injection.
- **Never interpolate paths into command strings.** Always use shell variables: `path='/foo'; git -C "$path" log`. Never `git -C "/foo" log` where `/foo` came from YAML.
- **Check for .git before running git commands.** A valid directory isn't necessarily a git repo. Use `test -e "$path/.git"` (not `-d`, because worktrees/submodules use a `.git` file).
- **Don't parse YAML with shell tools.** Use the Read tool to read `components.yaml`, then parse the content. Never `cat | grep` YAML.
- **Keep blueprint under 2000 tokens.** It's loaded by /evolve on every cycle. If it's too long, it wastes context budget.
- **status.md is ephemeral.** It can be deleted and regenerated anytime. Don't put important decisions there.
- **Dependencies are component names, not paths.** Always reference by the key in `components:`, never by path or URL.

### Context Engineering

- **Blueprint is high-frequency context.** It's loaded in every /evolve cycle (Phase 0). Keep it under 2000 tokens. Architecture diagram + one-line-per-component is the target density.
- **Put current project info at the top of blueprint output.** When /org-sync shows context, the current component's info should appear first (high recall position), not alphabetically sorted.
- **components.yaml is low-frequency detail.** It stores full metadata but is only read on-demand. Don't duplicate its content in blueprint.md.
- **Compress status.** `status.md` should be one line per component: name + status + last commit date. Not full git logs.

## Integration

- `/evolve` reads `blueprint.md` in Phase 0 to understand project boundaries
- `/evaluate` uses org context for architecture dimension scoring
- All three skills share the same memory system in `~/.claude/memory/`
