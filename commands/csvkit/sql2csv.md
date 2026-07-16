
# sql2csv：数据库查询 → CSV——让数据库进入 csvkit 管道

csvkit 处理 CSV 文件很在行，但很多数据根本不存成文件——它们在 PostgreSQL、MySQL、SQLite 里。`sql2csv` 是 csvkit 从关系型数据库拉数据的入口：一条 SQL 查询，结果直接输出为 CSV，然后就可以走 csvkit 管道。不需要先手动导出再处理，一条命令完成「查询 → CSV → 管道」。

`in2csv` 把外部格式拉进管道，`sql2csv` 把数据库也拉进管道——它俩是 csvkit 管道世界的两个入口。

---

## 场景引入：两个在数据库和 CSV 之间反复导出的瞬间

### 场景一：线上数据临时分析

```bash
# 老板要看最近一周每个品类的销售额。订单数据在 PostgreSQL 里。
# ❌ 传统做法：开 DataGrip → 写 SQL → 导出 CSV → 再传给 csvstat

# ✅ sql2csv 一步到位
sql2csv --db "postgresql://user:pass@host:5432/shop" \
  --query "
    SELECT category, SUM(amount) AS total
    FROM orders
    WHERE created_at >= date('now', '-7 days')
    GROUP BY category
    ORDER BY total DESC
  " | csvlook
```

### 场景二：数据库数据 + 本地 CSV 关联分析

```bash
# 线上用户表做 LEFT JOIN 本地的手工数据
# 先拉数据库 → 再和本地 CSV 关联
sql2csv --db "postgresql://..." --query "SELECT id, name, city FROM users" \
  | csvjoin -c id,user_id - local_labels.csv \
  | csvsql --query "SELECT city, label, COUNT(*) FROM stdin GROUP BY city, label"
```

---

## 它是怎么工作的——IO 模型

sql2csv 是 Python 数据库驱动 + csvkit 的桥接器。它用 SQLAlchemy 连接数据库，执行 SQL，把结果集的行对象逐行转换为 CSV 输出。

```
数据库 (PG/MySQL/SQLite/MSSQL/Oracle)
    │
    ↓ SQLAlchemy 连接 → 执行 --query 或 --file 中的 SQL
    │
    ↓ 结果集 (Row objects)
    │  逐行读取，以 CSV 格式写入 stdout
    │  表头 = 查询结果的列名
    │
    ↓ CSV → stdout → 进入管道
```

> 💡 sql2csv 不缓存全量结果——它用数据库游标逐行读取，内存友好。百万行级别的查询也能稳定输出。

---

## 语法骨架

```
sql2csv  --db 连接串  --query "SQL"  或  --file query.sql
         ─────┬─────   ──────┬─────       ──────┬─────
            数据库位置      要执行的查询           从文件读 SQL
```

连接串格式：

```
postgresql://user:pass@host:port/dbname
mysql://user:pass@host:port/dbname
sqlite:///path/to/file.db
mssql://user:pass@host:port/dbname
oracle://user:pass@host:port/dbname
```

---

## ⚠️ 先排雷：sql2csv 最容易踩的五个坑

### 雷一：连接串里的特殊字符需要 URL 编码

```bash
# 密码里有 @ → %40
# 密码里有 / → %2F
# 密码里有 : → %3A

sql2csv --db "postgresql://user:p%40ss@host/db" --query "..."
```

### 雷二：数据库驱动是可选依赖

```bash
# PostgreSQL 需要 psycopg2
pip install psycopg2-binary

# MySQL 需要 mysqlclient 或 pymysql
pip install mysqlclient

# Oracle 需要 cx_Oracle（安装最复杂）
```

csvkit 安装时不带数据库驱动——它们太大了。报 `No module named 'psycopg2'` 就去装对应的驱动。

### 雷三：查询超时不是你控制的

sql2csv 没有内置查询超时。如果 SQL 跑了 30 分钟还没返回，sql2csv 会一直等。在 SQL 层面加保护：

```sql
-- PostgreSQL：在 SQL 里设置超时
SET statement_timeout = '5min';
SELECT ...;
```

### 雷四：从文件读连接信息 `-y`

```bash
# 连接串写死在命令行里不安全（密码会留在 shell 历史里）
# 用 YAML 配置文件：
cat > db.yml << 'EOF'
username: myuser
password: mypass
host: localhost
port: 5432
database: mydb
EOF

sql2csv -y db.yml --query "SELECT * FROM users"
```

