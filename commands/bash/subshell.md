# bash 子 shell——你不可见的"平行宇宙"

> 子 shell（subshell）是 bash 里最不容易察觉的陷阱。它在你不知情的情况下创建了一个独立的运行环境——变量修改、`cd` 目录切换在里面有效，出来就没了。管道、命令替换、括号分组——这三种最常见的操作都会悄悄启��子 shell。

## 一、什么是子 shell

子 shell 是当前 shell 的一个 fork 出来的子进程。它继承了父 shell 的所有变量和状态，但：

- **在子 shell 里修改变量——父 shell 不受影响**
- **在子 shell 里 cd——父 shell 目录不变**
- **在子 shell 里 exit——只退出子 shell，父 shell 继续**

```bash
# 验证
var="original"
(var="changed"; echo "$var")   # → changed（子 shell 内）
echo "$var"                     # → original（父 shell 没变）
```

## 二、五种创建子 shell 的场景

### 1. 括号分组 `( )`

```bash
(cd /tmp && pwd)     # 子 shell 里 cd 到 /tmp
pwd                  # 还在原地——cd 的影响只在括号内
```

### 2. 管道 `|`

```bash
count=0
echo -e "a\nb\nc" | while read line; do
    ((count++))
done
echo "$count"        # → 0！管道右边的 while 在子 shell 里
```

### 3. 命令替换 `$( )` 和反引号 `` ` ``

```bash
var="outer"
result=$(var="inner"; echo "$var")
echo "$result"       # → inner
echo "$var"          # → outer（子 shell 里的赋值没传出来）
```

### 4. 后台进程 `&`

```bash
(var="background") &
echo "$var"          # → 还是原来的值
```

### 5. 外部命令（非 builtin）的某些行为

外部命令本身就在子进程中运行——它不能修改当前 shell 的变量。只有 `source` 和 `.` 在当前 shell 中执行。

## 三、管道中的子 shell——最难排查的 bug

```bash
# ❌ 这个 while 循环修改变量后外部读不到
line_count=0
cat access.log | while read -r line; do
    ((line_count++))
done
echo "Total: $line_count"    # → Total: 0

# ❌ 即使加了 set -e，管道也暗藏杀机
set -e
false | true                  # false 失败了但脚本不退出！
# 因为管道的退出码看的是最后一个命令（true = 0）

# ✅ 解决 1：进程替换
line_count=0
while read -r line; do
    ((line_count++))
done < <(cat access.log)
echo "Total: $line_count"    # → Total: 1000 ✅

# ✅ 解决 2：直接重定向
while read -r line; do
    ((line_count++))
done < access.log

# ✅ 解决 3：bash 4.2+ 的 lastpipe
shopt -s lastpipe
# 管道最后一个命令在当前 shell 运行（需要关闭作业控制）
```

## 四、子 shell 也有用的时候

```bash
# 好处 1：隔离副作用（临时 cd，不影响外面）
(cd /tmp && tar -xf archive.tar)

# 好处 2：临时修改环境变量
(export PATH=/custom/bin:$PATH; ./build.sh)

# 好处 3：并行执行
(start_server && echo "Server ready") &
(start_worker && echo "Worker ready") &
wait
```

## 五、子 shell vs 子进程 vs source

```bash
./script.sh          # 子进程：新 bash 实例，变量不共享，exit 不影响父 shell
( commands )         # 子 shell：fork 当前 shell，继承所有状态但写时复制
source script.sh     # 当前 shell：直接在当前环境执行，变量和 cd 都共享
. script.sh          # 同上
```

## 六、踩坑清单

- **坑一：管道右边的循环修改变量，外面读不到** → 用进程替换 `< <(cmd)` 或直接重定向 `< file`。
- **坑二：`set -e` 在管道中不生效** → 管道的退出码看最后一个命令，中间失败被忽略。用 `set -o pipefail`。
- **坑三：`(cd /tmp && tar ...)` 想改变外部目录** → `cd` 只在括号内生效。用 `pushd /tmp && tar ... && popd`。
- **坑四：`echo "hello" | read myvar` 然后 `echo $myvar` 为空** → read 在管道右边的子 shell 里，变量传不出来。
- **坑五：命令替换 `$(cmd)` 里 `exit` 只退出子 shell** → 如果想在命令替换里出错时退出整个脚本，需要在外面检查 `$?`。

---

> **核心观点：** 子 shell 是 bash 里最隐蔽的平行宇宙。记住五个触发场景：**`( )` 括号分组、`|` 管道、`$( )` 命令替换、`&` 后台、外部命令。** 其中管道 + while 的组合是最常见的 bug 来源——永远用进程替换或重定向代替。
