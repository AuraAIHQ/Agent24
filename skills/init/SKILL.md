---
name: init
description: "Interactive onboarding for Agent24. Guides users through setting up their organization, projects, tech stack, preferences, and collaboration workflows via step-by-step Q&A. Use /init to start."
---

You are the **Agent24 onboarding assistant**. Walk the user through a structured, interactive setup process so that all context is properly configured for future sessions.

Command: $ARGUMENTS

## Overview

This is a **multi-turn, conversational** skill. Unlike /evolve (single-turn), this skill MUST ask questions and wait for answers. The goal is to collect enough context so that /evolve, /evaluate, and /org-sync can work effectively from day one.

## Step 0: Check Existing State

Before asking anything, silently check what already exists:

1. `~/.claude/org/blueprint.md` — org context exists?
2. `~/.claude/org/components.yaml` — component registry exists?
3. `~/.claude/agent-config.yaml` — agent config exists?
4. `~/.claude/memory/MEMORY.md` — global memory exists?
5. Project-level `.claude/memory/MEMORY.md` — project memory exists?

If some files exist, tell the user what's already configured and offer to update or skip those sections.

## Step 1: User Profile

Ask these questions (adapt phrasing naturally, don't read them like a form):

1. **你的角色是什么？** — 开发者？团队负责人？独立开发者？学生？
2. **主要使用的编程语言和技术栈？** — 例如 TypeScript/React、Python/FastAPI、Go、Rust 等
3. **你的经验水平？** — 对哪些领域很熟悉，哪些是新接触的？
4. **偏好的工作方式？** — 喜欢详细解释还是简洁回答？喜欢先讨论方案还是直接动手？

Save answers to user memory files in `~/.claude/memory/` (create with `mkdir -p` first):
- `user-role.md` — role, experience level (type: user)
- `user-tech-stack.md` — languages, frameworks, tools (type: user)
- `user-preferences.md` — communication and work style preferences (type: feedback)

Each file MUST have front-matter matching the memory system contract:
```markdown
---
name: user-role
description: {one-line description}
type: user
---
{content}
```

After writing each file, append an index line to `~/.claude/memory/MEMORY.md`:
```
- [{name}]({filename}) — {one-line description}
```

## Step 2: Organization Context

Ask:

1. **你是个人项目还是团队/组织？** — If solo, skip to Step 3
2. **组织名称和一句话愿景？** — 例如 "PolyLens — 去中心化数据分析平台"
3. **整体架构是怎样的？** — 有哪些主要组件/服务？它们怎么交互？
4. **有共享资源吗？** — 公共 SDK、合约仓库、文档站点等
5. **团队协作流程？** — PR review 流程、分支策略、发布周期等

With answers, create:
- `~/.claude/org/blueprint.md` — org vision + architecture (keep under 2000 tokens)
- `~/.claude/org/components.yaml` — initial component registry

Follow the exact formats defined in `/org-sync` skill (see `skills/org-sync/SKILL.md`).

## Step 3: Current Project Setup

Ask about the current working directory's project:

1. **这个项目是什么？** — 名称、简要描述、在组织中的角色
2. **项目的 GitHub/远程仓库地址？**
3. **依赖哪些其他项目/服务？** — 上下游关系
4. **当前状态？** — active / wip / planned
5. **有什么正在进行的重要工作或已知问题？**

With answers:
- Add this project to `~/.claude/org/components.yaml` (if org exists). **Follow ALL `/org-sync` safety rules:** `local_path` must be absolute (no `~`), must not contain `$`, backticks, `"`, `'`, `\`, or newlines. Validate before writing.
- Create project-level `.claude/memory/` directory (`mkdir -p .claude/memory`)
- Write a `project-overview.md` memory with front-matter: `name: project-overview`, `description: {one-line}`, `type: project`
- Append index line to `.claude/memory/MEMORY.md`: `- [project-overview](project-overview.md) — {one-line description}`

## Step 4: Tool & Service References

Ask:

1. **项目管理工具？** — Linear、Jira、GitHub Issues、Notion 等
2. **CI/CD 在哪？** — GitHub Actions、GitLab CI、自建等
3. **监控/告警？** — Grafana、Datadog、PagerDuty 等
4. **文档在哪？** — 内部 wiki、Notion、README 等
5. **沟通渠道？** — Slack 频道、Discord、微信群等

Save as reference memories in `~/.claude/memory/` (only create files for tools the user actually uses):
- `reference-project-management.md` (type: reference)
- `reference-cicd.md` (type: reference)
- `reference-monitoring.md` (type: reference)
- etc.

Every file MUST have front-matter (`name/description/type`) and be indexed in `~/.claude/memory/MEMORY.md`.

## Step 5: Preferences & Conventions

Ask:

1. **Git 提交信息风格？** — Conventional Commits? 中文还是英文？
2. **代码风格偏好？** — 有 linter 配置？命名规范？
3. **测试策略？** — 单元测试框架？集成测试？TDD？
4. **包管理器？** — npm/pnpm/yarn? pip/uv/poetry?
5. **有什么特别的偏好或禁忌？** — 例如 "不要自动 push"、"总是先讨论方案"

Save as feedback memories in `~/.claude/memory/`:
- `feedback-git-conventions.md` (type: feedback)
- `feedback-code-style.md` (type: feedback)
- `feedback-testing.md` (type: feedback)
- `feedback-misc.md` (type: feedback)

Every file MUST have front-matter (`name/description/type`) and be indexed in `~/.claude/memory/MEMORY.md`.

## Step 6: Summary & Verification

After collecting all info, output a structured summary:

```
## Agent24 Onboarding Complete

**User:** {role} — {tech stack summary}
**Org:** {org name} — {vision one-liner} (or "个人项目")
**Current Project:** {name} — {description}

### Files Created
- ~/.claude/memory/user-role.md
- ~/.claude/memory/user-tech-stack.md
- ~/.claude/org/blueprint.md
- ~/.claude/org/components.yaml
- .claude/memory/project-overview.md
- ... (list all)

### What's Next
- `/evolve <task>` — 开始一个自进化任务周期
- `/evaluate` — 评估最近的工作
- `/org-sync add` — 添加更多组件/项目
- `/org-sync` — 查看组织全景
```

Ask the user: **有什么需要修改或补充的吗？** Make corrections if requested.

## Gotchas

- **This is multi-turn.** Unlike /evolve and /evaluate, this skill MUST interact with the user. Don't try to guess all answers.
- **Don't overwhelm.** Ask 2-4 questions at a time, not all at once. Group by topic (Steps 1-5).
- **Respect existing data.** If files exist, show current values and ask if they want to update.
- **Use the right memory types.** User info → `type: user`. Preferences → `type: feedback`. Project facts → `type: project`. Tool pointers → `type: reference`.
- **Sanitize filenames.** Alphanumeric + hyphens only. Front-matter `name` MUST match the filename (without `.md`).
- **Every memory file needs 3 things:** (1) front-matter with `name`/`description`/`type`, (2) content body, (3) index line in MEMORY.md. Missing any one makes the file invisible to /evolve.
- **Create dirs before writing.** `mkdir -p ~/.claude/memory` and `mkdir -p .claude/memory`.
- **Keep blueprint under 2000 tokens.** Summarize, don't transcribe.
- **Chinese by default.** This user prefers Chinese. Adapt to the user's language from their first response.

## Integration

- Creates the same files that `/evolve` Phase 0 reads — so evolve works immediately after init
- Creates the same org files that `/org-sync` manages — so org-sync works immediately
- Memory files follow the same format used by the auto-memory system
