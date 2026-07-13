# bash 通配符展开——`*.txt` 为什么会变成 100 个文件名？

> 通配符展开（Globbing / Pathname Expansion）是 bash 在单词拆分之后自动执行的操作——它把 `*`、`?`、`[...]` 这些模式替换成匹配的文件名列表。不理解这一步，你的脚本在某个目录下的行为就是不可预测的。

## 一、什么是通配符展开

```bash
ls *.txt
# bash 在执行 ls 之前，先把 *.txt 替换成当前目录下所有匹配的 .txt 文件名
# 然后 ls 收到的是展开后的文件名列表，根本不是 *.txt 这个字面量
```

通配符展开发生在 bash 的命令解析过程中——目标命令（ls、rm）永远不会看到 `*`。

## 二、通配符语法

```bash
*        # 匹配任意数量字符（不含 /）
?        # 匹配单个字符（不含 /）
[abc]    # 匹配 a、b、c 中任一个
[a-z]    # 匹配 a 到 z 中任一个
[!abc]   # 匹配不是 a、b、c 的任一个（POSIX 用 [^abc]）

# 组合
ls *.log              # 所有 .log 文件
ls file-?.txt         # file-1.txt, file-a.txt 等
ls report[0-9].txt    # report0.txt ~ report9.txt
ls [!0-9]*.txt        # 不以数字开头的 .txt 文件
```

## 三、展开的时机和层级

```bash
# 1. 大括号展开（最先）：{a,b,c} → a b c
echo file-{a,b,c}.txt     # file-a.txt file-b.txt file-c.txt

# 2. 变量展开：$var → value
# 3. 命令替换：$(cmd) → output
# 4. 单词拆分（IFS）
# 5. 通配符展开（最后）：*.txt → a.txt b.txt

# 注意：变量展开出来的 * 也会经历通配符展开！
var="*.txt"
echo $var          # → a.txt b.txt（如果目录下有 .txt 文件）
echo "$var"        # → *.txt（引号阻止了通配符展开）
```

## 四、没有匹配时的行为

```bash
# ⚠️ 默认行为：如果没有匹配，保留原始模式（字面量）
ls *.xyzzy          # 如果没有 .xyzzy 文件 → ls: *.xyzzy: No such file or directory
                    # *.xyzzy 被当成字面量传给了 ls！

# ✅ 改变行为：shopt -s nullglob（没有匹配时替换为空）
shopt -s nullglob
for f in *.xyzzy; do
    echo "$f"       # 循环体不会执行（*.xyzzy 展开为空）
done

# ✅ 改变行为：shopt -s failglob（没有匹配时报错退出）
shopt -s failglob
cat *.xyzzy         # → bash: no match: *.xyzzy
```

> 💡 脚本里推荐 `shopt -s nullglob`。默认行为（保留字面量 `*.xyzzy`）几乎是 bug 的温床——文件不存在时命令收到的是一个无效文件名。

## 五、`**` 递归通配符

```bash
shopt -s globstar

# 递归匹配所有 .log 文件
echo **/*.log

# 匹配所有目录（末尾 / 只匹配目录）
echo **/
```

## 六、控制通配符展开

```bash
# 临时禁用（用引号）
echo "*.txt"        # → *.txt（字面量）

# 全局禁用
set -f              # 禁用通配符展开
set +f              # 恢复

# 或者用反斜杠转义
echo \*.txt          # → *.txt
```

## 七、extglob——扩展通配符

```bash
shopt -s extglob

# ?(pattern)    匹配 0 或 1 次
# *(pattern)    匹配 0 或多次
# +(pattern)    匹配 1 或多次
# @(pattern)    匹配恰好 1 次
# !(pattern)    匹配不满足模式的

ls !(*.log)          # 所有不是 .log 结尾的文件
ls *.+(jpg|png|gif)  # 所有图片文件
```

## 八、踩坑清单

- **坑一：不加引号的变量包含 `*` 会被展开** → `pattern="*.txt"; echo $pattern` 在目录下有 txt 文件时输出文件名列表，不是 "*.txt"。用 `"$pattern"`。
- **坑二：默认 nullglob 不开启** → `for f in *.nope` 在没有匹配时循环体会执行一次（`f=*.nope`）。用 `shopt -s nullglob`。
- **坑三：`*` 不匹配隐藏文件（`.` 开头）** → `.gitignore` 不会被 `*` 匹配到。要匹配隐藏文件用 `.*`（但这也会匹配 `.` 和 `..`）。
- **坑四：方括号 `[abc]` 内大部分字符都是字面量** → `[!abc]` 和 `[^abc]` 都表示"排除 a/b/c"，但 `!` 在某些 bash 版本里行为不同。跨版本用 `[^abc]`。
- **坑五：命令行参数过长** → `rm *.log` 在某个目录下有十万个 .log 文件时可能超过 `ARG_MAX`。用 `find -delete` 或 `xargs`。

---

> **核心观点：** 通配符展开是 bash 在命令执行前自动做的文件名匹配。理解它发生的时机（单词拆分之后）和默认行为（无匹配时保留字面量），就知道什么时候该加引号、什么时候该开 `nullglob`。脚本开头写 `shopt -s nullglob` 是个好习惯。
