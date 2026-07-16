
# csvstat：描述性统计——一行看完每列的 min/max/mean/median/unique

拿到一个 50 万行的 CSV，你的第一反应是什么？`cat | head`？打开 Excel？写 Python `df.describe()`？`csvstat` 用一行命令告诉你这张表的一切——每列的数据类型、空值数、唯一值数、最大值、最小值、均值、中位数、标准差。不需要加载数据到任何环境，CSV 文件就是输入，秒出统计剖面。

---

## 场景引入：两个你来来回回翻数据的瞬间

### 场景一：新拿到一张表，想快速了解它

```bash
# 老板扔过来 sales.csv（50 万行），问「客单价大概多少？最高一笔多少？」
# ❌ 新手做法：打开 Excel → 等待加载 → 选中金额列 → 看底部状态栏
#    或者写 Python：pd.read_csv() → df.describe()

# ✅ csvstat 一行搞定
csvstat sales.csv
```

输出示例：

```
  1. "order_id"
    Type: Number
    Nulls: 0
    Unique: 500000
    Min: 1
    Max: 500000

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
    Most common values: 电子产品 (125000), 食品 (98000), 服装 (72000)
```

五个问题（多少行？有空值吗？值范围多大？有异常值吗？哪个值最常见？）一个命令全回答。

### 场景二：检查数据质量问题

```bash
# 怀疑 email 列有空的、残缺的、重复的
csvstat -c email users.csv
# Nulls: 342     ← 有 342 个空邮箱
# Unique: 9847   ← 共 10000 个用户但只有 9847 个唯一邮箱？有重复注册！
```

---

## 它是怎么工作的——IO 模型

csvstat 是**全表扫描 + 在线统计**：它不存储数据，读一行算一行，最后汇总输出。

```
输入 CSV（stdin / 文件名）
    │
    ↓ 读表头 → 初始化每列的统计追踪器
    │
    ↓ 对每一行：
    │   ├─ 对每列：更新计数 / 最大值 / 最小值 / 累加和 / 平方累加和
    │   ├─ 对文本列：维护频次字典（Most common values）
    │   └─ 类型推断：遇到非数字值时标记为 Text
    │
    ↓ 读完全表：
    │   ├─ Unique = 去重后的值数量
    │   ├─ Mean = Sum / Count
    │   ├─ StdDev = sqrt(平方和/Count - Mean²)
    │   └─ Median：需要全部值排序 → 如果数据量大，csvstat 用近似算法
    │
    ↓ 输出：每列一行统计块 → stdout
```

> 💡 csvstat 是 Python 的 `df.describe()` 在命令行里的等价物。区别是：它不加载数据进 DataFrame，而是边读边算——内存占用比 pandas 低得多。

---

## 语法骨架

```
csvstat  [-c 列名]  [--freq] [--unique] [--sum] [--mean] [--median] [--max] [--min]  [文件.csv]
         ──┬──      ──────────────────────────┬───────────────────────────             ──┬──
         只看哪些列                        只看哪些统计量                             数据源
```

---

## ⚠️ 先排雷：csvstat 最容易踩的三个坑

### 雷一：类型推断可能猜错

```bash
# id 列是纯数字 → Type: Number ✅
# zip_code 列：100000, 200000 → Type: Number
#   但 "00100" 这种前导零的邮编会被当成文本 → Type: Text ⚠️

# 混合列：大部分是数字，但有一个 "N/A" → 整列被标记为 Text！
```

类型推断是逐行做的——只要是纯数字就是 Number，只要有一个非数字值就可能是 Text。`Type` 标签仅供参考，不代表数据一定干净。

### 雷二：中位数在大数据量时是近似值

csvstat 默认对大数据集使用近似中位数算法（T-Digest），不是精确的。如果必须精确中位数，用 csvsql：

```bash
csvsql --query "
  SELECT amount FROM sales ORDER BY amount LIMIT 1 OFFSET (SELECT COUNT(*) FROM sales) / 2
" sales.csv
```

