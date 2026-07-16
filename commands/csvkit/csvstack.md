
# csvstack：纵向拼接 CSV——命令行里的 UNION ALL

两个结构相同（列名一样）的 CSV，想把它们摞在一起。这就是 SQL 的 `UNION ALL`、Excel 的「复制粘贴到底部」。`csvstack` 一行搞定。

---

## 场景引入

两个文件结构完全一样：

`q1.csv`：

```
month,sales
1月,100
2月,200
3月,150
```

`q2.csv`：

```
month,sales
4月,300
5月,250
6月,180
```

拼成一个完整的半年报表：

```bash
csvstack q1.csv q2.csv
```

输出：

```
month,sales
1月,100
2月,200
3月,150
4月,300
5月,250
6月,180
```

---

## 核心能力

### 基本拼接

```bash
csvstack file1.csv file2.csv file3.csv
```

### 加来源标识列（`-g`）

想知道每行来自哪个文件：

```bash
csvstack -g source q1.csv q2.csv
# 输出时新增一列 "source"，值为文件名 "q1.csv" 或 "q2.csv"
```

### 自定义组名（`-n`）

```bash
csvstack -g quarter -n "Q1,Q2" q1.csv q2.csv
# source=quarter 列的值分别为 "Q1" 和 "Q2"
```

### 管道输入

```bash
cat q1.csv | csvstack - q2.csv          # '-' 代表 stdin
```

---

## ⚠️ 雷区

### 列名必须一致（大小写敏感）

```bash
# q1.csv 有 "month,sales"，q2.csv 有 "Month,Sales" → 会被当成不同列
# 拼接后会有 4 列：month, sales, Month, Sales
csvstack q1.csv q2.csv
```

### 列的顺序也必须一致

```bash
# q1.csv：name,age
# q2.csv：age,name   → 数据会错列！
```

拼接前用 `csvcut -n` 检查两个文件的列名和顺序：

```bash
csvcut -n q1.csv && csvcut -n q2.csv
```

不一致时先用 `csvcut -c` 统一顺序：

```bash
csvstack q1.csv <(csvcut -c name,age q2.csv)
```
