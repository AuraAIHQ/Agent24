# AutoAgent 使用范围：在任意项目中使用

## 核心问题：必须在这个仓库下跑吗？

**不是。** 有两种部署方式：

## 方式一：全局安装（推荐）

把 skill 和 memory 安装到 `~/.claude/`，在任何项目目录都能用。

```
~/.claude/                          ← 全局配置，所有项目共享
├── skills/
│   ├── evolve.md                   ← /evolve 在任何项目都能用
│   ├── evaluate.md
│   └── worker.md
├── memory/
│   ├── MEMORY.md                   ← 全局经验积累
│   ├── strategies.md
│   └── patterns.md
└── settings.json                   ← 全局 hooks
```

使用方式：

```bash
# 在任意项目目录
cd ~/Dev/some-other-project
# 直接用
claude
> /evolve 帮我重构这个项目的测试框架
```

优点：
- 一次安装，到处使用
- 经验跨项目共享（在项目 A 学到的策略，项目 B 也能用）
- 不污染其他项目的 git 仓库

## 方式二：项目级安装

把 skill 和 memory 放到具体项目的 `.claude/` 下，只在该项目生效。

```
~/Dev/some-other-project/
├── .claude/
│   ├── skills/
│   │   └── evolve.md              ← 只在这个项目有效
│   └── memory/
│       └── MEMORY.md              ← 只积累这个项目的经验
├── src/
└── ...
```

使用方式：

```bash
cd ~/Dev/some-other-project
claude
> /evolve 优化这个项目的 API 性能
```

优点：
- 经验隔离（不同项目的策略不互相干扰）
- 可以提交到 git，团队共享
- 针对特定项目定制 skill

## 推荐：全局 + 项目级混合

```
~/.claude/                          ← 全局：通用能力
├── skills/
│   ├── evolve.md                   ← 通用自进化循环
│   └── evaluate.md                 ← 通用评估
└── memory/
    ├── strategies.md               ← 通用策略（跨项目有效）
    └── patterns.md                 ← 通用模式

~/Dev/project-a/.claude/            ← 项目级：专属定制
├── skills/
│   └── worker.md                   ← 这个项目特定的任务执行方式
└── memory/
    └── project-context.md          ← 这个项目的特定知识
```

Claude Code 的加载优先级：**项目级 > 全局**。同名 skill 项目级会覆盖全局。

## 具体场景示例

### 场景 1：克隆一个新的 GitHub 仓库

```bash
git clone https://github.com/someone/cool-project.git
cd cool-project
claude
> /evolve 分析这个项目的架构，找出可以改进的地方
```

如果你用全局安装，`/evolve` 直接可用。
Agent 会读项目代码 → 分析 → 给出改进方案 → 执行 → 评估 → 记录到全局 memory。

### 场景 2：在自己的项目上长期迭代

```bash
cd ~/Dev/my-saas-project

# 第一天
claude
> /evolve 帮我把测试覆盖率从 60% 提到 80%

# 第二天（新 session，但 memory 还在）
claude
> /evolve 继续昨天的测试改进工作
# Agent 读 memory，知道昨天做了什么，继续推进
```

### 场景 3：定时自动运行

```bash
# 设置 schedule，每天凌晨 2 点自动跑
claude
> /schedule 每天 2:00 AM 运行 /evolve 检查代码质量并修复问题
```

## 这个仓库（autoagent）的角色

这个仓库是 **AutoAgent 框架的开发仓库**，不是运行环境：

| 角色 | 说明 |
|------|------|
| 开发/维护 | skill 的源码在这里开发、测试、迭代 |
| 文档 | 设计文档、调研结果、方案说明 |
| 安装器 | 提供一个脚本，把 skill 安装到 `~/.claude/` |
| 原始 AutoAgent | `agent.py` / `agent-claude.py` 保留，未来有 API Key 可以用 |

```bash
# 未来的安装方式（我们会做一个安装脚本）
cd autoagent
./install.sh
# → 把 skills 复制到 ~/.claude/skills/
# → 把 memory 模板复制到 ~/.claude/memory/
# → 完成，去任意项目用 /evolve
```
