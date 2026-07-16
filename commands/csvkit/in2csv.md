
# in2csv：万用格式 → CSV——所有格式进管道的第一站

Excel、JSON、固定宽度文本、dBASE、ndjson——这些东西读成的第一关就是转成标准 CSV。`in2csv` 是 csvkit 的「万能翻译器」：识别输入格式，转成 CSV 输出，然后就可以走 csvcut/csvgrep/csvsql 的管道了。

---

## 场景引入

老板扔给你一个 `report.xlsx`，让你提取第三张表里销售额 > 1000 的行，按金额排序。你没装 Excel，也不想装。

```bash
in2csv --sheet "Q3 Sales" report.xlsx \
  | csvsql --query "SELECT * FROM stdin WHERE amount > 1000" \
  | csvsort -c amount -r \
  | csvlook
```

全程不需要 Excel。

---

## 核心能力

### Excel → CSV（`--sheet` 指定表）

```bash
in2csv report.xlsx                           # 第一张表
in2csv --sheet "Sheet2" report.xlsx          # 指定表名
in2csv --write-sheets sheets/ report.xlsx    # 所有表各写一个 CSV
in2csv -n report.xlsx                        # 只看有哪些表名，不导出
```

### JSON → CSV

```bash
in2csv -f json data.json
```

### ndjson（一行一个 JSON）→ CSV

```bash
in2csv -f ndjson data.ndjson
```

### 固定宽度文本 → CSV

```bash
# 需要提供 schema 文件（CSV 格式，定义每列的名字和起止位置）
cat > schema.csv << 'EOF'
column,start,length
name,1,20
age,21,3
city,24,20
EOF

in2csv -f fixed -s schema.csv data.txt
```

### dBASE (.dbf) → CSV

```bash
in2csv data.dbf
```

### 自动检测格式

```bash
in2csv whatever.ext   # 根据扩展名自动判断
```

---

## 管道中的经典用法

```bash
# Excel → 过滤 → 排序 → 渲染
in2csv staff.xlsx \
  | csvgrep -c department -m "研发" \
  | csvsort -c salary -r \
  | csvlook

# JSON API 响应 → CSV → 统计
curl https://api.example.com/data | in2csv -f json | csvstat

# 日志文件（固定宽度） → CSV → SQL 分析
in2csv -f fixed -s schema.csv app.log | csvsql --query "SELECT ..." stdin
```

---

## ⚠️ 雷区

### Excel 依赖 xlrd / openpyxl

老版 `.xls` 需要 `xlrd`，新版 `.xlsx` 需要 `openpyxl`。装 csvkit 时通常一起装了，但如果在精简环境里可能缺：

```bash
pip install xlrd openpyxl
```

### JSON 的嵌套结构会被展平

```json
{"name": "张三", "address": {"city": "北京", "zip": "100000"}}
```

转成 CSV 后：

```
name,address_city,address_zip
张三,北京,100000
```

嵌套对象会被用 `_` 展开为平列。如果你不需要这种行为，可能要先自己用 jq 预处理。

### 固定宽度需要精确的 schema

固定宽度转换非常依赖 schema 文件里的 `start` 和 `length`——一个字符不对就会所有行错位。先用 `head` 看几行实际数据确认列宽。
