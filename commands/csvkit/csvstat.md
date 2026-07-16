
# csvstat：描述性统计——一行看完每列的 min/max/mean/median/unique

拿到一个 CSV 先干什么？不是 `cat | head`，也不是打开 Excel。是 `csvstat`——一行命令告诉你每列是什么类型、有多少唯一值、最大最小值、均值中位数。这是 csvkit 里最被低估的命令。

---

## 场景引入

你刚拿到一个 50 万行的销售数据 `sales.csv`，老板问「平均客单价多少？最高一单多少？有多少个不同客户？」

```bash
csvstat sales.csv
```

五秒出结果：

```
  1. "order_id"
    Type: Number
    Nulls: 0
    Unique: 500000
    Min: 1
    Max: 500000

  2. "customer_id"
    Type: Number
    Nulls: 0
    Unique: 12847
    Min: 1001
    Max: 98765

  3. "amount"
    Type: Number
    Nulls: 23
    Unique: 45210
    Min: 9.9
    Max: 128000
    Mean: 346.5
    Median: 198
    StdDev: 1230.2

  4. "category"
    Type: Text
    Nulls: 0
    Unique: 18
    Most common values: 电子产品 (125000), 食品 (98000), ...
```

不用写 SQL、不用开 Excel、不用写 Python。一个命令全出来。

---

## 核心能力

### 只看指定列的统计（`-c`）

```bash
csvstat -c amount,category sales.csv
```

### 只看汇总（`--sum` `--mean` `--median` `--max` `--min` 等）

```bash
csvstat --sum --mean --max --min -c amount sales.csv
```

### 统计频次分布（`--freq`）

```bash
csvstat --freq -c category sales.csv
# 输出每个 category 值出现的次数和百分比
```

### 统计唯一值数量（`--unique`）

```bash
csvstat --unique -c customer_id sales.csv
```

### 只输出数字不输出描述（`--csv`）

```bash
csvstat --csv sales.csv > stats.csv   # 把统计结果本身导出为 CSV
```

---

## 管道中的经典用法

```bash
# 先过滤再统计
csvgrep -c category -m "电子产品" sales.csv | csvstat -c amount

# 关联后再统计
csvjoin -c customer_id,id customers.csv sales.csv | csvstat -c city,amount

# 看每月统计（先用 csvsql 加计算列，再统计）
csvsql --query "
  SELECT substr(date,1,7) AS month, amount FROM sales
" sales.csv | csvstat -c month,amount
```

---

## ⚠️ 雷区

### Null 处理：有 23 个空值会直接告诉你

Null 值不会污染统计结果，csvstat 会单独报告 `Nulls: 23`。不需要自己先清洗。

### 大文件类型推断可能需要时间

csvstat 会扫描全表来做类型推断（判断每列是 Number 还是 Text 还是 Date），50 万行以内很快，千万级可以先用 `head -100000 | csvstat` 看个大概。
