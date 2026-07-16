
# csvgrep：按列值过滤行——CSV 的 WHERE 子句

`grep` 是 Linux 里最常用的文本搜索工具，但用它搜 CSV 有一个致命缺陷：它不认列。`grep "研发" employees.csv` 会把「研发」两个字出现在**任何一列**的行都捞出来——名字叫「李研发」的、备注里写了「转研发部门」的，甚至表头本身，全来了。`csvgrep` 解决了这个问题：它只在你指定的那一列里搜索。

---

## 场景引入：两个用 grep 搜 CSV 翻车的瞬间

### 场景一：搜研发部门的员工

```bash
# ❌ grep 做法：把名字里有"研发"的、备注里有"研发"的全捞出来了
grep "研发" employees.csv

# ✅ csvgrep 做法：只在 department 列里搜
csvgrep -c department -m "研发" employees.csv
```

grep 不知道 CSV 的结构，它看到的只是「整行文本」。csvkit 知道表头、知道列边界，能做到精确的列级匹配。

### 场景二：搜所有 Gmail 用户

```bash
# ❌ grep "gmail.com" 会匹配到 "notgmail.com" 这种
grep "gmail.com" users.csv

# ✅ csvgrep 用正则锚定
csvgrep -c email -r "@gmail\.com$" users.csv
```

---

## 它是怎么工作的——IO 模型

csvgrep 是一个**行过滤器**：读入 CSV → 对每一行检查指定列的值是否匹配 → 匹配则保留该行，不匹配则丢弃。

```
输入 CSV（stdin / 文件名）
    │
    ↓ 读表头 → 定位目标列
    │
    ↓ 对每一行：
    │   ├─ 取出 -c 指定列的值
    │   ├─ 用 -m（精确匹配）/ -r（正则匹配）检查
    │   └─ 匹配？→ 输出该行  |  不匹配？→ 丢弃
    │
    ↓ 输出 CSV（stdout），表头保留
```

> 💡 csvgrep 是 csvkit 的 WHERE——它不修改任何列的值，不改变列的顺序，只负责「留下哪些行」。

---

## 语法骨架

```
csvgrep  -c 列名  (-m 精确值 | -r 正则)  [-i]  [文件.csv]
         ─┬─      ─────────┬───────────   ─┬─    ──┬──
        在哪列搜          怎么匹配        取反    数据源
```

属于**骨架模式 E**：`输入 → 行过滤 → 输出`。

---

## ⚠️ 先排雷：csvgrep 最容易踩的四个坑

### 雷一：`-m` 是精确匹配，不是包含

```bash
csvgrep -c city -m "京" data.csv       # ❌ 值为 "京" 的行（几乎没有）
csvgrep -c city -r "京" data.csv       # ✅ 值为 "北京"、"南京" 都能匹配
```

`-m` 要求列值**完全等于**你给的字符串。要做包含/模糊匹配，必须用 `-r`。

### 雷二：数字列被当成字符串匹配

```bash
csvgrep -c salary -m "15000" employees.csv     # ✅ 文本 "15000" 可以匹配
csvgrep -c salary -r "^1[5-9]" employees.csv   # ⚠️ 正则匹配的是文本，不是数值大小
# salary > 15000 应该用 csvsql
```

csvgrep 不知道 salary 是数字。要做数值范围过滤（`salary > 15000`），换 `csvsql`。

### 雷三：大小写敏感

```bash
csvgrep -c city -m "beijing" data.csv     # ❌ 如果是 "Beijing"，不匹配
csvgrep -c city -r "(?i)beijing" data.csv # ✅ 正则可以用 (?i) 忽略大小写
```

### 雷四：空值匹配

```bash
csvgrep -c email -r "^$" users.csv        # 找 email 为空的用户（正则空串）
# 但 csvgrep 对空值的处理可能不一致——最可靠的做法是用 csvsql：
csvsql --query "SELECT * FROM users WHERE email IS NULL OR email=''" users.csv
```

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 匹配轴 | 怎么比较？ | `-m` 精确匹配、`-r` 正则匹配 |
| 目标轴 | 在哪一列搜索？ | `-c` 指定列名或列号 |
| 方向轴 | 要命中还是排除？ | 默认匹配、`-i` 反向匹配 |
| 多值轴 | 一次搜多个值？ | `-f` 从文件读取模式列表 |

