# bash 退出码和错误处理——脚本为什么在错的地方继续跑？

> 很多脚本的失败不是逻辑错了，而是"上一个命令失败了，脚本没停，继续在错误的前提下执行了后面的操作"。bash 默认行为是忽略中间命令的失败——除非你显式告诉它停下来。

## 一、退出码——每个命令的"成绩单"

```bash
# 每个命令执行完都会设置 $?
grep "ERROR" app.log
echo $?    # 0 = 找到了（成功）
           # 1 = 没找到（失败——但对 grep 来说是正常结果）
           # 2 = 真正的错误（文件不存在等）
```

规则：**0 = 成功，非 0 = 失败。** 但各命令对"失败"的定义不同——grep 的 "没找到"返回 1，diff 的 "文件不同"也返回 1——这些不是"异常"。

### 常用命令的退出码约定

```bash
# 0 -> 一切正常
# 1 -> 正常完成但结果为"否"（grep 没匹配、diff 发现不同、test 条件为假）
# 2 -> 使用错误（参数错误、文件不存在）
# 126 -> 命令不可执行（权限问题）
# 127 -> 命令未找到
# 128+N -> 被信号 N 终止（如 130 = SIGINT）
```

## 二、`&&` 和 `||` ——条件链

```bash
# &&：前一个成功（退出码=0）才执行后一个
mkdir -p /tmp/build && cd /tmp/build && cmake .. && make

# ||：前一个失败（退出码≠0）才执行后一个
grep -q "pattern" file || echo "Not found"

# 组合：三元运算
grep -q "healthy" /var/log/health.log && echo "OK" || echo "FAIL"
```

> ⚠️ `cmd1 && cmd2 || cmd3` 不是真正的 `if-else`。如果 `cmd2` 失败了，`cmd3` 也会执行。真三元用 `if then else`。

## 三、`set` 选项——让脚本在失败时停下来

```bash
set -e          # 任何命令失败（非0退出）就立即退出脚本
set -u          # 使用未定义的变量时退出（防止拼写错误的变量）
set -o pipefail # 管道中任何命令失败，整个管道算失败
set -x          # 执行前打印每个命令（调试用）

# 脚本开头推荐写法
set -euo pipefail
```

### `set -e` 的例外（容易踩的坑）

```bash
# set -e 在这些情况不会触发退出：
# 1. if/while/until 的条件部分
if grep "error" file; then ...    # grep 返回 1 不会退出，这合理

# 2. && 或 || 的左边
grep "error" file || true          # 失败也被 || 捕获了

# 3. 管道中的非最后一个命令（除非 set -o pipefail）
false | true                       # false 失败但管道退出码看 true（0）

# 4. 子 shell 里的失败
( false )                         # 外面不会退出
```

### `set -o pipefail` 的必要性

```bash
set -e
# 没有 pipefail——管道的退出码看最后一个命令
grep "ERROR" app.log | wc -l      # grep 失败（返回1），但 wc 成功（0）
echo "Still running"              # ← 脚本继续了！危险

set -eo pipefail
# 有了 pipefail——管道中任何一个失败，整体算失败
grep "ERROR" app.log | wc -l      # grep 失败 → 脚本退出 ✅
```

## 四、trap——优雅的清理和错误捕获

```bash
# EXIT：脚本退出时执行（正常退出 + 错误退出都触发）
trap 'rm -f "$tmpfile"' EXIT

# ERR：任何命令失败时执行（配合 set -e 使用）
trap 'echo "Error at line $LINENO"' ERR

# SIGINT/SIGTERM：被中断时执行
trap 'echo "Interrupted"; exit 1' INT TERM

# 完整示例：
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"; echo "Cleaned up"' EXIT
trap 'echo "Script failed at line $LINENO" >&2' ERR

# ... 使用 tmpfile 做任何事情 ...
# 即使中途失败，trap 也会清理临时文件
```

## 五、错误处理模式

### 模式 1：关键命令手动检查

```bash
if ! cd /important/dir; then
    echo "Cannot cd to /important/dir" >&2
    exit 1
fi
```

### 模式 2：`||` 快速兜底

```bash
cd /important/dir || { echo "Failed to cd" >&2; exit 1; }
```

### 模式 3：包装函数

```bash
die() {
    echo "[FATAL] $*" >&2
    exit 1
}

cd /important/dir || die "Cannot cd"
[[ -f config.ini ]] || die "config.ini not found"
```

### 模式 4：记录错误行号

```bash
set -e
trap 'echo "Error at line $LINENO: $BASH_COMMAND" >&2' ERR
```

## 六、`$?` 的正确使用和避免

```bash
# ❌ 反模式：把 $? 存起来再判断
grep "error" file
status=$?
if [[ $status -eq 0 ]]; then ...

# ✅ 直接用 if
if grep -q "error" file; then ...

# $? 必要的时候：想知道具体退出码（不只是 0/1）
some_command
case $? in
    0) echo "success" ;;
    1) echo "not found" ;;
    2) echo "invalid usage" ;;
    *) echo "unknown error" ;;
esac
```

## 七、踩坑清单

- **坑一：脚本没有 `set -e`，一个命令失败后继续跑** → 后续操作基于错误的前提，后果灾难性。每个脚本开头写 `set -euo pipefail`。
- **坑二：`set -e` 在管道中不生效（没有 `-o pipefail`）** → 管道中间的失败会被静默吞掉。`set -eo pipefail`。
- **坑三：`var=$(false)` 不触发 `set -e`** → 命令替换内部即使失败，外层也不会退出（因为退出码被赋值吞掉了）。
- **坑四：检查 `$?` 太晚了** → `echo $?` 本身会覆盖 `$?`（echo 总是返回 0）。必须在一行内使用：`cmd; echo $?`。
- **坑五：在 `set -e` 的脚本里用 `let` 或 `(( ))` 要小心** → `((count++))` 在 count=0 时返回 1（算术语义上 0=false），可能触发退出。用 `((count++)) || true` 抑制。

---

> **核心观点：** bash 错误处理的核心只有两样：**`set -euo pipefail`** 让脚本在出错时停下来，**`trap`** 让脚本在停下来之前做好清理。这两样是所有生产级 bash 脚本的底线。
