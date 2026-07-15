# Linux 命令实战手册

> 不是命令列表，是排障工具箱。
>
> 每一条命令都从一个真实场景出发——先讲"为什么需要它"，再讲"怎么用好它"。

---

## 命令导航

### 文件与目录操作

| 命令 | 速记 | 教程 |
|------|------|------|
| `pwd` | 你在哪 | [pwd.md](commands/pwd.md) |
| `cd` | 切换目录 | [cd.md](commands/cd.md) |
| `ls` | 看看里面有什么 | [ls.md](commands/ls.md) |
| `tree` | 目录的地图视图 | [tree.md](commands/tree.md) |
| `mkdir` / `rmdir` | 创建和删除目录 | [mkdir-rmdir.md](commands/mkdir-rmdir.md) |
| `touch` | 不只是创建空文件 | [touch.md](commands/touch.md) |
| `rm` | 删除 | [rm.md](commands/rm.md) |
| `mv` | 移动或重命名 | [mv.md](commands/mv.md) |
| `cp` | 复制 | [cp.md](commands/cp.md) |
| `ln` | 软链接和硬链接 | [ln.md](commands/ln.md) |

### 文件内容查看

| 命令 | 速记 | 教程 |
|------|------|------|
| `cat` | 全量查看（小文件） | [cat.md](commands/cat.md) |
| `less` | 分页查看（大文件） | [less.md](commands/less.md) |
| `head` / `tail` | 只看开头或结尾 | [head-tail.md](commands/head-tail.md) |

### 内容搜索与过滤：find + grep

| 命令 | 速记 | 教程 |
|------|------|------|
| `find` | 按条件搜文件 | [find.md](commands/find.md) |
| `grep` | 搜文件内容 | [grep.md](commands/grep.md) |

### 文本处理

| 命令 | 速记 | 教程 |
|------|------|------|
| `sed` | 流式文本编辑 | [sed.md](commands/sed.md) |
| `awk` | 按列处理文本 | [awk.md](commands/awk.md) |
| `cut` | 简单列切割 | [cut.md](commands/cut.md) |
| `tr` | 字符替换/删除 | [tr.md](commands/tr.md) |
| `xargs` | 列表转命令参数 | [xargs.md](commands/xargs.md) |
| `echo` | 输出文本 | [echo.md](commands/echo.md) |
| `parallel` | 并行批量执行 | [parallel.md](commands/parallel.md) |

### 排序与统计

| 命令 | 速记 | 教程 |
|------|------|------|
| `sort` | 排序 | [sort.md](commands/sort.md) |
| `uniq` | 去重（先 sort） | [uniq.md](commands/uniq.md) |
| `wc` | 统计行数/词数/字节数 | [wc.md](commands/wc.md) |

### 权限管理

| 命令 | 速记 | 教程 |
|------|------|------|
| `chmod` | 改权限 | [chmod.md](commands/chmod.md) |
| `chown` | 改所有者 | [chown.md](commands/chown.md) |
| `umask` | 默认权限掩码 | [umask.md](commands/umask.md) |
| `su` / `sudo` | 切换用户 / 提权 | [su-sudo.md](commands/su-sudo.md) |

### 进程管理

| 命令 | 速记 | 教程 |
|------|------|------|
| `ps` | 查看进程快照 | [ps.md](commands/ps.md) |
| `top` | 实时监控（经典） | [top.md](commands/top.md) |
| `htop` | 实时监控（增强版） | [htop.md](commands/htop.md) |
| `kill` | 终止进程 | [kill.md](commands/kill.md) |
| `jobs` / `bg` / `fg` | 作业控制 | [jobs-bg-fg.md](commands/jobs-bg-fg.md) |
| `nohup` | 退出终端后继续运行 | [nohup.md](commands/nohup.md) |
| `systemctl` | 服务管理（systemd） | [systemctl.md](commands/systemctl.md) |

### 系统信息与排障

| 命令 | 速记 | 教程 |
|------|------|------|
| `uname` | 系统/内核/架构信息 | [uname.md](commands/uname.md) |
| `df` | 磁盘空间 | [df.md](commands/df.md) |
| `du` | 谁在占空间 | [du.md](commands/du.md) |
| `free` | 内存够吗 | [free.md](commands/free.md) |
| `uptime` | 运行多久、负载如何 | [uptime.md](commands/uptime.md) |
| `date` | 时间查看与计算 | [date.md](commands/date.md) |
| `which` / `whereis` | 命令在哪 | [which-whereis.md](commands/which-whereis.md) |
| `lsof` | 查看打开的文件 | [lsof.md](commands/lsof.md) |

