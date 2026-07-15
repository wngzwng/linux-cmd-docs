
# tr：单字符替换、删除、压缩——管道链里的无名英雄

如果你问"tr 是干什么的"，很多人答不上来。但如果你问"怎么把日志里的 Windows 换行符 `\r` 去掉"，大家会说："那个好像是 tr 干的。"

tr 就是那种"存在感很低，但关键时刻无可替代"的命令。它不做复杂处理——它只做一件事：**按字符一对一地替换或删除。** 但这件事 sed 也能做——为什么还需要 tr？因为 tr 更快、更简单、而且在某些场景下 sed 反而麻烦。

---

## 场景引入：从 Windows 传过来的脚本跑不了

你从同事那里拿到一个在 Windows 上写的 `.sh` 脚本，传到 Linux 服务器上执行：

```bash
./deploy.sh
# bash: ./deploy.sh: /bin/bash^M: bad interpreter: No such file or directory
```

`^M` 是什么鬼？它就是 Windows 的换行符 `\r\n` 中的 `\r`。Linux 只认 `\n`，多出来的 `\r` 被当成了文件名的一部分。

```bash
# 一行搞定
tr -d '\r' < deploy.sh > deploy_fixed.sh

# 或者原地修复
cat deploy.sh | tr -d '\r' > deploy.sh
```

sed 也能做到：`sed -i 's/\r//g' deploy.sh`。但 tr 的语法明显更简洁——因为它就是为了这种"字符级清理"而生的。

---

## 核心概念：tr 不读文件，只处理标准输入

tr 可能是 Linux 里最特殊的文本处理命令——**它不接受文件名作为参数。** 你只能通过管道或重定向把数据喂给它。

```bash
# ✅ 正确：通过管道或重定向
echo "hello" | tr 'a-z' 'A-Z'
tr 'a-z' 'A-Z' < file.txt

# ❌ 错误：tr 不接受文件名
tr 'a-z' 'A-Z' file.txt    # 不报错，但 file.txt 被当成字符串处理了
```

> ⚠️ 这是 tr 最容易踩的坑：`tr 'a-z' 'A-Z' file.txt` 不会报错，但 `file.txt` 被当成普通字符串参数，不是文件名。tr 只有两个集合参数和选项。

---

## 核心能力逐层拆解

### 1. 字符替换（tr 的主业）

```bash
# 大小写转换
echo "Hello World" | tr 'a-z' 'A-Z'      # HELLO WORLD
echo "Hello World" | tr 'A-Z' 'a-z'      # hello world

# 自定义映射
echo "abc123" | tr 'abc' 'XYZ'           # XYZ123（a→X, b→Y, c→Z）
echo "abc" | tr 'abc' '12'               # 122（c 没有映射，复用最后一位）

# 把换行替换成空格（把多行变成一行）
cat file.txt | tr '\n' ' '               # 所有行用空格连在一起
```

### 2. 删除字符 `-d`

```bash
# 删除 Windows 换行符
tr -d '\r' < windows_file.txt

# 删除所有数字
echo "abc123def456" | tr -d '0-9'        # abcdef

# 删除所有空格
echo "a b  c" | tr -d ' '                # abc
```

### 3. 压缩重复字符 `-s`

```bash
# 把多个连续空格压成一个
echo "a    b   c" | tr -s ' '            # a b c

# 把多个连续换行压成一个（去掉空行）
cat file.txt | tr -s '\n'

# 把连续空格压成单个制表符
echo "a    b   c" | tr -s ' ' '\t'       # a→b→c
```

`-s` 的模式是：前一个参数指定要压缩哪些字符，后一个可选参数指定"压成什么"。如果不给后一个，保持原字符但只保留一个。

### 4. 删除补集 `-c`（取反）

```bash
# 只保留字母，删除其他所有字符
echo "abc123!@#def" | tr -cd 'a-zA-Z'    # abcdef

# 只保留数字
echo "abc123def456" | tr -cd '0-9'       # 123456

# 只保留可打印字符
tr -cd '[:print:]' < binary_file
```

> ⚠️ `-c` 在某些系统上是"取补集"（complement），配合 `-d` 就是"删除不在集合里的"。这是一个强大但容易出意外的组合。

### 5. 字符类（不用自己写范围）

```bash
tr '[:lower:]' '[:upper:]'     # 小写转大写
tr '[:upper:]' '[:lower:]'     # 大写转小写
tr -d '[:space:]'              # 删除所有空白字符
tr -d '[:punct:]'              # 删除所有标点符号
tr -s '[:space:]'              # 压缩所有空白字符
```

---

## 场景驱动

### 1. 清理 Windows 文件

```bash
# 去 \r
tr -d '\r' < winfile.txt > unixfile.txt

# 把 \r\n 变成 \n（如果文件同时有 \r 和 \n）
tr -d '\r' < winfile.txt | cat -v   # -v 可以看到残余的控制字符
```

### 2. 生成随机密码

```bash
# 从 /dev/urandom 取随机字节，只保留字母数字，取前 20 个字符
tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20
```

### 3. 把列转成行

```bash
# 文件每行一个单词，想把它们用逗号连起来
cat words.txt | tr '\n' ',' | sed 's/,$//'
# words.txt 中的换行全变逗号，最后去掉末尾多余的逗号
```

### 4. 清理配置文件中的多余空白

```bash
# 压缩连续空格，去掉每行首尾空白
cat nginx.conf | tr -s ' ' | sed 's/^ *//;s/ *$//'
```

---

## tr vs sed：什么时候用哪个

| 场景 | tr | sed |
|------|-----|-----|
| 字符一对一替换 | ✅ 语法更简单 | 也行 |
| 删除特定字符 | ✅ `-d` | `sed 's/[abc]//g'` |
| 压缩重复字符 | ✅ `-s` | ❌ 很麻烦 |
| 字符串替换（多个字符） | ❌ 只做单字符 | ✅ `sed 's/foo/bar/g'` |
| 按行操作（插入、删除行） | ❌ 不支持 | ✅ |
| 处理文件（原地修改） | ❌ 不支持 | ✅ `-i` |

> 💡 **选 tr 的信号：你需要对"字符"做操作，而不是对"字符串"。** 删除、替换单个字符、压缩重复字符——全是 tr 的活。

---

## 新手踩坑总结

- **坑一：tr 不接受文件名参数。** `tr 'a' 'b' file.txt` 是错的，要用 `tr 'a' 'b' < file.txt`。
- **坑二：tr 处理的是字节流，不是行。** 换行符在 tr 眼里也是个普通字符——你可以把它替换掉。
- **坑三：集合长度不对等。** `tr 'abc' '12'` 会把 c 映射到 2（重复最后一个字符）。不是你想要的行为时，显式写完整映射。
- **坑四：`-c` 在不同系统上的行为可能有差异。** 有些老系统不支持，跨平台脚本测试一下。

---

## 最后

tr 是 Linux 命令里罕见的"文件名盲"——它眼里只有字符流，没有文件的概念。正因为它这么简单，它在管道链里才不可替代：sed 能做但啰嗦，awk 能做但杀鸡用牛刀。

下次拿到一个 Windows 来的文件跑不了，别急着手动删 `^M`。`tr -d '\r'`，三个参数，一秒钟。
