# csvkit：命令行里的 Excel——用 SQL 和管道处理 CSV

> csvkit 是一套 CSV 处理工具箱，一共 13 个命令，覆盖了你在 Excel 里最常做的事：筛选列、过滤行、排序、关联、统计、格式互转。它的设计哲学是「每个命令只做一件事，全部读 stdin、写 stdout」，可以像 `grep`/`cut`/`sort` 一样自由组合。

## 零、为什么用 csvkit 而不是 awk/sed？

awk 按列处理文本没问题，但遇到这些场景就吃力了：

- 表头带空格或特殊字符（awk 只能按位置 `$1 $2`）
- 需要按列名操作而非列号（`csvcut -c name,age` vs `awk '{print $1,$3}'`）
- 两个 CSV 做 JOIN（awk 要做到天荒地老）
- Excel 文件转 CSV（awk 根本读不了 `.xlsx`）

csvkit 补的就是这个缺口——它在 shell 管道里给了你一个轻量级的关系型数据处理层。

## 一、命令全景

```
                     ┌──────────────────────────────┐
                     │     csvkit (13 commands)     │
                     └──────────────────────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          │                           │                           │
    ┌─────▼─────┐              ┌──────▼──────┐            ┌───────▼───────┐
    │ 筛选与加工  │              │ 统计与查看   │            │ 格式转换       │
    ├───────────┤              ├─────────────┤            ├───────────────┤
    │ csvcut    │ 选列         │ csvstat     │ 描述统计   │ csvformat     │ CSV方言互转
    │ csvgrep   │ 过滤行       │ csvlook     │ 表格式渲染  │ csvjson       │ CSV → JSON
    │ csvsort   │ 排序         │ csvsql      │ SQL 查询    │ csvpy         │ CSV → Python
    │ csvjoin   │ 表关联       │             │            │ in2csv        │ 万能 → CSV
    │ csvstack  │ 纵向拼接     │             │            │ sql2csv       │ 数据库 → CSV
    └───────────┘              └─────────────┘            └───────────────┘
```

## 二、快速决策表

```
你想做的事                                      →  用哪个

只看某几列                                      → csvcut -c name,age data.csv
搜包含某个值的行                                  → csvgrep -c city -m "北京" data.csv
按某列排序                                      → csvsort -c age -r data.csv
看每列的统计（min/max/median/distinct）            → csvstat data.csv
美化成对齐的表格看                                → csvlook data.csv | less -S
用 SQL 直接查 CSV                               → csvsql --query "SELECT * FROM data WHERE age>30" data.csv
两个表按某列关联                                  → csvjoin -c id a.csv b.csv
合并两个结构相同的 CSV                            → csvstack a.csv b.csv
CSV 转 JSON                                    → csvjson data.csv
Excel 转 CSV                                   → in2csv report.xlsx
改分隔符（逗号→Tab）                              → csvformat -T data.csv
进入 Python REPL 直接操作数据                     → csvpy data.csv
从 PostgreSQL/MySQL 导出为 CSV                   → sql2csv --db postgresql://... --query "SELECT ..."
```

## 三、管道组合示例

csvkit 全部命令支持 stdin/stdout，可以任意串联：

```bash
# 从 Excel 提取某几列 → 按部门过滤 → 按薪资排序 → 看统计
in2csv staff.xlsx \
  | csvcut -c 姓名,部门,薪资 \
  | csvgrep -c 部门 -m 研发 \
  | csvsort -c 薪资 -r \
  | csvstat

# 两个 CSV 关联 → 选列 → 渲染成表格输出
csvjoin -c user_id users.csv orders.csv \
  | csvcut -c user_id,name,order_total \
  | csvsort -c order_total -r \
  | csvlook

# 用 SQL 直接关联 + 聚合
csvsql --query "
  SELECT u.name, SUM(o.amount) AS total
  FROM users u JOIN orders o ON u.id = o.user_id
  GROUP BY u.name
  ORDER BY total DESC
" users.csv orders.csv
```

## 四、安装

```bash
pip install csvkit        # Python 包
brew install csvkit       # macOS Homebrew
apt install csvkit        # Debian/Ubuntu
```

## 五、各命令详解

| 命令 | 速记 | 教程 |
|------|------|------|
| `csvcut` | 按列名/列号选列 | [csvcut.md](csvcut.md) |
| `csvgrep` | 按值过滤行 | [csvgrep.md](csvgrep.md) |
| `csvsort` | 按列排序 | [csvsort.md](csvsort.md) |
| `csvjoin` | 两个表的 JOIN | [csvjoin.md](csvjoin.md) |
| `csvstack` | 纵向拼接（UNION ALL） | [csvstack.md](csvstack.md) |
| `csvstat` | 描述性统计 | [csvstat.md](csvstat.md) |
| `csvlook` | 表格式人眼渲染 | [csvlook.md](csvlook.md) |
| `csvsql` | 用 SQL 查 CSV | [csvsql.md](csvsql.md) |
| `csvformat` | CSV 方言转换 | [csvformat.md](csvformat.md) |
| `csvjson` | CSV → JSON | [csvjson.md](csvjson.md) |
| `csvpy` | 进入 Python REPL | [csvpy.md](csvpy.md) |
| `in2csv` | 各种格式 → CSV | [in2csv.md](in2csv.md) |
| `sql2csv` | 数据库查询 → CSV | [sql2csv.md](sql2csv.md) |
