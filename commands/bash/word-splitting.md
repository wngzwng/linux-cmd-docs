# bash 单词拆分——为什么 `$var` 有时候是一个词，有时候是三个词？

> 单词拆分（Word Splitting）是 bash 里最隐蔽的行为——它在你不知情的情况下把变量值按空格拆成多个参数。几乎所有"我的文件名明明是对的但脚本说找不到"的问题，根因都是它。

## 一、什么是单词拆分

```bash
var="hello world"
echo $var       # echo 收到两个参数：hello 和 world
echo "$var"     # echo 收到一个参数：hello world
```

bash 在展开 `$var`（不加引号）后，会扫描结果中的每个字符，根据 `IFS`（Internal Field Separator）把字符串切成多个单词。

## 二、IFS——决定拆分的"刀"

```bash
# IFS 默认值：空格、Tab、换行
echo "$IFS" | cat -vet   # →  ^I$（空格 + Tab + 换行）

# 修改 IFS（临时）
IFS=: read -r user pw uid gid name home shell < /etc/passwd

# 恢复 IFS（重要！）
OLDIFS="$IFS"
IFS=: read -r ... 
IFS="$OLDIFS"
```

```bash
# IFS 的不同值对拆分的影响
var="a:b:c"

IFS=:
echo $var    # → a b c（三个参数）

IFS=,
echo $var    # → a:b:c（一个参数，逗号不是分隔符）
```

## 三、什么时候会触发单词拆分

单词拆分只在**不加引号的变量展开**和**不加引号的命令替换**时发生：

```bash
var="a b c"

# 发生拆分
echo $var           # → a b c（拆成 3 个参数）
echo $(echo "$var") # → a b c（拆成 3 个参数）
for i in $var; do ... done  # 循环 3 次

# 不发生拆分（引号保护）
echo "$var"          # → a b c（1 个参数）
for i in "$var"; do ... done  # 循环 1 次

# 也不发生（这里是赋值，不是命令参数）
x=$var               # x 的值是 "a b c"（保留空格）
```

## 四、拆分后还会发生通配符展开

```bash
var="*.txt"
echo $var    # 先拆分为 *.txt（一个词），然后通配符展开成 a.txt b.txt ...
echo "$var"  # → *.txt（引号阻止了拆分和通配符展开）
```

> ⚠️ **不加引号的变量展开会依次经历：① 单词拆分（IFS）② 通配符展开（globbing）。** 两步都可能导致非预期的行为。

## 五、什么时候单词拆分是"有用的"

```bash
# 场景 1：遍历 CFLAGS（故意拆分）
CFLAGS="-O2 -Wall -Wextra"
for flag in $CFLAGS; do
    echo "flag: $flag"
done

# 场景 2：分割路径
OLDIFS="$IFS"; IFS=:
for dir in $PATH; do
    echo "$dir"
done
IFS="$OLDIFS"
```

但即使是这些场景，更好的做法往往是用数组：

```bash
# 用数组避免依赖 IFS
CFLAGS=(-O2 -Wall -Wextra)
for flag in "${CFLAGS[@]}"; do
    echo "flag: $flag"
done
```

## 六、踩坑清单

- **坑一：`$@` 和 `$*` 的拆分行为不同** → `"$@"` 每个参数独立引号（推荐，保留参数边界）；`"$*"` 合并成单一字符串（丢失边界）；不加引号的 `$@` 或 `$*` 都会经历拆分。
- **坑二：修改 IFS 忘了恢复** → 函数内用 `local IFS` 限定作用域：`local IFS=:`。
- **坑三：空变量不加引号时"消失"** → `$empty`（变量为空）展开后变成空，后续命令收到比预期少的参数。`"$empty"` 展开成空字符串，参数个数不变。
- **坑四：命令替换不加引号** → `result=$(cmd)` 的结果会被拆分。用 `result="$(cmd)"`。

---

> **核心观点：** 单词拆分的规则很简单——**IFS 里的字符会在不加引号的变量展开时切割字符串。** 大多数时候你不需要这个行为。默认策略：变量永远加引号。如果你有意使用单词拆分，一定在代码里注释说明。