### 磁盘与存储

| 命令 | 速记 | 教程 |
|------|------|------|
| `mount` / `umount` | 挂载/卸载 | [mount.md](commands/mount.md) |
| `dd` | 磁盘级复制 | [dd.md](commands/dd.md) |

### 压缩与归档

| 命令 | 速记 | 教程 |
|------|------|------|
| `tar` | 打包 + 压缩 | [tar.md](commands/tar.md) |
| `gzip` / `gunzip` | 单文件压缩 | [gzip-gunzip.md](commands/gzip-gunzip.md) |
| `zip` / `unzip` | 跨平台压缩 | [zip-unzip.md](commands/zip-unzip.md) |

### 网络相关

| 命令 | 速记 | 教程 |
|------|------|------|
| `ping` | 能通吗 | [ping.md](commands/ping.md) |
| `curl` | 请求和下载 | [curl.md](commands/curl.md) |
| `wget` | 下载工具 | [wget.md](commands/wget.md) |
| `ssh` | 远程登录 | [ssh.md](commands/ssh.md) |
| `scp` | 远程拷贝 | [scp.md](commands/scp.md) |
| `rsync` | 增量同步 | [rsync.md](commands/rsync.md) |
| `ss` | 查看端口和连接 | [ss.md](commands/ss.md) |
| `netstat` | 端口和连接（旧版） | [netstat.md](commands/netstat.md) |
| `ifconfig` | 网络配置（旧版） | [ifconfig.md](commands/ifconfig.md) |

### 包管理

| 命令 | 适用系统 | 教程 |
|------|---------|------|
| `brew` | macOS | [brew.md](commands/brew.md) |
| `apt` | Debian / Ubuntu | [apt.md](commands/apt.md) |
| `dnf` / `yum` | Fedora / RHEL / CentOS | [dnf-yum.md](commands/dnf-yum.md) |

### Shell 技巧

| 命令/主题 | 速记 | 教程 |
|-----------|------|------|
| `alias` | 命令别名 | [alias.md](commands/alias.md) |
| `history` | 命令历史 | [history.md](commands/history.md) |
| `tmux` | 终端复用器 | [tmux.md](commands/tmux.md) |

### Shell 编程

| 主题 | 教程 |
|------|------|
| 条件表达式：`[ ]` vs `[[ ]]` vs `(( ))` | [conditionals.md](commands/bash/conditionals.md) |
| 变量与引号 | [variables-quoting.md](commands/bash/variables-quoting.md) |
| 引号规则 | [quoting-rules.md](commands/bash/quoting-rules.md) |
| 通配符（globbing） | [globbing.md](commands/bash/globbing.md) |
| 单词拆分 | [word-splitting.md](commands/bash/word-splitting.md) |
| 函数 | [functions.md](commands/bash/functions.md) |
| 循环 | [loops.md](commands/bash/loops.md) |
| 子 Shell | [subshell.md](commands/bash/subshell.md) |
| 退出码 | [exit-codes.md](commands/bash/exit-codes.md) |
| Bash 索引 | [index.md](commands/bash/index.md) |

### 开发工具

| 命令 | 速记 | 教程 |
|------|------|------|
| `git` | 版本控制 | [git.md](commands/git.md) |
| `docker` | 容器 | [docker.md](commands/docker.md) |
| `nvim` | 编辑器 | [nvim.md](commands/nvim.md) |

---

## 快速参考

### 权限数字速查

```
r=4  w=2  x=1
7=rwx  6=rw-  5=r-x  4=r--  0=---
```

### 常用组合速查

```bash
# 磁盘排障三板斧
df -h
du -sh * | sort -h
find / -xdev -type f -size +500M 2>/dev/null

# 进程排障三板斧
ps aux | grep <name>
top -o %MEM
kill -15 <PID>

# 日志排障三板斧
tail -F app.log
grep -i "error" app.log
grep -C 5 "error" app.log

# 网络排障三板斧
ping -c 4 <host>
curl -v <url>
ss -tlnp
```

> ⚠️ **macOS 用户注意**：macOS 的 `sed`、`find` 等命令是 BSD 版，和 Linux 的 GNU 版有细微差异。如果遇到奇怪行为，可以 `brew install coreutils` 安装 GNU 版本，前缀为 `g`（如 `gsed`、`gfind`）。
