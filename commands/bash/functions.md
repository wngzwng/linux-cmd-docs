# bash 函数——你的第一个"自定义命令"

> bash 函数的心智模型极其简单：**它就是一个你自己写的命令。** 参数用 `$1 $2 ...`，退出码用 `return`，输出用 `echo`。理解了这一点，函数就不再神秘。

## 一、定义和调用

```bash
# 定义（两种写法等价）
myfunc() {
    echo "Hello from myfunc"
}

function myfunc {
    echo "Hello from myfunc"
}

# 调用——像普通命令一样，不需要括号！
myfunc
myfunc arg1 arg2 "arg 3"
```

> ⚠️ **调用函数时不要加括号。** `myfunc(args)` 是 Python/JS 的习惯，在 bash 里 `myfunc()` 是定义函数，`myfunc (args)` 是语法错误。

## 二、参数——`$1 $2 $@ $#`

```bash
greet() {
    echo "Hello, $1!"
    echo "You passed $# arguments: $@"
}

greet Alice       # → Hello, Alice!
                  # → You passed 1 arguments: Alice
greet Alice Bob   # → Hello, Alice!
                  # → You passed 2 arguments: Alice Bob
```

函数的参数系统和脚本参数完全一致：

```bash
$1 ~ $9    # 第 1 到第 9 个参数
${10}      # 第 10 个及以上的参数
$#         # 参数个数
$@         # 所有参数（"$1" "$2" ...）
$*         # 所有参数合成一个字串
$0         # 仍然指向脚本名（不是函数名！）
```

## 三、返回值——退出码 vs 输出

```bash
# return：返回退出码（0-255，0=成功）
is_even() {
    (( $1 % 2 == 0 )) && return 0 || return 1
}

if is_even 10; then
    echo "even"
fi

# echo：返回数据（被调用方用 $( ) 捕获）
get_sum() {
    local result=$(( $1 + $2 ))
    echo "$result"
}

total=$(get_sum 3 5)
echo "$total"   # → 8
```

> 💡 **bash 函数不能像 Python 那样 `return value`。** `return` 只返回退出码。要向调用者返回数据，用 `echo`（调用方用 `$(func args)` 捕获），或者用全局变量。

## 四、局部变量——`local` 避免污染全局

```bash
# ❌ 没有 local：函数内变量是全局的——污染外部作用域
count=0
increment() {
    count=$((count + 1))    # 写的是全局 count
}

# ✅ 用 local：变量作用域限定在函数内
process_file() {
    local file="$1"          # 局部变量
    local count=0            # 局部变量
    while read -r line; do
        ((count++))
    done < "$file"
    echo "$count"            # 返回行数
}
```

> 💡 **函数内所有变量都应该用 `local` 声明，除非你确定需要修改全局变量。** 这是 bash 函数最容易被忽视的规则。

## 五、函数库——`source` 引入

```bash
# lib.sh
log_info()  { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
die()       { log_error "$*"; exit 1; }

# main.sh
source lib.sh    # 或 . lib.sh
log_info "Starting..."
die "Config not found"   # 打印错误并退出
```

## 六、常见模式

### 模式 1：参数校验

```bash
require_args() {
    local required=$1
    shift
    if (( $# < required )); then
        echo "Usage: $0 requires at least $required arguments" >&2
        return 1
    fi
}

mycmd() {
    require_args 2 "$@" || return 1
    echo "Processing $1 and $2"
}
```

### 模式 2：默认参数

```bash
connect() {
    local host="${1:-localhost}"
    local port="${2:-8080}"
    echo "Connecting to $host:$port"
}

connect              # → localhost:8080
connect db-server    # → db-server:8080
connect db 5432      # → db:5432
```

### 模式 3：多值返回（用全局变量）

```bash
get_stats() {
    local file="$1"
    stats_lines=$(wc -l < "$file")
    stats_bytes=$(wc -c < "$file")
}

get_stats /etc/hosts
echo "lines=$stats_lines, bytes=$stats_bytes"
```

### 模式 4：包装命令（前置检查 + 后置处理）

```bash
# 在指定目录下执行命令，失败时回滚
in_dir() {
    local dir="$1"
    shift
    (cd "$dir" && "$@") || return 1
}

in_dir /var/log ls -la
```

## 七、踩坑清单

- **坑一：函数内修改全局变量没加 `local`** → 无意中覆盖外部同名变量。养成每个函数变量都用 `local` 的习惯。
- **坑二：`return` 不能返回字符串数据** → `return "hello"` 不是返回字符串，是返回非 0 退出码。用 `echo` 输出数据，调用方用 `$( )` 捕获。
- **坑三：管道里的函数在子 shell 运行** → `func | while read` 里的 func 修改不了外部变量。
- **坑四：函数名和已有命令冲突** → 定义 `ls() { ... }` 会覆盖 `/bin/ls`。`command ls` 可以调用原始命令。
- **坑五：`$0` 在函数里仍然是脚本名** → 没有内置变量能获取函数名。需要函数名用 `${FUNCNAME[0]}`。

---

> **核心观点：** bash 函数 = 自定义命令。**参数用 `$1 $2`，退出码用 `return`，数据用 `echo` 输出 + `$( )` 捕获。** 做到这三件事再加一条"所有变量用 `local`"，你的函数就足够稳健了。
