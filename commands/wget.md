# 为什么 wget 很强，但大多数人只会 `wget URL`？

> `wget` 是命令行里最纯粹的文件下载工具。和 `curl` 不同，wget 的设计哲学是"下了再说"——默认存到文件、支持断点续传、递归下载、镜像整个网站。它不需要你显式告诉它输出到哪里。

## 一、你会遇到的场景

某天你需要下载一个 10GB 的数据集。网络不稳定，下载到 80% 断了。

`curl` 的做法：重新开始——10GB 重来。

wget 的做法：

```bash
wget -c https://example.com/large-dataset.tar.gz
```

`-c` (continue) 从断点继续，只下载剩下的 2GB。

又或者你需要镜像一个文档站离线阅读：

```bash
wget -r -l 2 -np -k https://docs.example.com/
```

递归下载 2 层深度、只限当前目录、链接改写为相对路径——整个站点变成可离线浏览的本地副本。

**这就是 wget 的核心价值：非交互式文件下载——支持断点续传、递归下载、后台运行，专为大文件和批量下载设计。**

> ⚠️ wget 不是预装的（macOS 上需要 `brew install wget`，Linux 上 `apt install wget`）。和 curl 定位不同：curl 是"数据交换工具"，wget 是"下载工具"。

## 二、语法骨架

```
wget  [选项]  [URL]
      ──┬──   ──┬─
       控制     目标
```

## 三、核心能力逐轴拆解

| 能力轴 | 问题 | 核心选项 |
|--------|------|---------|
| 输出轴 | 存到哪？叫什么？ | `-O`(指定文件名)、默认(按远程文件名存) |
| 续传轴 | 断了怎么办？ | `-c`(断点续传)、`-t`(重试次数)、`--retry-connrefused` |
| 后台轴 | 能不能后台跑？ | `-b`(后台)、`-q`(安静) |
| 递归轴 | 能不能下载整个站点？ | `-r`(递归)、`-l`(深度)、`-np`(不爬父目录)、`-k`(改写链接) |
| 控制轴 | 限速？认证？ | `--limit-rate`、`--user`、`--password`、`--header` |

---

### 轴 1：输出轴——"下载到哪？"

```bash
# 下载到当前目录，使用远程文件名
wget https://example.com/file.tar.gz

# 指定文件名
wget -O myname.tar.gz https://example.com/file.tar.gz

# 下载到指定目录
wget -P /tmp/downloads/ https://example.com/file.tar.gz
```

> 💡 wget 默认行为就是"存文件"——你不需要像 curl 那样显式加 `-o`。这是 wget 和 curl 最根本的设计哲学差异。

---

### 轴 2：续传轴——"断了怎么办？"

```bash
# -c：断点续传（Continue）
wget -c https://example.com/large-file.iso

# -t：重试次数（默认 20 次，-t 0 表示无限重试）
wget -t 5 -c https://example.com/unstable-file.iso

# 重试间隔
wget --retry-connrefused --waitretry=10 https://example.com/file
```

> 💡 `-c` 是 wget 的核心优势。curl 也有 `-C -` 做续传，但这是 wget 的默认思维模式——wget 被设计来处理不稳定的网络。

---

### 轴 3：后台轴——"能不能后台跑？"

```bash
# -b：后台下载（日志写到 wget-log）
wget -b https://example.com/large-file.iso

# -q：安静模式（配合 -b 或 cron）
wget -q https://example.com/file.tar.gz

# 组合：后台 + 日志到指定文件
wget -b -o download.log https://example.com/file.iso
```

---

### 轴 4：递归轴——"能不能下载整个站点？"

```bash
# -r：递归下载
# -l 2：最多爬 2 层深度
# -np：不爬父目录（no-parent）
# -k：把链接改写成相对路径（方便离线浏览）
# -p：下载页面所需资源（图片、CSS、JS）
wget -r -l 2 -np -k -p https://docs.example.com/
```

> ⚠️ 递归下载时务必加 `-l` 限制深度，否则可能无限爬取整个互联网。也别忘了 `-np`，防止爬到父目录去。

---

### 轴 5：控制轴——"限速、认证、自定义头"

```bash
# 限速（避免占满带宽）
wget --limit-rate=1M https://example.com/file.iso

# HTTP 基本认证
wget --user=alice --password=secret https://example.com/private/

# 自定义请求头
wget --header='Authorization: Bearer token123' https://api.example.com

# 自定义 User-Agent
wget --user-agent='Mozilla/5.0' https://example.com
```

---

## 四、curl vs wget——什么时候用哪个

| 场景 | curl | wget |
|------|------|------|
| API 调试（POST/PUT/DELETE） | ✅ 天然支持 | ❌ 主要做 GET |
| 输出到 stdout（管道处理） | ✅ 默认行为 | ❌ 默认存文件 |
| 下载大文件 | ✅ 可以 | ✅ **优势**（断点续传、重试） |
| 递归下载/镜像站点 | ❌ 不支持 | ✅ **专为这个设计** |
| 测试响应时间 | ✅ `-w` 输出性能数据 | ❌ 不支持 |
| 后台下载 | ❌ 需要 `&` | ✅ `-b` 内置 |
| 支持协议数量 | 20+ (HTTP/FTP/SMTP/...) | HTTP/HTTPS/FTP |
| macOS 预装 | ✅ | ❌ `brew install wget` |

---

## 五、踩坑清单

- **坑一：wget 默认存文件，不是 stdout** → 想看内容用 `wget -O - URL`（`-O -` 输出到 stdout），或者直接换 curl。
- **坑二：`-c`（断点续传）依赖服务器支持 Range 请求** → 不是所有文件服务器都支持。wget 会尝试，失败就整文件重下。
- **坑三：递归下载不加 `-l` 和 `-np` 是危险的** → 可能爬整个互联网的子目录。至少加 `-l 2 -np`。
- **坑四：`-r` 对动态网站（PHP/Rails）几乎没用** → wget 拿的是 HTML 快照，不会执行 JavaScript。适合静态文档站。
- **坑五：wget 在 macOS 上不存在，需要 `brew install wget`** → curl 预装在 macOS 上，但 curl 不做递归下载。

## 六、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 下载大文件/整站镜像 | wget | 断点续传 + 递归下载 + 智能重试 |
| API 调试/测试 | curl | 请求方法灵活，输出控制精细 |
| BitTorrent 下载 | `aria2c` | wget 不支持 BT 协议 |
| 多线程加速下载 | `aria2c` / `axel` | wget 单线程，大文件不够快 |
| 云端存储同步 | `rclone` | 专门适配 S3/GoogleDrive/Dropbox 等 |

---

> **核心观点：** wget 和 curl 不是竞争关系——wget 是**下载工具**（默认存文件、断点续传、递归），curl 是**数据交换工具**（默认 stdout、多协议、自定义请求）。选择原则：你要下载完整文件 → wget；你要交互式 API 调试 → curl。两个都装，根据场景切换。
