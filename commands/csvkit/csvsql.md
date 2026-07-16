
# csvsql：用 SQL 直接查 CSV——当 csvkit 的能力不够用时，SQL 兜底

csvcut、csvgrep、csvsort、csvjoin 各自只做一件事——这是 Unix 哲学。但当你需要「筛选 A 列 = X AND B 列 > 100 AND C 列以 Y 开头，然后按 D 列分组取平均值，最后按平均值降序取 Top 10」这种组合操作时，一个链式管道会变得又长又脆弱。`csvsql` 就是 csvkit 为这种场景保留的后门：把 CSV 导入内存中的 SQLite 数据库，让你用真正的 SQL 写任意复杂度的查询。不需要建表、不需要装数据库、不需要配置——CSV 文件就是你的表，文件名就是表名。

---

## 场景引入：两个 csvkit 管道写到一半放弃的瞬间

### 场景一：多条件组合查询

你有一个 `employees.csv`，想要：「研发部 AND 薪资 > 15000 AND 2020 年以后入职」的所有人。用 csvkit 链式：

```bash
# ⚠️ 勉强能做，但读了 3 遍文件，而且 sql 一句能表达的非要拆成 3 个工具
csvgrep -c department -m "研发" employees.csv \
  | csvgrep -c salary -r "^[2-9]|^1[5-9]" \
  | csvgrep -c hire_date -r "^202[0-9]"

# ✅ csvsql：一个 WHERE 语句，直白可读
csvsql --query "
  SELECT * FROM employees
  WHERE department = '研发'
    AND salary > 15000
    AND hire_date >= '2020-01-01'
" employees.csv
```

### 场景二：三表关联 + 聚合

你有 `users.csv`、`orders.csv`、`products.csv` 三个文件。想求「每个用户的消费总额，按城市分组，只看北上广深的」。

```bash
# csvjoin 只能两表关联——三表需要中间文件，非常痛苦

# ✅ csvsql：一次搞定三表 + 聚合 + 过滤
csvsql --query "
  SELECT u.city, u.name, SUM(o.amount) AS total
  FROM users u
  JOIN orders o ON u.id = o.user_id
  JOIN products p ON o.product_id = p.id
  WHERE u.city IN ('北京','上海','广州','深圳')
  GROUP BY u.city, u.name
  ORDER BY total DESC
" users.csv orders.csv products.csv
```

---

## 它是怎么工作的——IO 模型

csvsql 的核心原理：**SQLite 内存数据库作为计算引擎，CSV 文件作为数据源。**

```
CSV 文件1  CSV 文件2  CSV 文件3
    │          │          │
    ↓          ↓          ↓
  导入 SQLite 内存数据库（:memory:）
    │  自动推断列类型、建表、插入数据
    │  表名 = 文件名（去掉 .csv）
    │
    ↓
  执行 --query 里的 SQL（或 --db 生成建表语句）
    │  SQL 引擎做 JOIN / WHERE / GROUP BY / ORDER BY
    │
    ↓
  输出 CSV → stdout
```

> 💡 csvsql 不是「解析 SQL 语法然后自己执行」——它是真的把数据塞进 SQLite，让 SQLite 来执行 SQL。所以它支持完整的 SQLite 语法（子查询、窗口函数、CTE 等）。

---

## 语法骨架

```
csvsql  --query "SQL 语句"  [文件.csv ...]
        ──────┬──────        ────┬────
           要执行的 SQL        数据源（自动建表）
```

或者生成数据库操作：

```
csvsql  --db 连接串  --insert  [--tables 表名]  [文件.csv]
        ────┬────    ───┬────        ──┬──        ──┬──
         目标数据库   写入模式      自定义表名     数据源
```

---

## ⚠️ 先排雷：csvsql 最容易踩的五个坑

### 雷一：表名就是文件名（去掉 .csv）——小心连字符

```bash
# 文件 user-data.csv → 表名 user-data（带连字符）
csvsql --query "SELECT * FROM user-data WHERE status='active'" user-data.csv
# ❌ SQLite 报错：user-data 被解析为 user 减 data

# ✅ 双引号括起来
csvsql --query 'SELECT * FROM "user-data" WHERE status="active"' user-data.csv
```

文件名有 `-` 或空格时一定要在 SQL 里用双引号括表名。推荐做法：CSV 文件命名不要用连字符，用下划线 `user_data.csv`。

### 雷二：类型推断是 sqlite 自动做的

```bash
# salary 列大部分是数字但有一行 "待定" → sqlite 可能把该列推断为 TEXT
# 导致：SELECT * WHERE salary > 10000 把 TEXT 和数字比较，结果不可预期
```

导入前确保数字列是纯数字。有脏数据可以先过滤掉：

```bash
# 先过滤出 salary 是纯数字的行，再给 csvsql
csvgrep -c salary -r "^[0-9]+$" employees.csv \
  | csvsql --query "SELECT * FROM stdin WHERE salary > 15000"
```

### 雷三：SQLite 语法不是 MySQL/PostgreSQL 语法

```bash
# ✅ SQLite
substr(date, 1, 7)           -- 截取子串
strftime('%Y-%m', date)      -- 日期格式化
datetime('now')               -- 当前时间
SELECT * FROM t LIMIT 10      -- 限制行数

# ❌ MySQL/PG 用法在 SQLite 不存在
SUBSTRING(date, 1, 7)         -- SQLite 用 substr
NOW()                          -- SQLite 用 datetime('now')
```

### 雷四：内存限制

