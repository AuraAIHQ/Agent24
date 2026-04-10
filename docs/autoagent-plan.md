# Agent24 产品设计文档

> 自进化 Claude Code 技能组：执行 → 评估 → 进化，每个循环都让 Agent 更聪明。

## 产品定位

Agent24 是一组安装到 `~/.claude/skills/` 的 **Claude Code Skills**，无需 API Key，只需 Claude Code 订阅。

**四个核心特征：**
- **自我进化** — 每次执行后评估+改进策略，越用越强
- **分层记忆** — L0-L3 按需加载，temporal validity，跨 session 持久化
- **组织感知** — 蓝图 + 组件依赖 + 跨 repo 状态 + 跨机器同步
- **主动通信** — Agent 之间通过 Nostr 协议广播-订阅-响应（规划中）

## 架构

```
┌─────────────────────────────────────────────────┐
│              Claude Code（你的订阅）               │
│                                                 │
│  ┌──────────────────────────────────────────┐   │
│  │ /evolve  — 自进化主循环                    │   │
│  │   Phase 0: 分层记忆加载 (L0-L3)           │   │
│  │   Phase 1: 理解 + 计划                    │   │
│  │   Phase 2: 执行 (可 spawn Agent 子任务)    │   │
│  │   Phase 3: 评估 (自评 + 可选外部评估)      │   │
│  │   Phase 4: 改进 (memory + config + archive)│   │
│  │   Phase 5: 报告                           │   │
│  └──────────────────────────────────────────┘   │
│                                                 │
│  ┌─────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │ /setup  │ │ /evaluate│ │ /org-sync        │ │
│  │ 交互初始化│ │ 独立评估  │ │ 组织上下文管理   │ │
│  └─────────┘ └──────────┘ └──────────────────┘ │
│                                                 │
│  ┌──────────────────────────────────────────┐   │
│  │ Memory System                            │   │
│  │  L0: identity.md (~100 token, 每次加载)   │   │
│  │  L1: essential.md + blueprint (<2500 tok) │   │
│  │  L2: 按索引选择性加载相关 memory            │   │
│  │  L3: 深度 grep 搜索 (仅需要时)             │   │
│  └──────────────────────────────────────────┘   │
│                                                 │
│  ┌──────────────────────────────────────────┐   │
│  │ Auto-Save Hooks                          │   │
│  │  Stop: 每 15 条消息自动保存 memory          │   │
│  │  PreCompact: 上下文压缩前紧急保存           │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
  ┌─────────────┐          ┌────────────────┐
  │ Org Context  │          │ Agent Speaker  │
  │ ~/.claude/org│          │ (Nostr MCP)    │
  │ 可 git 同步  │          │ 跨 Agent 通信   │
  └─────────────┘          └────────────────┘
```

## 技能清单

| 技能 | 命令 | 功能 |
|------|------|------|
| **evolve** | `/evolve <task>` | 自进化主循环：执行→评估→改进→记录 |
| **evaluate** | `/evaluate [target]` | 独立多维度评估（代码/commit/PR/项目） |
| **setup** | `/setup` | 交互式初始化：收集用户/组织/项目/偏好信息 |
| **org-sync** | `/org-sync [cmd]` | 组织上下文管理：蓝图/组件/状态/git 同步 |

## 评估系统

### 自评估（默认）

Phase 3 分阶段评估：
1. **Stage 1**: 正确性快速检查（correctness gate）
2. **Stage 2**: 全维度评估（correctness/efficiency/robustness/strategy）
3. **Stage 3**: 历史比较（与 memory 中的策略对比）

正确性门控：correctness < gate → overall 封顶为 2，防止"漂亮但错误"的高分。

### 外部评估（可选，配置驱动）

```yaml
# agent-config.yaml
evaluation:
  evaluator: "self"          # 默认自评
  # evaluator: "codex"       # Codex MCP 评审
  # evaluator: "agent-speaker"  # 远程 Agent 评审
  # evaluator: "dual"        # 双重评审
```

| 模式 | 工作方式 | 适用场景 |
|------|---------|---------|
| `self` | Phase 3 内部评估 | 默认，零配置 |
| `codex` | 发 diff 给 Codex MCP，Codex 打分 | 有 Codex 订阅时 |
| `agent-speaker` | 发 diff 给远程 Agent via Nostr | 团队互评 |
| `dual` | 同时跑 Codex + Agent，取外部平均分 | 高可靠性需求 |

**偏差追踪**：自评分数始终记录为 `self_score`，外部分数为 `external_score`。Phase 5 报告展示对比表，长期可观察自评偏差趋势。

## 记忆系统

### 分层加载（MemPalace 启发）

