
# csvformat：CSV 方言互转——不同系统之间的 CSV 翻译器

CSV 没有统一标准。逗号分隔、分号分隔、Tab 分隔、pipe 分隔；有的用双引号包住所有值，有的只包住含逗号的值；有的行尾是 `\r\n`（Windows），有的是 `\n`（Unix）。同一个 CSV 在不同系统间流转时，格式差异常常是「文件打不开」「导入报错」「中文乱码」的根源。`csvformat` 做的事很简单：**把一种 CSV 方言转成另一种**。不修改数据，只改表示层。

---

## 场景引入：两个被 CSV 方言坑过的瞬间

### 场景一：从老旧系统导出的 pipe 分隔文件

```bash
# 文件内容（pipe 分隔，所有值带引号）：
# "id"|"name"|"amount"
# "1"|"张三"|"500"

# ❌ Excel 打开：一列到底，全在一个单元格里
# ❌ csvcut 直接读：不认识 pipe 分隔符

# ✅ 先转换格式
csvformat -D "|" old_data.txt > standard.csv
# id,name,amount
# 1,张三,500
```

`-D`（大写）告诉 csvformat **输入**的分隔符是什么。输出默认用逗号，所以结果是标准 CSV。

### 场景二：给欧洲同事发送 CSV

```bash
# 欧洲版 Excel 默认用分号分隔（因为逗号被用作小数点：3,14 €）
# 标准逗号 CSV 在欧洲 Excel 里打开 → 全乱

# 转成分号分隔
csvformat -d ";" data.csv > europe.csv
```

---

## 它是怎么工作的——IO 模型

csvformat 做的是**格式层变换**，不碰数据。它把 CSV 按一种方言解析，再按另一种方言输出。

```
输入 CSV（某种方言）
    │
    ↓ 用输入方言参数解析：
    │   -D 输入分隔符、-Q 输入引号字符、-M 输入行尾
    │
    ↓ 按输出方言参数重新编码：
    │   -d 输出分隔符、-q 输出引号字符、-m 输出行尾、-U 引号策略
    │
    ↓ 输出 CSV（另一种方言）→ stdout
```

> 💡 csvformat 和 `csvcut` 这类数据处理命令不同——它不读列名，不关心数据结构。它只是「把 CSV 当成格式，做格式转换」。

---

## 语法骨架

```
csvformat  [-D 输入分隔符]  [-d 输出分隔符]  [-T]  [-U 引号级别]  [文件.csv]
           ──────┬───────   ──────┬───────   ─┬─   ─────┬─────     ──┬──
              输入方言           输出方言     Tab     引号策略       数据源
```

关键记忆点：**大写选项控制输入（从哪里来），小写选项控制输出（到哪里去）。** 这是 csvkit 全家桶的统一约定。

---

## ⚠️ 先排雷：csvformat 最容易踩的四个坑

### 雷一：`-D` vs `-d`：大写是输入，小写是输出

```bash
csvformat -D "|" pipe_data.txt        # ✅ 输入是 pipe，输出标准逗号
csvformat -d "|" pipe_data.txt        # ❌ 把标准输入转成 pipe 输出（输入没指定 → 默认逗号）
```

搞反了不会报错，只是输出不是你想要的。

### 雷二：`-T` 和 `-d` 互斥

```bash
csvformat -T data.csv                  # ✅ 输出 Tab 分隔
csvformat -d $'\t' data.csv            # ✅ 同上
csvformat -T -d "|" data.csv           # ❌ 冲突
```

### 雷三：引号策略 `-U` 的数字含义

```bash
csvformat -U 0 data.csv    # 所有列都不加引号（最干净，但数据含逗号时会错）
csvformat -U 1 data.csv    # 只在必要时加引号（含逗号、引号、换行的列）← 默认
csvformat -U 2 data.csv    # 所有列都加引号（最安全，但文件变大）
```

