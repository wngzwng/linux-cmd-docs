
# csvgrep：按列值过滤行——CSV 版的 grep

`grep` 搜的是整行文本，`csvgrep` 搜的是**指定列的值**。当你只需要「部门=研发 的所有行」而非「整行里出现"研发"两个字的行」时，csvgrep 更精确。

---

## 场景引入

从 `employees.csv` 里挑出研发部门的所有人：

```bash
csvgrep -c department -m "研发" employees.csv
```

`-c` 指定列名，`-m` 指定匹配值。对比 grep：

```bash
grep "研发" employees.csv
# 危险：如果 hire_date 里出现了"研发"（比如备注栏），也会被匹配
```

---

## 核心能力

### 精确匹配（`-m`）

```bash
csvgrep -c department -m "研发" employees.csv
```

### 正则匹配（`-r`）

```bash
csvgrep -c name -r "^张" employees.csv       # 名字以"张"开头
csvgrep -c email -r "@gmail\.com$" data.csv  # Gmail 地址
```

### 反向匹配（`-i`）

```bash
csvgrep -c department -m "研发" -i employees.csv  # 不是研发的
```

### 模糊匹配（`-f`）

```bash
# 从文件读取匹配模式，一行一个
echo "研发"  > patterns.txt
echo "市场" >> patterns.txt
csvgrep -c department -f patterns.txt employees.csv
```

---

## 管道中的经典用法

```bash
# 先过滤再统计
csvgrep -c department -m "研发" employees.csv | csvstat

# 多个条件串联：研发 + 薪资 > 15000
csvgrep -c department -m "研发" employees.csv \
  | csvsql --query "SELECT * FROM stdin WHERE salary > 15000"
```

> 💡 csvgrep 只支持单个条件。多个 AND 条件要么串联 csvsql，要么链式调用 csvgrep（多次过滤）。

---

## ⚠️ 雷区

### `-m` 是精确匹配，不是包含

```bash
csvgrep -c city -m "京" data.csv     # ❌ 只匹配值为 "京" 的行
csvgrep -c city -r "京" data.csv     # ✅ 正则匹配，值为 "北京" 或 "南京" 都命中
```

### csvgrep 不知道列的类型

`salary` 列是数字，但 csvgrep 当文本匹配：

```bash
csvgrep -c salary -m "15000" employees.csv    # ✅ 文本匹配
csvgrep -c salary -r "^1[5-9]" employees.csv  # ✅ 正则也能做数值范围（但不推荐）
```

做数值范围过滤，应该用 `csvsql`：

```bash
csvsql --query "SELECT * FROM employees WHERE salary > 15000" employees.csv
```
