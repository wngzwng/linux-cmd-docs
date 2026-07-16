
# csvpy：CSV 打开就是 Python REPL——从命令行到交互式探索的无缝切换

管道处理 CSV 很方便，但有时候你需要交互式探索——试一个操作，看结果，不满意再换一个试试。反复跑一长串管道来探索数据是低效的。`csvpy` 把 CSV 加载为 Python 的 agate table 对象，直接打开一个 REPL（交互式 Python 环境），数据已经在 `table` 变量里等着你。不需要写 `import csv`、`open()`、`csv.reader()`——csvpy 全帮你做好了。

---

## 场景引入：两个在管道和 Python 之间反复横跳的瞬间

### 场景一：「这列到底是数字还是文本？」

```bash
csvpy sales.csv
```

进入 REPL 后：

```python
>>> table.column_names
['order_id', 'customer_id', 'amount', 'category', 'date']

>>> table.columns['amount'].data_type
Number

>>> table.columns['amount'].aggregate(agate.Mean())
346.5

>>> table.aggregate(agate.Count())
500000
```

不需要 `pd.read_csv()`，不需要 `df.info()`——数据已经就位。

### 场景二：「我想算一个 csvkit 没有的统计量」

```python
# 比如：amount 列的偏度（skewness），csvstat 不输出

>>> import statistics
>>> values = [r['amount'] for r in table.rows if r['amount'] is not None]
>>> statistics.stdev(values) / statistics.mean(values)  # 变异系数
```

---

## 它是怎么工作的——IO 模型

csvpy 本质上是 csvkit 底层引擎（agate 库）的 REPL 入口。它用 csvkit 的能力把 CSV 解析为 agate Table 对象，然后启动一个增强版 Python REPL，把 `table` 变量注入其中。

```
输入 CSV → agate.Table（内存中的关系表）
    │
    ↓ 启动 Python REPL
    │  变量 table = 这张表
    │  可用方法：table.columns / table.rows / table.where() / table.compute()
    │  可用聚合：agate.Mean() / agate.Sum() / agate.Count() ...
    │
    ↓ 交互式探索 → Ctrl+D 退出
```

---

## 语法骨架

```
csvpy  [-c "Python 代码"]  [文件.csv ...]
       ───────┬───────      ─────┬─────
          非交互执行             数据源
```

---

## ⚠️ 先排雷：csvpy 最容易踩的三个坑

### 雷一：csvpy 是探索工具，不是生产工具

```bash
# ❌ 不要写进脚本
csvpy -c "print(len(table.rows))" data.csv > count.txt

# ✅ 脚本里用 Python 直接 import agate，或者用 csvsql
```

csvpy 的设计目的是**你坐在终端前和它交互**。脚本里请用 agate 库或 csvsql。

### 雷二：需要了解 agate 的 API

```python
>>> table.where(lambda r: r['amount'] > 100)      # ❌ 结果被丢弃了，where 返回新表
>>> filtered = table.where(lambda r: r['amount'] > 100)  # ✅ 赋给变量，后续操作 filtered
```

agate 是一个完整的 Python 数据分析库，比 pandas 轻量但有自己的 API 风格。`table.where()` 返回新 table（不会修改原表），`table.compute()` 返回加了新列的 table。

### 雷三：大文件加载到 REPL 可能很慢

csvpy 加载 500 万行 CSV 可能要好几十秒——它把整张表载入 Python 对象。对超大数据集，考虑用 `csvsql` 或先抽样：`head -10000 | csvpy`。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 入口轴 | 怎么启动？ | `csvpy data.csv` 打开 REPL |
| 变量轴 | 数据在哪？ | 单文件 → 变量 `table`，多文件 → `table1, table2, ...` |
| 库轴 | 用什么操作数据？ | 内置 `agate` 库自动导入 |
| 脚本轴 | 能不能不进入 REPL？ | `-c "代码"` 非交互执行 |

### 轴 1：交互式 REPL

```bash
csvpy data.csv
>>> table
<agate.table.Table ...>
>>> table.print_table(max_rows=10)
```

### 轴 2：多文件

```bash
csvpy sales.csv users.csv
# table1 = sales.csv, table2 = users.csv
```

### 轴 3：非交互执行 `-c`

```bash
csvpy -c "print(table.columns['amount'].aggregate(agate.Sum()))" sales.csv
```

### 轴 4：管道输入

```bash
csvgrep -c category -m "电子产品" sales.csv | csvpy
# stdin → table
```

---

## 典型探索流程

```bash
$ csvpy employees.csv
>>> table.column_names                           # 有哪些列
>>> table.columns['salary'].aggregate(agate.Mean())  # 平均薪资
>>> high = table.where(lambda r: r['salary'] > 50000)  # 高薪的
>>> high.column_names == table.column_names      # 验证列没丢
>>> high.compute([('bonus', agate.Formula(...))]) # 计算新列
>>> high.to_csv('high_salary.csv')              # 导出
>>> exit()                                        # Ctrl+D
$ csvlook high_salary.csv                        # 回管道继续
```

---

## 新手踩坑总结

- **csvpy 用于探索，不用在脚本。** 脚本用 agate 库或 csvsql。
- **aggate API 需要熟悉。** `table.where()` 返回新表，`table.compute()` 返回加列的新表。
- **大文件加载慢。** 提前抽样 `head | csvpy`，或者用 csvsql。
- **退出是 Ctrl+D。** 不是 `exit`（虽然有时也能用）。
