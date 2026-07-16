
# csvstack：纵向拼接 CSV——命令行里的 UNION ALL

两个结构相同（列名和顺序一致）的 CSV，想把它们摞在一起。这就是 SQL 的 `UNION ALL`，Excel 的「复制粘贴到底部」，命令行里 `cat file1.csv file2.csv` 的升级版——升级在哪？`cat` 会重复表头，csvstack 只保留一份。

---

## 场景引入：两个你试图用 cat 拼接 CSV 的瞬间

### 场景一：按季度拆分的销售报表

```bash
# Q1.csv：month,sales,region
# Q2.csv：month,sales,region

# ❌ cat：表头重复！
cat Q1.csv Q2.csv
# month,sales,region
# 1月,100,北区
# 2月,200,北区
# month,sales,region    ← 第二份表头出现在数据行里！
# 4月,300,南区

# ✅ csvstack：只保留第一份表头
csvstack Q1.csv Q2.csv
# month,sales,region
# 1月,100,北区
# 2月,200,北区
# 4月,300,南区          ← 干净，没有重复表头
```

### 场景二：多个数据源合并，想知道每行来自哪里

```bash
# 三个分公司各交了一份 CSV，结构一样，但你想标注来源
csvstack -g source branch_a.csv branch_b.csv branch_c.csv
# 输出新增一列 "source"，值为文件名
```

---

## 它是怎么工作的——IO 模型

csvstack 的逻辑极其简单：把多个 CSV 看成同一张表，按顺序首尾相接。

```
file1.csv           file2.csv           file3.csv
  │                    │                    │
  ↓ 读表头              ↓ 读表头（校验）      ↓ 读表头（校验）
  ↓ 保留 → 输出         ↓ 丢弃               ↓ 丢弃
  ↓ 逐行输出             ↓ 逐行输出           ↓ 逐行输出
  │                    │                    │
  └────────────────────┴────────────────────┘
                      ↓
               输出 CSV（stdout）
               可选：-g 新增一列标示来源文件
```

> 💡 csvstack 就做两件事：1）去重表头；2）可选地加来源标识列。它不检查数据是否有重复——那是 `uniq` 的活。

---

## 语法骨架

```
csvstack  [-g 来源列名]  [-n 组名列表]  文件1.csv  文件2.csv  ...
          ─────┬─────    ─────┬─────    ───────┬────────
           加来源列         自定义组名        多个输入文件
```

---

## ⚠️ 先排雷：csvstack 最容易踩的三个坑

### 雷一：列名不完全一致 → 列数膨胀

```bash
# a.csv：name,age
# b.csv：Name,Age
# csvstack 看到的是 4 个不同的列名：name, age, Name, Age
# 输出有 4 列，数据错位！
csvstack a.csv b.csv
```

列名是**大小写敏感**的。拼接前务必确认列名完全一致：

```bash
csvcut -n a.csv && csvcut -n b.csv
```

### 雷二：列顺序不一致 → 数据错位

```bash
# a.csv：name,age,city
# b.csv：name,city,age
# csvstack 不会自动按列名对齐——它按位置拼接！
# b.csv 的 city 数据会跑到 a.csv 的 age 列位置
```

拼接前用 `csvcut -c` 统一列顺序：

```bash
csvstack a.csv <(csvcut -c name,age,city b.csv)
```

### 雷三：csvstack 不自动校验表头

和 csvjoin 不同，csvstack **不会报错**告诉你列名不一致——它只是静默地产生错位数据。必须在拼接前自己检查列名和顺序。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 拼接轴 | 纵向合并多个 CSV | 文件列表（位置参数） |
| 来源轴 | 标注每行从哪个文件来 | `-g` 加一列 |
| 命名轴 | 来源列叫什么值 | `-n` 自定义组名替代文件名 |

### 轴 1：基本拼接

```bash
csvstack file1.csv file2.csv file3.csv          # 多个文件拼接
csvstack part-*.csv                              # 通配符（shell 展开）
cat monthly/*.csv | csvstack                     # ❌ 不工作：stdin 只能是一个文件
```

> ⚠️ csvstack 不支持从 stdin 读取多个文件。管道只能送一个文件的内容——csvstack 需要知道文件边界来判断哪些行是表头。

### 轴 2：加来源标识 `-g`

```bash
csvstack -g source q1.csv q2.csv q3.csv
# 输出自动加一列 "source"，值分别为 "q1.csv"、"q2.csv"、"q3.csv"
```

列名就是 `-g` 后面的名字，值就是文件名。

### 轴 3：自定义组名 `-n`

```bash
csvstack -g quarter -n "Q1,Q2,Q3,Q4" q1.csv q2.csv q3.csv q4.csv
# quarter 列的值分别为 "Q1"、"Q2"、"Q3"、"Q4"（而非文件名）
```

---

## 场景组合

### 1. 统一列序 → 拼接 → 排序 → 去重

```bash
# 三个分公司交的数据列序不一样，先统一
csvstack \
  <(csvcut -c name,age,city branch_a.csv) \
  <(csvcut -c name,age,city branch_b.csv) \
  <(csvcut -c name,age,city branch_c.csv) \
  | csvsort -c name \
  | head -1 > combined.csv; csvsort -c name combined.csv | tail -n +2 | sort -u >> combined.csv
```

### 2. 拼接 → 加来源标识 → 统计各分支贡献

```bash
csvstack -g branch east.csv west.csv north.csv south.csv \
  | csvstat --freq -c branch
# 看每个分支的数据量
```

### 3. 月度数据拼接成年报 → SQL 分析

```bash
csvstack -g month -n "$(printf '%s,' {1..12} | sed 's/,$//')" month_*.csv \
  | csvsql --query "
      SELECT month, category, SUM(amount) AS total
      FROM stdin GROUP BY month, category
    "
```

---

## csvstack vs cat vs SQL UNION ALL：什么时候用哪个

| 场景 | csvstack | cat | csvsql |
|------|----------|-----|--------|
| 简单拼接（列名一致） | ✅ | ⚠️ 需手动去重表头 | 可以但不必要 |
| 需要去重表头 | ✅ | ❌ | ✅ |
| 需要加来源标识 | ✅ `-g` | ❌ | ✅ `SELECT *, 'east' AS region FROM ...` |
| 需要去重数据行 | ❌ | ❌ | ✅ `UNION`（自动去重） |
| 列名不一致时自动处理 | ❌ | ❌ | ⚠️ 需要显式处理 |

> 💡 一句话：**纵向拼 CSV 用 csvstack；要同时去重数据行用 csvsql UNION；普通文本文件拼接用 cat。**

---

## 新手踩坑总结

- **拼接前检查列名和列序。** csvstack 不校验，不一致就静默错位。
- **`-g` 会自动加一列。** 值的默认是文件名，可以用 `-n` 自定义。
- **csvstack 不做数据去重。** 重复数据行会直接保留——需要去重请用 `sort -u` 或 csvsql `UNION`。
- **无法从 stdin 拼接多个文件。** 管道只能送一个文件的内容。
- **csvstack 是 UNION ALL，不是 UNION。** 和 SQL 不一样，它不去重。
