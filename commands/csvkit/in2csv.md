
# in2csv：各种格式 → CSV——所有数据进 csvkit 管道的第一站

csvkit 的管道只能吃 CSV。但现实中的数据从来不只 CSV——同事扔过来的 Excel、从 API 取的 JSON、老系统导出的固定宽度文本、甚至上世纪遗留的 dBASE 文件。`in2csv` 是 csvkit 的「万能翻译器」：识别输入格式，转成标准 CSV，然后就可以走 csvcut/csvgrep/csvsql 的管道了。没有 in2csv，csvkit 就只能处理已经规整好的 CSV 文件。

---

## 场景引入：两个让你绝望地想装 Excel 的瞬间

### 场景一：老板扔过来一个 .xlsx

```bash
# 老板：帮我从第三张表里把销售额 > 1000 的挑出来，按金额排个序
# 你：没有 Excel，也不想装

# ❌ 新手做法：求同事导出 CSV → 邮箱里找了半天

# ✅ in2csv 一行开始管道
in2csv --sheet "Q3 Sales" report.xlsx \
  | csvsql --query "SELECT * FROM stdin WHERE amount > 1000" \
  | csvsort -c amount -r \
  | csvlook
```

Excel 变成了管道里的第一个环节。全程不需要打开任何 Office 软件。

### 场景二：日志文件是固定宽度的

```
20250713 14:30:15 ERROR disk full
20250713 14:30:16 INFO  retrying
```

没有逗号分隔，字段靠固定的列宽来区分。awk 也能处理，但需要你手工量每列的起止位置。in2csv 提供了结构化的方式：

```bash
# 先定义列宽（schema.csv）
cat > schema.csv << 'EOF'
column,start,length
timestamp,1,17
level,18,5
message,23,100
EOF

in2csv -f fixed -s schema.csv app.log | csvgrep -c level -m "ERROR"
```

---

## 它是怎么工作的——IO 模型

in2csv 是一个**格式检测 + 格式转换**工具。它根据输入文件扩展名或 `-f` 显式指定，选择合适的解析器，统一输出为 CSV。

```
输入（各种格式）
    │
    ↓ 格式检测：
    │   .xlsx/.xls → openpyxl/xlrd
    │   .json → json 解析器（自动展平嵌套对象）
    │   .dbf → dbf 解析器
    │   -f fixed → 固定宽度解析器（需 schema 文件）
    │   -f ndjson → 一行一个 JSON 的解析器
    │
    ↓ 转换为 CSV → stdout
```

> 💡 in2csv 和 `csvformat` 的区别：csvformat 在 CSV 方言间转换（pipe↔逗号），in2csv 在不同文件格式间转换（Excel↔CSV、JSON↔CSV）。一个是「同一种东西的不同说法」，一个是「完全不同的语言」。

---

## 语法骨架

```
in2csv  [-f 格式]  [-s schema文件]  [--sheet 表名]  [文件]
        ───┬───     ─────┬─────      ─────┬──────    ──┬─
        输入格式    固定宽度的列定义     Excel 表名    数据源
```

常用 `-f` 值：`csv`（默认）、`json`、`ndjson`、`fixed`、`dbf`、`xls`、`xlsx`。

---

## ⚠️ 先排雷：in2csv 最容易踩的四个坑

### 雷一：Excel 依赖 Python 库

```bash
# .xls 需要 xlrd
pip install xlrd

# .xlsx 需要 openpyxl
pip install openpyxl
```

csvkit 安装时不一定带这些（它们是可选依赖）。遇到 `No module named 'openpyxl'` 不要慌，装一下就好。

### 雷二：JSON 嵌套对象会被展平

```json
{"name": "张三", "address": {"city": "北京", "zip": "100000"}}
```

转成 CSV 后：

```
name,address_city,address_zip
张三,北京,100000
```

嵌套对象用 `_` 连接父键和子键来实现展平。这不是 bug，是 CSV 扁平本质的必然结果。如果你需要保留嵌套结构，先用 `jq` 做预处理。

### 雷三：固定宽度转换对 schema 精度要求极高

```bash
# schema 里写 start=2,length=5，但实际列宽是 6 → 全表错位
# 一定先用 head + 肉眼确认列边界，再写 schema
```

### 雷四：`-n` 看一眼 Excel 有哪些表

```bash
in2csv -n report.xlsx
# Sheet1: Q1 Sales
# Sheet2: Q2 Sales
# Sheet3: Q3 Summary
```

一定先用 `-n` 看有哪些 sheet，再 `--sheet` 选择。名字有空格的一定要加引号。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 格式轴 | 输入是什么格式？ | `-f` 显式指定，或靠扩展名自动推断 |
| Excel 轴 | 哪个 sheet？ | `--sheet` 表名、`-n` 列出所有表名、`--write-sheets` 导出全部 |
| 固定宽度轴 | 每列多宽？ | `-s schema.csv` 定义列起止位置 |
| 编码轴 | 什么字符集？ | `--encoding utf-8/gbk/latin-1` |

### 轴 1：自动格式检测

```bash
in2csv data.xlsx               # 根据 .xlsx 自动选 Excel 解析器
in2csv data.json               # 根据 .json 自动选 JSON 解析器
in2csv data.csv                # 已经是 CSV → 相当于 cat（但会校验）
```

### 轴 2：Excel 操作

```bash
in2csv -n report.xlsx                              # 列出 sheet
in2csv --sheet "Q3" report.xlsx                    # 导出指定 sheet
in2csv --write-sheets sheets/ report.xlsx           # 所有 sheet 各写一个 CSV
```

### 轴 3：JSON / ndjson

```bash
in2csv -f json api_response.json                   # JSON 数组 → CSV
in2csv -f ndjson events.ndjson                     # 一行一个 JSON → CSV
```

### 轴 4：固定宽度

```bash
in2csv -f fixed -s schema.csv legacy_report.txt    # 需要 schema 文件
```

---

## 场景组合

### 1. Excel → 过滤 → 聚合 → 渲染

```bash
in2csv --sheet "Sales" report.xlsx \
  | csvgrep -c region -m "华东" \
  | csvsql --query "SELECT category, SUM(amount) FROM stdin GROUP BY category" \
  | csvlook
```

### 2. JSON API → 统计

```bash
curl -s https://api.example.com/users | in2csv -f json | csvstat
```

### 3. 固定宽度日志 → CSV → SQL

```bash
in2csv -f fixed -s schema.csv app.log \
  | csvsql --query "SELECT level, COUNT(*) FROM stdin GROUP BY level"
```

---

## 新手踩坑总结

- **Excel 依赖 `xlrd`（.xls）和 `openpyxl`（.xlsx）。** 报 `ModuleNotFoundError` 就去 pip install。
- **JSON 嵌套会自动展平。** 复杂的嵌套结构先 `jq` 处理再给 in2csv。
- **固定宽度 schema 必须精确。** 一个字符的偏差都可能导致全表错位。
- **`-n` 先看有哪些 sheet。** 不要猜名字。
- **in2csv 是管道的起点。** 它把「不是 CSV 的东西」变成 CSV，然后交给 csvcut/csvgrep/csvsql 继续处理。
