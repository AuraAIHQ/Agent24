  调研结果：Top 5 自我进化 Agent 项目

  ┌──────┬─────────────────────────────────────┬────────┬──────────────────────────────────────────────────────────┬──────────────────┐
  │ 排名 │                项目                 │  Star  │                         核心思路                         │   Claude 支持    │
  ├──────┼─────────────────────────────────────┼────────┼──────────────────────────────────────────────────────────┼──────────────────┤
  │ 1    │ SWE-agent/SWE-agent                 │ 18,929 │ Agent harness 修 GitHub issue，YAML 驱动，LiteLLM 多模型 │ ✅ 首选模型      │
  ├──────┼─────────────────────────────────────┼────────┼──────────────────────────────────────────────────────────┼──────────────────┤
  │ 2    │ facebookresearch/HyperAgents        │ 2,138  │ Meta-Agent 递归改进自身代码 + Task Agent，litellm 多模型 │ ✅ 明确支持      │
  ├──────┼─────────────────────────────────────┼────────┼──────────────────────────────────────────────────────────┼──────────────────┤
  │ 3    │ jennyzzt/dgm (Darwin Gödel Machine) │ 1,984  │ 进化算法迭代修改 agent 自身代码，Archive 保留优胜变体    │ ✅ 默认用 Claude │
  ├──────┼─────────────────────────────────────┼────────┼──────────────────────────────────────────────────────────┼──────────────────┤
  │ 4    │ metauto-ai/GPTSwarm                 │ 1,014  │ 图结构 agent swarm，RL 优化 agent 连接权重               │ ❌ 仅 OpenAI     │
  ├──────┼─────────────────────────────────────┼────────┼──────────────────────────────────────────────────────────┼──────────────────┤
  │ 5    │ xvirobotics/metabot                 │ 539    │ Claude Code SDK 驱动，IM 控制，MetaMemory 知识积累       │ ✅ 原生 Claude   │
  └──────┴─────────────────────────────────────┴────────┴──────────────────────────────────────────────────────────┴──────────────────┘

  ---
  关键发现

  与当前 AutoAgent 最相似的项目

  HyperAgents 和 DGM 跟你的 AutoAgent 定位几乎一样——都是「meta-agent 改 agent 代码 → 跑 benchmark → 保留/回退」。区别在于：

  - HyperAgents：Meta-Agent 不仅改 Task Agent，还能改自己的改进策略（递归自改进）
  - DGM：用进化算法（种群 + 选择 + 变异），维护一个 Archive 保留历史最优变体
  - AutoAgent（你的）：单线性 hill-climbing，每次改一个点

  你的独特约束：只有 Claude Code 订阅，没有 API Key

  这其实是个重要约束。上面 5 个项目全部需要 API Key，因为被测 agent 需要独立调模型。

  ---
  方案建议：基于 Claude Code 的双 Agent 自迭代系统

  考虑到你只有 Claude Code 订阅，我建议的思路是：

  核心架构：Claude Code 内的「双 Agent」

  ┌─────────────────────────────────────────┐
  │           Claude Code (你的订阅)          │
  │                                         │
  │  ┌─────────────┐    ┌───────────────┐   │
  │  │  Meta-Agent  │───→│  Task-Agent   │   │
  │  │  (优化循环)   │←───│  (执行任务)    │   │
  │  └─────────────┘    └───────────────┘   │
  │         │                    │           │
  │         ▼                    ▼           │
  │   编辑 agent 代码      用 Claude Code    │
  │   分析失败原因        的 Agent SDK 跑任务 │
  │   决定保留/回退       （不需要额外 API）  │
  │                                         │
  │  ┌─────────────────────────────────┐    │
  │  │  Docker 容器（任务沙盒环境）      │    │
  │  └─────────────────────────────────┘    │
  └─────────────────────────────────────────┘

  关键：agent-claude.py 使用 claude_agent_sdk

  看你已有的 agent-claude.py，它用的是 claude_agent_sdk（Claude Agent SDK），这个 SDK 可以在 Claude Code 的 bypassPermissions
  模式下运行，不需要单独的 API Key——它复用 Claude Code 的订阅额度。

  具体实施路线

  1. 借鉴 HyperAgents 的递归自改进：Meta-Agent 不仅改 Task Agent，还能改自己的策略
  2. 借鉴 DGM 的进化 Archive：保留多个历史最优变体，不只是线性 hill-climbing
  3. 借鉴 SWE-agent 的 harness 设计：YAML 配置驱动、history processor、cost tracking
  4. 借鉴 MetaBot 的 MetaMemory：跨迭代的知识积累，agent 学到的东西持久化

  24 小时运行方案

  - 用 Claude Code 的 schedule/trigger 功能或 cron 定时启动迭代循环
  - 每次迭代：改代码 → Docker 内跑 benchmark → 记录结果 → 下一轮
  - agent-claude.py 路线最合适，因为全链路都在 Claude 生态内

  ---
  要不要我把 HyperAgents 和 DGM clone 到当前目录作为 submodule，然后我们开始制定详细的实施计划？
