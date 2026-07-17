# Tile CLI 设计

> 状态：草案 · 最后修订：2026-07-16

---

## 全局约定

```
tile --help       →  列出所有子命令
tile --version    →  输出版本号（格式 `tile x.y.z`）
tile <cmd> --help →  列出该子命令的参数表
```

所有子命令的 `--help` 输出与本文档各参数表保持一致；如存在冲突以本文档为准。

## 命令总览

```
tile simulate    →  跑模拟（单条 / 批量 CSV）
tile metrics     →  指标发现 & 配置生成
tile scorers     →  算分算法发现 & 配置生成
tile validate    →  关卡字符串校验
tile completion  →  shell 补全脚本生成
```

---

## 一、`tile simulate`

### 模式 A：单条

```bash
tile simulate \
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
tile simulate \
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
  --preserve-columns \
  --progress
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
| `--scorer` | string | PiKa | 算分器名称，单值。传入多个报错 |
| `--scorer-config` | path | — | 算分配置 toml，内含 `[PiKa]` 等 per-scorer 段。simulate 仅解析 `--scorer` 对应的段 |
| `--metrics-config` | path | — | 指标配置 toml（与 `--metrics-columns` **互斥**，同时传入直接报错） |
| `--metrics-columns` | string | — | 指标列名逗号分隔（与 `--metrics-config` **互斥**，同时传入直接报错） |
| `--softmax-temperature` | float | 0.5 | Softmax 温度。仅 Behaviour scorer（如 PiKa）生效；非 Behaviour scorer 下静默忽略，`--show-config` 中标注 `(not applicable)` |
| `--show-config` | flag | — | 打印所有实际生效的参数及来源，然后退出（不执行模拟） |
| `--progress` | flag | 不显示 | 批量模式在 stderr 输出实时进度（格式 `[n/total]`）。单条模式忽略 |

### `--show-config` 输出示例

```bash
tile simulate --input-file levels.csv --level-column level_str --id-column id \
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
- `--scorer` 参数中的 `scorer` 指代算分算法名称，与子命令 `tile scorers`（列出/管理算分器）区分
- 配置文件内的参数逐项展开，标注来自哪个文件
- 传入 `--show-config` 后只打印信息并退出，不执行任何模拟

### 单条模式输出格式

单条模式（`--level`）输出为 CSV 一行，列与批量模式输出一致（**始终输出** `id,success_rate,avg_score`；通过 `--metrics-config` 或 `--metrics-columns` 可追加 `median_score,std_score,min_score,max_score` 等指标列），id 列固定为 `single`（保持与批量模式列结构一致，便于下游脚本统一处理）。输出到 stdout；错误信息输出到 stderr。

---

## 二、批量模式 I/O 模型

```
输入 CSV                          输出 CSV（不含 --preserve-columns）      错误 CSV
────────                          ────────────────────────────────        ─────────
id,level_str,author               id,success_rate,avg_score[,median_score,std_score,…]              id,level_str,author,error
1,"...",Alice    ──模拟──▶        1,0.87,0.234,…                           5,"???",Eve,"invalid char
2,"...",Bob      ──模拟──▶        2,0.91,0.198,…                            at position 3"
3,"...",Alice    ──模拟──▶        3,0.76,0.301,…
4,"...",Bob      ──模拟──▶        4,0.82,0.256,…
5,"???",Eve      ──校验失败──▶
```

- 输出文件只含成功跑完的行；错误文件只含失败的行；两文件互不重叠，并集 = 输入全集
- 「失败」包括两类：(a) 关卡字符串校验失败（格式非法），(b) 校验通过但模拟执行异常（如规则不兼容、运行时 panic）。error 列为具体错误信息
- 错误文件保留全部原始列 + 追加 `error` 列
- `--preserve-columns` 下，若原始列与输出列有同名冲突（例如同时存在原始 `id` 列和模拟输出 `id` 列），原始列自动加 `_input` 后缀去重（如 `id_input`）
- 单条模式（`--level`）走 stdout/stderr，不涉及上述分文件逻辑
- **默认输出列**（未指定 `--metrics-config` 或 `--metrics-columns`）：`id, success_rate, avg_score`。指定后追加对应指标列

### CSV 格式规范

所有 CSV 输入/输出遵循 **RFC 4180**。字段值在含 `,`、`"` 或 `\n` 时用双引号包裹，内部 `"` 转义为 `""`。错误文件中的 `error` 列同样适用——错误信息若含逗号或换行，由该规则保证 CSV 行完整性。

### 退出码

| 模式 | 退出码 | 含义 |
|---|---|---|
| 单条 | 0 | 模拟成功 |
| 单条 | 1 | 模拟失败（校验不通过或运行时异常） |
| 批量 | 0 | 全部行成功，无错误行 |
| 批量 | 1 | 存在至少一行失败（错误已写入 `--error-file`） |

---

## 三、`tile metrics`

```bash
tile metrics --list                     # 列出所有支持的聚合指标
tile metrics --generate ./metrics.toml  # 生成默认指标配置
```

| 参数 | 别名 | 说明 |
|---|---|---|
| `--list` | `-l` | 列出可用指标（名称 + 简短描述） |
| `--generate <path>` | | 生成默认 metrics.toml |

指标名仅允许字符 `[a-zA-Z0-9_]`，大小写不敏感，内部统一归一化为小写。

生成文件示例：

