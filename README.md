# Linux 命令实战手册

> 不是命令列表，是排障工具箱。
>
> 每一条命令都从一个真实场景出发——先讲"为什么需要它"，再讲"怎么用好它"。

---

## 目录

- [关于这个文档](#关于这个文档)
- [文件与目录操作](#文件与目录操作)
- [文件内容查看](#文件内容查看)
- [内容搜索与过滤：find + grep](#内容搜索与过滤find--grep)
- [文本处理](#文本处理)
- [排序与统计](#排序与统计)
- [权限管理](#权限管理)
- [进程管理](#进程管理)
- [系统信息与排障](#系统信息与排障)
- [磁盘与存储](#磁盘与存储)
- [压缩与归档](#压缩与归档)
- [网络相关](#网络相关)
- [包管理](#包管理)
- [Shell 技巧](#shell-技巧)

---

## 关于这个文档

和大多数命令手册不同，本文的核心思路是：**每条命令都有一个"为什么需要它"的场景**。你可以从头到尾顺序读，学的是"排障思路"；也可以跳到你需要的命令查参数，当成速查表用。

两个核心原则贯穿全文：

1. **先理解场景，再记命令**——知道什么情况下用它，比背选项更重要
2. **每次 destructive 操作前，先 dry-run 确认**——删文件、改配置、杀进程，养成"先打印再看再执行"的习惯

---

## 文件与目录操作

> 最基础的命令，但很多人在"把文件搞丢"这件事上反复踩坑。这一节不讲花哨技巧，只讲几个真正需要记住的安全习惯。

### 最重要的安全习惯：rm 之前先确认

很多人第一次用 `rm -rf` 时，并不知道 `-f` 意味着"即使有写保护也直接删除，不提示你"。等到删错了才意识到少了哪一步。

安全流程应该是：

```bash
# 第一步：列出要删的文件
find /tmp -name "*.tmp" -print

# 第二步：确认无误
ls -lh /tmp/*.tmp

# 第三步：执行删除
rm /tmp/*.tmp
```

同理，`mv` 和 `cp` 的覆盖也是不可逆的——养成加 `-i` 的习惯：

```bash
rm -i file.txt      # 每个文件都问你一下
cp -i source dest   # 覆盖前确认
mv -i source dest   # 覆盖前确认
```

### `pwd` — 你在哪

这可能是最简单但最容易被遗忘的命令——特别是当你 `cd` 了几个目录之后，或者在别人的服务器上时：

```bash
pwd     # 当前工作目录
```

很多人出事后复盘，第一句就是"我以为我在那个目录"——`pwd` 是让你别"以为"的命令。

### `cd` — 切换目录

```bash
cd /path/to/dir      # 进入指定目录
cd ~                 # 回家
cd -                 # 回上一个目录——比手动输入路径快得多
cd ..                # 上级目录
cd ../..             # 上两级
```

> 💡 `cd -` 是排障时最常用的一个技巧：你去某个目录查了东西，想回到刚才的位置，不用重新输入路径。

### `ls` — 看看里面有什么

```bash
ls           # 默认：简洁列表
ls -l        # 详细信息——权限、大小、修改时间
ls -a        # 连隐藏文件也显示
ls -lh       # 文件大小显示为 1K、2M、3G（人类友好）
ls -lt       # 按修改时间排，最新的在最上面
ls -lS       # 按文件大小排，最大的在最上面
```

> 💡 新手常见的误区：`ls` 不会告诉你目录下**有多少个文件**，也不会递归显示。要统计数量用 `ls | wc -l`，要递归用 `find` 或 `ls -R`。

### `tree` — 目录的"地图"视图

**场景**：你接手一个项目，不知道目录结构长什么样。`ls` 只能看一层，你需要一个全景图。

```bash
tree                     # 完整目录树
tree -L 2                # 只看两层，避免刷屏
tree -I node_modules     # 排除烦人的 node_modules
tree -d                  # 只看目录，不看文件
```

> 💡 如果你的系统没有 `tree`，macOS 用 `brew install tree`，Linux 用对应的包管理器安装。

### `mkdir` / `rmdir` — 创建和删除目录

```bash
mkdir dir           # 创建目录
mkdir -p a/b/c/d    # 递归创建——不需要一层层 mkdir
mkdir -m 755 dir    # 创建时直接设权限

rmdir dir           # 删除空目录——非空会报错
rmdir -p a/b/c/d    # 递归向上删除空父目录
```

> 💡 `mkdir -p` 是最容易被低估的选项。很多人写脚本时会写 `mkdir dir 2>/dev/null`，实际上用 `mkdir -p` 更干净——目录已存在也不会报错。

### `touch` — 不只是创建空文件

```bash
touch file.txt              # 创建空文件（已存在则更新时间戳）
touch -t 202401010000 log   # 把文件时间改成 2024-01-01 00:00
```

> 💡 第二个用法是排障技巧：有些日志轮转策略依赖文件的时间戳，你可以用 `touch -t` 模拟"这个文件是那天生成的"。

### `rm` — 删除

```bash
rm file.txt              # 删除文件
rm -r dir/               # 删除目录及其内容
rm -f file.txt           # 强制删除（不提示）
rm -rf dir/              # ⚠️ 递归强制删除——用之前确认三遍
```

> ⚠️ `rm -rf /` 是经典段子，但现实里更常见的是 `rm -rf ./*` 跑错了目录。建议：**每次用 `-rf` 之前，先 `ls` 一下确认当前目录**。

### `mv` — 移动或重命名

```bash
mv old.txt new.txt          # 重命名
mv file.txt /tmp/           # 移动
mv -i file.txt /tmp/        # 覆盖前提醒
mv -v file.txt /tmp/        # 显示过程
```

### `cp` — 复制

```bash
cp file.txt /tmp/           # 复制文件
cp -r dir/ /tmp/            # 复制目录
cp -a dir/ /tmp/            # 归档复制——保留权限、链接等
cp -i file.txt /tmp/        # 覆盖前确认
cp -p file.txt /tmp/        # 保留原始时间戳
cp -v file.txt /tmp/        # 显示过程
```

> 💡 `cp -a` 在备份时特别有用，它能保留几乎所有文件属性，比 `cp -r` 更适合"完整复制"的场景。

### `ln` — 链接

```bash
ln -s /real/path link       # 软链接（符号链接）——类似 Windows 的快捷方式
ln /real/path link          # 硬链接——同一个文件的两个名字
```

> ⚠️ 软链接和硬链接的区别是个经典面试题：软链接可以跨文件系统、可以链接目录、删除原文件会失效；硬链接不行。实际工作中 **99% 的场景用软链接就够了**。

---

## 文件内容查看

> 排障时最常做的事情就是"看文件里写了什么"。这一节是查看工具，下一节才是搜索工具——先把两个概念分清楚。

### `cat` — 全量查看（适合小文件）

```bash
cat file.txt              # 内容全量输出
cat -n file.txt           # 带行号
cat -b file.txt           # 只给非空行编号
cat file1 file2 > merged  # 合并文件
```

> ⚠️ `cat` 不适合大文件——一个几百 MB 的日志文件直接 `cat`，终端会被刷到卡住。大文件用 `less` 或 `tail`。

### `less` — 分页查看（大文件专用）

```bash
less file.txt
```

进入 `less` 后的常用操作：

| 操作 | 作用 |
|------|------|
| `空格` / `f` | 下一页 |
| `b` | 上一页 |
| `回车` / `j` | 向下一行 |
| `k` | 向上一行 |
| `/关键词` | 向下搜索 |
| `?关键词` | 向上搜索 |
| `n` | 下一个匹配 |
| `N` | 上一个匹配 |
| `G` | 跳到末尾 |
| `gg` | 跳到开头 |
| `q` | 退出 |

> 💡 很多人用 `cat` 看完就忘了，其实 `less` 看大日志文件是标准做法——你不需要把所有内容加载到终端，按需翻页就好。

### `head` / `tail` — 只看开头或结尾

**场景**：一个日志文件一直在写，你不想重新打开它，只想看最新的几行。这就是 `tail -f` 的用武之地。

```bash
head file.txt          # 前 10 行
head -n 20 file.txt    # 前 20 行

tail file.txt          # 后 10 行
tail -n 20 file.txt    # 后 20 行
tail -f app.log        # 🔄 实时跟踪追加内容（Ctrl+C 退出）
tail -F app.log        # 🔄 跟 -f 类似，但支持日志轮转（文件被重命名后自动重新打开）
```

> 💡 `tail -f` 是排查线上问题时的标准姿势——打开日志、挂着、复现操作、看输出。`-F`（大写）比 `-f` 更稳定：如果日志文件半夜被轮转了，`-f` 会停在空文件上，`-F` 会自动跟到新文件。

---

## 内容搜索与过滤：find + grep

> 这是排障工具箱里最重要的两个命令。简单说：
>
> - **`find` 搜的是文件本身**——名字、类型、大小、时间、权限
> - **`grep` 搜的是文件内容**——文件里写了什么
>
> 排障时它们经常**组合使用**：先用 `find` 定位文件范围，再用 `grep` 定位内容位置。

---

### find — 不只是"找文件"

> 很多人用好几年 Linux，`find` 永远只会 `find . -name "xxx"`，再复杂一点就写脚本去了。其实 `find` 真正的设计目标是——**按任意条件筛选文件系统里的对象，并对结果执行动作**。

#### 先避开最常踩的坑

```bash
# ❌ 错误的写法——Shell 会在执行 find 之前就把 *.txt 展开
find . -name *.txt

# ✅ 正确写法——加引号，让 find 自己解释模式
find . -name "*.txt"
```

不加引号的话，如果当前目录恰好有 `.txt` 文件，Shell 会把 `*.txt` 展开成具体文件名再传给 `find`，结果完全不对——这是新手用 `find` 结果不对的头号原因。

---

#### 按名字找

```bash
find /etc -name "*.conf"          # 区分大小写
find /etc -iname "*.CONF"         # 不区分大小写
```

**排除某些文件**——很多人不知道 `find` 本身就支持：

```bash
find . -name "*test*" ! -name "*.log"
# 找出包含 test 的文件，但排除 .log 结尾的
```

如果需要正则表达式（不只是通配符）：

```bash
find . -regex ".*\.\(txt\|md\)$"   # 注意：匹配的是完整路径
```

> ⚠️ `-regex` 和 `-name` 的匹配范围不一样：`-name` 只匹配文件名，`-regex` 匹配完整路径。这点很容易搞混。

---

#### 按类型找

**场景**：你想确认某个路径到底是文件、目录还是软链接——不要相信名字，用 `-type` 验证：

```bash
find /opt -type d    # 只找目录
find /opt -type f    # 只找普通文件
find /opt -type l    # 只找符号链接
```

---

#### 按时间找

**场景**：清理过期日志时，"超过 7 天的日志文件"是一个经典需求：

```bash
find /var/log -name "*.log" -mtime +7
# 最后修改时间超过 7 天的日志文件
```

| 写法 | 含义 |
|------|------|
| `+7` | 超过 7 天 |
| `-7` | 7 天以内 |
| `7` | 刚好第 7 天那个区间 |

按分钟算（排查最近被改动过的文件）：

```bash
find /etc -mmin -10
# 最近 10 分钟内被修改过的文件
```

#### atime / mtime / ctime 的误区

> ⚠️ `ctime` **不是**"创建时间"，而是"元数据最后一次变更的时间"——你只是 `chmod` 改了权限，文件内容没动，`ctime` 也会更新。

| 时间戳 | 含义 | 典型场景 |
|--------|------|---------|
| `atime` | 最后一次被**读取**的时间 | 清理很久没人访问的归档文件 |
| `mtime` | 最后一次内容被**修改**的时间 | 清理过期日志 |
| `ctime` | 最后一次**元数据变更**的时间 | 检查权限是否被改过 |

```bash
# 找出超过一年没被读取过的文件
find /data/archive -type f -atime +365
```

---

#### 按大小找

**场景**：磁盘报警 95%，找出占空间的大文件：

```bash
# 新手：一层层 cd + du -sh *
# 老手：
find / -xdev -type f -size +500M 2>/dev/null
```

> `-xdev` 只在当前文件系统内搜索，不跨到其他挂载点。不加的话，`find` 会钻进 `/proc`、`/sys`，又慢又没意义。

配合排序，找出最大的前几个：

```bash
find / -xdev -type f -size +100M -exec du -h {} \; 2>/dev/null | sort -rh
```

---

#### 按权限找

**场景**：安全排查时，找出所有设置了 SUID 位的文件——这类文件执行时会获得所有者权限，是权限提升的常见突破口：

```bash
find / -perm -4000 -type f 2>/dev/null
```

`-perm` 的前缀符号注意区分：

| 写法 | 含义 |
|------|------|
| `-perm -4000` | 至少包含 SUID 位 |
| `-perm /4000` | 包含任意指定的位 |
| `-perm 4000` | 精确等于 4000 |

---

#### 对结果执行命令 -exec

**场景**：找到文件之后，你想对它们做点什么——删除、移动、压缩、检查内容。

```bash
# 低效写法：每个文件单独启动一个进程
find /var/log -name "*.log" -mtime +30 -exec rm {} \;

# 高效写法：打包成尽量少的命令调用
find /var/log -name "*.log" -mtime +30 -exec rm {} +
```

> 💡 能用 `+` 就不要用 `\;`。1000 个文件用 `+` 可能几次命令就处理完了，用 `\;` 要启动 1000 次进程。

**安全铁律**：任何带删除的命令，先跑一遍 `-print` 确认：

```bash
# 第一步：打印确认
find /var/log -name "*.log.*" -mtime +14 -print

# 第二步：确认无误后再删除
find /var/log -name "*.log.*" -mtime +14 -delete
```

-exec 配合 grep 的组合用法——`find` 定文件范围，`grep` 定内容位置：

```bash
find . -name "*.java" -exec grep -l "public static void main" {} \;
```

---

#### 跳过某些目录 -prune

**场景**：搜代码时不想搜进 `node_modules` 或 `.git`：

```bash
find . -path "./node_modules" -prune -o -name "*.js" -print
```

> 这条命令的拆解：`-path "./node_modules" -prune` 表示"遇到这个路径就跳过"；`-o`（逻辑或）后面是"否则"的部分。

---

#### 配合 xargs 安全处理

文件名带空格时，直接 `| xargs` 会出错：

```bash
# ✅ 安全写法
find . -name "*.bak" -print0 | xargs -0 rm
```

`-print0` 用 `\0` 分隔文件名，`xargs -0` 按 `\0` 解析——这样任何带空格、换行的文件名都能正确处理。

---

#### 性能注意点

1. **加 `-maxdepth` 限制深度**——很多场景你只需要搜第一层：

   ```bash
   find /tmp -maxdepth 1 -type f -mtime +1 -delete
   ```

2. **从 `/` 搜索记得加 `-xdev`**——避免跨到网络文件系统

3. **大目录搜索放后台**——`&`

---

#### 什么时候换其他工具

- **只想快速找文件**（不关心时间、权限等条件）→ 用 `locate`（查索引，更快）
- **日常按名字找文件** → 可以用 `fd`（语法更简洁，非默认安装）

---

### grep — 搜文件内容

> `find` 帮你找到"哪些文件"，`grep` 帮你在这些文件里找"具体是哪行出了问题"。

**场景**：你看到日志里有错误，想找到所有出错的行——但又不想一条条翻：

```bash
grep "error" app.log              # 基本搜索
grep -i "error" app.log           # 忽略大小写
grep -n "error" app.log           # 告诉我行号
grep -c "error" app.log           # 统计有多少行匹配
grep -v "timeout" app.log         # 排除 timeout 的行
```

**场景**：你想知道整个项目里哪些文件调用了某个函数：

```bash
grep -r "sendEmail" ./src/        # 递归搜索目录
grep -rl "sendEmail" ./src/       # 只列出文件名，不显示内容
```

**场景**：你想看错误行的上下文：

```bash
grep -A 3 "error" log.txt         # 匹配行 + 后面 3 行
grep -B 3 "error" log.txt         # 匹配行 + 前面 3 行
grep -C 3 "error" log.txt         # 前后各 3 行
```

**场景**：多个关键词——找出既包含 error 又包含 timeout 的行：

```bash
grep -E "error|timeout" log.txt   # 扩展正则，| 表示或
```

> 💡 建议 `alias grep='grep --color=auto'`——匹配到的关键词高亮显示，排查时一目了然。

---

## 文本处理

> 如果 `find + grep` 是"定位问题"用的，那么 `sed + awk` 是"批量处理"用的。不需要你精通，但记住最常用的三五条用法，能省大量手动编辑的时间。

### `sed` — 流式文本编辑

**场景**：你需要把配置文件里所有的 `localhost` 替换成线上域名：

```bash
# 预览替换结果（不改原文件）
sed 's/localhost/api.example.com/g' config.js

# 确认无误后直接修改文件
sed -i 's/localhost/api.example.com/g' config.js

# ⚠️ macOS 上需要额外一个空字符串
sed -i '' 's/localhost/api.example.com/g' config.js
```

其他常用法：

```bash
sed -n '5,10p' file.txt            # 只看第 5 到 10 行
sed '/debug/d' file.txt            # 删除包含 debug 的行
sed 's/^/  /' file.txt             # 每行前加两个空格（缩进）
```

> 💡 `s/old/new/g` 里的 `g` 表示"这一行里所有的"，不加的话只替换每行的第一个匹配。

### `awk` — 按列处理文本

**场景**：你想要一个表格文件里的某一列——比如 `ps aux` 的输出里只看 PID 和命令：

```bash
ps aux | awk '{print $2, $11}'
```

进阶用法：

```bash
awk '{print $1, $NF}' file.txt     # 第 1 列和最后一列
awk -F',' '{print $1}' data.csv    # 指定逗号作为分隔符
awk '/error/ {print}' log.txt      # 只处理包含 error 的行
awk '{sum+=$1} END {print sum}' nums.txt  # 求第一列的总和
```

### `cut` — 更简单的列切割

```bash
cut -d':' -f1 /etc/passwd          # 按 : 分隔，取第一列
cut -c1-5 file.txt                 # 取每行的前 5 个字符
```

> 💡 `cut` 比 `awk` 简单，适合只需要按分隔符切一列的场景；`awk` 适合需要条件判断或统计的场景。

### `tr` — 字符替换

```bash
echo "hello" | tr 'a-z' 'A-Z'     # 小写转大写
cat file.txt | tr -d '\r'          # 删除 Windows 的 \r（^M）
cat file.txt | tr -s ' '           # 把多个连续空格压缩成一个
```

### `xargs` — 把列表变成命令参数

**场景**：你想删除一批文件，但它们是 `find` 或 `grep -l` 输出的结果：

```bash
find . -name "*.log" | xargs rm
cat urls.txt | xargs curl -O       # 批量下载
find . -type f | xargs wc -l       # 统计所有文件行数
```

> ⚠️ 文件名有空格时，`xargs` 默认按空格/换行切分会出错，用 `-print0 | xargs -0` 解决（见 find 章节）。

---

## 排序与统计

### `sort` — 排序

```bash
sort file.txt                    # 按字母排序
sort -n file.txt                 # 按数字排序
sort -r file.txt                 # 倒序
sort -k2 file.txt                # 按第 2 列排序
sort -t',' -k3 -n data.csv       # 逗号分隔，按第 3 列数字排序
sort -u file.txt                 # 排序并去重（等价于 sort | uniq）
```

### `uniq` — 去重（必须先排序）

```bash
sort file.txt | uniq              # 去重
sort file.txt | uniq -c           # 统计每个值的出现次数
sort file.txt | uniq -d           # 只显示有重复的行
```

> ⚠️ `uniq` 只处理连续相同的行——所以去重之前必须 `sort`。这是一个很常见的误区：直接 `uniq` 发现去得不干净，以为是自己操作错了。

### `wc` — 统计

```bash
wc file.txt                      # 行数 / 词数 / 字节数
wc -l file.txt                   # 只看行数
wc -w file.txt                   # 只看词数
wc -c file.txt                   # 只看字节数
wc -l *.txt                      # 统计多个文件
```

> 💡 `wc -l` 是最常用的：统计代码行数、统计匹配结果数量、统计目录下文件数。

---

## 权限管理

> 权限问题的排查场景通常只有两个：**"为什么我不能读/写这个文件"** 和 **"这个文件怎么被改了权限"**。

### `chmod` — 改权限

```bash
chmod 755 script.sh               # rwxr-xr-x——常见于可执行文件
chmod 644 file.txt                # rw-r--r--——常见于普通文件
chmod 600 secret.txt              # rw-------——私密文件
chmod u+x script.sh               # 给所有者加执行权限
chmod -R 755 dir/                 # 递归修改——用于整个目录
```

> 权限速查：`r=4, w=2, x=1`，所以 `7=rwx, 6=rw-, 5=r-x, 4=r--`。

### `chown` — 改所有者

```bash
chown user file.txt               # 改所有者
chown user:group file.txt         # 同时改所有者和组
chown -R user:group dir/          # 递归修改
```

### `umask` — 默认权限

```bash
umask                              # 查看当前掩码
umask 022                          # 设置新文件的默认权限
```

> `umask 022` 意味着新文件的默认权限是 `666 - 022 = 644`，新目录是 `777 - 022 = 755`。

---

## 进程管理

> 排查线上问题时，进程管理的手势通常是：**先找到问题进程（ps），再看它在干什么（top），最后决定要不要杀（kill）**。

### `ps` — 查看进程

**场景**：服务器负载飙升，你想快速看看到底是哪个程序在吃资源：

```bash
ps aux                             # 所有进程的完整信息
ps aux | grep nginx                # 找 nginx 的进程
ps -ef                             # 标准格式全列表
ps -eo pid,ppid,cmd,%mem,%cpu      # 只看你关心的列
```

> `ps aux` 是日常排查用得最多的——USER（谁跑的）、%CPU、%MEM、CMD（命令路径），一眼能看出异常。

### `top` — 实时监控

```bash
top                                # 默认按 CPU 排序
top -o %MEM                        # 改为按内存排序
```

进入 `top` 后的常用操作：

| 操作 | 作用 |
|------|------|
| `P` | 按 CPU 排序 |
| `M` | 按内存排序 |
| `1` | 查看每个 CPU 的负载 |
| `q` | 退出 |

### `kill` — 终止进程

**场景**：一个进程卡住了，怎么也退不出来。你要把它终结掉。

```bash
kill 1234                          # SIGTERM（默认）——给进程一个"组织一下再退"的机会
kill -15 1234                      # 同上，显式指定
kill -9 1234                       # SIGKILL——直接干掉（⚠️ 进程没法做清理工作）
kill -HUP 1234                     # SIGHUP——常用于让进程重载配置
killall nginx                      # 按进程名字杀
```

> 💡 优先用 `kill`（SIGTERM），不行再用 `kill -9`。很多新手一上来就 `-9`，其实不优雅——进程可能正在写文件，直接杀掉会丢数据。

### `jobs` / `bg` / `fg` — 作业控制

```bash
command &                          # 后台运行
jobs                               # 查看后台作业
bg %1                              # 把作业 1 放到后台继续
fg %1                              # 把作业 1 拉回前台
```

### `nohup` — 退出终端后继续运行

**场景**：你在远程服务器上启动了一个耗时任务，但怕退出 SSH 后进程被干掉：

```bash
nohup long-running.sh &
nohup command > output.log 2>&1 &  # 输出重定向到文件
```

---

## 系统信息与排障

> 接到告警时的第一轮排查就是"看系统状态"：磁盘满了吗？内存够吗？CPU 负载正常吗？

### `uname` — 搞清楚机器是什么

**场景**：你 SSH 到一台新服务器，连它是什么系统、什么架构都不知道：

```bash
uname -a                           # 所有信息
uname -r                           # 内核版本——安装驱动时最常查
uname -m                           # 架构：x86_64 还是 arm64
```

### `df` — 磁盘还有多少空间

**场景**：收到"磁盘使用率 95%"的告警：

```bash
df -h                              # 查看所有分区的磁盘使用
df -h /                            # 只看根分区
df -i                              # 查看 inode 使用情况（小文件太多也会满）
```

> 💡 很多人只知道看磁盘空间，忽略了 inode 也会满——一个几万个零碎文件的目录，可能空间还有余但 inode 用光了，同样写不了文件。

### `du` — 什么在占空间

**场景**：你已经知道根分区满了，接下来要看具体是哪个目录在吃空间：

```bash
du -sh dir/                        # 目录总大小
du -h --max-depth=1                # 看当前目录下每个项目的大小
du -sh * | sort -h                 # 按大小排序，一目了然
```

### `free` — 内存够吗

```bash
free -h                            # 人性化显示
free -m                            # 以 MB 为单位
free -s 2                          # 每 2 秒刷新一次——类似 top 的内存版
```

> 注意 Linux 内存管理的特殊性："available"才是真正可用的内存，"free"只是完全空闲的那部分，因为 Linux 会尽量用空闲内存做缓存（buff/cache），需要时会释放。

### `uptime` — 跑了多久、负载如何

```bash
uptime                             # 运行时间 + 1/5/15 分钟平均负载
```

> 负载值需要结合 CPU 核心数看：4 核机器负载 < 4 算正常，> 4 说明有进程在排队。

### `date` — 不只是看时间

```bash
date +%Y-%m-%d                     # 2024-01-01
date +%Y%m%d_%H%M%S                # 20240101_120000——适合做文件名后缀
```

### `which` / `whereis` — 命令在哪

**场景**：你运行一个命令说"not found"，但你觉得明明装了：

```bash
which python                       # 看它在不在 PATH 里
whereis python                     # 连源码和 man 页都找出来
```

---

## 磁盘与存储

### `mount` / `umount` — 挂载/卸载

```bash
mount                              # 查看所有挂载点
mount /dev/sdb1 /mnt/data          # 挂载硬盘
umount /mnt/data                   # 卸载
umount -l /mnt/data                # 强制卸载（lazy——等没人用了再真正卸载）
```

### `dd` — 磁盘级别复制

```bash
# 创建指定大小的文件（测试用）
dd if=/dev/zero of=testfile bs=1M count=100   # 创建 100MB 文件

# 备份磁盘/分区（⚠️ 谨慎使用）
dd if=/dev/sda of=backup.img bs=4M
```

---

## 压缩与归档

> 压缩文件的格式识别经常让人困惑。记住一句话：**`tar` 是打包工具（可以把多个文件合成一个），`gzip`/`bzip2` 才是压缩工具**。但你最常用的是两者的组合。

### `tar` — 打包 + 压缩

**场景**：你要把一个项目目录发给别人，或者备份到另一台机器：

```bash
# 打包（不压缩）
tar -cvf archive.tar dir/

# 打包 + gzip 压缩（最常用）
tar -czvf archive.tar.gz dir/

# 打包 + 更好的压缩比
tar -cjvf archive.tar.bz2 dir/
```

解压对应：

```bash
tar -xvf archive.tar               # 解包
tar -xzvf archive.tar.gz           # 解压 tar.gz
tar -xjvf archive.tar.bz2          # 解压 tar.bz2
tar -tf archive.tar.gz             # 查看包里的内容
```

> 参数速记：`c`=创建、`x`=解压、`z`=gzip、`j`=bzip2、`v`=显示过程、`f`=文件名、`t`=查看

### `gzip` / `gunzip` — 单文件压缩

```bash
gzip file.txt                      # 压缩为 file.txt.gz（原文件消失）
gzip -k file.txt                   # 压缩并保留原文件
gzip -d file.txt.gz                # 解压
gunzip file.txt.gz                 # 同上
```

### `zip` / `unzip` — 跨平台压缩

```bash
zip -r archive.zip dir/            # 压缩目录
zip archive.zip file1 file2        # 压缩多个文件
unzip archive.zip                  # 解压到当前目录
unzip -d /target/ archive.zip      # 解压到指定目录
unzip -l archive.zip               # 查看内容（不解压）
```

> 💡 `.zip` 在 Windows 和 macOS 上都原生支持，`tar.gz` 在 Linux 上更常见。发给非技术同事，优先用 `.zip`。

---

## 网络相关

> 网络排障的典型流程：**先看能不能通（ping），再看端口对不对（curl/ss），最后看要不要传文件（scp/rsync）**。

### `ping` — 能通吗

```bash
ping -c 4 google.com               # 发 4 个包后停止（不要忘了 -c，否则 Ctrl+C）
ping -i 0.5 google.com             # 每 0.5 秒一个包，更快检测
```

### `curl` — 请求和下载

**场景**：你的 API 返回 500，你想亲自看看请求回来什么：

```bash
curl https://api.example.com                    # GET 请求，输出响应体
curl -v https://api.example.com                 # 🧵 显示详细过程（请求头、响应头、SSL 握手）
curl -I https://api.example.com                 # 只看响应头（确认状态码）
curl -o output.json https://api.example.com     # 保存到文件
curl -L http://bit.ly/short                     # 跟随重定向
curl -H "Authorization: Bearer xxx" https://api # 带自定义请求头
curl -d '{"key":"value"}' -H "Content-Type: application/json" https://api  # POST JSON
```

> 💡 `curl -v` 是排障时最有用的选项——它把整个 HTTP 对话过程都打印出来，一眼就能看出是哪一步出了问题（DNS 解析失败？SSL 证书不对？连接被拒绝？）。

### `wget` — 下载工具

```bash
wget https://example.com/file.zip   # 下载
wget -c https://example.com/big.zip # 断点续传
wget -O out.zip https://example.com/file  # 指定文件名
```

### `ssh` — 远程登录

**场景**：你需要在远程服务器上执行操作：

```bash
ssh user@hostname                           # 基本登录
ssh -p 2222 user@hostname                   # 改端口
ssh -i ~/.ssh/key.pem user@hostname         # 使用密钥
ssh user@hostname "ls -l /var/log"          # 远程执行一条命令
ssh -L 8080:localhost:80 user@host          # 🔄 本地端口转发——把远程的 80 端口映射到本地的 8080
```

> 💡 `ssh -L` 的典型场景：线上数据库只允许本机连接，你在本地通过端口转发访问，不需要把数据库端口暴露到公网。

### `scp` — 远程拷贝

```bash
scp file.txt user@host:/remote/path          # 本地上传到服务器
scp user@host:/remote/file.txt ./            # 从服务器下载
scp -r dir/ user@host:/remote/path           # 拷贝目录
scp -P 2222 file.txt user@host:/remote/path  # 指定端口
```

### `rsync` — 增量同步（推荐替代 scp）

**场景**：你有一个大的项目目录需要同步到远程服务器。第一次用 `scp -r` 可以，但以后每次改了几个文件也全量拷贝，很慢。`rsync` 只传差异部分：

```bash
rsync -av dir/ user@host:/backup/          # 增量同步
rsync -avz dir/ user@host:/backup/         # 同步时压缩传输（适合网络慢的场景）
rsync -av --delete dir/ user@host:/backup/ # 同步并删除远程多余的文件
```

> 💡 `-a` 归档模式（保留权限、时间等）、`-v` 显示过程、`-z` 压缩传输、`--delete` 使远程和本地完全一致

### `ss` / `netstat` — 端口和连接

**场景**：你启动了一个服务，不知道怎么确认它是否在监听端口：

```bash
ss -tlnp                              # 查看所有 TCP 监听端口（推荐用 ss，更快）
netstat -tlnp                         # 同上，老版本用这个
ss -s                                 # 连接统计概览
```

### `ip` / `ifconfig` — 网络配置

```bash
ip addr                               # 查看 IP 地址
ip link                               # 查看网络接口状态
ifconfig                              # 旧版（已弃用，但很多系统还有）
```

---

## 包管理

> 不同系统的包管理命令差异很大。这里列出最常见的几个。

### `brew` — macOS

```bash
brew install wget                     # 安装
brew uninstall wget                   # 卸载
brew update                           # 更新 Homebrew 自身
brew upgrade                          # 升级所有已装包
brew search keyword                   # 搜索
brew list                             # 查看已装包
brew info wget                        # 查看包信息
brew services start nginx             # 启动后台服务
```

### `apt` — Debian / Ubuntu

```bash
apt update                            # 更新软件源
apt install nginx                     # 安装
apt remove nginx                      # 卸载
apt purge nginx                       # 卸载并清理配置
apt upgrade                           # 升级所有包
apt search keyword                    # 搜索
apt list --installed                  # 查看已装包
```

### `dnf` / `yum` — Fedora / CentOS / RHEL

```bash
dnf install nginx                     # 安装
dnf remove nginx                      # 卸载
dnf update                            # 升级
dnf search keyword                    # 搜索
dnf list installed                    # 查看已装包
```

### `npm` / `yarn` — Node.js

```bash
npm install package                   # 安装依赖
npm install -g package                # 全局安装
npm uninstall package                 # 卸载
npm list --depth=0                    # 查看顶层依赖

yarn add package                      # 添加依赖
yarn remove package                   # 移除
yarn install                          # 安装所有依赖
```

---

## Shell 技巧

> 这些不是命令，而是把命令串起来用的"语法"。排障时 90% 的场景都可以用**管道 + 重定向 + grep** 解决。

### 管道 `|` — 命令串联

`|` 把前一个命令的输出变成后一个命令的输入——这是 Linux 哲学"一个命令只做一件事"的核心：

```bash
# 查找 nginx 进程的 PID
ps aux | grep nginx | awk '{print $2}'

# 统计日志中 error 的数量
cat app.log | grep "error" | wc -l
```

### 重定向

```bash
command > output.txt                  # 覆盖写入
command >> output.txt                 # 追加写入
command 2> error.txt                  # 错误输出到文件
command &> output.txt                 # 全部输出
command > /dev/null                   # 丢弃所有输出
command 2>&1                          # 合并错误到标准输出（管道时常用）
```

> 💡 `2>&1` 的典型场景：`command > log.txt 2>&1`——把正常输出和错误输出都写到一个文件里。

### 通配符

```bash
*.txt                                 # 所有 txt 文件
file??.txt                            # file 后两个任意字符
[abc]*.txt                            # 以 a/b/c 开头的 txt 文件
```

### 命令组合

```bash
cmd1 && cmd2                          # 前面成功了，才执行后面（常用：cd /tmp && rm -rf *）
cmd1 || cmd2                          # 前面失败了，才执行后面
cmd1 ; cmd2                           # 不管怎样都执行
$(command)                            # 命令替换——把结果嵌入到另一个命令里
```

> 💡 `$(command)` 示例：将当前时间嵌入文件名——`cp config.json config.json.$(date +%Y%m%d)`。

### `alias` — 别名

```bash
alias ll='ls -lh'                     # 设置别名
alias grep='grep --color=auto'
alias -s                              # 查看所有别名
unalias ll                            # 移除
```

### `history` — 命令历史

```bash
history                               # 看刚才做了什么
!!                                    # 重复上一条命令
!100                                  # 执行第 100 条
!$                                    # 上一条命令的最后一个参数
```

> 💡 在远程服务器上排查问题时，先用 `history` 看看之前的人执行过什么——有时候能直接看出问题是怎么引起的。

### shell 快捷键

| 快捷键 | 作用 | 排障场景 |
|--------|------|----------|
| `Ctrl+R` | 搜索历史命令 | 记不全命令时搜一下 |
| `Ctrl+A` | 跳到行首 | 给命令前面加 `sudo` |
| `Ctrl+E` | 跳到行尾 | 继续在末尾补参数 |
| `Ctrl+U` | 删到行首 | 输错了直接重来 |
| `Ctrl+W` | 删前一个词 | 只改路径参数时 |
| `Ctrl+L` | 清屏 | 输出太多，清一下 |
| `Ctrl+C` | 终止 | 命令卡住了 |
| `Tab` | 自动补全 | 路径/命令名不用全打 |

---

## 快速参考

### 权限数字速查

```
r=4  w=2  x=1
7=rwx  6=rw-  5=r-x  4=r--  0=---
755 = 所有者(7) + 组(5) + 其他人(5)  → 可执行文件
644 = 所有者(6) + 组(4) + 其他人(4)  → 普通文件
600 = 所有者(6)                        → 私密文件
```

### 特殊路径符号

```
.        当前目录
..       上级目录
~        Home 目录
-        上一个目录
/        根目录
```

### 三类时间戳（避免搞混）

| 缩写 | 全称 | 含义 |
|------|------|------|
| `mtime` | modify time | 文件内容被修改的时间 |
| `ctime` | change time | **元数据**变更的时间（不是创建时间！） |
| `atime` | access time | 文件被读取的时间 |

### 常用组合速查

```bash
# 磁盘排障三板斧
df -h                                  # 看磁盘用了多少
du -sh * | sort -h                     # 看哪个目录占最多
find / -xdev -type f -size +500M 2>/dev/null  # 看哪些大文件

# 进程排障三板斧
ps aux | grep <name>                   # 看进程在不在
top -o %MEM                            # 看资源占用排序
kill -15 <PID>                         # 优雅终止

# 日志排障三板斧
tail -F app.log                        # 跟踪最新日志
grep -i "error" app.log                # 搜索错误
grep -C 5 "error" app.log              # 看错误上下文

# 网络排障三板斧
ping -c 4 <host>                       # 通不通
curl -v <url>                          # 请求具体问题
ss -tlnp                               # 端口在监听吗
```

---

> ⚠️ **macOS 用户注意**：macOS 的 `sed`、`find` 等命令是 BSD 版，和 Linux 的 GNU 版有细微差异（比如 `sed -i` 需要空备份后缀）。如果遇到奇怪行为，可以 `brew install coreutils` 安装 GNU 版本，前缀为 `g`（如 `gsed`、`gfind`）。