### 轴 1：精确匹配 `-m`

```bash
# 单值匹配
csvgrep -c status -m "active" data.csv

# 注意：列值必须完全等于 "active"
# "Active" / " active" / "active（已激活）" 都不匹配
```

### 轴 2：正则匹配 `-r`

```bash
csvgrep -c name -r "^张" users.csv              # 以"张"开头
csvgrep -c phone -r "^1[3-9][0-9]{9}$" users.csv # 手机号格式
csvgrep -c email -r "@(gmail|outlook)\." users.csv # Gmail 或 Outlook
```

正则语法是 Python 的（csvkit 底层是 Python），和 `grep -E` 基本兼容。

### 轴 3：反向匹配 `-i`

```bash
csvgrep -c department -m "研发" -i employees.csv  # 不是研发部的
csvgrep -c status -r "^(active|pending)$" -i data.csv  # 状态异常的行
```

### 轴 4：多模式匹配 `-f`

```bash
# patterns.txt 内容（一行一个）：
# 研发
# 市场
# 产品

csvgrep -c department -f patterns.txt employees.csv
# 匹配 department 为研发、市场或产品的所有行
```

`-f` 读文件每一行作为精确匹配值（不支持正则）。逻辑是 OR——满足任意一个即可。

---

## 场景组合

### 1. 多条件 AND：链式调用

```bash
# 研发部 AND 薪资数字以 "1" 开头（正则：1 万多）
csvgrep -c department -m "研发" employees.csv \
  | csvgrep -c salary -r "^1"
```

csvgrep 每次只能做一个条件。多个 AND 条件 = 多次链式调用。

### 2. 多条件 OR：正则 `|` 一把梭

```bash
csvgrep -c department -r "研发|市场|产品" employees.csv
```

### 3. 过滤 → 统计

```bash
csvgrep -c category -m "电子产品" sales.csv \
  | csvstat -c amount
```

### 4. 过滤 → SQL 做数值范围

```bash
csvgrep -c department -m "研发" employees.csv \
  | csvsql --query "SELECT * FROM stdin WHERE salary > 15000"
```

---

## csvgrep vs grep vs awk：什么时候用哪个

| 场景 | csvgrep | grep | awk |
|------|---------|------|-----|
| 指定列精确匹配 | ✅ `-c col -m val` | ❌ 整行搜 | ✅ `/col/ {if($x=="val")}` |
| 指定列正则匹配 | ✅ `-c col -r re` | ❌ | ✅ 稍复杂 |
| 表头自动保留 | ✅ | ❌ 表头可能被过滤 | ❌ 需手动 `NR==1` |
| 整行文本搜索 | ❌ 必须指定列 | ✅ | ✅ |
| 数字比较 | ❌ 换 csvsql | ❌ | ✅ `$3 > 15000` |
| 引号内的逗号处理 | ✅ | ❌ 会错位 | ❌ 需手动处理 |

> 💡 一句话：**搜 CSV 用 csvgrep，搜纯文本用 grep，需要多条件组合或数值比较时考虑 csvsql 或 awk。**

---

## 新手踩坑总结

- **`-m` 是精确匹配 ≠ 包含。** 想做包含匹配用 `-r "关键词"`。
- **大小写敏感。** `"Active" ≠ "active"`，用正则 `(?i)` 忽略大小写。
- **数字比较换 csvsql。** `csvgrep -c salary -r "^[2-9]"` 不等于「薪资 ≥ 20000」，只是「数字文本以 2-9 开头」。
- **多个 AND 条件 = 链式调用。** csvgrep 每次一个条件，串起来就能组合。
- **空值匹配不可靠。** 涉及 NULL/空字符串的判断建议用 csvsql。
