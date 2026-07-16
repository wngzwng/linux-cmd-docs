
# csvformat：CSV 方言互转——改分隔符、引号、行尾

不同系统对 CSV 的「方言」要求不同：Excel 要逗号分隔，某些欧洲系统要分号，数据库导出的可能是 tab 分隔或 pipe 分隔。`csvformat` 让你在不同方言之间自由转换，不需要重新生成。

---

## 场景引入

你从某个老旧系统导出了一个 pipe 分隔、双引号括住的 CSV：

```
"id"|"name"|"amount"
"1"|"张三"|"500"
"2"|"李四"|"300"
```

要把它转成标准的逗号分隔 CSV 给 Excel 打开：

```bash
csvformat -D "|" old_data.csv
```

输出：

```
id,name,amount
1,张三,500
2,李四,300
```

连多余的引号都去掉了。

---

## 核心能力

### 改分隔符：`-D`（输入方） / `-d`（输出方）

```bash
# 输入是 pipe 分隔，输出为标准逗号
csvformat -D "|" data.pipe

# 输出改为 tab 分隔
csvformat -T data.csv                # 等效于 -d $'\t'
csvformat -d ";" data.csv            # 输出用分号分隔（欧洲版 Excel）
```

### 改引号风格：`-Q`（输入方） / `-q`（输出方）

```bash
# 去掉所有引号
csvformat -U 0 data.csv              # 输出不加引号
csvformat -U 1 data.csv              # 输出只对需要的地方加引号（默认）
csvformat -U 2 data.csv              # 输出每列都加引号
```

### 改行尾：`-M`（输入方） / `-m`（输出方）

```bash
csvformat -m $'\r\n' data.csv        # Unix LF → Windows CRLF
```

### 跳过行（`--skip-lines`）

```bash
csvformat --skip-lines 3 data.csv    # 跳过前 3 行（有些文件开头有注释）
```

---

## 管道中的经典用法

```bash
# pipe → 逗号 → 选列 → 标准差格式
csvformat -D "|" pipe_data.txt | csvcut -c name,amount | csvformat -T

# MySQL 导出的 \N null → 空白 → 标准 CSV
sed 's/\\N//g' mysql_export.csv | csvformat -U 1
```

---

## ⚠️ 雷区

### `-D` vs `-d`：大写是输入，小写是输出

几乎所有 csvkit 命令都是大写选项控制输入格式，小写控制输出格式。`csvformat` 中记混了很容易出 bug。

### csvformat 不验证数据完整性

它只是改了格式，不会告诉你转换后是否还符合 CSV 标准。如果原始数据里有未转义的逗号，csvformat 不会帮你修。
