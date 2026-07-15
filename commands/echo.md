# echo：输出文本的三个坑——`-n`、`-e` 和引号的陷阱

> `echo` 是每个人学的第一个命令——`echo "hello world"`。但它有几个行为坑：`-n` 不换行、`-e` 转义、不同 shell 实现不同——这些坑在脚本里能让你 debug 一下午。

## 语法骨架

```
echo  [选项]  [字符串...]
```

## 核心用法

```bash
# 输出文本
echo "hello world"

# 输出变量
echo "Current user: $USER"

# 输出到文件
echo "content" > file.txt

# 追加到文件
echo "more content" >> file.txt

# -n：不输出末尾换行
echo -n "Processing..."
echo "done"           # → Processing...done（同一行）

# -e：解释转义字符（⚠️ BSD echo 默认就解释，Linux 需要 -e)
echo -e "line1\nline2\nline3"
```

## 跨平台陷阱：BSD echo vs GNU echo vs shell builtin

```bash
# macOS (BSD echo)：默认解释 \n \t 等转义
echo "hello\nworld"        # → hello (换行) world

# Linux (GNU echo)：默认不解释，需要 -e
echo "hello\nworld"        # → hello\nworld（字面量！）
echo -e "hello\nworld"     # → hello (换行) world

# bash 内建 echo：行为取决于 shell 的 xpg_echo 选项
# 结论：脚本里不要依赖 echo 的转义行为——用 printf！
```

> ⚠️ **脚本里需要可靠行为时，不要用 echo，用 `printf`。** `printf '%s\n' 'hello world'` 在所有系统上行为一致，不依赖 shell 版本或操作系统。

## echo 常见用法速查

```bash
# 不换行输出（脚本里重要！）
echo -n "Enter name: "; read name

# 多行输出（推荐用 printf 代替）
printf "line1\nline2\nline3\n"

# 写配置文件（推荐用 cat << EOF 代替）
cat << 'EOF' > config.conf
[server]
port=8080
host=0.0.0.0
EOF

# 生成空白行
echo ""
```

## 踩坑清单

- **坑一：`echo` 的转义行为在不同系统上不同** → 脚本里永远用 `printf`。
- **坑二：`echo $VAR` 如果 VAR 未定义或为空，只输出空行** → 不是 bug，但有歧义。用 `echo "VAR=$VAR"` 更清晰。
- **坑三：`echo` 不能输出以 `-` 开头的内容** → `echo -n` 被当成选项。用 `printf '%s\n' '-n'` 或 `echo -- -n`（GNU 版 `--` 终止选项解析）。

---

> **核心观点：** echo 不需要学——你早就会了。但要知道它的两个替代者：**`printf`**（脚本里做格式化输出，行为跨平台一致）和 **`cat << EOF`**（写多行内容到文件）。echo 适合交互式随手用，不适合写在脚本里。
