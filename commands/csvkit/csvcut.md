
# csvcut：按列名或列号选取列——比 awk 更可读的列操作

如果你需要从 CSV 里提取某几列，awk 的 `'{print $1,$3}'` 可以做到，但当表头是 `"Full Name"`、`"Annual Salary (USD)"` 这种带空格和括号的名字时，数第几列就很痛苦了。`csvcut` 让你可以用**列名**而非列号来操作。

---

## 场景引入

你有一个 `employees.csv`：

```
id,name,department,salary,hire_date
1,张三,研发,15000,2020-03-15
2,李四,市场,12000,2019-07-01
3,王五,研发,18000,2018-01-20
```

老板只想要姓名和部门两列。用 awk 你得先数 `name` 是第几列。用 csvcut：

```bash
csvcut -c name,department employees.csv
```

列名直接写，不需要数位置。

---

## 核心能力

### 按列名选列（`-c` + 列名）

```bash
csvcut -c name,salary employees.csv

# 也可以用 -C 排除某些列（取反）
csvcut -C id,hire_date employees.csv
```

### 按列号选列

```bash
csvcut -c 2,4 employees.csv   # 第 2 和第 4 列（从 1 开始）
```

### 先看一眼有哪些列（`-n`）

```bash
csvcut -n employees.csv
# 输出:
#   1: id
#   2: name
#   3: department
#   4: salary
#   5: hire_date
```

这个是最常用的前置操作——看一眼列名和列号，再决定选哪些。

---

## 管道中的经典用法

```bash
# 从一个大 CSV 里摘几列 → 排序 → 看前 10 行
csvcut -c name,salary big_data.csv | csvsort -c salary -r | head -10

# 排除不需要的列后再做统计
csvcut -C id,hire_date employees.csv | csvstat
```

---

## ⚠️ 雷区

### 列名有空格或特殊字符

```bash
# ✅ 引号括起来
csvcut -c "Full Name","Annual Salary" data.csv

# ✅ 用列号
csvcut -c 2,4 data.csv
```

### csvcut 不修改原文件

`csvcut` 只输出到 stdout，不会改动原文件。要保存结果必须重定向：

```bash
csvcut -c name,salary data.csv > subset.csv
```
