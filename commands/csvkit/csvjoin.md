
# csvjoin：两个 CSV 按列关联——命令行里的 JOIN

两个 CSV 文件按公共列关联起来——这是 Excel VLOOKUP 的经典场景，也是 SQL JOIN 的核心操作。在命令行里，`csvjoin` 用一行命令完成这件事，然后在管道里继续处理。不需要加载到数据库，不需要写 Python 脚本，两个 CSV 文件就是两张表。

---

## 场景引入：两个你默默打开 Excel 做 VLOOKUP 的瞬间

### 场景一：用户表 × 订单表

`users.csv`：

```
id,name,city
1,张三,北京
2,李四,上海
3,王五,深圳
```

`orders.csv`：

```
order_id,user_id,amount,date
101,1,500,2025-01-15
102,1,300,2025-02-20
103,2,800,2025-01-10
```

要看到「每笔订单是谁下的」——新手打开 Excel，在两个 sheet 之间 VLOOKUP。csvjoin 一行搞定：

```bash
csvjoin -c id,user_id users.csv orders.csv
```

### 场景二：员工表 × 部门预算表

员工表有 `dept_id`，部门表有 `id` 和 `budget`。需要把每个人的部门预算带出来：

```bash
csvjoin -c dept_id,id --left employees.csv departments.csv
# --left：保留所有员工，即使他的部门没有预算数据
```

---

## 它是怎么工作的——IO 模型

csvjoin 是 csvkit 里唯一一个**同时读两个文件**的命令——它把第二个文件的内容按关联列构建为内存中的查找表，然后遍历第一个文件的每一行做匹配。

```
文件1 (左表)                      文件2 (右表)
    │                                  │
    ↓ 读全部行                         ↓ 读全部行 → 按关联列建 HashMap
    │                                  │
    └──────────┬───────────────────────┘
               ↓
    对左表每一行：
      用 -c 指定的左表列值在 HashMap 中查找
      找到？→ 合并两行输出（INNER）  没找到？→ 看 JOIN 类型
    │
    ↓ 输出 CSV（stdout），表头 = 左表列 + 右表列（去重关联列）
```

> 💡 csvjoin 本质上是 **Hash Join**：右表全量加载到内存，左表逐行匹配。所以右表越小越好——如果你把大表放右边，内存会炸。

---

## 语法骨架

```
csvjoin  -c 左表列,右表列  [--left|--right|--outer]  左表.csv  右表.csv
         ───────┬───────         ──────┬──────        ──┬───   ──┬───
             按什么关联              JOIN 类型          左表     右表
```

---

## ⚠️ 先排雷：csvjoin 最容易踩的四个坑

### 雷一：`-c` 的参数顺序是「左表列,右表列」

```bash
# users.csv (左) 的 id 列 = orders.csv (右) 的 user_id 列
csvjoin -c id,user_id users.csv orders.csv         # ✅ 左.id = 右.user_id
csvjoin -c user_id,id users.csv orders.csv         # ❌ 左.user_id（但左表根本没这列）
```

这个顺序是反直觉的——很多人觉得「被关联的列应该写在前面」。但 csvjoin 的设计是「左表列,右表列」，因为左表是主表。

### 雷二：两边列名一样时可以简写

```bash
# 如果两个表都有 "id" 列
csvjoin -c id a.csv b.csv                          # 等价于 -c id,id
```

### 雷三：文本精度导致关联失败

```bash
# 左表 id 列：1, 2, 3（数字）
# 右表 user_id 列："001", "002", "003"（带前导零的字符串）
# → 没有一行能匹配！
```

关联前检查两边的数据格式。用 `csvstat` 看数据类型，用 `csvsql` 做格式转换：

```bash
csvsql --query "SELECT printf('%03d', user_id) AS id FROM orders" orders.csv > orders_fixed.csv
```

### 雷四：多对多 JOIN 导致行数膨胀

```bash
# 左表有 3 个 "张三"，右表有 4 个 "张三" → 结果有 3×4=12 行 "张三"
```

