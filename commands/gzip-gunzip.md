
# gzip / gunzip：单文件压缩——以及为什么它需要和 tar 配合

如果你第一次用 gzip 压缩一个目录，你会得到这样的结果：

```bash
gzip myproject/
# gzip: myproject/ is a directory -- ignored
```

傻眼了吧。

gzip 的设计哲学极其简单：**一次只压缩一个文件。** 它不管目录、不管打包、不管归档——它就做一件事：把一个文件变小。想要同时打包多个文件和压缩？你需要的是 tar + gzip 的组合拳。

---

## 场景引入：为什么不能直接压缩目录

你有一个日志目录，50 个文件，想压缩了发给同事。直觉是 `gzip logs/`——然后它拒绝了你。

这是因为 Unix 哲学：**一个工具只做一件事。** gzip 负责压缩，tar 负责打包。两者配合使用：

```bash
# 打包 + 压缩（最常用）
tar -czf logs.tar.gz logs/

# 过程拆解：
# tar -c：把 logs/ 打包成一个 .tar 文件（归档）
# 管道给 gzip 压缩
# 最终：logs.tar.gz
```

---

## 核心概念：gzip 不是归档工具

| 工具 | 干什么 | 产物 |
|------|--------|------|
| `tar` | 把多个文件打成一个包 | `.tar` |
| `gzip` | 把单个文件压缩 | `.gz` |
| `tar + gzip` | 打包并压缩 | `.tar.gz` 或 `.tgz` |

> 💡 你下载软件时看到的 `.tar.gz` 就是 tar 打包 + gzip 压缩。`.tar.bz2` 是 tar + bzip2，`.tar.xz` 是 tar + xz。

---

## 核心参数

### gzip

```bash
gzip file.txt                  # 压缩为 file.txt.gz（原文件消失！）
gzip -k file.txt               # 压缩但保留原文件
gzip -9 file.txt               # 最高压缩率（1-9，默认 6）
gzip -1 file.txt               # 最快压缩（质量最低）
gzip -v file.txt               # 显示压缩率和结果
```

### gunzip（等价于 `gzip -d`）

```bash
gunzip file.txt.gz             # 解压（.gz 文件消失）
gzip -d file.txt.gz            # 同上
gunzip -k file.txt.gz          # 解压但保留 .gz 文件
gunzip -v file.txt.gz          # 显示过程
```

### 查看压缩文件内容（不解压）

```bash
zcat file.txt.gz               # 把压缩文件内容输出到终端
zless file.txt.gz              # 用 less 分页查看
zgrep "error" file.txt.gz      # 在压缩文件里搜索
```

> 💡 `zcat`/`zless`/`zgrep` 系列是 gzip 附带的强大工具——不需要先解压，直接在压缩文件上操作。

---

## 场景驱动

### 1. 压缩单个大日志文件

```bash
# 日志轮转后，压缩旧日志节省空间
gzip -9 access.log.2025-07-01
# 变成 access.log.2025-07-01.gz，原 .log 文件消失
```

### 2. 在不解压的情况下搜索日志

```bash
# 找出所有压缩日志中 500 错误的行
zgrep " 500 " /var/log/nginx/access.log.*.gz
```

### 3. 快速查看压缩文件内容

```bash
# 不用解压，直接看压缩日志前 20 行
zcat access.log.2025-07-01.gz | head -20
```

### 4. 压缩保留原文件（发送给别人）

```bash
gzip -k report.txt
# 得到 report.txt.gz 和 report.txt 两份
# 把 .gz 发出去，本地还留着原文件
```

---

## gzip vs bzip2 vs xz

| | gzip | bzip2 | xz |
|---|---|---|---|
| 文件后缀 | `.gz` | `.bz2` | `.xz` |
| 压缩速度 | 快 | 中 | 慢 |
| 压缩率 | 中 | 高 | 最高 |
| 解压速度 | 快 | 中 | 中 |
| 适用场景 | 日常使用 | 需要更好压缩率 | 需要最小体积 |

> 💡 日常使用优先 gzip——够快够好。发布软件包时可以考虑 xz（更小的体积）。

---

## 新手踩坑总结

- **坑一：以为 gzip 能压缩目录。** 它不能。配合 tar 使用：`tar -czf archive.tar.gz dir/`。
- **坑二：压缩后原文件消失。** gzip 默认删除原文件！保留原文件用 `-k`。
- **坑三：不知道 zcat/zgrep 系列。** 每次想看压缩文件内容都先 `gunzip`，看完再 `gzip`——效率极低。
- **坑四：`.tgz` 就是 `.tar.gz`。** 两者完全等价，只是后缀名不同。

---

## 最后

gzip 是最纯粹的 Unix 哲学的体现——它只做一件事：把一个文件变小。它不打包、不归档、不管理目录。正因如此，它和 tar 的组合才成了 Linux 世界里最经典的压缩方案。

下次看到 `.tar.gz`，你就知道：它走了两步——先 tar 打包，再 gzip 压缩。
