# Tile CLI 设计

> 状态：草案 · 最后修订：2026-07-16

---

## 命令总览

```
tile simulation  →  跑模拟（单条 / 批量 CSV）
tile metrics     →  指标发现 & 配置生成
tile scorer      →  算分算法发现 & 配置生成
tile check       →  关卡字符串校验
```

---

## 一、`tile simulation`

### 模式 A：单条

```bash
tile simulation \
  --level "..." \
  --max-run-count 1000 \
  --stop-after-success 200 \
  --rule TripleTile \
  --scorer PiKa \
  --scorer-config score.toml \
  --metrics-config metrics.toml
```

### 模式 B：批量 CSV

```bash
tile simulation \
  --input-file levels.csv \
  --level-column level_str \
  --id-column level_id \
  --max-run-count 1000 \
  --stop-after-success 200 \
  --rule TripleTile \
  --scorer PiKa \
  --scorer-config score.toml \
  --metrics-config metrics.toml \
  --output-file results.csv \
  --error-file errors.csv \
  --preserve-columns
```

### 参数表

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `--level` | string | — | 单条关卡（与 `--input-file` 互斥） |
| `--input-file` | path | — | 批量关卡 CSV |
| `--level-column` | string | — | 关卡所在列名（batch 模式**必填**） |
| `--id-column` | string | — | 唯一 ID 列名。不填则自动生成 base-1 自增序号 |
| `--output-file` | path | stdout | 成功模拟结果 CSV |
| `--error-file` | path | stderr | 失败行 CSV：**保留全部原始列 + 追加 error 列** |
| `--preserve-columns` | flag | 不保留 | 传入此 flag 后，输出中携带原始列 |
| `--max-run-count` | int | 1000 | **每行**独立模拟次数 |
| `--stop-after-success` | int | — | 每行成功 N 次后提前停止（可选） |
| `--rule` | string | PairClassic | 规则名，单值。传入多个报错 |
| `--scorer-config` | path | — | 算分配置 toml，内含 `[PiKa]` 等 per-scorer 段 |
| `--metrics-config` | path | — | 指标配置 toml（与 `--metrics-columns` 互斥，config 优先） |
| `--metrics-columns` | string | — | 指标列名逗号分隔 |
| `--softmax-temperature` | float | 0.5 | Softmax 温度 |
| `--show-config` | flag | — | 打印所有实际生效的参数及来源，然后退出（不执行模拟） |

### `--show-config` 输出示例

```bash
tile simulation --input-file levels.csv --level-column level_str --id-column id \
  --stop-after-success 200 --scorer-config score.toml --show-config
```

```
=== CLI Parameters ===
Parameter                Value              Source
─────────────────────────────────────────────────────────────
input-file               levels.csv         CLI
level-column             level_str          CLI
id-column                id                 CLI
output-file              <stdout>           default
error-file               <stderr>           default
preserve-columns         false              default
max-run-count            1000               default
stop-after-success       200                CLI
rule                     PairClassic        default
scorer                   PiKa               default
scorer-config            score.toml         CLI
metrics-config           (not set)          —
metrics-columns          (not set)          —
softmax-temperature      0.5                default

=== Scorer: PiKa (from score.toml) ===
Parameter                Value              
─────────────────────────────────────────────
weight_a                 1.0                
weight_b                 0.8                
weight_c                 0.6                
# ... 共 11 个权重

=== Metrics: none ===
No metrics configured. Specify --metrics-config or --metrics-columns.
```

- 来源分为三档：`CLI`（用户显式传入）、`default`（内置默认值）、`<file>`（从配置文件读入）
- 配置文件内的参数逐项展开，标注来自哪个文件
- 传入 `--show-config` 后只打印信息并退出，不执行任何模拟

---

## 二、批量模式 I/O 模型