csvsql 默认使用 SQLite 内存数据库。一个 100MB 的 CSV 文件导入内存没问题；但 1GB 的 CSV 可能让系统卡死。对大文件，用 `--db` 先写入磁盘 SQLite 再查询：

```bash
# 先导入磁盘数据库
csvsql --db sqlite:///data.db --insert huge_file.csv
# 再查询
csvsql --db sqlite:///data.db --query "SELECT ... FROM huge_file" 
```

### 雷五：stdin 进来的表固定叫 `stdin`

```bash
cat data.csv | csvgrep -c status -m active | csvsql --query "SELECT * FROM stdin WHERE score > 80"
#                                                     表名固定为 stdin ↑
```

所有管道进来的数据都叫 `stdin`，没有扩展名去掉的逻辑。多表 JOIN 时不要混用 stdin 和文件（不容易读），要么全用文件，要么全用 stdin 配合 csvjoin。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 查询轴 | 要执行什么 SQL？ | `--query` 直接执行 |
| 导入轴 | CSV 怎么进数据库？ | 默认 SQLite 内存库、`--db` 指定真实数据库 |
| 输出轴 | 生成什么？ | 默认 CSV 到 stdout、`--insert` 写入数据库、`--tables` 只建表 |
| 方言轴 | 目标数据库是什么？ | `--dialect` 指定 sqlite/postgresql/mysql/mssql/oracle |

### 轴 1：SQL 查询

```bash
csvsql --query "SELECT * FROM data WHERE age > 30" data.csv
csvsql --query "
  SELECT category, COUNT(*) AS cnt, AVG(amount) AS avg_amt
  FROM sales GROUP BY category HAVING cnt > 100
  ORDER BY avg_amt DESC
" sales.csv
```

### 轴 2：写入真实数据库

```bash
# 导入 CSV 到 PostgreSQL
csvsql --db "postgresql://user:pass@host/db" --insert data.csv

# 导入 CSV 到 SQLite 磁盘文件
csvsql --db sqlite:///mydata.db --insert --tables my_table data.csv
```

### 轴 3：生成建表语句（不插入数据）

```bash
csvsql --db "postgresql:///db" --tables employees employees.csv
# 生成 CREATE TABLE employees (...) 语句
# 方便你把 CSV 结构复制到数据库，再自己决定怎么灌数据
```

### 轴 4：跨数据库方言

```bash
csvsql --dialect mysql --db "mysql://..." --insert data.csv
# 生成的 CREATE TABLE 和 INSERT 语句适配 MySQL 语法
```

---

## 场景组合

### 1. 过滤 + 聚合 + 排序（代替 csvgrep + csvstat + csvsort）

```bash
csvsql --query "
  SELECT department,
         COUNT(*) AS headcount,
         AVG(salary) AS avg_salary,
         MAX(salary) AS max_salary
  FROM employees
  WHERE hire_date >= '2023-01-01'
  GROUP BY department
  ORDER BY avg_salary DESC
" employees.csv | csvlook
```

一条 SQL 替代了筛选 → 统计 → 排序三步骤的管道。

### 2. 子查询和窗口函数

```bash
csvsql --query "
  SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
    FROM employees
  ) WHERE rn <= 3
" employees.csv
# 每个部门薪资 Top 3
```

### 3. WITH CTE 复杂分析

```bash
csvsql --query "
  WITH dept_stats AS (
    SELECT department, AVG(salary) AS dept_avg FROM employees GROUP BY department
  )
  SELECT e.name, e.department, e.salary, d.dept_avg,
         CASE WHEN e.salary > d.dept_avg THEN 'above' ELSE 'below' END AS vs_avg
  FROM employees e JOIN dept_stats d ON e.department = d.department
" employees.csv
```

---

## csvsql vs csvkit 管道 vs 真实数据库：什么时候用哪个

| 场景 | csvsql | csvkit 管道 | 真实数据库 |
|------|--------|------------|-----------|
| 简单筛选 1-2 条件 | ⚠️ 杀鸡用牛刀 | ✅ csvgrep | ❌ |
| 多条件 + 聚合 + 排序 | ✅ 一条 SQL | ⚠️ 长管道难维护 | ✅ 性能更好 |
| 多表 JOIN | ✅ 三表以上一次搞定 | ❌ csvjoin 只用两表 | ✅ |
| 窗口函数 / CTE | ✅ | ❌ | ✅ |
| 100 万行以上 | ⚠️ 内存吃紧 | ⚠️ | ✅ |
| 重复使用（多次查询同一批数据） | ❌ 每次重新导入 | ❌ | ✅ 建表一次查多次 |

> 💡 一句话：**简单操作用 csvkit 管道，复杂操作用 csvsql，高频重复查询导入真实数据库。**

---

## 新手踩坑总结

- **表名 = 文件名（去掉 .csv）。** 连字符和空格需要用双引号括起来。
- **Sqlite 语法 ≠ MySQL 语法。** `substr` 不是 `SUBSTRING`，`||` 不是 `CONCAT`。
- **大文件慎用内存模式。** 超过几百 MB 建议先导入磁盘 SQLite。
- **类型是 SQLite 自动推断的。** 混合类型列可能推断为 TEXT，导致数值比较出错。
- **stdin 表名固定为 `stdin`。** 管道输入的数据在 SQL 里统一用 `stdin` 引用。
- **csvsql 是整个 csvkit 的「兜底方案」。** 任何 csvcut/csvgrep/csvsort/csvjoin 解决不了的问题，大概率可以用 csvsql 的 SQL 搞定。
