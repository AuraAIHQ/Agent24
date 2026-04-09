# AutoAgent 自进化 Agent 方案

> 基于 Claude Code 订阅的自我迭代 Agent 系统，无需 API Key。

## 背景与约束

- 只有 Claude Code 订阅（Max plan），没有独立 API Key
- 目标：构建一个能自我进化、24 小时运行的 Agent
- 参考了 Top 5 自进化 Agent 项目（见 `docs/top5.md`）
- 参考了 Anthropic 官方 Managed Agents 架构思想（三层解耦：Brain / Hands / Session）

## 为什么不用其他方案

| 方案 | 可行性 | 原因 |
|------|--------|------|
| Claude Managed Agents | ❌ | 需要 API Key，按用量计费 |
| `agent-claude.py` + Docker | ❌ | `claude_agent_sdk` 需要 API Key |
| `agent.py` + OpenAI | ❌ | 需要 OpenAI API Key |
| **Claude Code 自身作为 Agent** | ✅ | 只需订阅，自带工具/memory/schedule |

## 核心架构

```
┌──────────────────────────────────────────┐
│         Claude Code（你的订阅）             │
│                                          │
│  ┌──────────────┐   ┌────────────────┐   │
│  │ Meta-Agent    │──→│ Worker Agent   │   │
│  │ (主对话)      │   │ (subagent)     │   │
│  │ 分析+决策+改进 │←──│ 执行具体任务    │   │
│  └──────────────┘   └────────────────┘   │
│         │                                │
│  ┌──────────────────────────────────┐    │
│  │ Memory 持久化 + Schedule 定时触发  │    │
│  └──────────────────────────────────┘    │
└──────────────────────────────────────────┘
```

### 三个核心组件

| 组件 | 形式 | 作用 |
|------|------|------|
| **Skill** | `/evolve` 命令 | 启动迭代循环：执行任务 → 评估 → 改进策略 → 记录 |
| **Memory** | 持久化文件 | 跨 session 积累经验：什么有效、什么失败、如何改进 |
| **Schedule** | 定时触发 | 24 小时无人值守运行 |

### 自进化循环

```
/evolve
  │
  ├─ 1. 读 program.md 指令
  ├─ 2. 读 memory（历史经验）
  ├─ 3. 启动 worker subagent 执行任务
  ├─ 4. 评估结果（完成度、效率、错误）
  ├─ 5. 自我改进
  │     ├─ 更新 agent-config
  │     ├─ 优化 skill prompt
  │     ├─ 写入 memory
  │     └─ 记录到 results.tsv
  └─ 下一轮循环
```

## 借鉴来源

| 项目 | 借鉴什么 | 落地形式 |
|------|---------|---------|
| HyperAgents (Facebook) | 递归自改进：Meta-Agent 能改自己的改进策略 | Skill 可以修改自己的 prompt |
| DGM (Darwin Gödel Machine) | Archive 保留历史最优变体 | Memory 记录有效策略，results.tsv 追踪分数 |
| SWE-agent | Harness 设计：YAML 配置驱动 | agent-config.yaml 配置驱动 |
| MetaBot | MetaMemory 跨迭代知识积累 | Claude Code 原生 Memory 系统 |

## 文件结构

```
项目目录/
├── .claude/
│   ├── skills/               ← Skill（核心执行引擎）
│   │   ├── evolve.md         ← 自进化主循环
│   │   ├── evaluate.md       ← 自评估
│   │   └── worker.md         ← 任务执行
│   ├── memory/               ← Memory（经验积累）
│   │   ├── MEMORY.md
│   │   ├── strategies.md     ← 哪些策略有效/无效
│   │   ├── patterns.md       ← 任务模式识别
│   │   └── improvements.md   ← 改进记录
│   └── settings.json         ← Hooks（自动触发）
├── program.md                ← 人类写的指令
├── agent-config.yaml         ← agent 可进化配置
└── results.tsv               ← 迭代记录
```

## 能帮你做什么

1. **日常编码助手自动变强** — 每次任务后记录有效方法，下次自动用更好的策略
2. **自动化重复工作** — 定时跑代码审查、日志分析、依赖更新检查，每次自动改进
3. **知识积累不丢失** — Memory 跨 session 持久化，越用越聪明
4. **零额外成本** — 全部跑在 Claude Code 订阅内

## 未来扩展

如果后续获得 API Key，可以：
- 接入 Claude Managed Agents（云端运行，不占本地资源）
- 恢复 `agent-claude.py` + Docker 的 benchmark 驱动模式
- 多 agent 并行迭代

---

## 使用范围：本仓库 vs 其他项目

见下一节。
