
# csvjson：CSV → JSON——命令行里的数据序列化桥

管道里处理数据用 csvkit，但传给 Web 前端、API、或者存到 NoSQL 数据库时需要 JSON。`csvjson` 就是 csvkit 到外部世界的出口——把处理好的 CSV 转成 JSON，可以是数组、可以是按主键嵌套的对象、也可以是 GeoJSON。

---

## 场景引入：两个 CSV 要变成 API 数据的瞬间

### 场景一：给前端同事一个 mock API

```bash
# users.csv → JSON 数组，直接复制粘贴给前端
csvjson users.csv
```

```json
[
  {"id": "1", "name": "张三", "city": "北京"},
  {"id": "2", "name": "李四", "city": "上海"}
]
```

### 场景二：按 ID 快速查找——Keyed JSON

```bash
csvjson -k id users.csv
```

```json
{
  "1": {"id": "1", "name": "张三", "city": "北京"},
  "2": {"id": "2", "name": "李四", "city": "上海"}
}
```

前端可以直接 `data["1"].name` 取值，不需要遍历数组。

---

## 它是怎么工作的——IO 模型

csvjson 是**单向转换**——CSV → JSON，不可逆（反向用 `in2csv -f json`）。

```
输入 CSV（stdin / 文件名）
    │
    ↓ 读表头 + 所有数据行
    │
    ↓ 按输出模式组装 JSON：
    │   ├─ 默认：每行 → 一个 JSON 对象，所有行 → JSON 数组
    │   ├─ -k key：按指定列的值做顶层 key → 嵌套对象
    │   └─ --lat/--lon：纬度/经度 → GeoJSON Point
    │
    ↓ 输出 JSON → stdout
```

> 💡 csvjson 默认把所有值当字符串处理。数字、布尔值、null 在 JSON 里都会变成带引号的字符串——除非加 `-t` 让 csvkit 做类型推断。

---

## 语法骨架

```
csvjson  [-k 主键列]  [-c]  [-t]  [--lat 纬度列 --lon 经度列]  [文件.csv]
         ────┬────    ─┬─   ─┬─   ───────────┬───────────      ──┬──
          嵌套模式   压缩  类型推断           GeoJSON           数据源
```

---

## ⚠️ 先排雷：csvjson 最容易踩的四个坑

### 雷一：默认所有值都是字符串

```bash
csvjson data.csv
# "amount": "500"     ← 字符串！
# "active": "true"    ← 字符串！

csvjson -t data.csv
# "amount": 500       ← 数字
# "active": true      ← 布尔
```

传给 API 时，后端同学期望 `"amount": 500` 而不是 `"amount": "500"`。加了 `-t` 才做类型推断。

### 雷二：CSV 10MB → JSON 40MB

JSON 比 CSV 冗余。每行都要带上所有列名做键，再加上花括号、方括号、逗号、缩进。体积通常膨胀 2-5 倍。大文件转 JSON 前先确认下游真能接收。

### 雷三：`-c` 压缩输出的可读性

```bash
csvjson -c data.csv      # 一行 JSON，无缩进无空格
# 人没法读，但适合机器消费——curl -d 可以直接用
```

### 雷四：嵌套对象和数组不支持

CSV 是扁平的。csvjson 只能生成扁平的 JSON 对象。如果你的下游需要嵌套结构（`"address": {"city": "北京", "zip": "100000"}`），csvjson 做不了——必须先转再用 `jq` 重组。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 结构轴 | JSON 顶层是什么？ | 默认数组、`-k` 按主键嵌套对象 |
| 类型轴 | 值是什么类型？ | 默认字符串、`-t` 自动推断 |
| 格式轴 | 格式化还是压缩？ | 默认美化、`-c` 压缩 |
| 地理轴 | 经纬度数据？ | `--lat` + `--lon` → GeoJSON |

### 轴 1：默认数组模式

```bash
csvjson data.csv
# [{"col1": "val1", ...}, {"col1": "val2", ...}]
```

### 轴 2：Keyed 模式 `-k`

```bash
csvjson -k id users.csv
# {"1": {...}, "2": {...}}
```

选了 `-k` 之后，该列的值变成 JSON 顶层对象的 key。要求该列值在该文件中唯一——否则后面的行会覆盖前面的。

### 轴 3：类型推断 `-t`

```bash
csvjson -t data.csv
# 数字 → Number, true/false → Boolean, 空 → null
```

### 轴 4：GeoJSON `--lat` `--lon`

```bash
csvjson --lat latitude --lon longitude --type Point locations.csv
# {"type": "Point", "coordinates": [116.4, 39.9]}
```

---

## 场景组合

```bash
# 过滤 → 选列 → 排序 → 数字类型 → 压缩 → 喂给 curl
csvgrep -c status -m active users.csv \
  | csvcut -c id,name,email,score \
  | csvsort -c score -r \
  | csvjson -t -c \
  | curl -X POST https://api.example.com/upload \
      -H "Content-Type: application/json" -d @-

# 统计 → Keyed JSON
csvstat --csv data.csv | csvjson -k column_name
```

---

## csvjson vs jq vs Python json：什么时候用哪个

| 场景 | csvjson | jq | Python |
|------|---------|-----|--------|
| CSV → JSON | ✅ 一行 | ❌ 需先转 | ⚠️ 需写脚本 |
| JSON → CSV | ❌ 用 in2csv | ⚠️ | ⚠️ |
| JSON 重组/嵌套 | ❌ | ✅ `jq '{...}'` | ✅ |
| 大文件转 JSON | ⚠️ 会膨胀 | — | ⚠️ |

> 💡 一句话：**CSV → JSON 用 csvjson，JSON 处理和重组用 jq，复杂逻辑写 Python。**

---

## 新手踩坑总结

- **默认值是字符串。传给机器用 `-t` 做类型推断。**
- **`-k` 要求主键列值唯一。** 重复值会导致后面的覆盖前面的。
- **大文件转 JSON 体积膨胀严重。** 10MB CSV = 30-50MB JSON。
- **csvjson 不处理嵌套。** 扁平 CSV 只能出扁平 JSON。
