# metrics.toml 配置格式

> 状态：草案 · 最后修订：2026-07-16
>
> 关联文档：[tile-cli.md](./tile-cli.md) · [score-config-toml.md](./score-config-toml.md) · [toml-guide.md](./toml-guide.md)

---

## 设计动机

tile simulate 的输出 CSV 包含多列指标。分组式 `[metrics.<group>]` 配置解决两个核心问题：

1. **输出列顺序的显式控制**：section 和 key 的书写顺序即 CSV 列顺序，无需额外的 `order` 字段——想调整顺序只需在文件中挪行。
2. **关注层次的语义分组**：`basic`（核心指标）、`distribution`（分布指标）、`advanced`（高级指标）等分组帮助用户按关注层次管理指标，一目了然。

每个指标用布尔开关（`true`/`false`）控制启用/禁用，禁用的指标不出现在输出中但保留在文件里方便随时开启。

---

## 文件格式

### 基本结构

```toml
# metrics.toml

[metrics.basic]
success_rate = true
avg_score = true

[metrics.distribution]
median_score = true
std_score = true
min_score = true
max_score = true
percentile_25 = false
percentile_75 = false
```

- 每个 `[metrics.<group>]` 是一个指标分组
- 组内每个 key 是一个指标名，value 为 `true`（启用）或 `false`（禁用）
- 禁用的指标不出现在输出 CSV 中，但保留在配置文件中方便随时开启

### Section 命名规范

```
[metrics.<group>]
```

| 层级 | 含义 | 取值 |
|---|---|---|
| `metrics` | 固定前缀，标识指标配置段 | 字面量 `metrics` |
| `<group>` | 指标分组名 | `basic`、`distribution`、`advanced` 等 |

- 组名仅允许 `[a-z][a-z0-9_]*`，小写
- 用户可自定义组名；内置组仅作生成模板的默认划分

### 指标名规范

- 仅允许字符 `[a-zA-Z0-9_]`，大小写不敏感，内部归一化为小写
- 指标名即输出 CSV 列名：`median_score` → CSV 列 `median_score`
- 同一指标不能出现在多个组中（重复定义直接报错）

---

## 内置指标清单

按组划分的完整指标列表（由 `tile metrics --list` 输出）：

### `builtin`（内部，不可配置）

以下指标始终由模拟引擎计算并输出，不出现在配置文件中，不受 `metrics.toml` 控制。

| 指标名 | 说明 |
|---|---|
| `failure_rate` | 失败次数 / 总模拟次数（= 1 − success_rate） |
| `avg_failure_step` | 失败模拟的平均失败步数（仅统计失败回合） |

> **边界行为**：
> - `failure_rate` 与 `success_rate` 独立计算——即使 `success_rate` 在配置中被关闭，`failure_rate` 仍会输出。`failure_rate` 仅作便利列，始终可由 `success_rate` 推导。
> - `avg_failure_step` 仅统计存在失败回合的模拟；若全部模拟均成功（无失败回合），输出 `N/A`。

### `basic`

| 指标名 | 说明 | 默认 |
|---|---|---|
| `success_rate` | 成功次数 / 总模拟次数 | true |
| `avg_score` | 所有成功模拟的平均得分 | true |

### `distribution`

| 指标名 | 说明 | 默认 |
|---|---|---|
| `median_score` | 得分中位数 | true |
| `std_score` | 得分标准差 | true |
| `min_score` | 最低得分 | false |
| `max_score` | 最高得分 | false |

### `advanced`（预留）

| 指标名 | 说明 | 默认 |
|---|---|---|
| `percentile_25` | 第 25 百分位数 | false |
| `percentile_75` | 第 75 百分位数 | false |
| `percentile_90` | 第 90 百分位数 | false |
| `percentile_95` | 第 95 百分位数 | false |

---

## 与 `tile metrics` 命令的关系

### `--list` 分组输出

```bash
tile metrics --list
```

