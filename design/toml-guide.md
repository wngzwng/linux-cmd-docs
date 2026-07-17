# TOML 格式速览

> 写给没接触过 TOML 的人。聚焦实际会用到的部分，不追求面面俱到。

---

## 一、这是什么

TOML（Tom's Obvious, Minimal Language）是一种配置文件格式，设计目标是「人类一眼就能看懂」。Rust 的 `Cargo.toml`、Python 的 `pyproject.toml` 都用它。

和 JSON / YAML 的关系：

| | JSON | YAML | TOML |
|---|---|---|---|
| 注释 | ❌ | ✅ | ✅ |
| 缩进敏感 | 否 | **是**（缩进就是层级） | 否（层级靠 `[section]`） |
| 适合场景 | 数据交换 | K8s/CI 配置 | 项目配置、工具参数 |
| 容易写错 | 少 | **多**（空格不对就炸） | 少 |

tile-cli 选用 TOML 而非 YAML，核心原因就一个：**缩进不会引入 bug**。

---

## 二、最基础：key = value

```toml
# 这是注释
name = "PiKa"
max_run_count = 1000
temperature = 0.5
enabled = true
```

支持的类型：

```toml
string_val = "hello"           # 字符串（双引号必加）
int_val = 42                   # 整数
float_val = 0.5                # 浮点（必须带小数点或用指数形式 5e-1）
bool_val = true                # 布尔（小写 true/false）
date_val = 2026-07-16          # 日期
```

---

## 三、核心概念：Table（节 / section）

TOML 用 `[section]` 组织层级，**不靠缩进**：

```toml
[server]
host = "0.0.0.0"
port = 8080

[database]
url = "postgres://..."
pool_size = 10
```

等价于 JSON：

```json
{
  "server": { "host": "0.0.0.0", "port": 8080 },
  "database": { "url": "postgres://...", "pool_size": 10 }
}
```

### 嵌套 table：用 `.` 分隔

```toml
[server.https]
port = 443
cert_file = "/etc/ssl/cert.pem"
```

等价于 JSON：

```json
{
  "server": {
    "https": { "port": 443, "cert_file": "/etc/ssl/cert.pem" }
  }
}
```

把 `.` 理解成路径分隔符就行——`[a.b.c]` 就是「a 下面的 b 下面的 c」。

### ⚠️ 关键规则：table 不能「既是爹又是儿子」

这是 TOML 最容易踩的坑。看这个：

```toml
# ❌ 非法！
[server]
host = "0.0.0.0"

[server.https]
port = 443
```

**为什么非法？**

- `[server]` 把 `server` 定义为一个**叶子 table**（直接持有 `host`）
- `[server.https]` 又要求 `server` 是**中间 table**（下面还要有子 table `https`）
- TOML 不允许同一个 table 同时当「叶子」和「中间节点」

正确写法：

```toml
# ✅ 要么全扁平
[server]
host = "0.0.0.0"

[https]          # 换个名字，独立 table
port = 443

# ✅ 要么统一嵌套
[server.connection]
host = "0.0.0.0"

[server.https]
port = 443
```

这也是 score-config.toml 设计中 `[scorer.PiKa]` 和 `[scorer.PiKa.PairClassic]` 必须互斥的原因——它们在 TOML 层面就无法共存。

---

## 四、数组

```toml
# 简单数组
ports = [8080, 8081, 8082]
names = ["alice", "bob"]

# 多行写法（逗号可选，但推荐加）
colors = [
    "red",
    "green",
    "blue",
]

# 数组的数组
matrix = [[1, 0], [0, 1]]
```

---

## 五、数组 Table：`[[name]]`

双中括号表示「这个 table 在数组中」：

```toml
[[players]]
name = "Alice"
score = 100

[[players]]
name = "Bob"
score = 85
```

等价于 JSON：

```json
{
  "players": [
    { "name": "Alice", "score": 100 },
    { "name": "Bob", "score": 85 }
  ]
}
```

每一次 `[[players]]` 往 `players` 数组里追加一个元素。tile-cli 暂时用不到这个，知道有就行。

---

## 六、内联 Table

```toml
# 标准写法
[point]
x = 1
y = 2

# 等价内联写法
point = { x = 1, y = 2 }
```

适合简单结构，太长了反而难读。score-config 里的权重用标准 section 别用内联。

---

## 七、常见错误

### 1. 重复定义同一个 table

```toml
# ❌ 非法
[server]
host = "0.0.0.0"

[database]
url = "..."

[server]        # 重复了！
port = 8080
```

TOML 不允许同一个 section 出现两次。要么合并到一个 `[server]`，要么改名。

### 2. 字符串忘加引号

```toml
# ❌ 非法
name = PiKa      # 没引号，解析器会懵

# ✅ 正确
name = "PiKa"
```

### 3. 浮点数写成整数

```toml
# ❌ 会被解析为整数 1，不是浮点 1.0
weight = 1

# ✅
weight = 1.0
```

类型敏感的解析器可能会报错，建议需要浮点时就写小数点。

### 4. 空 section

```toml
# ✅ 合法
[scorer.Random.TripleTile]
# 无配置参数
```

里面只有注释没有键值对，这是合法的。生成模板时用这种方式占位很常见。

---

## 八、和 tile-cli 的关系

tile-cli 用到 TOML 的地方：

| 文件 | 用途 |
|---|---|
| `score-config.toml` | scorer 权重等参数配置 |
| `metrics.toml` | 聚合指标选择 |

两个文件都用 `[section]` 组织，不涉及 `[[array]]` 和内联 table。记住一个核心规则就够：**同一个 table 名不能既有直接键值对，又有子 table**。

---

## 九、快速参考

```
# 注释
key = "string"              # 字符串
key = 42                    # 整数
key = 0.5                   # 浮点
key = true                  # 布尔
key = [1, 2, 3]            # 数组

[table]                     # 普通 table
[parent.child]              # 嵌套 table（parent.child 是路径）
[[array_table]]             # 数组 table（追加到数组）
key = { a = 1, b = 2 }     # 内联 table
```

---

## 延伸阅读

- [TOML 官方 spec（v1.0.0）](https://toml.io/cn/v1.0.0) — 有中文版
- [design/score-config-toml.md](./score-config-toml.md) — 基于 TOML 的 scorer 配置设计
