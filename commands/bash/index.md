# 为什么 bash 语法很"简单"，但大多数人总在同样的坑里摔倒？

> bash 的语法概念一只手数得过来——变量、条件、循环、函数、重定向。真正让人头疼的不是语法本身，而是它的**隐式行为**：分词、通配符展开、子 shell、引号规则。理解了这四个隐式行为，bash 就从"玄学"变成"工具"。

## 零、理解 bash 的角色

bash 做两件事：

1. **交互式命令执行器**：你敲命令，它解析、展开、执行
2. **脚本语言**：`.sh` 文件里的程序

大多数人从 1 开始，在 2 上踩坑——因为脚本里的行为有些和交互式不一样（比如 `alias` 默认不展开、`$1` 在脚本里有值但在交互式里是空的）。

## 一、变量和引号——90% 的 bash bug 源头

### 赋值：等号两边不能有空格

```bash
name="Alice"      # ✅
name = "Alice"    # ❌ bash 把 name 当命令执行
```

### 使用变量：$var 或 ${var}

```bash
echo $name
echo "${name}"    # 养成加引号的习惯
```

### 为什么加引号？

```bash
file="my document.txt"
rm $file          # ❌ rm 看到两个参数：my 和 document.txt
rm "$file"        # ✅ rm 看到一个参数：my document.txt
```

核心原则：**变量引用永远加双引号，除非你明确需要分词（word splitting）。**

### 单引号 vs 双引号

```bash
# 单引号：一切字面量，不展开变量，不解释转义
echo '$USER is here'     # → $USER is here

# 双引号：展开变量，解释部分转义
echo "$USER is here"     # → admin is here

# 无引号：展开变量 + 分词 + 通配符展开（通常不是你想要的）
echo $USER is here       # → admin is here（碰巧一样，多空格就露馅了）
```

> 经验法则：**awk/sed 程序用单引号（防 shell 吃掉 `$` 和 `\`）；变量引用用双引号；字面量固定字符串随便。**

## 二、条件判断——`[ ]` vs `[[ ]]` vs `(( ))`

```bash
# [ ] = test 命令的别名（POSIX 兼容，但坑多）
if [ "$a" = "$b" ]; then    # 字符串比较
if [ "$a" -eq "$b" ]; then  # 数字比较
# ⚠️ [ ] 里变量不引号会在为空时报语法错误

# [[ ]] = bash 扩展（推荐！更安全，功能更多）
if [[ $a == $b ]]; then     # == 和 = 都可以
if [[ $a =~ ^[0-9]+$ ]]; then  # 正则匹配
if [[ -z $var ]]; then      # 检查是否为空（即使 var 没引号也安全）

# (( )) = 算术运算
if (( a > b )); then        # 数字比较，不需要 $
for (( i=0; i<10; i++ )); then
```

> 经验法则：**日常用 `[[ ]]`，算术用 `(( ))`，写 POSIX shell（dash/sh）时才用 `[ ]`。**

### 常用条件测试速查

```bash
[[ -f file ]]       # 文件存在且是普通文件
[[ -d dir ]]        # 目录存在
[[ -e path ]]       # 路径存在（不管类型）
[[ -z "$var" ]]     # 字符串为空
[[ -n "$var" ]]     # 字符串非空
[[ "$a" == "$b" ]]  # 字符串相等
[[ "$a" != "$b" ]]  # 字符串不等
```

## 三、循环——for 和 while 的两个经典模式

```bash
# for：遍历列表
for file in *.log; do
    echo "Processing $file"
    gzip "$file"
done

# for：C 风格
for ((i=1; i<=10; i++)); do
    echo "Line $i"
done

# while：逐行读文件（标准模式）
while IFS= read -r line; do
    echo "Got: $line"
done < file.txt
```

### ⚠️ while + pipe 的陷阱：管道右边在子 shell 里

```bash
count=0
cat file.txt | while read line; do
    ((count++))           # count 只在这个子 shell 里变了
done
echo $count               # → 0！（子 shell 里的变更丢失了）

# ✅ 解决方案：用进程替换
while read line; do
    ((count++))
done < <(cat file.txt)    # 或者直接 done < file.txt
```

## 四、函数——bash 里的"命令"

```bash
# 定义函数（两种写法）
myfunc() {
    local var="local only"    # local 避免污染全局
    echo "arg1=$1, arg2=$2, all=$@"
}

# 调用（像命令一样——不需要括号！）
myfunc hello world            # → arg1=hello, arg2=world, all=hello world
```

bash 函数的核心心智模型：**它就是一个自定义命令。** `$1 $2 $@ $#` 和脚本参数完全一致。`return` 返回退出码（0-255），用 `echo` 返回数据。