```
输入 CSV                          输出 CSV（不含 --preserve-columns）      错误 CSV
────────                          ────────────────────────────────        ─────────
id,level_str,author               id,success_rate,avg_score,…              id,level_str,author,error
1,"...",Alice    ──模拟──▶        1,0.87,0.234,…                           5,"???",Eve,"invalid char
2,"...",Bob      ──模拟──▶        2,0.91,0.198,…                            at position 3"
3,"...",Alice    ──模拟──▶        3,0.76,0.301,…
4,"...",Bob      ──模拟──▶        4,0.82,0.256,…
5,"???",Eve      ──校验失败──▶
```

- 输出文件只含成功跑完的行；错误文件只含失败的行；两文件互不重叠，并集 = 输入全集
- 错误文件保留全部原始列 + 追加 `error` 列
- 单条模式（`--level`）走 stdout/stderr，不涉及上述分文件逻辑

---

## 三、`tile metrics`

```bash
tile metrics --list                     # 列出所有支持的聚合指标
tile metrics --generate ./metrics.toml  # 生成默认指标配置
```

| 参数 | 说明 |
|---|---|
| `--list` | 列出可用指标（名称 + 简短描述） |
| `--generate <path>` | 生成默认 metrics.toml |

---

## 四、`tile scorer`

```bash
tile scorer --list                     # 或 -l，列出所有可用 scorer
tile scorer --show PiKa                # 展示 PiKa 的默认权重系数
tile scorer --generate ./score.toml    # 生成包含所有 scorer 默认配置的 toml
```

生成文件示例：

```toml
# score.toml — 由 `tile scorer --generate` 生成，可修改后通过 --scorer-config 传入

[PiKa]
weight_a = 1.0
weight_b = 0.8
# ... 共 11 个权重

[Random]
# 无配置参数
```

| 参数 | 别名 | 说明 |
|---|---|---|
| `--list` | `-l` | 列出已注册 scorer（名称 + 模式 + 描述） |
| `--show <name>` | | 展示指定 scorer 的默认系数 |
| `--generate <path>` | | 生成包含所有 scorer 默认配置的 toml 文件 |

### 现有 scorer

| 名称 | 模式 | 说明 |
|---|---|---|
| `PiKa` | Behaviour | 11 个可配置权重 |
| `Random` | Tile | 纯随机，无配置 |

`Tokiki`、`Feature` 计划中。

---

## 五、`tile check`

```bash
# 单条
tile check --level "..." --rule TripleTile,PairClassic

# 批量
tile check --input-file levels.txt --rule TripleTile,PairClassic --output-file report.txt
```

| 参数 | 说明 |
|---|---|
| `--level` | 单条关卡（与 `--input-file` 互斥） |
| `--input-file` | 批量输入，每行一条 |
| `--rule` | 规则名，单值。传入多个报错 |
| `--output-file` | 批量结果落盘（默认 stdout） |

### 行为约定

- **单条检查**：合法则静默退出（exit 0），不合法则输出错误信息到 stderr（exit 1）
- **批量检查**：逐行输出 `行号: OK` 或 `行号: <错误信息>`，退出码取决于是否全部通过

---

## 六、修订记录

| 日期 | 变更 |
|---|---|
| 2026-07-16 v1 | 初稿：修复 shell 管道冲突（`\|` → `,`）、拼写修正（temperate → temperature）、参数命名统一（list/show/generate）、拆分 `--metrics` 三种语义、补充 `--output`/`--format` |
| 2026-07-16 v2 | `--count` → `--max-run-count`；`--max-success` → `--stop-after-success`；新增 CSV 批量模式参数（`--input-file`/`--output-file`/`--error-file`/`--level-column`/`--id-column`/`--preserve-columns`） |
| 2026-07-16 v3 | 移除 `--format`/`--input-format`，统一 CSV；`--preserve-columns` 默认 false；`--level-column` 必填；错误文件保留全部原始列 + error 列；单条/批量参数统一；`tile scorer` 新增 `--generate` |
| 2026-07-16 v4 | `tile simulation` 新增 `--show-config`：打印所有生效参数及来源（CLI/default/file），配置文件内参数逐项展开，打印后退出不执行模拟 |