数字 0/1/2 而非 1/2/3——不是从 1 开始的。

### 雷四：csvformat 不校验数据完整性

如果输入数据本身就有未转义的逗号（比如原始数据是一个损坏的 CSV），csvformat **不会报错**——它会忠实地把损坏的输入转成损坏的输出。

---

## 核心能力逐层拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 分隔符轴 | 分割列用什么字符？ | `-D` 输入分隔符、`-d` 输出分隔符、`-T` 输出 Tab |
| 引号轴 | 值怎么包起来？ | `-Q` 输入引号符、`-q` 输出引号符、`-U 0/1/2` 引号策略 |
| 行尾轴 | 换行符是什么？ | `-M` 输入行尾、`-m` 输出行尾 |
| 跳过轴 | 前面几行不是数据？ | `--skip-lines N` 跳过前 N 行 |

### 轴 1：分隔符转换

```bash
csvformat -D "|" pipe_data.csv                  # pipe → 逗号
csvformat -D "|" -d ";" pipe_data.csv           # pipe → 分号
csvformat -T data.csv                            # 逗号 → Tab
csvformat -d "|" data.csv                        # 逗号 → pipe
```

### 轴 2：引号转换

```bash
csvformat -U 0 data.csv                          # 输出不带引号
csvformat -U 2 data.csv                          # 所有列强制加引号
csvformat -Q "'" -q '"' single_quoted.csv        # 单引号 → 双引号
```

### 轴 3：行尾转换

```bash
csvformat -m $'\r\n' data.csv                    # Unix LF → Windows CRLF
csvformat -M $'\r\n' -m $'\n' windows.csv        # Windows CRLF → Unix LF
```

### 轴 4：跳过前导行

```bash
# 有些 CSV 文件前几行是注释或元数据
csvformat --skip-lines 3 data_with_comments.csv
```

---

## 场景组合

### 1. 老旧 pipe 文件 → 过滤 → 排序 → 渲染

```bash
csvformat -D "|" legacy_data.pipe \
  | csvgrep -c status -m "active" \
  | csvsort -c amount -r \
  | csvlook
```

### 2. Windows 编码问题：BOM 头 + CRLF

```bash
# Windows 导出的 CSV 经常有 BOM 头（\xEF\xBB\xBF）和 CRLF
sed '1s/^\xEF\xBB\xBF//' windows_export.csv \
  | csvformat -M $'\r\n' -m $'\n' \
  > clean.csv
```

---

## csvformat vs sed/awk 手动替换：什么时候用哪个

| 场景 | csvformat | sed/awk |
|------|-----------|---------|
| 改分隔符 | ✅ `-d ";"` | ⚠️ `sed 's/,/;/g'` 但会把引号内的逗号也改了 |
| 去引号 | ✅ `-U 0` | ⚠️ 需处理转义引号 |
| 改行尾 | ✅ `-m` | ✅ `sed 's/$/\r/'` 或 `dos2unix` |
| 跳过注释行 | ✅ `--skip-lines` | ✅ `tail -n +N` |

csvformat 相对 sed/awk 的核心优势：**它能正确区分引号内的分隔符和真正的列分隔符。** `sed 's/,/;/g'` 会把 `"张三,北京"` 变成 `"张三;北京"`——列本身没变，但你已经破坏了一个合法的 CSV 值。

---

## 新手踩坑总结

- **大写输入，小写输出。** `-D`/`-Q`/`-M` 是输入方言，`-d`/`-q`/`-m` 是输出方言。
- **`-T` 等价于 `-d $'\t'`。** 只是快捷方式。
- **`-U` 的数字是 0/1/2。** 0=不引号, 1=必要时引号（默认）, 2=全部引号。
- **不校验数据完整性。** 损坏的 CSV 输入 = 损坏的 CSV 输出。
- **csvformat 只做格式转换。** 它不帮你清洗数据——脏数据进去脏数据出来。
