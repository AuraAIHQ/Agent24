# Vendor 深度调研报告：对 Agent24 的借鉴价值

> Agent24 两大核心目标：**自进化（Self-Evolution）** + **组织级共享上下文（Org Context）**

---

## 一、总览评估矩阵

| 项目 | Stars | 自进化价值 | 上下文价值 | 整体借鉴度 | 核心借鉴点 |
|------|-------|-----------|-----------|-----------|-----------|
| **HyperAgents** | 2.1k | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | 递归自改进 + 分阶段评估 + 元数据谱系 |
| **DGM** | 2.0k | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐⭐ | 进化Archive + 父代链式继承 + 分层评估 |
| **SWE-agent** | 18.9k | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | YAML配置驱动 + History处理器链 + 成本控制 |
| **Agent-Skills-CE** | 14.8k | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Context Engineering最佳实践 + Skill模板 + Multi-Agent模式 |
| **MetaBot** | 539 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | MetaMemory(SQLite+FTS5) + Agent Bus + Skill Factory |
| **Water** | 274 | ⭐⭐ | ⭐⭐ | ⭐⭐⭐ | 生产级容错(Checkpoint+CircuitBreaker) + 中间件洋葱模型 |
| **GPTSwarm** | 1.0k | ⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐ | 参数化图拓扑 + RL优化连接权重 |
| **Harness Patterns** | 182 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 四层Memory + 四轴Context框架 + 两步保存不变式 |

---

## 二、自进化目标：关键借鉴

### 借鉴点 1：分阶段评估（HyperAgents + DGM）

**问题**：每次改进都跑全量评估太贵（token/时间）。

**HyperAgents 做法**：
- 先跑小样本评估（staged eval），所有分数 > 0 才继续
- 完整评估只给通过初筛的改进
- 未跑完整评估的按比例折扣分数（保守估计）

**DGM 做法**：
- small → medium → big 三层评估
- 每层设阈值（如 small ≥ 40%），达标才触发下一层
- 动态阈值：`threshold = max(第二高分, 0.4)`

**Agent24 应用**：
```
/evolve 执行任务后：
  → 快速自评（1-5分，低成本）
  → 分数 ≥ 3 才深度评估
  → 分数 ≥ 4 才更新策略 memory
  → 避免在失败迭代上浪费 memory 空间
```

---

### 借鉴点 2：Archive + 谱系追踪（DGM + HyperAgents）

**问题**：线性 hill-climbing 只保留最新，无法回溯或比较。

**DGM 做法**：
- `archive.jsonl` 记录所有变体
- 父代 patch 链式继承：`get_model_patch_paths()` 反向追溯所有祖先
- 选择策略加权：准确率 + 子代数量，平衡开采/探索

**HyperAgents 做法**：
- 每代保存 `metadata.json`（父代ID、patch、分数、有效性）
- `valid_parent` 标记控制哪些节点可被选为下一代父代
- `get_saved_score()` 缓存历史分数避免重复评估

**Agent24 应用**：
```yaml
# results.log 升级为结构化 Archive
archive:
  - id: "evolve-001"
    parent: null
    task_type: "refactoring"
    strategy: "understand-test-refactor-verify"
    score: 4
    insight: "先跑测试再重构，成功率高"
    config_snapshot: {hash}  # 当时的 agent-config.yaml
  - id: "evolve-002"
    parent: "evolve-001"
    # ...
```

---

### 借鉴点 3：递归自改进（HyperAgents）

**问题**：普通 agent 只改任务策略，不改自己的改进方式。

**HyperAgents 做法**：
- Meta-Agent 可以修改 Task-Agent 的代码
- **也可以修改自己的代码**（递归）
- 通过 `git diff` 捕获每次修改为 patch

**Agent24 应用**：
```
/evolve 的 Phase 5d 已经设计了这个：
  → 跨多次循环发现模式
  → "我反复在 X 类任务上失败" → 建议修改 skill prompt
  → 写入 memory: meta-improvement 标签
  → 下次 /evolve 读到后自动应用

关键：允许 /evolve 修改自己的 SKILL.md
      但需要人类确认（安全机制）
```

---

### 借鉴点 4：RL优化策略选择（GPTSwarm）

**问题**：多种策略怎么选？

**GPTSwarm 做法**：
- 把策略选择参数化为 logit 值
- `sigmoid(logit/temperature)` 给出概率
- Adam 优化器根据 utility 反馈调整

**Agent24 应用（简化版）**：
```yaml
# agent-config.yaml 中为每种策略维护成功率
strategies:
  coding:
    approaches:
      - name: "read-plan-implement-verify"
        success_rate: 0.85  # 自动更新
        uses: 12
      - name: "test-driven"
        success_rate: 0.70
        uses: 5
    # /evolve 根据 success_rate 加权选择
    # 偶尔随机探索低频策略（exploration）
```

---

## 三、组织级上下文目标：关键借鉴

### 借鉴点 5：Context Engineering 四轴框架（Agent-Skills-CE + Harness Patterns）

**核心框架**：

| 轴 | 含义 | Agent24 应用 |
|----|------|-------------|
| **Select** | 按需加载，不要一次全塞 | org/blueprint.md 只加载当前项目相关部分 |
| **Write** | 学到的写回持久存储 | /evolve 自动更新 memory |
| **Compress** | 过长内容压缩 | components.yaml 只存摘要，详情按需读 |
| **Isolate** | 子任务用独立上下文 | subagent 不继承全部 org context |

**关键数字**（来自 Agent-Skills-CE）：
- 有效容量 = 标称窗口的 60-70%
- 开头/结尾记忆率 85-95%，**中间仅 76-82%**（lost-in-middle）
- 20-30 轮对话后历史占 70-80% 窗口

