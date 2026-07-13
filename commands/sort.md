# 为什么 sort 很强，但大多数人只会 `sort` 和 `sort -r`？

> `sort` 是管道里的排序引擎。大多数人只用它来按字母排序——`sort` 回车。但其实 sort 可以做数值排序、按字段排序、去重、随机打乱、人类可读大小排序、检查有序性——它是管道组合里最不可或缺的一环。

## 一、你会遇到的场景

某天你统计了每个 IP 的访问次数，想按次数从高到低排列——但出来的数据是 `cnt IP` 这种格式（数字在前，但默认按字母排就会出问题）。

```bash
# ❌ 字母排序：10 排在 2 前面（因为 '1' < '2'）
awk '{cnt[$1]++} END {for (k in cnt) print cnt[k], k}' access.log | sort

# ✅ 数值排序 + 反向：按数字大小排，降序
awk '{cnt[$1]++} END {for (k in cnt) print cnt[k], k}' access.log | sort -rn
```

**这就是 sort 的核心价值：对文本行排序——支持数字排序、按字段排序、去重、合并有序文件。** 它是 `| sort | uniq -c | sort -rn | head` 这个经典管道模式的心脏。

## 二、语法骨架

```
sort  [选项]  [文件...]
      ──┬──   ──┬──
       怎么排    排什么
```

属于**骨架模式 E**：`输入 → 排序 → 输出`。sort 自己不开门——它总是站在管道中间。

## 三、核心能力逐轴拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 比较轴 | 按什么规则比大小？ | `-n`(数值)、`-h`(人类可读)、`-M`(月份)、`-V`(版本号)、默认(字母) |
| 字段轴 | 按第几列排序？ | `-k N`、`-t`(分隔符) |
| 方向轴 | 升序还是降序？ | 默认(升序)、`-r`(降序) |
| 去重轴 | 重复的要不要合并？ | `-u`(去重) |
| 控制轴 | 怎么控制输出？ | `-o`(写到文件)、`-c`(检查是否有序)、`-R`(随机)、`-m`(合并) |

---

### 轴 1：比较轴——"按什么规则比大小？"

```bash
# 默认：字母排序（按当前 locale 的字典序）
printf 'cat\ndog\napple\n' | sort
# → apple, cat, dog

# -n：数值排序（10 > 9 > 2）
printf '10\n2\n1\n100\n' | sort -n
# → 1, 2, 10, 100

# -h：人类可读的数字排序（1K < 1M < 1G）
du -h | sort -h

# -V：版本号排序（1.10 > 1.9）
printf 'v1.10\nv1.9\nv2.0\nv1.2\n' | sort -V
# → v1.2, v1.9, v1.10, v2.0

# -M：月份排序（Jan < Feb < ... < Dec）
printf 'Oct\nJan\nMar\n' | sort -M
# → Jan, Mar, Oct
```

> ⚠️ **默认排序是字母序（lexicographic），不是数字序。** `10` 排在 `2` 前面，因为 `'1' < '2'`。只要排的是数字，永远带 `-n`。

---

### 轴 2：字段轴——"按第几列排序？"

```bash
# -k N：按第 N 列排序（列从 1 开始）
ps aux | sort -k2 -n          # 按 PID 排序

# -k M,N：按第 M 到第 N 列排序（多列）
sort -k2,2 -k3,3 file.txt     # 先按第 2 列，再按第 3 列

# -t：指定列分隔符（CSV 按逗号，passwd 按冒号）
sort -t, -k3 -n data.csv      # 按 CSV 第 3 列数值排序
sort -t: -k3 -n /etc/passwd   # 按 UID 排序

# 反向排序某列
ps aux | sort -k4 -rn          # 按内存使用降序
```

> 💡 `-k` 的完整语法是 `-k start[,end]`。`-k2` 等于 `-k2,0`（从第 2 列到行尾）。如果要严格只按第 2 列排序，用 `-k2,2`。

---

### 轴 3：方向轴——"升序还是降序？"

```bash
# 默认：升序（a → z，小 → 大）
sort file.txt

# -r：降序（z → a，大 → 小）
sort -r file.txt

# 数值降序（最常见组合）
sort -rn
```

---

### 轴 4：去重轴——"重复行怎么处理？"

```bash
# -u：排序 + 去重（保留第一条）
printf 'b\na\nb\na\nc\n' | sort -u
# → a, b, c

# 注意：-u 和 uniq 的区别
# sort -u：排序后去重（整行相同才去重）
# uniq：只合并相邻重复行（需要先 sort）
```

> 💡 大多数场景下 `sort -u` 比 `sort | uniq` 更简洁。但 `uniq -c`（统计每行出现次数）是 uniq 独占的杀手功能——那个组合你还是需要 `sort | uniq -c`。

---

### 轴 5：控制轴——"输出到哪？怎么检查？"

```bash
# -o：排序结果写回文件（不能用重定向：sort file > file 会清空文件）
sort -o file.txt file.txt

# -c：只检查是否已经有序（不排序，不输出）
sort -c file.txt && echo "sorted" || echo "not sorted"

# -R：随机排序（打乱行顺序）
seq 10 | sort -R

# -m：合并多个已排序的文件（比排序快得多）
sort -m sorted1.txt sorted2.txt sorted3.txt > merged.txt
```

> ⚠️ **`sort file > file` 会清空文件！** 重定向 `>` 先截断文件，sort 读到一个空文件。用 `sort -o file file` 安全地原地排序。

---

## 四、经典管道模式

```bash
# 统计 + 排序 + Top N（Linux 分析的基本功）
cat access.log \
  | awk '{print $1}' \
  | sort \
  | uniq -c \
  | sort -rn \
  | head -10

# 查最大的 10 个目录
du -h -d 1 | sort -rh | head -10

# 按文件扩展名分组统计
ls -1 | sed 's/.*\.//' | sort | uniq -c | sort -rn
```

---

## 五、踩坑清单

- **坑一：默认字母排序，10 排在 2 前面** → 数字永远用 `-n`；人类可读大小用 `-h`。
- **坑二：`sort file > file` 清空文件** → 用 `sort -o file file` 安全原地排序。
- **坑三：`-k` 不写 `-n` 时会按字母排数字列** → `sort -k3` 对数值列无效，必须 `sort -k3 -n`。
- **坑四：`sort -u` 无法替代 `uniq -c`（行计数）** → 需要统计出现次数的场景保留 `| sort | uniq -c | sort -rn` 管道。
- **坑五：locale 影响排序行为** → 中文环境下 sort 可能用拼音序而非字节序。需要一致性时 `LC_ALL=C sort`。

## 六、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 文本行排序 | sort | 标准工具，管道核心 |
| 在管道里自然排序（含数字） | `sort -n` | 必须显式指定 |
| 去重（不需要计数） | `sort -u` | 比 sort + uniq 简洁 |
| 去重 + 统计 | `sort \| uniq -c` | sort -u 不做计数 |
| 原地编辑文件排序 | vim `:sort` | 交互式编辑时更方便 |

---

> **核心观点：** 学 sort 不是为了记住 `sort file` 这个最简单用法，而是理解它的 **比较方式**（字母 vs 数字 vs 人类可读）和 **字段能力**（`-k` + `-t`）。95% 的日常场景只需要三个组合：**`sort -n`**（数字排序）、**`sort -rn`**（数字降序）、**`sort -t, -k2 -n`**（按第 2 列数值排序）。
