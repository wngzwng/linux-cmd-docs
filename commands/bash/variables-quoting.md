# bash 变量和引号——90% 的 bash bug 源头

> bash 脚本里最隐蔽的 bug 不是逻辑错误，而是一个没加引号的变量、一个等号旁边的空格、一个用错的引号类型。这一篇把变量和引号的规则彻底讲透。

## 一、变量赋值——等号两边绝对不能有空格

```bash
name="Alice"      # ✅ 正确
name = "Alice"    # ❌ bash 把 name 当成命令执行："name: command not found"
name= "Alice"     # ❌ 空值赋值 + 把 "Alice" 当成命令执行
```

这是 bash 最反直觉的语法规则——大多数语言里空格是无害的，但在 bash 里 `name = value` 和 `name=value` 是两件完全不同的事。

### 变量命名

```bash
# ✅ 字母、数字、下划线（不能以数字开头）
my_var="ok"
_private="ok"

# ❌
1var="no"          # 数字开头不合法
my-var="no"        # 连字符不合法，bash 理解为 my 减 var
```

### 一次赋值多个变量

```bash
a=1 b=2 c=3          # ✅ 同行赋值
readonly PI=3.14     # 只读变量（不可修改）
declare -i count=0   # 整数变量
export PATH           # 导出为环境变量（子进程可见）
```

## 二、使用变量——`$var` 和 `${var}`

```bash
name="Alice"
echo $name         # Alice
echo ${name}       # Alice（推荐写法）

# ${} 的必要场景：变量名后紧跟其他字符
echo "${name}smith"    # Alicesmith ✅
echo "$namesmith"      # 空（bash 找的是 $namesmith 这个变量）
```

## 三、引号规则——核心中的核心

```bash
# 无引号：变量展开 → 单词拆分 → 通配符展开
# 双引号：变量展开，不拆分，不通配
# 单引号：一切字面量，什么都不做

var="hello world"
echo $var       # hello world（拆成两个参数传给 echo）
echo "$var"     # hello world（一个参数）

# 差异体现在这里：
file="my file.txt"
touch "$file"       # ✅ 创建一个文件
touch $file         # ❌ 创建了两个文件：my 和 file.txt
```

### 单引号 vs 双引号

```bash
echo '$USER is here'     # → $USER is here（字面量）
echo "$USER is here"     # → admin is here（变量展开）

# 双引号里需要字面量 $ 时用转义
echo "The cost is \$100"  # → The cost is $100
```

### 原则：变量引用永远加双引号

```bash
# ✅ 日常写法
echo "$file"
rm "$file"
cat "$file" | grep "$pattern"

# ❌ 唯一不加引号的场景：你需要单词拆分
for flag in $CFLAGS; do ... done   # 把 -O2 -Wall 拆成两个参数
```

> ⚠️ **不加引号的变量会经历两步处理：单词拆分 + 通配符展开。** `*.txt` 如果目录下有 `a.txt b.txt`，不加引号时会被展开成 `a.txt b.txt`。加引号后保持 `*.txt` 原样。

## 四、变量展开的高级玩法

### 默认值——变量不存在时用默认值

```bash
# ${var:-default}：var 未设置或为空时用 default（最常用）
echo "Hello, ${USER:-guest}"     # USER 有值就用，没有就是 guest

# ${var:=default}：不仅返回默认值，还赋值给 var
: ${PORT:=8080}                  # PORT 没设置就设为 8080，: 是空命令

# ${var:?message}：var 没设置就报错退出
: ${CONFIG:?config file required}

# ${var:+value}：var 有值时用 value，否则空
echo "${DEBUG:+debug mode on}"   # DEBUG 有值才输出
```

### 字符串操作

```bash
path="/usr/local/bin/script.sh"

# 长度
echo ${#path}                    # 27

# 截取子串
echo ${path:5}                   # local/bin/script.sh（从第 5 个字符开始）
echo ${path:5:5}                 # local（从第 5 开始，取 5 个）

# 删除前缀
echo ${path#*/}                  # usr/local/bin/script.sh（删除最短匹配 */）
echo ${path##*/}                 # script.sh（删除最长匹配 */）

# 删除后缀
echo ${path%.*}                  # /usr/local/bin/script（删除最短匹配 .*）
echo ${path%%.*}                 # /usr/local/bin/script（删除最长匹配 .*）

# 替换
echo ${path/local/global}        # /usr/global/bin/script.sh（替换第一个）
echo ${path//\//:}              # :usr:local:bin:script.sh（替换所有 / 为 :）
```

### `${!var}`——间接引用

```bash
name="USER"
echo "${!name}"       # 等价于 echo "$USER"——取 name 的值作为变量名再展开
```

## 五、特殊变量速查

```bash
$0          # 脚本名称
$1 ~ $9     # 第 1 到第 9 个参数
${10}       # 第 10 个参数（必须用大括号）
$#          # 参数个数
$@          # 所有参数（每个独立引号："$1" "$2" ...）
$*          # 所有参数（合在一起："$1 $2 ..."）
$?          # 上一个命令的退出码
$$          # 当前 shell 的 PID
$!          # 最后一个后台进程的 PID
```

## 六、踩坑清单

- **坑一：等号旁边加空格** → `name = "Alice"` 会被当成三个词：`name`（命令）、`=`（参数）、`Alice`（参数）。永远紧贴等号。
- **坑二：变量值含空格不加引号** → `rm $file` 在文件名含空格时毁天灭地。99% 的场景双引号。
- **坑三：`$@` 和 `$*` 的区别** → `"$@"` 每个参数独立引号（推荐），`"$*"` 所有参数被合成一个字符串。脚本里传参永远用 `"$@"`。
- **坑四：单引号里变量不展开** → `'$HOME/log'` 是字面量。需要展开用双引号。
- **坑五：`export` 只对子进程可见，不影响父 shell** → 脚本里 `export FOO=bar` 只在脚本内和它的子进程有效。

---

> **核心观点：** 变量和引号是 bash 的基石。记住三条铁律：**① 赋值：`name=value`，不等号旁边无空格 ② 引用：永远 `"$var"` 双引号 ③ 选择：单引号字面量，双引号展开变量**。90% 的 bash bug 都是这三条之一没遵守。