csvjoin 不会警告你行数膨胀。关联后用 `wc -l` 对比输入和输出的行数。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 关联轴 | 怎么匹配？ | `-c 左列,右列` 指定关联键 |
| 类型轴 | 匹配不上怎么处理？ | 默认 INNER、`--left`、`--right`、`--outer` |

### 轴 1：关联键指定

```bash
csvjoin -c id,user_id users.csv orders.csv          # 文本关联
```

csvjoin 默认把关联键当文本比较（`"1"` 和 `1` 可能不匹配，取决于 CSV 是否有引号）。如果确定是数字，确保两边格式一致。

### 轴 2：JOIN 类型

```bash
# INNER JOIN（默认）：只在两边都匹配时才保留
csvjoin -c id,user_id users.csv orders.csv

# LEFT JOIN：保留左表所有行，右表没匹配的列为空
csvjoin -c id,user_id --left users.csv orders.csv

# RIGHT JOIN：保留右表所有行
csvjoin -c id,user_id --right users.csv orders.csv

# FULL OUTER JOIN：两边全部保留
csvjoin -c id,user_id --outer users.csv orders.csv
```

这四种类型和 SQL 完全对应。

---

## 场景组合

### 1. 关联 → 选列 → 排序 → 渲染

```bash
csvjoin -c id,user_id users.csv orders.csv \
  | csvcut -c name,city,amount,date \
  | csvsort -c amount -r \
  | csvlook
```

JOIN 之后列可能会很多（两边的列全在上面），立刻用 csvcut 精简。

### 2. 关联后用 SQL 做聚合

```bash
csvjoin -c id,user_id users.csv orders.csv \
  | csvsql --query "
      SELECT name, city, COUNT(*) AS orders, SUM(amount) AS total
      FROM stdin GROUP BY name, city ORDER BY total DESC
    "
```

csvjoin 做关联，csvsql 做聚合——互不越界，各司其职。

### 3. 多个 LEFT JOIN（需要中间文件）

csvjoin 一次只能 JOIN 两个表。三表 JOIN 需要中间步骤：

```bash
# 先 users + orders
csvjoin -c id,user_id --left users.csv orders.csv > tmp1.csv
# 再 tmp1 + products
csvjoin -c product_id,id --left tmp1.csv products.csv
```

或者直接用 csvsql 一次搞定三表：

```bash
csvsql --query "
  SELECT u.*, o.amount, p.name AS product
  FROM users u
  LEFT JOIN orders o ON u.id = o.user_id
  LEFT JOIN products p ON o.product_id = p.id
" users.csv orders.csv products.csv
```

---

## csvjoin vs Excel VLOOKUP vs csvsql JOIN：什么时候用哪个

| 场景 | csvjoin | Excel VLOOKUP | csvsql |
|------|---------|---------------|--------|
| 简单两表关联 | ✅ `-c id,id` | ✅ | ✅ `JOIN` |
| 三表以上关联 | ❌ 需中间文件 | ✅ 多次 VLOOKUP | ✅ 一次搞定 |
| 关联后做聚合 | ❌ 需管道给 csvsql | ✅ 数据透视表 | ✅ 同一条 SQL |
| LEFT/RIGHT/OUTER JOIN | ✅ | ⚠️ VLOOKUP 只做 LEFT | ✅ |
| 100 万行以上 | ⚠️ 内存吃紧 | ❌ Excel 直接卡死 | ✅ SQLite 更稳定 |
| 管道友好 | ✅ stdout | ❌ | ✅ |

> 💡 一句话：**两表关联用 csvjoin，三表以上或用聚合用 csvsql，别开 Excel。**

---

## 新手踩坑总结

- **`-c` 的顺序是「左表列,右表列」。** 左表是第一个文件参数，右表是第二个。
- **关联前确认两边数据格式一致。** 特别是数字 vs 字符串、前导零、空格等问题。
- **注意行数膨胀。** 多对多 JOIN 会产生笛卡尔积式的膨胀，不要让意外重复值把你坑了。
- **内存管理。** 右表越小越好——csvjoin 把右表全部加载进内存做 Hash Join。如果右表很大，考虑反过来写参数（把大表放在左边），或者用 csvsql。
