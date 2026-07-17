# score-config.toml 配置格式

> 状态：草案 · 最后修订：2026-07-16
>
> 关联文档：[tile-cli.md](./tile-cli.md)

---

## 设计动机

当前 `score.toml` 采用扁平结构，scorer 参数与 rule 无关：

```toml
[PiKa]
weight_a = 1.0
weight_b = 0.8
```

这意味着同一 scorer 在所有规则下共用一套参数。但实际场景中，PiKa 在 PairClassic 和 TripleTile 下的最优权重很可能不同——前者牌型空间小、偏保守；后者组合爆炸、偏激进。

因此引入三段式层级：`[scorer.<scorer>.<rule>]`，允许按规则定制 scorer 参数。

---

## 文件格式

### 基本结构

```toml
# score-config.toml

[scorer.PiKa.PairClassic]
weight_a = 1.0
weight_b = 0.8
weight_c = 0.6
# ... 共 11 个权重

[scorer.PiKa.TripleTile]
weight_a = 1.2
weight_b = 0.9
weight_c = 0.5
# ...

[scorer.Tokiki.PairClassic]
temperature = 0.7
top_k = 5
```

### Section 命名规范

```
[scorer.<scorer>.<rule>]
```

| 层级 | 含义 | 取值 |
|---|---|---|
| `scorer` | 固定前缀，标识 scorer 配置段 | 字面量 `scorer` |
| `<scorer>` | 算分器名称 | `PiKa`、`Tokiki`（计划中）等 |
| `<rule>` | 规则名称 | `PairClassic`、`TripleTile` 等 |

