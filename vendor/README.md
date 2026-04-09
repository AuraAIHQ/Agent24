# Vendor: Reference Frameworks

These are git submodules of top open-source projects we study and borrow ideas from.
**Do not modify** — read-only references for learning.

## Self-Evolving Agent Frameworks (Top 5 研究)

| Project | Stars | What We Learn |
|---------|-------|---------------|
| **HyperAgents** (Facebook) | 2.1k | 递归自改进：Meta-Agent 能改自己的改进策略 |
| **dgm** (Darwin Gödel Machine) | 2.0k | 进化算法 + Archive 保留历史最优变体 |
| **SWE-agent** | 18.9k | Harness 设计标杆：YAML 驱动、history processor、cost tracking |
| **GPTSwarm** | 1.0k | 图结构 agent swarm，RL 优化 agent 连接权重 |
| **metabot** | 539 | Claude Code SDK 原生、MetaMemory 知识积累、IM 控制 |

## AI Memory Systems

| Project | Stars | What We Learn |
|---------|-------|---------------|
| **MemPalace** (Milla Jovovich) | 新 | 分层记忆(L0-L3)、Palace 结构化检索(+34%)、时序KG、Auto-Save Hooks |

## Agent Harness & Skills

| Project | Stars | What We Learn |
|---------|-------|---------------|
| **Agent-Skills-Context-Engineering** | 14.8k | Context engineering 最佳实践，skill 设计模式 |
| **water** | 274 | 生产级 agent harness 框架设计 |
| **agentic-harness-patterns** | 182 | Harness 工程模式：memory、permissions、context |

## Keeping Up to Date

```bash
# Update all submodules to latest
git submodule update --remote --merge

# Update a specific one
git submodule update --remote vendor/HyperAgents

# Track upstream autoagent (original fork source)
git fetch fork-upstream
git log fork-upstream/main --oneline -10
```

## Git Remote Setup

```
origin          → https://github.com/jhfnetboy/Agent24.git     (our repo)
upstream        → git@github.com:jhfnetboy/autoagent.git        (our fork)
fork-upstream   → https://github.com/kevinrgu/autoagent.git     (original source)
```
