
# csvsort：按列排序 CSV——知道表头的排序引擎

`sort -t, -k2` 能给 CSV 排序，但它不认表头。它会把你第一行的 `"salary"` 也当成数字排进数据里，而且排序结果中 `"9"` 排在 `"10"` 后面（字母序）。`csvsort` 是专为 CSV 设计的排序工具：它知道第一行是表头，知道哪列是数字、哪列是日期，还能按多列排序。

---

## 场景引入：两个被 sort 坑过的瞬间

### 场景一：按薪资排序，表头被排到最后

```bash
# employees.csv：
# id,name,department,salary
# 1,张三,研发,15000
# 2,李四,市场,9000
# 3,王五,研发,12000

# ❌ sort -t, -k4 -n：数字排正确，但 "salary" 行被排到了最前面
sort -t, -k4 -n employees.csv
# salary
# 9000
# 12000
# 15000
# — 表头变成了一条数据！

# ✅ csvsort 自动跳过表头
csvsort -c salary -r employees.csv
# id,name,department,salary
# 1,张三,研发,15000   ← 表头还在第一行，数据按薪资降序
# 3,王五,研发,12000
# 2,李四,市场,9000
```

### 场景二：按日期列排序，sort 当文本排

```bash
# ❌ sort -t, -k5：日期按字母序排，"2020-03-15" < "2020-11-01" 但 "2020-11-01" < "2020-03-15"？
sort -t, -k5 employees.csv  # "01" > "15"？不可预测！

# ✅ csvsort 指定日期格式
csvsort -c hire_date --date-format "%Y-%m-%d" employees.csv
```

---

## 它是怎么工作的——IO 模型

csvsort 是**全量排序**引擎：它必须读完整张表才能输出——因为最后一行可能排在最前面。

```
输入 CSV（stdin / 文件名）
    │
    ↓ 读表头 → 保留，不参与排序
    │
    ↓ 读全部数据行 → 解析排序列为 Python 类型（int/float/date/str）
    │
    ↓ 按 -c 指定的列排序（稳定排序）
    │   多列：先按第一列排，相同值再按第二列排
    │
    ↓ 输出：表头 + 排序后的数据行 → stdout
```

> 💡 csvsort 和 `csvsql "ORDER BY"` 的区别：csvsort 是流式的（读完全表就排完），csvsql 会把整个 CSV 导入 SQLite 再排序。小文件 csvsort 更快，大文件 csvsql 内存效率更好。

---

## 语法骨架

```
csvsort  -c 列名  [-r]  [--date-format 格式]  [文件.csv]
         ──┬──    ─┬─        ─────┬─────         ──┬──
         按哪列   降序         日期格式           数据源
```

---

## ⚠️ 先排雷：csvsort 最容易踩的三个坑

### 雷一：数字排序可能猜错类型

```bash
# 如果 salary 列里混入了 "N/A" 这种文本值，csvsort 可能把整列当文本排序
# 结果："15000" < "9000"（因为 '1' < '9'）

# ✅ 确保排序列是纯数字。有脏数据先过滤
csvgrep -c salary -r "^[0-9]+$" data.csv | csvsort -c salary -r
```

### 雷二：多列排序的方向问题

```bash
# ⚠️ 一个 -r 作用于全部排序列！
csvsort -c department,salary -r employees.csv
# department 降序 AND salary 降序

# 如果想 department 升序、同部门内 salary 降序：
# csvsort 不支持单列指定方向！
# 只能先按 salary 降序排好存临时文件，再按 department 稳定排序
```

`-r` 是全局的——要么全升序，要么全降序。如果有复杂的混合方向需求，用 `csvsql`：

```bash
csvsql --query "SELECT * FROM employees ORDER BY department ASC, salary DESC" employees.csv
```

### 雷三：日期格式必须精确指定

```bash
csvsort -c hire_date --date-format "%Y-%m-%d" data.csv       # "2020-03-15"
csvsort -c hire_date --date-format "%d/%m/%Y" data.csv       # "15/03/2020"
csvsort -c hire_date --date-format "%Y-%m-%dT%H:%M:%S" data.csv # ISO 8601
```

格式不匹配不会报错——只是排序结果会退化为文本排序。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 目标轴 | 按哪一列排？ | `-c` 列名或列号 |
| 方向轴 | 升序还是降序？ | 默认升序、`-r` 降序 |
| 类型轴 | 按什么类型比？ | 自动推断 + `--date-format` 指定日期格式 |
| 多列轴 | 先按 A 再按 B？ | `-c A,B` 多列逗号分隔 |

### 轴 1：单列排序

```bash
csvsort -c name data.csv                  # 按 name 升序（A→Z）
csvsort -c salary -r data.csv             # 按 salary 降序（高→低）
```

### 轴 2：多列排序

```bash
csvsort -c department,salary -r data.csv  # 按部门降序，同部门内按薪资降序
csvsort -c department,salary data.csv     # 按部门升序，同部门内按薪资升序
```

`-c` 里的第一个列名是第一排序键，第二个是 tie-breaker。csvsort 使用稳定排序——相同键值的行保持原顺序。

### 轴 3：日期排序

```bash
csvsort -c hire_date --date-format "%Y-%m-%d" employees.csv
csvsort -c created_at --date-format "%Y-%m-%dT%H:%M:%S" events.csv
```

---

## 场景组合

### 1. 过滤 → 排序 → 渲染

```bash
csvgrep -c department -m "研发" employees.csv \
  | csvsort -c salary -r \
  | csvlook
```

### 2. 关联 → 排序 → 取 Top 10

```bash
csvjoin -c user_id,id users.csv orders.csv \
  | csvcut -c name,amount \
  | csvsort -c amount -r \
  | head -11   # +1 是表头
```

### 3. 按统计结果排序

```bash
# 先按品类汇总 → 汇总结果存为 CSV → 再按总额排序
csvsql --query "
  SELECT category, SUM(amount) AS total FROM sales GROUP BY category
" sales.csv | csvsort -c total -r | csvlook
```

---

## csvsort vs sort vs csvsql：什么时候用哪个

| 场景 | csvsort | sort | csvsql |
|------|---------|------|--------|
| 简单单列排序 | ✅ | ✅ `sort -t, -kN` | 可以但不必要 |
| 表头自动保留 | ✅ | ❌ | ✅ |
| 数字自动识别 | ✅ | 需加 `-n` | ✅ |
| 日期排序 | ✅ `--date-format` | ❌ 需 `-M` 手动处理 | ✅ `ORDER BY date()` |
| 混合方向多列排序 | ❌ 单方向 | ✅ `-k1,1 -k2,2nr` | ✅ `ASC/DESC` |
| 百万行以上 | ⚠️ | ✅ 内存友好 | ✅ SQLite 更稳定 |

> 💡 一句话：**标准 CSV 用 csvsort，需要混合方向的多列排序用 csvsql，非 CSV 纯文本用 sort。**

---

## 新手踩坑总结

- **`-r` 是全局的，作用于所有排序列。** 不能单独指定某一列升序、另一列降序。
- **日期排序必须指定 `--date-format`。** 没有格式参数 = 按文本排序 = 大概率错误。
- **确保排序列类型纯净。** 混入一个 `"N/A"` 可能导致整列被当文本排序。
- **csvsort 需要读全表。** 它不能像 sql 那样只排一部分——所有行都会参与排序。
