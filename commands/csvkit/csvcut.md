
# csvcut：按列名选列——告别"数第几列"的 CSV 列操作

如果你需要从 CSV 里提取某几列，awk 的 `'{print $1,$3}'` 是最常见的做法。但当表头是 `"Full Name"`、`"Annual Salary (USD)"` 这种带空格和括号的名字时，数第几列就很痛苦了——而且下个月同事在 CSV 中间加了一列 `"备注"`，你的 `$1,$3` 就全乱了。`csvcut` 让你用**列名**而非列号来操作，并且 `-n` 能瞬间列出一张表的「列名清单」——这个功能命令行的其他工具都做不到。

---

## 场景引入：两个你默默打开 Excel 数第几列的瞬间

### 场景一：只想要姓名和邮箱两列

```bash
# 文件 employees.csv：
# id,name,department,salary,email,hire_date
# 1,张三,研发,15000,zhangsan@example.com,2020-03-15

# 新手做法：打开 Excel，看看 email 在第几列……第 5 列
awk -F, '{print $2,$5}' employees.csv
# 输出：name email（数据行 OK，但表头是列名不是列号，awk 无法用列名指定）

# csvcut 做法：直接用列名
csvcut -c name,email employees.csv
```

不用数，不用记，列名就是参数。

### 场景二：你完全不知道这张表有哪些列

```bash
# 新手做法：head -1 data.csv，然后人眼解析逗号
head -1 data.csv
# id,name,department,salary,email,phone,address,city,zip,hire_date,...

# csvcut 做法：
csvcut -n data.csv
#   1: id
#   2: name
#   3: department
#   4: salary
#   5: email
#   ...
```

带编号的列名清单，一目了然——这是 `head -1` 做不到的。

---

## 它是怎么工作的——IO 模型

csvcut 本质上是一个**列过滤器**：读入整个 CSV，只输出你指定的那些列，其余丢弃。它不关心行内容，只关心列名和列号。

```
输入 CSV（stdin / 文件名）
    │
    ↓ 读表头 → 建立「列名 → 列号」映射
    │
    ↓ 对每一行：
    │   ├─ 保留 -c 指定的列
    │   └─ 丢弃其余
    │
    ↓ 输出 CSV（stdout）
```

> 💡 csvcut 不做值转换，不做过滤，不改行内容。它唯一的工作是「投影」——这是关系代数里的 π 操作，sql 里的 `SELECT name, email FROM ...`。

---

## 语法骨架

```
csvcut  [-c 列名列表 | -C 排除列列表]  [-n]  [文件.csv]
         ─────────┬─────────────        ─┬─    ──┬──
               选哪些列              查看列名   数据源
```

属于**骨架模式 E**：`输入 → 列投影 → 输出`。csvcut 不修改原文件，只输出到 stdout。

---

## ⚠️ 先排雷：csvcut 最容易踩的三个坑

### 雷一：列名有空格或特殊字符，不加引号就翻车

```bash
# ❌ shell 把空格当参数分隔符，csvcut 收到的是 -c Full 和 Name,Salary 两个东西
csvcut -c Full Name,Salary data.csv

# ✅ 整个列名列表用引号包住
csvcut -c "Full Name,Annual Salary" data.csv
```

### 雷二：`-c` 和 `-C` 的区别——一个选，一个排除

```bash
csvcut -c name,email data.csv    # 只要 name 和 email 两列
csvcut -C name,email data.csv    # 除了 name 和 email 以外的全部列
```

新手经常 `-c` 写成 `-C`，输出了一大堆——因为把所有不需要的列当成了要排除的。

### 雷三：列名不存在不报错

```bash
csvcut -c name,salayr data.csv   # "salayr" 拼错了
# 不报错！只是 salayr 列全是空的
```

csvkit 不会因为列名不存在而报错——这反而是个坑，因为你会拿到一份列数正确但某一列全是空白的数据，且不会有人告诉你。输出前用 `csvcut -n` 核对列名。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 选择轴 | 按什么选列？ | `-c` 按列名、`-c N` 按列号 |
| 排除轴 | 不要哪些列？ | `-C` 排除指定列 |
| 探查轴 | 有哪些列可以选？ | `-n` 列出所有列名和列号 |
| 排序轴 | 选出来的列按什么顺序？ | 按 `-c` 参数顺序输出，与原表顺序无关 |