```
=== builtin (always output, not configurable) ===
  failure_rate       失败率（失败次数 / 总模拟次数）
  avg_failure_step   失败模拟的平均失败步数

=== basic ===
  success_rate    成功率（成功次数 / 总模拟次数）
  avg_score       所有成功模拟的平均得分

=== distribution ===
  median_score    得分中位数
  std_score       得分标准差
  min_score       最低得分
  max_score       最高得分

=== advanced ===
  percentile_25   第 25 百分位数
  percentile_75   第 75 百分位数
  percentile_90   第 90 百分位数
  percentile_95   第 95 百分位数
```

### `--generate` 生成配置文件

```bash
tile metrics --generate ./metrics.toml
```

生成文件（全部指标 + 内置默认值）：

```toml
# metrics.toml — 由 `tile metrics --generate` 生成
# 修改后通过 --metrics-config 传入 tile simulate

[metrics.basic]
success_rate = true
avg_score = true

[metrics.distribution]
median_score = true
std_score = true
min_score = false
max_score = false

[metrics.advanced]
percentile_25 = false
percentile_75 = false
percentile_90 = false
percentile_95 = false
```

- 生成时列出**所有可配置指标及其默认启用状态**
- **builtin 指标不出现在生成文件中**（`failure_rate`、`avg_failure_step` 始终输出，无需配置）
- 用户删除某个指标行 → 该指标不启用（等同于 `= false`）
- 用户删除整个 `[metrics.<group>]` section → 该组全部不启用
- 用户新增自定义指标名 → 若 scorer 不支持则 `--show-config` 警告 + 静默忽略

---

## 解析与合并规则

### 启用指标收集

加载 `metrics.toml` 后，收集所有值为 `true` 的指标名，与内置的 builtin 指标合并，得到最终输出列集合。

```toml
[metrics.basic]
success_rate = true
avg_score = true

[metrics.distribution]
median_score = true
std_score = false       # 不启用
```

→ 配置指标：`{ success_rate, avg_score, median_score }`  
→ 最终输出（含 builtin）：`{ failure_rate, avg_failure_step, success_rate, avg_score, median_score }`

### 输出列顺序

输出 CSV 的列顺序由**文件中的书写顺序**决定，不依赖字母序或内置排序。

规则：
1. `id` 列**始终在第一列**（固定，不可调整）
2. **builtin 指标紧随其后**，固定顺序：`failure_rate` → `avg_failure_step`（不可调整）
3. 剩余列按 `[metrics.<group>]` section 的出现顺序排列
4. 同一 group 内，按 key 的书写顺序排列
5. 只有值为 `true` 的指标参与排序；`false` 的被跳过

```toml
# 文件中的书写顺序 ↓

[metrics.basic]          # ← 第 1 组
success_rate = true      #   组内第 1
avg_score = true         #   组内第 2

[metrics.distribution]   # ← 第 2 组
std_score = true         #   组内第 1
median_score = true      #   组内第 2
min_score = false        #   跳过
max_score = false        #   跳过
```

→ 输出列顺序：`id, failure_rate, avg_failure_step, success_rate, avg_score, std_score, median_score`

> **设计理由**：靠书写顺序而非显式 `order` 字段，原因是 (a) 避免重复信息，(b) TOML 解析器普遍保持 key 顺序，(c) 调整时只需在文件中挪行，直观且不易出错。

如果用户希望 `median_score` 在 `std_score` 前面，只需把两行互换：

```toml
[metrics.distribution]
median_score = true      # 挪到前面
std_score = true
```

→ 输出列顺序：`id, failure_rate, avg_failure_step, success_rate, avg_score, median_score, std_score`

### 默认输出列

未指定 `--metrics-config` 或 `--metrics-columns` 时，输出默认列：`id, failure_rate, avg_failure_step, success_rate, avg_score`（builtin + basic 组默认启用）。

### 与 `--metrics-columns` 的关系

CLI 参数 `--metrics-columns` 和配置文件 `--metrics-config` **互斥**，同时传入直接报错（与现有行为一致）。

### 运行时校验