`-y` 比 `--db` 安全——密码不会出现在 `ps` 和 `history` 里。

### 雷五：查询结果列名来自 SQL 的 AS 别名

```bash
sql2csv --db "..." --query "SELECT COUNT(*) AS cnt FROM orders"
# CSV 表头是 "cnt"，不是 "COUNT(*)"

sql2csv --db "..." --query "SELECT COUNT(*) FROM orders"
# CSV 表头是 "COUNT(*)" —— 含特殊字符，可能导致管道后续命令出问题
# 永远给聚合函数和计算列写 AS 别名
```

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 连接轴 | 怎么连数据库？ | `--db` 连接串、`-y` YAML 文件 |
| 查询轴 | SQL 从哪来？ | `--query` 直接写、`--file` 从文件读 |
| 格式轴 | 输出什么 CSV 方言？ | `--dialect` 指定、`--snifflimit` 类型检测行数 |
| 编码轴 | 数据库编码？ | `--encoding` 指定 |

### 轴 1：连接方式

```bash
sql2csv --db "postgresql://user:pass@host/db" --query "..."      # 直接写连接串
sql2csv -y db.yml --query "..."                                    # 从配置文件读
```

### 轴 2：SQL 来源

```bash
sql2csv --db "..." --query "SELECT * FROM users WHERE active=1"   # 直接写
sql2csv --db "..." --file monthly_report.sql                      # 从文件读
```

### 轴 3：支持的数据库

```bash
sql2csv --db "postgresql://..."  --query "..."
sql2csv --db "mysql://..."       --query "..."
sql2csv --db "sqlite:///db.sqlite" --query "..."
sql2csv --db "mssql://..."       --query "..."
sql2csv --db "oracle://..."      --query "..."
```

---

## 场景组合

### 1. 数据库 → 统计 → 渲染

```bash
sql2csv --db "postgresql://..." \
  --query "SELECT * FROM daily_summary WHERE report_date = CURRENT_DATE" \
  | csvstat
```

### 2. 数据库 + CSV 混合 JOIN

```bash
# 线上商品表 + 本地手工标签表
sql2csv --db "postgresql://..." --query "SELECT id, name, price FROM products" \
  | csvjoin -c id,product_id --left - local_tags.csv \
  | csvsql --query "SELECT tag, AVG(price) FROM stdin GROUP BY tag"
```

### 3. 多数据库对比

```bash
# 生产库 vs 备份库的同一条 SQL
diff <(sql2csv --db "pg://prod" --query "SELECT COUNT(*) FROM orders") \
     <(sql2csv --db "pg://backup" --query "SELECT COUNT(*) FROM orders")
```

---

## sql2csv vs in2csv vs 数据库客户端导出：什么时候用哪个

| 场景 | sql2csv | in2csv | 数据库客户端 (psql/mysql) |
|------|---------|--------|--------------------------|
| 数据库 → CSV → 管道 | ✅ | ❌ 不处理数据库 | ⚠️ `\copy` 也可以但不在管道里 |
| Excel → CSV | ❌ | ✅ | ❌ |
| 大查询（百万行+） | ✅ 逐行游标 | — | ✅ |
| 连接安全性 | ⚠️ `--db` 暴露密码 | — | ✅ `PGPASSWORD` 或 `.pgpass` |
| 写入数据库 | ❌ 只读 | ❌ | ✅ |

> 💡 一句话：**从数据库拉数据进管道用 sql2csv，把文件格式转成 CSV 用 in2csv，写回数据库用 csvsql `--insert`。**

---

## 新手踩坑总结

- **密码里的特殊字符要 URL 编码。** `@→%40`, `/→%2F`, `:→%3A`。
- **数据库驱动需要单独安装。** PG 装 `psycopg2`，MySQL 装 `mysqlclient`。
- **查询超时在 SQL 层面控制。** sql2csv 没有超时参数。
- **聚合函数写 AS 别名。** 否则 CSV 表头可能有 `COUNT(*)` 这种带特殊字符的名字。
- **安全性：`-y` YAML 文件比 `--db` 直接写密码更安全。**
- **sql2csv 只做查询，不写数据库。** 写入方向用 `csvsql --db ... --insert`。
