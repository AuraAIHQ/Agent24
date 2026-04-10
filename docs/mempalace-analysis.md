# MemPalace 分析 & Agent24 借鉴方案

## 一、MemPalace 核心架构

MemPalace 是 Milla Jovovich 和 Ben Sigman 开发的 AI 记忆系统，LongMemEval 基准测试 96.6% R@5（raw 模式，零 API 调用），是已发布的最高分。

### 关键设计

**1. Palace 结构（记忆宫殿隐喻）**

```
Wing（翼）→ Room（房间）→ Closet（壁橱）→ Drawer（抽屉）
   人/项目     具体话题       摘要/索引        原始内容
```

- **Wing**: 按人或项目分区（wing_kai, wing_driftwood）
- **Room**: wing 内的具体话题（auth-migration, graphql-switch）
- **Hall**: 语义走廊，同一 wing 内的关联（hall_facts, hall_events, hall_discoveries）
- **Tunnel**: 跨 wing 连接（同一 room 出现在不同 wing = 自动建隧道）
- **结构化检索提升 +34%**：wing+room 过滤 94.8% vs 全量搜索 60.9%

**2. 四层记忆栈（L0-L3）**

| 层 | 内容 | 大小 | 加载时机 |
|----|------|------|----------|
| L0 | 身份 — 我是谁 | ~50 token | 每次唤醒 |
| L1 | 关键事实 — 团队、项目、偏好 | ~120 token (AAAK) | 每次唤醒 |
| L2 | 房间召回 — 当前项目相关 | 按需 | 话题触发 |
| L3 | 深度搜索 — 全量语义查询 | 按需 | 明确请求 |

唤醒只要 ~170 token，知道整个世界。搜索按需触发。

**3. 时序知识图谱（SQLite）**

```sql
triples (subject, predicate, object, valid_from, valid_to, confidence)
```

- 事实有时间窗口：`valid_from` / `valid_to`
- 软删除：`valid_to` 标记过期，历史查询仍可见
- 时间线查询：`kg.timeline("项目A")` → 时序故事
- 对标 Zep Graphiti（Neo4j 云端 $25+/月），MemPalace 用 SQLite 免费

**4. Auto-Save Hooks**

- **Save Hook**: 每 15 条人类消息触发，阻塞 AI stop，要求先保存记忆
- **PreCompact Hook**: 上下文压缩前触发，紧急保存所有重要内容
- 幂等设计：`stop_hook_active` 标志防止无限循环
- AI 自己做分类（它有上下文知道该存什么、存到哪个 wing/room）

**5. AAAK 方言（实验性）**

- 有损压缩方言，实体编码 + 句子截断
- 用于 wake-up context loading，不是存储格式
- 目前回归：AAAK 84.2% vs raw 96.6%
- **核心教训：存原文，搜索/加载时再压缩**

---

## 二、Agent24 可借鉴的 7 个点

### 借鉴点 1：分层记忆（最重要）

**问题**：当前 Agent24 的 memory 是扁平的 — MEMORY.md 索引 + 一堆 .md 文件，没有分层。

**MemPalace 做法**：L0-L3 分层，唤醒只加载最关键的。

**Agent24 应用**：

```
~/.claude/memory/
  identity.md          ← L0: 用户是谁（/setup 生成）
  essential.md         ← L1: 自动生成的关键事实摘要（定期更新）
  MEMORY.md            ← 索引（现有）
  *.md                 ← L2/L3: 详细记忆文件（现有）
```

- `/evolve` Phase 0: 始终加载 identity.md + essential.md（< 500 token）
- 只在 MEMORY.md 索引描述匹配当前任务时才 Read 具体文件
- essential.md 由 `/evolve` Phase 4 自动维护（top 10 最重要记忆的摘要）

### 借鉴点 2：Wing/Room 层级组织

**问题**：当前记忆文件是扁平命名（strategy-coding-fix-auth.md），难以按项目/话题过滤。

**MemPalace 做法**：Wing（人/项目）→ Room（话题）→ 结构化过滤 +34%。

**Agent24 应用**（无需数据库，用文件夹）：

```
~/.claude/memory/
  wings/
    project-agent24/          ← wing = 项目
      strategy-staged-eval.md
      eval-code-quality.md
    project-polylens/
      strategy-api-design.md
    global/                   ← 跨项目记忆
      user-role.md
      feedback-git-conventions.md
```

- MEMORY.md 索引增加 wing 前缀：`- [strategy-staged-eval](wings/project-agent24/strategy-staged-eval.md)`
- `/evolve` Phase 0 只加载当前项目 wing + global wing 的记忆
- 不需要 ChromaDB — 文件夹 + Glob 就够了

### 借鉴点 3：时序有效性

**问题**：当前记忆没有时间维度。一个 6 个月前的策略记忆和昨天的同等权重。

**MemPalace 做法**：`valid_from` / `valid_to` 窗口，软删除。

**Agent24 应用**（在 YAML front-matter 中加字段）：

```yaml
---
name: strategy-coding-fix-auth
description: OAuth token refresh fix strategy
type: feedback
created: "2026-04-09"
valid_from: "2026-04-09"
valid_to: null              # null = 仍有效
importance: 4               # 1-5，用于 L1 essential 筛选
---
```

