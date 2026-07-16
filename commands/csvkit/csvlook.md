
# csvlook：CSV 渲染为对齐表格——让机器可读的数据变人眼可读

`cat data.csv` 看 CSV 是场灾难：逗号乱飞，列对不齐，眼睛找半天找不到第三列的值。`csvlook` 做的事非常简单——把 CSV 渲染成 Markdown 风格的对齐表格，列与列之间用 `|` 分隔，视觉对齐。它不做任何数据处理，只是纯渲染。但就是这样一个小功能，让你在终端里看 CSV 的体验从「灾难」变成「享受」。

---

## 场景引入：两个你对着 cat 输出干瞪眼的瞬间

### 场景一：看一眼刚才过滤的结果对不对

```bash
# ❌ cat：逗号乱飞，根本看不清
csvgrep -c department -m "研发" employees.csv | csvcut -c name,salary | cat
# name,salary
# 张三,15000
# 李四,12000

# ✅ csvlook：瞬间可读
csvgrep -c department -m "研发" employees.csv | csvcut -c name,salary | csvlook
# | name | salary |
# | ---- | ------ |
# | 张三 |  15000 |
# | 李四 |  12000 |
```

### 场景二：看一张 30 列宽的表

```bash
# cat 输出会疯狂换行，完全没法读
# csvlook + less -S 可以横向滚动
csvlook wide_table.csv | less -S
# 左右箭头键滚动，列名永远在视线内
```

---

## 它是怎么工作的——IO 模型

csvlook 是纯渲染器——它读 CSV、计算每列最大宽度（基于该列所有值）、生成对齐的表格线。

```
输入 CSV（stdin / 文件名）
    │
    ↓ 读表头 + 所有数据行
    │
    ↓ 扫描每列的最大宽度（表头名称 vs 数据值的字符宽度）
    │
    ↓ 按最大宽度生成 Markdown 表格：
    │   ├─ 表头行：| col1 | col2 | ...
    │   ├─ 分隔行：| ---- | ---- | ...
    │   └─ 数据行：| val1 | val2 | ...（右对齐数字，左对齐文本）
    │
    ↓ stdout
```

> 💡 csvlook 必须读完全表才能渲染——因为需要知道每列的最大宽度。它不能做流式输出。

---

## 语法骨架

```
csvlook  [--max-column-width N]  [--no-inference]  [文件.csv]
         ──────────┬─────────    ───────┬───────     ──┬──
              截断长文本            紧凑模式           数据源
```

---

## ⚠️ 先排雷：csvlook 最容易踩的四个坑

### 雷一：不要渲染给程序读

```bash
# ❌ 在 csvlook 后面再接 csvstat——csvstat 读到的是带 | 和空格的表格
csvlook data.csv | csvstat

# ✅ 管道中间的渲染是致命的——只有最后一步才 csvlook
csvsort -c salary -r data.csv | csvlook
```

**规则：csvlook 永远是管道的最末端。** 它输出的不是 CSV，是给人看的装饰文本。

### 雷二：宽表需要 less -S 横向滚动

```bash
csvlook wide.csv             # 终端太窄，每行折成 5 段，比 cat 还难读
csvlook wide.csv | less -S   # ← 加 -S 禁止折行，左右箭头横向滚动
```

### 雷三：必须读全表

csvlook 需要先扫描所有值来计算每列最大宽度。100 万行的表会先全量扫描一遍再输出——如果只是看一眼数据，用 `head -11 | csvlook` 先看前 10 行。

### 雷四：数字列是右对齐还是左对齐？

csvlook 会根据 csvkit 的类型推断自动决定对齐方式：数字右对齐，文本左对齐。但如果列里有混合数据（某些行是 "N/A"），对齐可能会不一致。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 宽度轴 | 长文本怎么办？ | `--max-column-width` 截断 |
| 紧凑轴 | 要不要分隔线？ | `--no-inference` 去掉类型推断和多余装饰 |

### 轴 1：截断长文本 `--max-column-width`

```bash
# description 列每行 500 字，不截断整个表格被撑爆
csvlook --max-column-width 40 products.csv
# 超过 40 字符的用 ... 替代
```

### 轴 2：紧凑模式 `--no-inference`

```bash
csvlook --no-inference data.csv
# 不显示表头下面的分隔线，不使用数字对齐
```

---

## 场景组合

### 1. 过滤 → 排序 → 截断 → 渲染

```bash
csvgrep -c status -m "failed" jobs.csv \
  | csvsort -c runtime -r \
  | csvcut -c seq,cmd,runtime \
  | csvlook --max-column-width 60
```

### 2. 看统计结果

```bash
csvstat --freq -c category sales.csv | csvlook
```

### 3. 只看表中某几行的渲染

```bash
# 先过滤到目标行，再渲染
head -11 data.csv | csvlook    # 前 10 行 + 表头
```

---

## csvlook vs column -t -s, vs 直接 cat：什么时候用哪个

| 场景 | csvlook | column -t -s, | cat |
|------|---------|---------------|-----|
| CSV 表格渲染 | ✅ 列对齐 + 分隔线 | ⚠️ 列对齐但无分隔线 | ❌ |
| 表头/数据区分 | ✅ 分隔线区分 | ❌ | ❌ |
| 大型数据快速看一眼 | ✅ `head | csvlook` | ⚠️ | ✅ 最快 |
| 非 CSV 文本 | ❌ 必须 CSV 格式 | ✅ 通用 | ✅ |

> 💡 一句话：**看 CSV 用 csvlook，看任何文本列对齐用 `column -t`。**

---

## 新手踩坑总结

- **csvlook 永远是管道的最末端。** 后面不能再接 csvkit 命令。
- **宽表加 `| less -S`。** 不折行 + 横向滚动是看宽表的正确姿势。
- **大表先用 head 看前几行。** csvlook 必须读全表，100 万行渲染前全量扫描很慢。
- **它不做数据处理。** 过滤、排序、统计都在前面做好，csvlook 只负责给你看。
