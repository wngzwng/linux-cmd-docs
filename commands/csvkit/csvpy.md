
# csvpy：CSV 打开就是 Python REPL——数据探索的快捷入口

在命令行里处理 CSV 很方便，但有时候你需要交互式探索——试几个操作、看结果、调整再试。`csvpy` 把 CSV 加载为 Python 的 agate table 对象，直接打开一个 REPL（交互式 Python 环境），数据已经就位。

---

## 场景引入

```bash
csvpy sales.csv
```

进入 REPL 后：

```python
>>> type(table)
<class 'agate.table.Table'>

>>> table.column_names
['order_id', 'customer_id', 'amount', 'category', 'date']

>>> len(table.rows)
500000

>>> table.columns['amount'].aggregate(agate.Mean())
346.5

>>> table.columns['category'].values_distinct()
('电子产品', '食品', '服装', '家居', ...)

>>> # 筛选 + 聚合
>>> filtered = table.where(lambda r: r['amount'] > 1000)
>>> filtered.columns['amount'].aggregate(agate.Sum())
4520000.0
```

不需要写 `import csv`、`open()`、`csv.reader()`——csvpy 全帮你做好了。

---

## 核心能力

### 基本入口

```bash
csvpy data.csv              # 数据在变量 table 中
csvpy data.csv --agate      # 同时导入 agate 模块
```

### 加载多个 CSV

```bash
csvpy sales.csv users.csv
# 变量：table1 = sales.csv, table2 = users.csv
```

### 管道输入

```bash
csvcut -c name,salary employees.csv | csvpy
# stdin 的数据在 table 变量中
```

### 直接执行代码（`-c`）

```bash
csvpy -c "print(len(table.rows))" data.csv
```

---

## 典型探索流程

```bash
csvpy data.csv
>>> table.compute([('tax', agate.Formula(agate.NumberType(), lambda r: r['amount'] * 0.13))])
>>> table.to_csv('with_tax.csv')

# 退出 Ctrl+D，回到命令行继续管道处理
```

---

## ⚠️ 雷区

### csvpy 是探索工具，不是生产工具

它适合你坐在终端前交互式探索数据。不要把它写进脚本——脚本里用 `csvsql` 或 Python 脚本直接 import agate。

### 依赖 agate 库

csvpy 背后是 [agate](https://agate.readthedocs.io/) 库。如果内部数据探索需要更复杂的操作，建议直接写 Python 脚本 import agate。