| 场景 | 行为 |
|---|---|
| 配置文件语法错误（TOML 解析失败） | 报错退出 |
| 同一指标出现在多个组 | 报错退出，提示重复的指标名和所在组 |
| 指标名 scorer 无法计算 | 输出 warning 到 stderr（`--show-config` 同步展示警告），静默忽略该指标，不影响其他指标 |
| 最终启用集合为空 | 报错退出：「至少启用一个指标」 |
| 配置文件不存在 | 报错退出（不静默回退默认值） |

---

## `--show-config` 输出变化

```bash
tile simulate --input-file levels.csv --level-column level_str \
  --metrics-config metrics.toml --show-config
```

```
=== CLI Parameters ===
...
metrics-config           metrics.toml        CLI
metrics-columns          (not set)           —
...

=== Builtin (always output) ===
builtin       failure_rate      —         builtin
builtin       avg_failure_step  —         builtin

=== Metrics (from metrics.toml) ===
Group          Metric            Enabled   Source
───────────────────────────────────────────────────
basic          success_rate      true      file
basic          avg_score         true      file
distribution   median_score      true      file
distribution   std_score         false     file
distribution   min_score         false     file
distribution   max_score         false     file
advanced       percentile_25     false     file
advanced       percentile_75     false     file
advanced       percentile_90     false     file
advanced       percentile_95     false     file

Output column order: id, failure_rate, avg_failure_step, success_rate, avg_score, median_score
```

---

## 完整示例

### 只关心基本指标

```toml
# metrics.toml

[metrics.basic]
success_rate = true
avg_score = true
```

输出列顺序：`id, failure_rate, avg_failure_step, success_rate, avg_score`

### 全量分析

```toml
# metrics.toml

[metrics.basic]
success_rate = true
avg_score = true

[metrics.distribution]
median_score = true
std_score = true
min_score = true
max_score = true
```

输出列顺序：`id, failure_rate, avg_failure_step, success_rate, avg_score, median_score, std_score, min_score, max_score`

如需调整顺序（例如把 distribution 指标放前面），有两种方式：

**方式一：调换 section 顺序**
```toml
[metrics.distribution]   # 这个 section 先出现 → 列在前
median_score = true
std_score = true
min_score = true
max_score = true

[metrics.basic]          # 这个 section 后出现 → 列在后
success_rate = true
avg_score = true
```
→ `id, failure_rate, avg_failure_step, median_score, std_score, min_score, max_score, success_rate, avg_score`

**方式二：合并到同一组，手动排序**
```toml
[metrics.all]
success_rate = true
avg_score = true
median_score = true
std_score = true
```
→ `id, failure_rate, avg_failure_step, success_rate, avg_score, median_score, std_score`

### 只开分布指标

```toml
# metrics.toml

[metrics.basic]
success_rate = false
avg_score = false

[metrics.distribution]
median_score = true
std_score = true
```

输出列顺序：`id, failure_rate, avg_failure_step, median_score, std_score`

---


---

## 修订记录

| 日期 | 变更 |
|---|---|
| 2026-07-16 v1 | 初稿：分组式 `[metrics.<group>]`、内置指标清单、生成/解析/校验规则、`--show-config` 输出 |
| 2026-07-16 v2 | 新增「输出列顺序」：书写顺序即输出顺序（section 顺序 + key 顺序），`id` 固定第一列；补充调序示例 |
| 2026-07-16 v3 | basic 组新增 `failure_rate`、`avg_failure_step`；默认输出列从 3 列扩展为 5 列 |
| 2026-07-16 v4 | `failure_rate`、`avg_failure_step` 移入 `builtin` 组：始终计算、始终输出、不出现在配置文件中、不可关闭 |
| 2026-07-16 v5 | 评审修订：重写设计动机（输出列顺序显式控制 + 语义分组）；明确 builtin 指标边界行为（全成功时 `avg_failure_step` 输出 `N/A`、`failure_rate` 关闭 `success_rate` 后仍输出）；统一未知指标名处理策略为 warning；移除旧格式迁移节（设计阶段直接采纳新格式） |
