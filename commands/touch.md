
# touch：你以为它只能创建空文件，但它真正的本事在时间上

如果你问"touch 是干什么的"，大多数人会说："创建空文件啊。" 确实，这可能是每个 Linux 用户学的第一个"创建"类命令。

但如果只用来创建空文件，你就用了 touch 不到 10% 的能力。touch 真正的名字应该叫"时间戳操控器"——它能把一个文件的访问时间和修改时间改成任何你指定的值。什么时候需要这个？排障、测试、日志轮转——非常多。

---

## 场景引入：两个让你愣住的瞬间

### 场景一：模拟"昨天的日志"

你在调试日志轮转脚本——这个脚本会删除 7 天前的日志。你怎么验证它管不管用？正常情况下你得等七天。

```bash
# 用 touch 把测试日志的时间改成 8 天前
touch -d "8 days ago" test.log

# 然后运行你的清理脚本，看它是不是真的删了
# 不用等一周，一秒模拟出"过期日志"
```

### 场景二：触发文件监控工具的响应

你有一个文件同步工具（如 rsync + inotify），它依靠文件的修改时间来判定是否需要同步。你改了一个配置文件，但同步没触发——可能是修改时间没变。

```bash
# 手动刷新时间戳，强制触发同步
touch /etc/myapp/config.yml
# 文件内容不变，但 mtime 变了——同步工具会把它当成"有改动"
```

---

## 核心概念：touch 的三个角色

touch 做的事其实就一句话：**更新文件的访问时间和修改时间；如果文件不存在，创建它。**

它有三种工作模式：

| 模式 | 行为 |
|------|------|
| 文件存在，不指定时间 | 把 atime 和 mtime 更新为"现在" |
| 文件存在，指定时间 | 把 atime 和 mtime 改成你指定的值 |
| 文件不存在 | 创建一个 0 字节的空文件 |

---

## 先排雷：touch 不改变内容，只改时间戳

这是一个认知偏差：很多人以为 touch 会"刷新"文件内容。不会。`touch existing.log` 只改变那个文件的元数据（时间戳），内容一字节都不变。

```bash
# 文件已经有 1MB 的日志内容
ls -lh app.log            # -rw-r--r-- 1 user user 1.0M Jul 13 10:00 app.log

touch app.log
# 内容完全不变，只把时间更新到现在
ls -lh app.log            # -rw-r--r-- 1 user user 1.0M Jul 13 14:30 app.log
```

> ⚠️ 如果你用 touch 去"刷新"一个重要的日志文件，然后发现它的内容没变——这不是 bug，是 touch 的设计就是如此。它不求改内容。

---

## 核心能力逐层拆解

### 第 1 层：创建空文件（你已经在用的）

```bash
touch file.txt                     # 创建一个 0 字节的文件
touch file1.txt file2.txt file3.txt # 一次创建多个
```

注意：如果文件已存在，touch 不会报错也不会覆盖——它只会更新时间戳。这也是 touch 比 `> file.txt` 安全的地方。

---

### 第 2 层：把时间戳改到任意时间

这是 touch 的杀手能力。

```bash
# 用 -d 指定自然语言时间（GNU touch）
touch -d "2024-01-01 00:00:00" file.txt   # 改成 2024 年元旦
touch -d "7 days ago" file.txt             # 改成 7 天前
touch -d "next Monday" file.txt            # 改成下周一
touch -d "yesterday 14:30" file.txt        # 改成昨天下午两点半

# 用 -t 指定精确时间戳
touch -t 202401010000 file.txt             # 2024-01-01 00:00
touch -t 202401010000.00 file.txt          # 同上，精确到秒
```

`-t` 的格式是 `[[CC]YY]MMDDhhmm[.ss]`：

```
202401010000.00
YYYYMMDDhhmm .ss
```

> ⚠️ **macOS 用户注意：** BSD touch 的 `-d` 不支持自然语言（"7 days ago"不生效），只能用 `-t` 指定精确值。要用自然语言时间，装 coreutils 后用 `gtouch`。

---

### 第 3 层：只改 atime 或只改 mtime

```bash
touch -a file.txt        # 只把访问时间（atime）更新到现在
touch -m file.txt        # 只把修改时间（mtime）更新到现在

touch -a -d "2024-01-01" file.txt   # 只改 atime 到指定值
touch -m -d "2024-01-01" file.txt   # 只改 mtime 到指定值
```

什么场景下需要区分？——当你不想干扰另外一个时间戳时。比如你只是 `cat` 了一下文件，想保留这个"被读取"的证据，但不想让备份系统认为文件内容被修改了。

---

### 第 4 层：从另一个文件复制时间戳 `-r`

```bash
touch -r reference.txt target.txt
# target.txt 的时间戳变得和 reference.txt 一模一样

# 实用场景：批量统一时间戳
touch -r master.log slave1.log slave2.log slave3.log
```

---

## 场景驱动

### 1. 测试日志清理脚本

```bash
# 创建一批"假装过期"的日志
touch -d "30 days ago" old1.log old2.log old3.log
touch -d "3 days ago" recent.log
touch now.log

# 运行清理脚本（应该只删 old1-3）
./cleanup-old-logs.sh
```

### 2. 触发器：强制让 make 重新编译

```bash
# 改了头文件，想让依赖它的所有 .c 文件重新编译
touch header.h
# make 看到 header.h 比 .o 文件新，就会重新编译
```

### 3. 统一备份文件的时间戳

```bash
# 把备份文件的时间改成和源文件一致
cp -p source.txt backup.txt   # -p 保留时间戳，但有时会被覆盖
touch -r source.txt backup.txt # 确保备份的时间戳和源文件一致
```

### 4. 快速生成一批测试文件

```bash
# 生成 test_001.txt 到 test_100.txt
touch test_{001..100}.txt
# 花括号展开出 100 个文件名，touch 全部创建
```

---

## 新手踩坑总结

- **坑一：以为 touch 能"刷新内容"。** touch 只改时间戳，不碰内容。刷新内容用 `> file` 清空，或用编辑器。
- **坑二：`-d` 在 macOS 上行为不同。** BSD touch 不支持自然语言时间。跨平台脚本用 `-t` 指定精确值。
- **坑三：`touch -t` 的格式容易搞错。** 是 `MMDDhhmm` 不是 `DDMMhhmm`——月份在前，日期在后。
- **坑四：touch 已存在的文件不报错。** 如果你想用 `touch newfile` 来创建文件，但 `newfile` 恰好已经存在——touch 静默成功，只是更新了时间戳。如果你期望它报错提示你，应该用 `set -C` 或 `> newfile`（noclobber 模式）。

---

## 什么时候换工具

| 需求 | touch 行不行 | 替代方案 |
|------|------------|---------|
| 创建空文件 | 行 | `> file.txt` 但注意 noclobber |
| 修改时间戳 | 行（核心功能） | — |
| 修改文件内容（如清空） | 不行 | `> file.txt` 或 `truncate -s 0 file.txt` |
| 查看文件时间戳 | 不行 | `ls -l` 或 `stat` |
| 批量创建带内容的文件 | 不行 | 循环 + echo |

---

## 最后

touch 是典型的"名字不好"的命令——它叫 touch，让人以为它就是"摸一下文件来创建"。但它真正的能力在时间轴上：它能让一个文件穿越到过去或未来，而内容不变。

下次你需要测试时间相关的逻辑——日志轮转、缓存过期、备份策略——别等七天。用 `touch -d "7 days ago"`，一秒搞定。
