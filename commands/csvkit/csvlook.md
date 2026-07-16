
# csvlook：把 CSV 渲染成对齐的表格——人眼友好的数据查看

`cat data.csv` 看 CSV 的体验是灾难——逗号乱飞，列对不齐，眼睛找不到数据。`csvlook` 是 csvkit 给你的「人眼渲染器」：把 CSV 渲染成对齐的 Markdown 风格表格，配合 `less -S` 浏览非常舒服。

---

## 场景引入

```bash
cat employees.csv
```

输出：

```
id,name,department,salary
1,张三,研发,15000
2,李四,市场,12000
3,王五,研发,18000
```

同样一个文件，换成 csvlook：

```bash
csvlook employees.csv
```

输出：

```
| id | name | department | salary |
| -- | ---- | ---------- | ------ |
|  1 | 张三 | 研发       |  15000 |
|  2 | 李四 | 市场       |  12000 |
|  3 | 王五 | 研发       |  18000 |
```

瞬间可读。宽表配合 `less -S` 横向滚动更舒服：

```bash
csvlook wide_table.csv | less -S
```

---

## 核心能力

### 基本渲染

```bash
csvlook data.csv
```

### 指定最大列宽（`--max-column-width`）

长内容会截断，防止一列占满整个屏幕：

```bash
csvlook --max-column-width 40 wide_data.csv
```

### 去掉分隔线（`--no-inference`）

```bash
csvlook --no-inference data.csv  # 更紧凑
```

### 输出为 CSV 格式的表格（`--csv`）

```bash
csvlook --csv data.csv > formatted.csv  # 保留格式但写回 CSV
```

---

## 管道中的经典用法

```bash
# 选几列 → 过滤 → 排序 → 渲染 → 浏览
csvcut -c name,department,salary employees.csv \
  | csvgrep -c department -m "研发" \
  | csvsort -c salary -r \
  | csvlook

# 统计后偶尔也渲染看看
csvstat --freq -c category sales.csv | csvlook
```

---

## ⚠️ 雷区

### 不要渲染给程序读

`csvlook` 的输出是给人看的，加了 `|` 和对齐空格。**不要**在 csvlook 后面接管道给另一个 CSV 处理命令：

```bash
csvlook data.csv | csvstat       # ❌ csvstat 读到的是带 | 和空格的数据
csvcut data.csv | csvstat        # ✅ 管道中间不要插入 csvlook
```

### csvlook 不是数据分析工具

它就是纯渲染，不做任何统计或过滤。想看统计数据用 `csvstat`，想看内容排版用 `csvlook`。