```toml
# metrics.toml — 由 `tile metrics --generate` 生成，可修改后通过 --metrics-config 传入

[metrics]
enabled = ["success_rate", "avg_score", "median_score", "std_score", "min_score", "max_score"]
```

---

## 四、`tile scorers`

```bash
tile scorers --list                     # 或 -l，列出所有可用 scorer
tile scorers --show PiKa                # 展示 PiKa 的默认权重系数
tile scorers --generate ./score.toml    # 生成包含所有 scorer 默认配置的 toml
```

生成文件示例：

```toml
# score.toml — 由 `tile scorers --generate` 生成，可修改后通过 --scorer-config 传入

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

## 五、`tile validate`

```bash
# 单条
tile validate --level "..." --rule TripleTile

# 批量
tile validate --input-file levels.txt --rule TripleTile --output-file report.txt
```

| 参数 | 说明 |
|---|---|
| `--level` | 单条关卡（与 `--input-file` 互斥） |
| `--input-file` | 批量输入，每行一条 |
| `--rule` | 规则名，单值（默认 `PairClassic`）。传入多个报错 |
| `--output-file` | 批量结果落盘（默认 stdout） |

### 行为约定

- **单条检查**：合法则静默退出（exit 0），不合法则输出错误信息到 stderr（exit 1）
- **批量检查**：逐行输出 CSV（列：`line_number,status,error`），`line_number` 从 1 开始。status 为 `OK` 或 `FAIL`；error 仅在 FAIL 时有值。退出码：全部通过为 0，任意 FAIL 为非 0。由于 `--rule` 为严格单值，不再冗余输出 `rule` 列；若未来支持多规则，再行追加。

---

## 六、`tile completion`

```bash
tile completion -s bash     # 生成 bash 补全脚本，输出到 stdout
tile completion -s zsh      # 生成 zsh 补全脚本，输出到 stdout
```

| 参数 | 别名 | 说明 |
|---|---|---|
| `-s` / `--shell` | — | 目标 shell：`bash` 或 `zsh` |

### 设计思路

C# + `System.CommandLine` 生态下不加 `dotnet-suggest`，采用**手写静态补全模板**方案：

- `tile completion -s bash` 输出一段 bash 脚本，内含完整子命令树和参数的静态补全规则
- `tile completion -s zsh` 同理，按 zsh 语法输出
- 零外部依赖，用户装完 `tile` 即可使用

### 安装方式

```bash
# bash — 临时生效
source <(tile completion -s bash)

# bash — 持久化
tile completion -s bash > ~/.local/share/bash-completion/completions/tile

# zsh — 持久化（先确保 ~/.zfunc 在 fpath 中）
tile completion -s zsh > ~/.zfunc/_tile
```

### 维护约定

新增子命令或参数时需同步更新补全模板。由于当前子命令树较扁平（5 个子命令 + 各子命令下少量参数），维护负担可控。

---

## 七、修订记录

| 日期 | 变更 |
|---|---|
| 2026-07-16 v1 | 初稿：修复 shell 管道冲突（`\|` → `,`）、拼写修正（temperate → temperature）、参数命名统一（list/show/generate）、拆分 `--metrics` 三种语义、补充 `--output`/`--format` |
| 2026-07-16 v2 | `--count` → `--max-run-count`；`--max-success` → `--stop-after-success`；新增 CSV 批量模式参数（`--input-file`/`--output-file`/`--error-file`/`--level-column`/`--id-column`/`--preserve-columns`） |
| 2026-07-16 v3 | 移除 `--format`/`--input-format`，统一 CSV；`--preserve-columns` 默认 false；`--level-column` 必填；错误文件保留全部原始列 + error 列；单条/批量参数统一；`tile scorers` 新增 `--generate` |
| 2026-07-16 v4 | `tile simulate` 新增 `--show-config`：打印所有生效参数及来源（CLI/default/file），配置文件内参数逐项展开，打印后退出不执行模拟 |
| 2026-07-16 v5 | 自查修正：补 `--scorer` 参数、明确 `--rule` 单值/多值语义、单条模式输出格式、`--preserve-columns` 列冲突去重、`tile validate` 批量输出改 CSV、补 metrics 生成示例、统一 `-l` 别名、`--softmax-temperature` 作用域、退出码定义、错误文件失败范围 |
| 2026-07-16 v6 | 子命令重命名：`simulation` → `simulate`，`scorer` → `scorers`，`check` → `validate`；`--rule` 改为严格单值，传入多个直接报错 |
| 2026-07-16 v7 | 新增 `tile completion` 子命令：`-s bash|zsh`，手写静态补全模板方案，输出到 stdout |
| 2026-07-16 v8 | 明确 `--metrics-config` 与 `--metrics-columns` 同时传入直接报错；补充 CSV RFC 4180 格式规范；补充默认输出列清单；明确 `validate --rule` 默认值；明确 simulate 仅解析当前 scorer 段；新增 `--progress` flag；限制 metric 名称字符集 |
| 2026-07-16 v9 | 微调：新增全局 `--help`/`--version` 约定；validate 批量输出去冗余 `rule` 列，`line_number` 注明 1-based；修正指标名字符集描述（`[a-zA-Z0-9_]` 大小写不敏感归一化）；明确 `--softmax-temperature` 非 Behaviour scorer 下静默忽略行为；补充单条模式 `id` 固定为 `single` 的设计理由 |