### 雷三：`--freq` 在大文本列上可能 OOM

```bash
# ❌ 50 万行，每行的 "description" 都不同 → --freq 尝试存 50 万个 key
csvstat --freq -c description huge_file.csv
```

`--freq` 会把该列所有唯一值存到内存字典里。如果唯一值数量和行数相当（比如 ID 列、描述列），内存会爆。先看 `--unique` 了解唯一值数量再决定。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 目标轴 | 统计哪些列？ | `-c` 指定列名，默认全部列 |
| 计量轴 | 要哪些统计量？ | `--sum` `--mean` `--median` `--max` `--min` `--stddev` `--len` |
| 频次轴 | 值分布怎么样？ | `--freq` 每个值出现次数和百分比 |
| 唯一轴 | 有多少不重复的值？ | `--unique` 唯一值计数 |
| 输出轴 | 输出格式？ | 默认人类可读、`--csv` 导出为 CSV |

### 轴 1：全量统计 vs 指定列

```bash
csvstat data.csv                    # 所有列的完整统计
csvstat -c amount,category data.csv # 只看这两列
```

### 轴 2：只看特定统计量

```bash
csvstat --sum --mean --max --min -c amount data.csv
# 只要四个数字，不需要 Nulls/Unique/Median…
```

这在脚本里很实用——你只要一个数字，不需要解析大段输出。

### 轴 3：频次分布 `--freq`

```bash
csvstat --freq -c category sales.csv
# 电子产品: 125000 (25.0%)
# 食品:      98000 (19.6%)
# 服装:      72000 (14.4%)
# ...
```

比 `sort | uniq -c | sort -rn` 更直观——因为自带百分比。

### 轴 4：唯一值数量 `--unique`

```bash
csvstat --unique -c customer_id data.csv
# 12847
# 有多少个不重复的客户
```

如果和总行数对比：`500000` 行但只有 `12847` 个唯一客户 → 平均每客户约 39 笔订单。

---

## 场景组合

### 1. 先过滤再统计

```bash
csvgrep -c category -m "电子产品" sales.csv | csvstat -c amount
# 只看电子产品的销售金额分布
```

### 2. 关联后再统计

```bash
csvjoin -c user_id,id users.csv orders.csv \
  | csvstat -c city,amount
```

### 3. 只看数据质量（空值 + 唯一值）

```bash
csvstat --nulls --unique data.csv
```

### 4. 把统计结果导出为 CSV

```bash
csvstat --csv data.csv > stats.csv
# stats.csv 本身可以用 csvlook 渲染：
csvstat --csv data.csv | csvlook
```

---

## csvstat vs pandas df.describe() vs SQL：什么时候用哪个

| 场景 | csvstat | pandas | csvsql/数据库 |
|------|---------|--------|--------------|
| 快速了解一张表 | ✅ 秒出 | ⚠️ 需写 `read_csv` | ⚠️ 需建表 |
| 精确中位数 | ⚠️ 大数据近似 | ✅ | ✅ `PERCENTILE` |
| 自定义聚合 | ❌ | ✅ `groupby().agg()` | ✅ `GROUP BY` |
| 内存效率 | ✅ 流式 | ❌ 全量加载 | ✅ 索引加速 |
| 管道友好 | ✅ stdout | ❌ | ✅ |

> 💡 一句话：**快速了解一张表用 csvstat，需要自定义聚合或精确统计用 csvsql，写脚本用 pandas。**

---

## 新手踩坑总结

- **`Type` 仅供参考。** 混合类型的列会被标记为 Text，统计量中的数字项会缺失。
- **中位数是近似值（数据量大时）。** 需要精确中位数用 csvsql 或 sort + awk。
- **`--freq` 慎用在大文本列。** 唯一值太多 → 内存爆炸。
- **Null 值会被自动排除。** `Nulls: 23` 意味着统计量（Mean/Max 等）是基于非空值计算的。
- **管道是 csvstat 最好的朋友。** 过滤 → 统计 → 关联 → 统计，无限组合。