- `/evolve` Phase 4 写入时自动加 `created` 和 `valid_from`
- 过期策略可设 `valid_to`（手动或 meta-improvement 建议）
- essential.md 只从 `valid_to == null` 且 `importance >= 4` 的记忆中生成

### 借鉴点 4：Auto-Save Hooks

**问题**：当前记忆只在 `/evolve` 周期中写入。普通对话中的重要决策不会被记住。

**MemPalace 做法**：Stop Hook 每 15 条消息触发，PreCompact Hook 压缩前紧急保存。

**Agent24 应用**：

```json
// ~/.claude/settings.json
{
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/agent24-save-hook.sh"
      }]
    }],
    "PreCompact": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/agent24-precompact-hook.sh"
      }]
    }]
  }
}
```

- Save Hook: 每 N 条消息提醒 AI 保存关键决策到 memory
- PreCompact Hook: 上下文压缩前强制保存
- AI 负责分类（它知道当前话题属于哪个 wing/room）
- install.sh 安装时自动配置 hooks

### 借鉴点 5：Essential Story 自动生成

**问题**：/evolve Phase 0 加载什么？如果记忆太多，加载哪些？

**MemPalace 做法**：L1 Essential Story 从 importance 最高的记忆中自动生成。

**Agent24 应用**：

- `/evolve` Phase 4 每次运行后，扫描所有 `importance >= 4` 的有效记忆
- 生成 `essential.md`：每条记忆一行摘要，总计 < 500 token
- Phase 0 加载 identity.md + essential.md = 始终 < 600 token
- 具体记忆按需读取（L2/L3）

### 借鉴点 6：Tunnel 跨项目关联

**问题**：不同项目的记忆互相隔离，同一话题（如 auth）在多项目中的关联被忽视。

**MemPalace 做法**：同一 room 名出现在不同 wing = 自动建 tunnel。

**Agent24 应用**：

- 如果 `wings/project-A/strategy-auth.md` 和 `wings/project-B/strategy-auth.md` 都存在
- `/evolve` Phase 0 或 `/org-sync` 可以检测到关联
- 在 essential.md 中注明："auth 策略在 project-A 和 project-B 中都有记录"
- 无需额外数据结构 — 用 Glob 模式 `wings/*/strategy-auth*.md` 即可发现

### 借鉴点 7：Specialist Agent Diary

**问题**：/evolve 每次是无状态的，没有"我是一个擅长 X 的 agent"的积累。

**MemPalace 做法**：每个 specialist agent 有自己的 diary，AAAK 格式，跨会话持久化。

**Agent24 应用**：

```
~/.claude/memory/
  diary/
    evolve-diary.md        ← /evolve 的工作日记
    evaluate-diary.md      ← /evaluate 的评估日记
```

- `/evolve` Phase 5 Report 后，追加一条到 `evolve-diary.md`
- 格式：`{date} | {task-type} | {score} | {one-line insight}`
- Phase 0 读取最近 10 条日记 → 快速了解"我最近在做什么，哪些有效"
- 与 results.log archive 互补：archive 是结构化数据，diary 是叙事性摘要

---

## 三、实施优先级

### 立即可做（P0）
1. **分层记忆** — 加 identity.md + essential.md 到 Phase 0
2. **时序有效性** — front-matter 加 created/valid_from/valid_to/importance
3. **Essential Story 自动生成** — Phase 4 每次更新

### 本周可做（P1）
4. **Wing 文件夹组织** — 从扁平迁移到 wings/ 层级
5. **Auto-Save Hooks** — install.sh 安装 Stop + PreCompact hooks
6. **Skill Diary** — evolve-diary.md 跨会话积累

### 后续做（P2）
7. **Tunnel 跨项目关联** — Glob 检测 + essential.md 注明
8. **Importance 排序** — 自动衰减低频记忆的 importance
9. **AAAK 实验** — 探索 wake-up context 压缩（当记忆规模大了以后）

---

## 四、与现有 vendor 对比

| 维度 | MemPalace | MetaBot | Agent24 当前 | Agent24 目标 |
|------|-----------|---------|-------------|-------------|
| 存储 | ChromaDB + SQLite | SQLite FTS5 | 文件系统 | 文件系统 + 结构化 |
| 检索 | 语义向量搜索 | FTS5 全文 | Grep + 索引 | Glob + 索引 + 层级 |
| 结构 | Wing/Room/Hall | Folder visibility | 扁平 MEMORY.md | Wing/Room 文件夹 |
| 时序 | KG valid_from/to | 无 | 无 | YAML valid_from/to |
| 唤醒 | L0+L1 ~170 token | 无 | 读全部 MEMORY.md | identity + essential < 600 |
| Hooks | Stop + PreCompact | 无 | 无 | Stop + PreCompact |
| 成本 | 免费（本地） | 免费 | 免费 | 免费 |

**核心结论：MemPalace 的结构化分层思想完美适配 Agent24 的文件系统方案。不需要 ChromaDB，用文件夹 + YAML front-matter 就能实现 80% 的效果。**
