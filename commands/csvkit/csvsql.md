
# csvsql：用 SQL 直接查 CSV——SQLite 内存库当计算引擎

这是 csvkit 里最强大的命令。它把 CSV 导入内存中的 SQLite 数据库，让你用真正的 SQL 来查询、过滤、聚合、关联。不需要装 MySQL，不需要建表，CSV 文件就是你的数据库表。

---

## 场景引入

你有 `sales.csv`：`order_id, customer_id, amount, category, date`。想问：每个品类的月销售额趋势？

纯 awk/sort/uniq 也能做，但如果涉及 GROUP BY + JOIN + 日期函数，SQL 写起来舒服得多：

```bash
csvsql --query "
  SELECT
    category,
    substr(date, 1, 7) AS month,
    SUM(amount) AS total
  FROM sales
  GROUP BY category, month
  ORDER BY category, month
" sales.csv
```

`csvsql` 自动把 `sales.csv` 创建为 SQLite 的同名表 `sales`，然后在上面执行你的 SQL。输出是 CSV 格式，继续走管道。

---

## 核心能力

### SQL 查询单个 CSV

```bash
csvsql --query "SELECT * FROM data WHERE age > 30" data.csv
```

### SQL 查询多个 CSV（自动做 JOIN）

```bash
csvsql --query "
  SELECT u.name, SUM(o.amount) AS total
  FROM users u JOIN orders o ON u.id = o.user_id
  GROUP BY u.name
" users.csv orders.csv
```

多个 CSV 文件会自动创建多张表，表名就是文件名（不含 `.csv` 后缀），可以直接在 SQL 里 JOIN。

### 查询 stdin（表名固定为 `stdin`）

```bash
cat data.csv | csvgrep -c status -m active | csvsql --query "SELECT * FROM stdin WHERE score > 80"
```

### 生成 CREATE TABLE 语句（`--db`）

```bash
csvsql --db postgresql:///mydb --insert data.csv
# 生成对应的 PostgreSQL 建表 + 插入语句
```

### 直接写入数据库

```bash
csvsql --db sqlite:///mydb.db --insert data.csv
# 把 CSV 写入真实的 SQLite 数据库文件
```

### 方言支持

```bash
csvsql --dialect mysql --db mysql://user:pass@localhost/db --insert data.csv
```

---

## 管道中的经典用法

```bash
# CSV → SQL 过滤 → 排序 → 渲染
csvsql --query "
  SELECT name, salary FROM employees WHERE department='研发' AND salary > 15000
" employees.csv | csvsort -c salary -r | csvlook

# 多文件关联 + 聚合
csvsql --query "
  SELECT c.city, COUNT(*) AS cnt, AVG(o.amount) AS avg_amt
  FROM customers c JOIN orders o ON c.id = o.customer_id
  GROUP BY c.city
  ORDER BY cnt DESC
" customers.csv orders.csv | csvlook

# 子查询
csvsql --query "
  SELECT * FROM (
    SELECT category, AVG(amount) AS avg_amt FROM sales GROUP BY category
  ) WHERE avg_amt > 1000
" sales.csv
```

---

## ⚠️ 雷区

### 表名就是文件名（去掉 `.csv`）

```bash
# 文件名为 user_data.csv → 表名 user_data
csvsql --query "SELECT * FROM user_data WHERE status='active'" user_data.csv
```

如果文件名有连字符（如 `user-data.csv`），表名也会带连字符——SQL 里需要双引号括起来：

```bash
csvsql --query 'SELECT * FROM "user-data" WHERE status="active"' user-data.csv
```

### csvsql 用的是 SQLite 引擎

SQL 语法是 SQLite 的，不是 MySQL/PostgreSQL 的。`substr()` 而不是 `SUBSTRING()`，`||` 而不是 `CONCAT()`。不过常用 SQL 基本都一样。

### 大文件性能

csvsql 把整个 CSV 载入内存 SQLite，50 万行以内流畅，百万级会慢。超大数据还是建议先导入真正的数据库再用 `sql2csv`。
