
# csvjoin：两个 CSV 按列关联——命令行里的 JOIN

两个 CSV 文件按某个公共列关联起来——这是 Excel VLOOKUP 的经典场景，也是 SQL JOIN 的经典场景。`csvjoin` 在命令行里给你同样的能力。

---

## 场景引入

`users.csv`：

```
id,name
1,张三
2,李四
```

`orders.csv`：

```
order_id,user_id,amount
101,1,500
102,1,300
103,2,800
```

把两个表按 `user_id` 关联起来，看谁买了什么：

```bash
csvjoin -c user_id,id users.csv orders.csv
```

输出：

```
id,name,order_id,user_id,amount
1,张三,101,1,500
1,张三,102,1,300
2,李四,103,2,800
```

---

## 核心能力

### 默认：内连接（INNER JOIN）

```bash
csvjoin -c user_id,id users.csv orders.csv
```

`-c` 后面是「左表列,右表列」的格式。只有两边都匹配的行才保留。

### 左连接（`--left`）

```bash
csvjoin --left -c id,user_id users.csv orders.csv
# 所有用户都保留，没订单的 amount 为空
```

### 右连接（`--right`）、全外连接（`--outer`）

```bash
csvjoin --right -c id,user_id users.csv orders.csv
csvjoin --outer -c id,user_id users.csv orders.csv
```

### 多列关联

```bash
csvjoin -c "year,month","year,month" stats1.csv stats2.csv
```

---

## 管道中的经典用法

```bash
# 关联 → 选列 → 排序 → 看表格
csvjoin -c user_id,id users.csv orders.csv \
  | csvcut -c name,amount \
  | csvsort -c amount -r \
  | csvlook

# 关联后用 SQL 做聚合
csvjoin -c user_id,id users.csv orders.csv \
  | csvsql --query "SELECT name, SUM(amount) AS total FROM stdin GROUP BY name"
```

---

## ⚠️ 雷区

### `-c` 的参数顺序是「左表列,右表列」

```bash
# users.csv 的 id = orders.csv 的 user_id
csvjoin -c id,user_id users.csv orders.csv    # ✅
csvjoin -c user_id,id users.csv orders.csv    # ❌ 如果两边列名不同就错了
```

### 两边列名一样时可以简写

```bash
# 如果两个表都有 id 列
csvjoin -c id a.csv b.csv                      # 等价于 -c id,id
```

### 文本格式很关键

```bash
# "1" 和 "001" 是不匹配的
# 关联前可以用 awk 或 csvsql 清洗
```
