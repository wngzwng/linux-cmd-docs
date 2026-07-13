# cat：不只是"看文件"，它是两个命令的伪装

> `cat` 是每个人第二个学会的 Linux 命令（第一个是 `ls`）。但大多数人只用它来"看文件内容"。其实 cat 有三个身份：文件浏览器、文件拼接器、文本转换器。而且——`cat file | grep xxx` 里那个 cat 大多数时候是不必要的。

## 语法骨架

```
cat  [选项]  [文件...]
     ──┬──   ──┬──
      控制     看什么
```

## 核心能力——三个身份

### 身份 1：文件浏览器

```bash
# 看一个文件
cat file.txt

# 看多个文件（按顺序拼接输出）
cat file1.txt file2.txt

# 带行号（-n：所有行 / -b：只对非空行）
cat -n file.txt
cat -b file.txt

# 打印不可见字符（-v：控制字符 / -t：Tab显示为^I / -e：行尾显示$）
cat -vet file.txt       # 看透文件里有没有隐藏的 \r \t 等
```

> 💡 `cat -vet` 是排查"为什么脚本跑不了"的神器——Windows 换行（`\r\n`）在 Linux 上会导致脚本报 `^M` 错误，`-e` 让行尾的 `\r` 现原形。

### 身份 2：文件拼接器（这才是 cat 名字的来源——con**cat**enate）

```bash
# 拼接多个文件
cat part1.log part2.log part3.log > full.log

# 拼接所有 .csv 文件（加表头去重技巧）
cat header.csv data*.csv > combined.csv

# 追加内容到文件
cat >> file.txt << EOF
new line 1
new line 2
EOF
```

### 身份 3：文本转换器

```bash
# -s：压缩连续空行（squeeze）
cat -s file_with_many_blanks.txt

# 从 stdin 读取（cat 不接文件名时从 stdin 读）
echo "hello" | cat
# 等价于直接 echo "hello"——这个 cat 是多余的（见下方 UUOC）
```

## ⚠️ UUOC：无用的 cat

```bash
# ❌ 多余的 cat——cat 读文件通过管道给 grep，grep 完全可以直接读
cat access.log | grep ERROR

# ✅ grep 可以直接读文件
grep ERROR access.log

# ❌ 又一个多余的 cat
cat file | wc -l

# ✅
wc -l < file
# 或
wc -l file
```

> 💡 **`cat file | command` 在 command 已经支持直接读文件时是多余的。** 这被称为 UUOC（Useless Use of Cat）。grep、sed、awk、wc、sort 都支持直接接文件名。但有一个例外：**当你需要多个文件的拼接作为输入时，cat 是必要的**——`cat *.log | grep ERROR` 和 `grep ERROR *.log` 的输出格式不同（后者会加上文件名前缀）。

## 反向操作：tac

```bash
tac file.txt    # 倒序输出——最后一行最先输出（cat 反过来）
```

## 踩坑清单

- **坑一：`cat file | grep` 的 cat 在大多数场景下多余** → grep/sed/awk/wc/sort 都直接支持文件名参数。
- **坑二：`cat` 大文件刷屏终端** → `cat 10GB.log` 会让终端卡死。大文件用 `less` 分页，或用 `head`/`tail` 看局部。
- **坑三：`cat` 读二进制文件会搞乱终端** → 二进制数据里的控制字符可能改变终端状态。用 `cat -v` 或 `xxd` 查看二进制。

## 什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 看小文件全部内容 | cat | 最直接 |
| 看大文件、滚动浏览 | less | cat 刷屏，less 分页 |
| 看文件开头几行 | head | `head -n 20 file` 比 `cat file \| head` 好 |
| 看文件结尾几行 | tail | 日志排查——`tail -f` 跟踪文件变化 |
| 带语法高亮的查看 | `bat` | cat 的现代替代品（语法高亮 + 行号 + Git 集成） |

---

> **核心观点：** cat 真正的名字是 con**cat**enate（拼接）。`cat file` 只是"拼接一个文件然后输出"的特殊情况。记住两个最实用的选项：**`-n`（加行号，快速定位）** 和 **`-vet`（排查隐藏字符，调试脚本）**。另外——**在管道里用 cat 之前，确认一下右边那个命令是不是本来就能直接读文件。**