### 轴 1：按列名选列 `-c`

```bash
csvcut -c name,salary data.csv              # 两列，按你写的顺序输出
csvcut -c id,name,department data.csv       # 可以重新排列列的顺序
```

`-c` 不只「选列」，同时也是「重排列」——输出的列顺序就是你写参数的顺序，不需要再手动 `awk` 调换 `$2` 和 `$1`。

### 轴 2：按列号选列

```bash
csvcut -c 2,4 data.csv                      # 第 2 列和第 4 列
```

> ⚠️ csvcut 的列号从 1 开始（不是 0），而且**不支持 `1-5` 这种范围写法**——这和 `cut -f1-5` 不同。需要连续多列只能用 `-C` 排除不需要的，或者一个列号一个列号地写。

### 轴 3：排除列 `-C`

```bash
csvcut -C id,internal_id,created_at data.csv  # 去掉三列，其余保留
```

适合「这张表有 40 列，我只想砍掉 3 列」的场景——比写 37 个列名轻松得多。

### 轴 4：探查 `-n`

```bash
csvcut -n data.csv
#   1: id
#   2: name
#   3: department
#   4: salary
#   5: email
```

这是 csvcut 最高频的使用方式——**在写 `-c` 之前先跑 `-n` 看一眼**，就像 sql 里先 `DESCRIBE table` 再写 `SELECT`。

---

## 场景组合

### 1. 探查 → 选列 → 排序 → 看表

```bash
# 先看一眼有哪些列
csvcut -n big_data.csv

# 选几列 → 按薪资降序 → 渲染成表格
csvcut -c name,department,salary big_data.csv \
  | csvsort -c salary -r \
  | csvlook
```

### 2. 两个 CSV 关联后再精简化

```bash
# 关联后会有很多重复列（两边的 id 都在），用 csvcut 精简
csvjoin -c user_id,id users.csv orders.csv \
  | csvcut -c name,product,amount
```

### 3. 重排列顺序

```bash
# 原表：id,name,department,salary
# 想输出：department,name,salary （把部门提到第一列）
csvcut -c department,name,salary data.csv
```

不需要 awk `'{print $3,$2,$4}'`——用列名写就行。

---

## csvcut vs awk vs cut：什么时候用哪个

| 场景 | csvcut | awk | cut |
|------|--------|-----|-----|
| 按列名选列 | ✅ `-c name,age` | ❌ 不支持 | ❌ 不支持 |
| 先看一眼有哪些列 | ✅ `-n` | ❌ | ❌ |
| 按列号选列 | ✅ `-c 2,4` | ✅ `{print $2,$4}` | ✅ `-f2,4` |
| 按范围选列 | ❌ 不支持 `1-5` | 可行但繁琐 | ✅ `-f1-5` |
| 排除某些列 | ✅ `-C` | 需要写复杂脚本 | ✅ `--complement` |
| 表头自动保留 | ✅ 自动 | ❌ 需手动 print | ❌ 表头被当数据处理 |
| CSV 引号正确处理 | ✅ | ❌ 需手动处理 | ❌ |

> 💡 一句话：**CSV 用 csvcut，纯文本用 cut，需要逻辑用 awk。** csvcut 不是为了替代 cut 和 awk，而是为了「只有 CSV 才需要的」列名操作和表头感知。

---

## 新手踩坑总结

- **跑 `-c` 之前先跑 `-n`。** 看一眼列名再写参数，避免 typo 导致的空列。
- **列名不存在不报错。** 拼写错误不会引发任何提示，输出中该列为空。
- **`-c` 不支持范围。** 不能写 `-c 3-7`，只能一个个列出来。排除场景用 `-C`。
- **管道是 csvcut 最好的朋友。** csvcut 永远只输出到 stdout，保存需要 `> output.csv`。
- **重排列顺序用 `-c`。** 参数顺序就是输出顺序，不需要额外工具。

---

## 最后

csvcut 做的事很简单——选列。但它解决了命令行处理 CSV 最大的痛点：**列是用名字而不是位置来引用的。** 在一张有 50 列的表里，`csvcut -c email,phone,city` 远比 `awk -F, '{print $5,$6,$8}'` 可读、可维护、可复用。下次同事在 CSV 里加了一列，你的 awk 脚本会静默输出错误数据——而 csvcut 用列名，不受影响。