| 层 | 内容 | 大小 | 加载时机 |
|----|------|------|----------|
| L0 | identity.md — 用户身份 | ~100 token | 每次 /evolve |
| L1 | essential.md + blueprint.md | <2500 token | 每次 /evolve |
| L2 | MEMORY.md 索引匹配 → 选择性读取 | 按需 | 任务相关时 |
| L3 | grep 全量搜索 | 按需 | 知识缺口时 |

### 时间有效性

```yaml
# 每个 memory 文件的 front-matter
created: "2026-04-10"
valid_from: "2026-04-10"
valid_to: null          # null = 仍然有效
importance: 4           # 1-5, essential.md 只收录 ≥4
```

### Essential Story（自动生成）

Phase 4e 自动从 importance ≥ 4 的 memory 中提取 top 10，生成 `essential.md`（<500 token），作为 L1 层快速恢复上下文。

## 组织上下文

### 文件结构

```
~/.claude/org/
├── blueprint.md          ← 愿景 + 架构图 (<2000 token)
├── components.yaml       ← 组件注册表 (名称/角色/依赖/状态)
└── status.md             ← 自动生成的状态快照 (可删除重建)
```

### 跨机器同步

通过 git repo 共享：
```bash
# 创建者
/org-sync init          → 创建 blueprint + components.yaml
/org-sync repo {url}    → 推送到共享 repo

# 新成员
/org-sync repo {url}    → 克隆共享 org context
/setup                  → 个人初始化

# 日常
/org-sync pull          → 拉取最新
/org-sync push          → 推送变更
```

## Agent 通信（规划中）

### 基于 Nostr 协议

```
Agent A (dev)              Relay              Agent B (marketing)
    |-- status_update ------>|                      |
    |                        |--- push ------------>|
    |                        |<--- trigger ---------|
    |<-- request ------------|                      |
    |-- response ----------->|--- push ------------>|
```

### 已完成

- agent-speaker CLI：消息发送/查询/时间线
- MCP Server：5 个 agent 工具（send_message, query_messages, timeline, init_identity, manage_relays）
- 协议设计文档：消息类型系统、团队群组、心跳感知、流程触发链

### 待开发

- 专用 Relay（fork strfry）
- Agent 注册（Kind 0 profile + agent 扩展）
- 订阅机制（REQ 长连接）
- 流程触发引擎
- Agent 发现（按能力/角色搜索）

## 进化历史

### 借鉴来源

| 项目 | 借鉴内容 | 落地形式 |
|------|---------|---------|
| HyperAgents (Meta) | 递归自改进、分阶段评估 | /evolve Phase 3 staged evaluation |
| DGM (Darwin Gödel Machine) | Archive + 血统追踪 | results.log YAML 多文档 + parent 链 |
| MemPalace | 分层记忆、temporal validity、auto-save hooks | L0-L3 + front-matter + hooks |
| SWE-agent | YAML 配置驱动 | agent-config.yaml |

### 思路来源：AutoAgent

Agent24 的核心理念——"meta-agent 持续迭代 agent harness"——来自 [kevinrgu/autoagent](https://github.com/kevinrgu/autoagent)。

AutoAgent 的模式：meta-agent (Claude Code) 运行 benchmark → 诊断失败 → 编辑 `agent.py` → 重跑 → 爬坡 pass rate。这个"执行-评估-改进"循环是 Agent24 `/evolve` 的直接灵感来源。

**关键差异：**

| | AutoAgent | Agent24 |
|---|-----------|---------|
| 进化对象 | `agent.py` 源代码 | `agent-config.yaml` + memory |
| 执行环境 | Docker + Harbor benchmark | Claude Code 任意项目 |
| 评估方式 | ATIF 轨迹 + 外部验证器 | 自评估 (Phase 3) + 可选外部 |
| 需要 API Key | 是 | 否（订阅即可）|

### 从 AutoAgent 到 Agent24

| 阶段 | 形态 | 进化对象 | 验证方式 |
|------|------|---------|---------|
| v1: AutoAgent | agent.py + Docker | 源代码 | ATIF 轨迹 + 外部验证器 |
| v2: Agent24 Skills | SKILL.md + config | agent-config.yaml + memory | 自评估 (Phase 3) |
| v3: + 外部评估 | + Codex/Agent MCP | 同上 | 自评 + 外部评审 |
| v4: + 通信 (规划中) | + Agent Speaker | 同上 + 跨 Agent 协调 | 互评 + 组织级反馈 |

## 安装

```bash
git clone https://github.com/jhfnetboy/Agent24.git
cd Agent24
bash install.sh    # 复制 skills 到 ~/.claude/skills/
```

## 配置文件

- `agent-config.yaml` — Agent 的 "DNA"，/evolve 自动修改
- `~/.claude/org/blueprint.md` — 组织蓝图 (<2000 token)
- `~/.claude/org/components.yaml` — 组件注册表
- `~/.claude/memory/` — 全局记忆
- `.claude/memory/` — 项目级记忆