- 三段均**大小写敏感**，与 CLI 传入值精确匹配
- 支持两种合法格式，但**同一 scorer 下两者互斥**（详见[互斥约束](#互斥约束)）
  1. `[scorer.<scorer>.<rule>]` —— 按规则定制
  2. `[scorer.<scorer>]` —— 所有规则共用一套（省略 rule 段）

---

## 解析与匹配规则

### 互斥约束

对于同一个 scorer，`[scorer.<scorer>]` 和 `[scorer.<scorer>.<rule>]` **不能同时出现在同一文件中**。

这是 TOML 语法的硬性约束：`[scorer.PiKa.PairClassic]` 使 `PiKa` 成为中间 table 节点，此时 `[scorer.PiKa]` 再直接持有键值对会导致解析错误。

| 文件中同时存在 | 行为 |
|---|---|
| `[scorer.PiKa]` + `[scorer.PiKa.PairClassic]` | TOML 解析失败，直接报错退出 |
| `[scorer.PiKa]` + `[scorer.Tokiki.PairClassic]` | 合法（不同 scorer，互不冲突） |

### 查找优先级

当用户执行 `tile simulate --scorer PiKa --rule TripleTile --scorer-config score-config.toml` 时：

```
1. 精确匹配  [scorer.PiKa.TripleTile]    （仅当文件使用三段式格式）
2. scorer 级  [scorer.PiKa]              （仅当文件使用两段式格式）
3. 内置默认    scorer 代码内硬编码的默认参数
```

- 命中第 1 层：使用该 section 的全部参数，缺失字段由第 3 层补齐
- 命中第 2 层：所有 rule 共用同一套参数，缺失字段由第 3 层补齐
- 仅命中第 3 层：全部使用内置默认值
- 第 1 层和第 2 层互斥——文件要么全是三段式，要么全是两段式（同一 scorer 下）

### 部分覆盖

配置文件不需要写出 scorer 的全部参数，只写想覆盖的部分即可：

```toml
# 只调 weight_a，其余沿用内置默认
[scorer.PiKa.TripleTile]
weight_a = 1.5
```

`--show-config` 会展示**最终生效的全部参数及各自来源**（`file` / `default`）。

> ⚠️ TOML 类型敏感：浮点参数必须写小数点（如 `1.5`），写成整数（如 `1`）在严格 TOML 解析器中可能报类型错误。

### 未匹配行为

| 场景 | 行为 |
|---|---|
| scorer 无配置参数 | 正常执行，无需任何 section |
| scorer 有参数但未匹配到任何 section | 使用内置默认值，正常执行 |
| 三段落式文件中 scorer 存在但对应 rule 的 section 不存在 | fallback 到内置默认值（第 2 层 scorer 级因互斥约束不可用） |
| section 存在但 scorer 名称不合法 | 输出 warning 到 stderr 并忽略该 section（避免用户因拼写错误而误用内置默认值） |
| rule 名称在 section 中出现但 CLI `--rule` 未匹配 | 不报错，该 section 仅当对应 rule 被指定时才生效 |
| 同一 scorer 下两段式和三段式混用 | TOML 解析失败，直接报错退出 |

---

## 与 `tile scorers --generate` 的关系

`tile scorers --generate` 行为需调整：不再生成扁平 `[PiKa]`，改为按 rule 生成 section。

```bash
tile scorers --generate ./score-config.toml
```

生成文件示例：

```toml
# score-config.toml — 由 `tile scorers --generate` 生成
# 修改权重后通过 --scorer-config 传入 tile simulate

[scorer.PiKa.PairClassic]
weight_a = 1.0
weight_b = 0.8
weight_c = 0.6
weight_d = 0.5
weight_e = 0.4
weight_f = 0.3
weight_g = 0.2
weight_h = 0.1
weight_i = 0.0
weight_j = 0.0
weight_k = 0.0

[scorer.PiKa.TripleTile]
weight_a = 1.0
weight_b = 0.8
weight_c = 0.6
weight_d = 0.5
weight_e = 0.4
weight_f = 0.3
weight_g = 0.2
weight_h = 0.1
weight_i = 0.0
weight_j = 0.0
weight_k = 0.0
```

- 生成时列出**所有 scorer × rule 的笛卡尔积**
- 每个 section 填充该 scorer 的内置默认值
- 无配置参数的 scorer 生成空 section 占位，方便用户了解可用组合

---

## `--show-config` 输出变化

```bash
tile simulate --rule TripleTile --scorer PiKa \
  --scorer-config score-config.toml --show-config
```

```
=== CLI Parameters ===
Parameter                Value              Source
─────────────────────────────────────────────────────────────
rule                     TripleTile         CLI
scorer                   PiKa               CLI
scorer-config            score-config.toml  CLI
...

=== Scorer: PiKa / Rule: TripleTile (from score-config.toml) ===
Parameter                Value              Source
─────────────────────────────────────────────────────────────
weight_a                 1.2                file
weight_b                 0.9                file
weight_c                 0.6                default
weight_d                 0.5                default
# ...
```

- 标题行标注当前生效的 scorer + rule 组合
- 来源列区分 `file`（从配置文件读取）和 `default`（内置默认值）
- 若命中两段式 `[scorer.PiKa]`（scorer 级），来源标注为 `file (scorer-level)`

两段式输出示例（`--rule` 不生效，所有 rule 共用同一套参数）：

```
=== Scorer: PiKa (scorer-level, from score-config.toml) ===
Parameter                Value              Source
─────────────────────────────────────────────────────────────
weight_a                 1.0                file (scorer-level)
weight_b                 0.8                file (scorer-level)
weight_c                 0.6                default
weight_d                 0.5                default
# ...
```

---

## 完整示例

### 场景：不同规则用不同 PiKa 权重

```toml
# score-config.toml

[scorer.PiKa.PairClassic]
weight_a = 1.0
weight_b = 0.8
weight_c = 0.6
weight_d = 0.5
weight_e = 0.4
weight_f = 0.3
weight_g = 0.2
weight_h = 0.1
weight_i = 0.0
weight_j = 0.0
weight_k = 0.0

[scorer.PiKa.TripleTile]
weight_a = 1.5
weight_b = 1.2
weight_c = 0.9
weight_d = 0.6
weight_e = 0.4
weight_f = 0.2
weight_g = 0.1
weight_h = 0.1
weight_i = 0.0
weight_j = 0.0
weight_k = 0.0
```

使用：

```bash
# PairClassic 用保守权重
tile simulate --rule PairClassic --scorer PiKa --scorer-config score-config.toml --level "..."

# TripleTile 用激进权重
tile simulate --rule TripleTile --scorer PiKa --scorer-config score-config.toml --level "..."
```

### 场景：所有 rule 共用同一套参数

不需要按规则区分时，使用两段式简写：

```toml
# score-config.toml — 所有 rule 共用

[scorer.PiKa]
weight_a = 1.0
weight_b = 0.8
weight_c = 0.6

[scorer.Tokiki]
temperature = 0.7
```

此时无论 `--rule` 传什么，均使用该 scorer 下唯一一套参数。

> ⚠️ 文件中一旦出现 `[scorer.PiKa]`，就不能再出现任何 `[scorer.PiKa.<rule>]`（互斥约束）。

---

## 未来方向

### `softmax-temperature` 纳入配置文件

当前 `--softmax-temperature` 仅作为 CLI 全局参数存在，所有 rule 共用同一值。但 PiKa 在不同 rule 下可能需要不同的探索/利用策略（如 PairClassic 偏保守可用较低 temperature，TripleTile 偏激进可用较高 temperature）。未来可考虑在 `[scorer.PiKa.<rule>]` section 中支持 `softmax_temperature` 字段，按 rule 定制；CLI `--softmax-temperature` 作为未配置时的 fallback 默认值。

---

## 修订记录

| 日期 | 变更 |
|---|---|
| 2026-07-16 v1 | 初稿：三段式 `[scorer.<scorer>.<rule>]` 层级、查找优先级、`tile scorers --generate` 调整、旧格式兼容策略 |
| 2026-07-16 v2 | 修正 TOML 格式冲突：两段式与三段式互斥约束；旧格式迁移改为 `tile scorers --migrate` 子命令 |
| 2026-07-16 v3 | 评审修订：未知 scorer 名称改为 warning + 忽略（防拼写错误）；补充三段落式 rule 未命中场景；新增 TOML 浮点类型提醒；补充两段式 `--show-config` 示例；记录 `softmax-temperature` 纳入配置文件为未来方向；移除旧格式迁移节（设计阶段直接采纳新格式） |
