# bash 循环——for、while、until 的正确打开方式

> bash 有三种循环：`for`、`while`、`until`。大多数脚本只用一个模式——`for i in $(ls)`——但这个模式在文件名含空格时就会出 bug。搞懂每种循环的正确用法和它背后的子 shell 陷阱，循环代码就不会再翻车。

## 一、三种循环速览

```bash
# for-in：遍历列表
for item in a b c; do echo "$item"; done

# for-C：C 风格
for ((i=0; i<10; i++)); do echo "$i"; done

# while：条件为真时重复
while [[ $count -lt 10 ]]; do ((count++)); done

# until：条件为假时重复（while 的反面）
until [[ -f /tmp/ready ]]; do sleep 1; done
```

## 二、for-in 循环——遍历列表的正确姿势

### ❌ 最常见的错误写法

```bash
# ❌ 反模式：解析 ls 的输出
for file in $(ls *.log); do
    echo "$file"
done
# 文件名含空格或换行时，会被拆成多个"文件"。
# 而且 ls 默认有列格式化输出，不太适合程序解析。

# ❌ 反模式：解析 find 的输出（没用 -print0）
for file in $(find . -name '*.log'); do
    echo "$file"
done
```

### ✅ 正确写法

```bash
# ✅ 方式 1：直接用 glob（最简单、最安全）
for file in *.log; do
    echo "Processing $file"
    gzip "$file"
done

# ✅ 方式 2：find + while（处理子目录、换行文件名安全）
find . -name '*.log' -print0 | while IFS= read -r -d '' file; do
    echo "Processing $file"
done

# ✅ 方式 3：shopt -s globstar（bash 4+，递归通配符）
shopt -s globstar
for file in **/*.log; do
    echo "$file"
done
```

### 遍历多列数据

```bash
# 用 while read 逐行读取多列
while read -r name age city; do
    echo "$name is $age years old, from $city"
done < data.txt
```

## 三、for-C 循环——数字范围

```bash
# 正向
for ((i=0; i<5; i++)); do echo "$i"; done

# 反向
for ((i=5; i>0; i--)); do echo "$i"; done

# 步进
for ((i=0; i<=100; i+=10)); do echo "$i"; done

# 也可以这样（更简洁）
for i in {0..10..2}; do echo "$i"; done    # 0 2 4 6 8 10
for i in {1..5}; do echo "$i"; done        # 1 2 3 4 5
```

## 四、while 循环——条件驱动

```bash
# 计数
count=0
while (( count < 5 )); do
    echo "$count"
    ((count++))
done

# 等待文件出现
while [[ ! -f /tmp/ready ]]; do
    echo "Waiting..."
    sleep 2
done

# 重试——连接失败时最多重试 5 次
retry=0
while (( retry < 5 )); do
    if curl -sf https://api.example.com/health; then
        echo "OK"
        break
    fi
    ((retry++))
    sleep 3
done
```

## 五、until 循环——while 的镜像

```bash
# until = while !（直到条件为真才停止）
# 这两个等价：
until [[ -f /tmp/ready ]]; do sleep 1; done
while [[ ! -f /tmp/ready ]]; do sleep 1; done
```

## 六、循环控制——break 和 continue

```bash
for file in *.log; do
    [[ -s $file ]] || continue     # 跳过空文件
    [[ $file == "system.log" ]] && break   # 找到 system.log 就停
    echo "Processing $file"
done
```

## 七、管道中的 while——子 shell 陷阱

```bash
# ❌ 陷阱：管道右边的 while 在子 shell 里运行
count=0
cat file.txt | while read -r line; do
    ((count++))
done
echo "$count"   # → 0！子 shell 里修改的变量传不出来
```

```bash
# ✅ 解决：用进程替换（推荐）
count=0
while read -r line; do
    ((count++))
done < <(cat file.txt)
echo "$count"   # → 正确值

# ✅ 或者直接重定向
count=0
while read -r line; do
    ((count++))
done < file.txt
echo "$count"   # → 正确值
```

> ⚠️ **管道 `|` 的两边在各自的子 shell 中运行。** 右边 while 里修改的变量不会影响外部 shell。这是 bash 脚本里最难排查的 bug 之一——逻辑全对，但数据就是不对。

### 当管道不可避免——用命名管道或临时文件

```bash
# 如果必须用管道而又需要传递变量：
tmpfile=$(mktemp)
cmd1 | cmd2 > "$tmpfile"
result=$(<"$tmpfile")
rm "$tmpfile"
```

## 八、循环的性能优化

```bash
# ❌ 慢：循环里每次都 fork 子进程
for file in *.log; do
    gzip "$file"                # 每个文件都 fork 一次 gzip
done

# ✅ 快：一次处理多个文件
gzip *.log

# ❌ 慢：循环逐行追加
for ((i=0; i<1000; i++)); do
    echo "$i" >> output.txt     # 每次打开、写入、关闭文件
done

# ✅ 快：一次性重定向整个循环
for ((i=0; i<1000; i++)); do
    echo "$i"
done > output.txt               # 文件只打开一次
```

## 九、踩坑清单

- **坑一：`for i in $(ls)` 或 `for i in $(find)`** → 文件名含空格时炸裂。用 glob 或 `find -print0 | while read -d ''`。
- **坑二：管道右边的 while 变量传不出来** → 用进程替换 `< <(cmd)` 代替管道。
- **坑三：`for i in {1..$n}` 不展开** → 大括号展开在变量展开之前，`{1..$n}` 被当成字面量。用 `for ((i=1; i<=n; i++))`。
- **坑四：循环里频繁 fork 子进程导致 O(n) 性能** → 能用一次命令处理多个文件的，不要在循环里逐个 fork。
- **坑五：循环忘了 `break` 造成死循环** → while true 里必须有退出条件。不确定时加计数上限。

---

> **核心观点：** bash 循环的核心抉择只有一个：**遍历列表用 `for`，条件驱动用 `while`。** 但最重要的是记住管道里的子 shell 陷阱——`cmd | while` 里修改的变量出不来。用 `< <(cmd)` 或直接重定向 `< file` 替代。
