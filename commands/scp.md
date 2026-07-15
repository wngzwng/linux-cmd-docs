# scp：远程拷贝——上传、下载、递归目录、指定端口

> `scp` 是 SSH 生态里最常用的文件传输工具。大多数人只用一个方向：`scp localfile remote:`。其实 scp 能做双向传输、递归目录、指定端口、显示进度，甚至远程到远程。

## 一、你会遇到的场景

某天你要把开发机上 5GB 的数据集传到 GPU 服务器。只有一个终端窗口。

新手的做法：下载到本地，再上传——数据经过你的笔记本，在咖啡店的 Wi-Fi 上跑了两遍。

而真正理解 scp 的人，一行命令让两台服务器直接对话（数据不经过本地）：

```bash
scp -r dev-server:/data/dataset/ gpu-server:/data/
```

**这就是 scp 的核心价值：通过 SSH 在主机间安全复制文件——支持本地↔远程、远程↔远程、递归目录。**

> ⚠️ 现代 OpenSSH 的 scp 默认使用 SFTP 协议（不再是传统的 scp 协议），修复了历史安全问题。行为上对用户透明，但需要知道它依赖 `ssh` 连接。

## 二、语法骨架

```
scp  [选项]  源  目标
     ──┬──   ─┬   ─┬
      参数    从哪   到哪
```

属于**骨架模式 A**：`源 → 目标`。和 rsync、cp 同族。语法和 `cp` 完全一致——你只是把路径加上了 `host:` 前缀。

## 三、核心能力逐轴拆解

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 方向轴 | 哪到哪？ | 本地→远程、远程→本地、远程→远程 |
| 传输轴 | 传什么？怎么传？ | `-r`(递归)、`-p`(保留属性)、`-C`(压缩)、`-P`(端口) |
| 安全轴 | 怎么认证？指定什么密钥？ | `-i`(密钥文件)、`-P`(端口)、`-o`(SSH 选项) |
| 反馈轴 | 看到什么信息？ | `-v`(详细)、`-q`(安静) |

---

### 轴 1：方向轴——"哪到哪？"

> 场景：scp 支持三种方向，语法和 cp 一样——源在前，目标在后。

```bash
# 本地 → 远程
scp file.txt user@host:/path/

# 远程 → 本地
scp user@host:/path/file.txt ./

# 远程 → 远程（数据不经过本地！）
scp user@hostA:/src/ user@hostB:/dst/

# 多文件一次性传输
scp file1.txt file2.txt user@host:/path/
```

> 💡 **远程→远程是 scp 的隐藏大招。** 很多人不知道 scp 支持这个，数据在 A 和 B 之间直接走 SSH，不经过你当前的机器。

---

### 轴 2：传输轴——"传什么？怎么传？"

> 场景：递归传目录、保留时间戳。

```bash
# -r：递归复制目录
scp -r src/ user@host:/backup/

# -p：保留修改时间、访问时间、权限（⚠️ 不是 -P！）
scp -p file.txt user@host:/path/

# -C：传输时压缩（慢网络下很有用）
scp -C largefile.bin user@host:/path/
```

> ⚠️ **`-p`（小写 = preserve）和 `-P`（大写 = port）是最容易搞混的两个选项。** 保留属性用 `-p`，指定端口用 `-P 2222`。

---

### 轴 3：安全轴——"怎么连接？"

> 场景：非标准 SSH 端口、指定密钥文件。

```bash
# -P：指定 SSH 端口
scp -P 2222 file.txt user@host:/path/

# -i：指定私钥文件
scp -i ~/.ssh/mykey file.txt user@host:/path/

# -o：透传 SSH 选项
scp -o StrictHostKeyChecking=no file.txt user@host:/path/
```

---

### 轴 4：反馈轴——"看到什么？"

```bash
# -v：详细输出（排查连接问题）
scp -v file.txt user@host:/path/

# -q：安静模式（脚本里用，不输出进度条）
scp -q file.txt user@host:/path/
```

---

## 四、踩坑清单

- **坑一：`-p`（保留属性）≠ `-P`（端口）** → 小写 preserve，大写 Port。搞混了会收到莫名其妙的错误。
- **坑二：远程路径忘了写 `:`** → `scp file user@host/path` 没有 `:`，会被当成本地路径复制（文件被复制成 `user@host/path` 这个文件名）。
- **坑三：scp 不会提示覆盖确认** → 目标端已有同名文件会静默覆盖。不确定时先用 `ssh host 'ls -l /path/'` 检查。
- **坑四：递归传大量小文件很慢** → scp 对每个文件建立独立传输，海量小文件（如 node_modules）比 rsync 慢得多。这种场景用 rsync。
- **坑五：远程→远程时认证信息要两边都有效** → 需要当前机器能 SSH 到 A 也能到 B，且可能需要 `-3`（通过本机中转）或配置 agent forwarding。

## 五、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 一次性文件传输 | scp | 简单、直接、SSH 生态标准 |
| 增量同步、镜像目录 | rsync | rsync 只传差异，支持断点续传、过滤规则 |
| 大文件传输（网络不稳定） | rsync -P | scp 断了要重传整个文件，rsync 能续传 |
| 交互式文件管理 | `sftp` | scp 是命令行一次性操作，sftp 可以浏览、断续操作 |
| 大量小文件 | `tar + ssh` | `tar czf - src/ \| ssh host 'tar xzf -'` 比 scp 快得多 |

---

> **核心观点：** scp 不需要"学"——它的语法就是 `cp` 加上 `host:`。需要记住的只有三点：① 源在前目标在后 ② `-p` 和 `-P` 的区别 ③ 远程→远程可以不经过本地。剩下的一切都交给 SSH。
