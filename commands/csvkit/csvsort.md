
# csvsort：按列排序——支持数字、日期、多列排序

`sort -t, -k2` 能做 CSV 排序，但它不知道表头的存在，也不区分数字和文本。`csvsort` 知道 CSV 的结构，知道哪列是数字、哪列是日期，不会把 "9" 排在 "10" 后面。

---

## 场景引入

按薪资从高到低排列员工：

```bash
csvsort -c salary -r employees.csv
```

`-c` 指定列名，`-r` 降序。如果用的是 `sort`：

```bash
sort -t, -k4 -nr employees.csv
# 问题1：表头那行也被排进去了（"salary" 是文本会被排到最前面或最后面）
# 问题2：-n 强制数字排序但可能被其他字符干扰
```

---

## 核心能力

### 单列排序

```bash
csvsort -c salary employees.csv          # 升序（默认）
csvsort -c salary -r employees.csv       # 降序
```

### 多列排序

```bash
csvsort -c department,salary -r employees.csv
# 先按 department 升序，同部门内按 salary 降序
```

### 按列号排序

```bash
csvsort -c 4 -r employees.csv            # 按第 4 列
```

### 日期排序（`--date-format`）

```bash
csvsort -c hire_date --date-format "%Y-%m-%d" employees.csv
```

---

## 管道中的经典用法

```bash
# 选列 → 过滤 → 排序 → 看前 10
csvcut -c name,salary employees.csv \
  | csvgrep -c name -r "^[张李]" \
  | csvsort -c salary -r \
  | head -10

# 排序后渲染成表格
csvsort -c department,salary employees.csv | csvlook
```

---

## ⚠️ 雷区

### 文本 vs 数字排序

```bash
# ❌ 如果没指定类型，csvsort 默认按文本排序
# "15000" > "100000"（文本：逐字符比，'1'='1', '5'>'0'）
csvsort -c salary data.csv

# ✅ 显式指定为数字（如果 csvkit 没自动识别）
# 通常 csvkit 会根据数据自动判断，但混合类型时可能出错
```

### 表头永远是第一行

csvsort 自动识别第一行为表头，不会把 `salary` 那一行排到数据里——这是和 `sort` 最本质的区别。
