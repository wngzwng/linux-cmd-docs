
# sql2csv：数据库查询 → CSV——管道的另一端

`in2csv` 把外部格式拉进管道，`sql2csv` 把关系型数据库也拉进管道。一行 SQL 查询直接从 PostgreSQL / MySQL / SQLite / Oracle 等导出为 CSV，然后走 csvkit 管道处理。

---

## 场景引入

线上 PostgreSQL 的 `orders` 表有 200 万行，老板要看最近一周每个品类的销售额。不用开 DataGrip，不用写 Python 脚本：

```bash
sql2csv --db "postgresql://user:pass@host:5432/dbname" \
  --query "
    SELECT category, SUM(amount) AS total
    FROM orders
    WHERE created_at >= date('now', '-7 days')
    GROUP BY category
    ORDER BY total DESC
  " | csvlook
```

---

## 核心能力

### 从数据库查询导出 CSV

```bash
sql2csv --db "postgresql://user:pass@host:5432/db" \
  --query "SELECT * FROM users WHERE status='active'" \
  > active_users.csv
```

### 支持多种数据库

```bash
# PostgreSQL
sql2csv --db "postgresql://user:pass@host/db" --query "..."

# MySQL
sql2csv --db "mysql://user:pass@host/db" --query "..."

# SQLite
sql2csv --db "sqlite:///path/to/db.sqlite" --query "..."

# Microsoft SQL Server
sql2csv --db "mssql://user:pass@host/db" --query "..."

# Oracle
sql2csv --db "oracle://user:pass@host/db" --query "..."
```

### 从文件读连接串（`-y`）

```bash
# db.yml
#   username: user
#   password: pass
#   host: localhost
#   port: 5432
#   database: mydb

sql2csv -y db.yml --query "SELECT * FROM users"
```

### 执行 SQL 文件（`--file`）

```bash
sql2csv --db "postgresql://..." --file query.sql
```

---

## 管道中的经典用法

```bash
# 数据库 → 统计 → 转 JSON → 喂给 API
sql2csv --db "postgresql://..." --query "SELECT * FROM daily_report" \
  | csvstat

# 跨源 JOIN：数据库 + CSV
# 先把数据库结果导出，再和本地 CSV 关联
sql2csv --db "postgresql://..." --query "SELECT id, name FROM users" \
  | csvjoin -c id,user_id - local_orders.csv \
  | csvsql --query "SELECT name, SUM(amount) FROM stdin GROUP BY name"
```

---

## ⚠️ 雷区

### 连接串里特殊字符要 URL 编码

```bash
# 密码里有 @ → %40
# 密码里有 / → %2F
sql2csv --db "postgresql://user:p%40ss@host/db" --query "..."
```

### 依赖数据库驱动

PostgreSQL 需要 `psycopg2`，MySQL 需要 `mysqlclient` 或 `pymysql`，Oracle 需要 `cx_Oracle`。装 csvkit 不会自动安装全部驱动：

```bash
pip install psycopg2-binary    # PostgreSQL
pip install mysqlclient         # MySQL
```

### 查询超时不是 csvkit 的事

`sql2csv` 不管理查询超时。大查询如果数据库没返回，`sql2csv` 会一直等。在 SQL 层面加 timeout 或 LIMIT 做保护。