## 五、退出码和错误处理

```bash
# 每个命令执行完都有一个退出码：0=成功，非0=失败
grep "ERROR" app.log
echo $?    # 0 或 1

# &&（成功才继续）和 ||（失败才继续）
grep -q "healthy" /var/log/health.log && echo "OK" || echo "FAIL"
```

### set 选项——脚本开头就写

```bash
set -e          # 任何命令失败就退出脚本
set -u          # 使用未定义变量就报错
set -o pipefail # 管道里任何一个命令失败，整个管道算失败

# 脚本开头推荐写法
set -euo pipefail
```

## 六、重定向——不只是 `>` 和 `|`

```bash
# >  覆盖写入
# >> 追加写入
# <  从文件读
# 2> stderr 重定向
# &> stdout + stderr 一起重定向

# 经典组合
cmd > out.log 2>&1        # stdout 和 stderr 都写到同一个文件
cmd 2>&1 | grep ERROR     # stderr 也进管道（默认只有 stdout 进管道）

# /dev/null：丢弃输出
cmd > /dev/null 2>&1      # 完全静默

# Here Document（多行输入）
cat << 'EOF' > config.ini
[server]
port=8080
EOF
# ↑ 'EOF' 加引号 = 不展开变量；不加引号 = 展开 $VAR
```

## 七、常见反模式——每个都值得纠正

```bash
# ❌ 反模式 1：解析 ls 的输出
for file in $(ls *.log); do ... done
# ✅ ls 输出的文件名可能含空格换行，用 glob 直接展开
for file in *.log; do ... done

# ❌ 反模式 2：cat 给能读文件的命令
cat file | grep ERROR
# ✅ grep ERROR file

# ❌ 反模式 3：用 $? 逐个判断，而不是直接 if
grep "ERROR" file
if [ $? -eq 0 ]; then ...
# ✅ if grep -q "ERROR" file; then ...

# ❌ 反模式 4：用 backtick `cmd` 而不是 $(cmd)
files=`ls`
# ✅ files=$(ls)    # $( ) 支持嵌套，可读性更好

# ❌ 反模式 5：忘了引号
if [ $a = hello ]; then ...
# ✅ if [[ $a == hello ]]; then ...   # [[ ]] 里不引号也安全
# 或 if [ "$a" = "hello" ]; then ... # [ ] 里必须引号
```

## 八、脚本模板——开箱即用

```bash
#!/bin/bash
set -euo pipefail
# -e: 命令失败就退出
# -u: 使用未定义变量就报错
# -o pipefail: 管道中间失败也算失败

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    echo "Hello, ${USER:-world}"
}

main "$@"
```

## 九、踩坑清单

- **坑一：等号两边加空格** → bash 把变量名当命令执行。赋值永远紧贴等号：`name=value`。
- **坑二：变量不加引号** → 空格、通配符导致意外分词和展开。原则：用变量就加引号。
- **坑三：管道右边是子 shell，变量变更丢失** → 用进程替换 `< <(cmd)` 代替管道。
- **坑四：`[ ]` 和 `[[ ]]` 混用** → `[ ]` 里 `==` 和 `-eq` 的行为不同且需要引号保护。日常用 `[[ ]]`。
- **坑五：脚本没有 `set -e`，错误悄悄累积** → 一个命令失败后脚本继续执行，后续操作在错误的前提下进行。脚本开头写 `set -euo pipefail`。
- **坑六：`$?` 只看最后一个命令的退出码** → 管道 `cmd1 | cmd2` 的 `$?` 是 cmd2 的退出码，cmd1 失败被忽略。用 `set -o pipefail`。

## 十、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 简单脚本（几十行、管道组合） | bash | 到处都是，零依赖 |
| 复杂逻辑、数据结构、API 调用 | Python | bash 没有真正的数据结构，复杂逻辑可读性差 |
| 跨平台脚本（需保持 POSIX） | sh（dash） | bash 扩展在 Alpine/Debian minimal 上可能不存在 |
| JSON/YAML 处理 | `jq` / `yq` + bash | bash 内置不支持结构化数据 |
| 更现代、类型安全的 shell 脚本 | `zx`（Google）/ `xonsh` | 混合 shell 和 Python/JS 语法 |

---

> **核心观点：** bash 的语法并不复杂——它只有变量、条件、循环、函数、重定向五个核心概念。真正让人头疼的是它的**隐式行为**：分词、通配符展开、子 shell、引号规则。把变量加引号、用 `[[ ]]` 替代 `[ ]`、脚本开头写 `set -euo pipefail`——这三个习惯能消除 80% 的 bash 脚本 bug。