**Agent24 应用**：
```
org/blueprint.md 必须精简（< 2000 token）
  → 只放架构图 + 组件一句话描述
  → 详细依赖关系放 components.yaml（按需读取）
  → 当前项目的上下游放 CLAUDE.md 顶部（高记忆位置）
```

---

### 借鉴点 6：四层 Memory 分级（Harness Patterns）

**架构**：

```
指令记忆（版本控制，CLAUDE.md）
    ↓
自动记忆（Agent 学到的，memory/）
    ↓
会话提取（后台异步，session 结束后提炼）
    ↓
审查晋升（人工确认后升级为指令记忆）
```

**关键设计**：
- **两步保存不变式**：先写文件，再更新索引（MEMORY.md）→ 抗崩溃
- **有界索引**：MEMORY.md 限制 200 行 / 25KB
- **手动失效不轮询**：变更点显式清缓存

**Agent24 应用**：
```
/org-sync 写入 org context 时：
  → blueprint.md = 指令记忆（人工维护）
  → components.yaml = 指令记忆（人工 + /org-sync add）
  → status.md = 自动记忆（/org-sync update 自动生成）
  → 跨仓库 insight = 审查晋升（agent 发现后建议，人确认后写入 blueprint）
```

---

### 借鉴点 7：MetaMemory + Agent Bus（MetaBot）

**MetaMemory**：
- SQLite WAL + FTS5 全文搜索
- documents 表 + documents_fts 虚拟表
- Folder visibility（shared/private）控制访问

**Agent Bus**：
- Intent Router 基于关键词匹配路由
- 跨实例发现：PeerManager 轮询刷新
- 防环头：`X-MetaBot-Origin`

**Agent24 应用**：
```
当前 memory 用文件系统（简单有效）。
未来如果组件多了、团队大了，可升级为：
  → SQLite 存储 org-wide 知识（MetaMemory 模式）
  → Agent Bus 让不同仓库的 agent 互相通信
  → 现阶段文件系统够用，不过度工程
```

---

### 借鉴点 8：Skill 设计最佳实践（Agent-Skills-CE）

**关键原则**：
1. **SKILL.md ≤ 500 行**，复杂内容放 references/
2. **第三人称叙述**，避免注入 system prompt 时 POV 混乱
3. **Gotchas 优先**：失败模式比理论讲解更有价值
4. **渐进式加载**：启动时只加载 skill 名称，激活时加载完整内容
5. **显式集成关联**：明确前置依赖和关联 skill

**Agent24 应用**：
```
当前 /evolve SKILL.md 已较规范。需补充：
  → 添加 Gotchas 章节（常见失败模式）
  → 添加 references/ 目录放详细策略说明
  → 添加 Integration 章节声明与 /evaluate、/org-sync 的关系
```

---

## 四、生产级工程：额外借鉴

### 借鉴点 9：成本控制三层追踪（SWE-agent）

```
单任务级: per_instance_cost_limit
全局级:   total_cost_limit  
API调用级: per_instance_call_limit
```
→ Agent24 的 /evolve 应该追踪每次循环的 token 消耗和累计成本

### 借鉴点 10：History 处理器链（SWE-agent）

```python
for processor in self.history_processors:
    messages = processor(messages)
```
→ Agent24 可在 /evolve 中实现类似的"memory 处理器链"：
  加载 → 过滤相关 → 排序by相关度 → 截断到预算 → 注入

### 借鉴点 11：容错机制（Water）

- **Checkpoint**：节点级快照，支持崩溃恢复
- **CircuitBreaker**：失败计数阈值触发熔断
- **RetryWithFeedback**：重试时注入错误反馈

→ Agent24 的 /evolve 如果执行中断，应该能从上次断点恢复

### 借鉴点 12：Skill Factory 自动生成团队（MetaBot）

`/metaskill` 命令自动生成完整的 `.claude/` 配置：
- Orchestrator + Specialists + CodeReviewer
- 共享 MetaMemory 知识库

→ Agent24 的 /org-sync init 可以借鉴，自动为新项目生成完整的 .claude/ 脚手架

---

## 五、优先级排序：Agent24 下一步行动

### P0（立即做）
1. **分阶段评估** — 给 /evolve 加 staged evaluation（借鉴 HyperAgents）
2. **SKILL.md 补充 Gotchas** — 给三个 skill 加失败模式章节（借鉴 Agent-Skills-CE）
3. **Blueprint 精简原则** — org context 文件控制在 2000 token 以内（借鉴 Context Engineering）

### P1（本周做）
4. **Archive 结构化** — results.log 升级为带谱系的 Archive（借鉴 DGM）
5. **策略成功率追踪** — agent-config.yaml 加 success_rate 字段（借鉴 GPTSwarm 简化版）
6. **Memory 四层分级** — 区分指令/自动/提取/审查（借鉴 Harness Patterns）

### P2（后续做）
7. **History 处理器链** — memory 加载时的过滤/排序/截断管道（借鉴 SWE-agent）
8. **递归自改进** — 允许 /evolve 修改自己的 SKILL.md（借鉴 HyperAgents，需安全机制）
9. **Skill Factory** — /org-sync init 自动生成完整脚手架（借鉴 MetaBot）

### P3（有 API Key 后）
10. **MetaMemory SQLite** — 文件系统升级为结构化存储（借鉴 MetaBot）
11. **Agent Bus** — 多仓库 agent 通信（借鉴 MetaBot）
12. **RL策略优化** — 真正的参数化策略选择（借鉴 GPTSwarm）
