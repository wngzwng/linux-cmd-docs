# Linux 命令速查手册

个人日常使用的 Linux 命令整理，按功能分类，简洁实用。

---

## 目录

- [文件与目录操作](#文件与目录操作)
- [文件内容查看](#文件内容查看)
- [内容搜索与过滤](#内容搜索与过滤)
- [文本处理](#文本处理)
- [排序与统计](#排序与统计)
- [权限管理](#权限管理)
- [进程管理](#进程管理)
- [系统信息](#系统信息)
- [磁盘与存储](#磁盘与存储)
- [压缩与归档](#压缩与归档)
- [网络相关](#网络相关)
- [包管理](#包管理)
- [Shell 技巧](#shell-技巧)

---

## 文件与目录操作

### `pwd` — 显示当前工作目录

```bash
pwd
# /Users/name/project
```

### `cd` — 切换目录

```bash
cd /path/to/dir    # 进入指定目录
cd ~               # 进入 home 目录
cd -               # 返回上一个目录
cd ..              # 进入上级目录
```

### `ls` — 列出目录内容

```bash
ls                 # 列出当前目录
ls -l              # 详细信息（权限、大小、日期）
ls -a              # 显示所有文件（包括隐藏文件）
ls -lh             # 人性化文件大小（K/M/G）
ls -lt             # 按修改时间排序
ls -lS             # 按文件大小排序
ls -R              # 递归列出子目录
```

### `tree` — 以树形结构显示目录

```bash
tree               # 显示目录树
tree -L 2          # 仅显示 2 层深度
tree -I node_modules   # 排除 node_modules
tree -F            # 目录加 /，可执行加 *
```

### `mkdir` — 创建目录

```bash
mkdir dir              # 创建单个目录
mkdir -p a/b/c         # 递归创建多级目录
mkdir -m 755 dir       # 创建并设置权限
```

### `rmdir` — 删除空目录

```bash
rmdir dir          # 删除空目录
rmdir -p a/b/c     # 递归删除空父目录
```

### `touch` — 创建空文件 / 更新时间戳

```bash
touch file.txt     # 创建空文件（已存在则更新 mtime）
touch -t 202401010000 file.txt   # 设置指定时间戳
```

### `rm` — 删除文件或目录

```bash
rm file.txt        # 删除文件
rm -r dir/         # 递归删除目录及内容
rm -f file.txt     # 强制删除（不提示）
rm -rf dir/        # 递归强制删除（⚠️ 谨慎使用）
```

### `mv` — 移动或重命名文件/目录

```bash
mv file.txt /tmp/         # 移动到目标目录
mv old.txt new.txt        # 重命名
mv -i file.txt /tmp/      # 覆盖前提示
mv -v file.txt /tmp/      # 显示移动过程
```

### `cp` — 复制文件或目录

```bash
cp file.txt /tmp/          # 复制文件
cp -r dir/ /tmp/           # 递归复制目录
cp -a dir/ /tmp/           # 归档复制（保留权限、链接等）
cp -i file.txt /tmp/       # 覆盖前提示
cp -p file.txt /tmp/       # 保留文件属性（mtime 等）
cp -v file.txt /tmp/       # 显示复制过程
```

### `ln` — 创建链接

```bash
ln -s /real/path link      # 创建软链接（符号链接）
ln /real/path link         # 创建硬链接
```

---

## 文件内容查看

### `cat` — 查看文件内容

```bash
cat file.txt               # 显示全部内容
cat -n file.txt            # 显示行号
cat > file.txt             # 创建并写入内容（Ctrl+D 结束）
```

### `less` / `more` — 分页查看

```bash
less file.txt              # 分页查看（支持上下翻页）
more file.txt              # 分页查看（仅支持向下翻页）
```

> `less` 中常用操作：`/关键词` 搜索，`n` 下一个，`q` 退出，`G` 末尾，`gg` 开头

### `head` — 查看文件开头

```bash
head file.txt              # 显示前 10 行
head -n 20 file.txt        # 显示前 20 行
head -c 100 file.txt       # 显示前 100 字节
```

### `tail` — 查看文件末尾

```bash
tail file.txt              # 显示后 10 行
tail -n 20 file.txt        # 显示后 20 行
tail -f app.log            # 实时跟踪日志追加（Ctrl+C 退出）
tail -F app.log            # 跟踪并支持日志轮转
```

---

## 内容搜索与过滤

### `find` — 查找文件

```bash
find . -name "*.txt"                 # 按名称查找
find . -iname "readme*"              # 忽略大小写
find . -type f                       # 只找文件
find . -type d                       # 只找目录
find . -size +10M                    # 大于 10MB 的文件
find . -mtime -7                     # 7 天内修改过的文件
find . -name "*.log" -delete         # 找到并删除
find . -name "*.js" -exec wc -l {} \;   # 找到后执行命令
```

### `grep` — 搜索文件内容

```bash
grep "keyword" file.txt              # 文件中搜索关键词
grep -r "keyword" ./                 # 递归搜索目录
grep -i "keyword" file.txt           # 忽略大小写
grep -n "keyword" file.txt           # 显示行号
grep -c "keyword" file.txt           # 统计匹配行数
grep -v "exclude" file.txt           # 反向匹配（排除）
grep -l "keyword" *.txt              # 只显示匹配的文件名
grep -A 3 "error" log.txt            # 匹配行 + 后 3 行
grep -B 3 "error" log.txt            # 匹配行 + 前 3 行
grep -C 3 "error" log.txt            # 匹配行 + 前后各 3 行
grep -E "err|warn" log.txt           # 扩展正则（| 表示或）
```

> 常用别名：`alias grep='grep --color=auto'`

---

## 文本处理

### `sed` — 流式文本编辑

```bash
sed 's/old/new/g' file.txt           # 替换所有 old 为 new
sed -i 's/old/new/g' file.txt        # 直接修改文件（原地替换）
sed -i '' 's/old/new/g' file.txt     # macOS 需要空备份后缀
sed -n '5,10p' file.txt              # 显示第 5-10 行
sed '/pattern/d' file.txt            # 删除匹配行
```

### `awk` — 文本分析工具

```bash
awk '{print $1}' file.txt            # 打印第 1 列
awk '{print $1, $NF}' file.txt       # 第 1 列和最后一列
awk -F',' '{print $1}' data.csv      # 指定分隔符（逗号）
awk '/error/ {print}' log.txt        # 匹配 error 的行
awk '{sum+=$1} END {print sum}' nums.txt   # 求第一列总和
```

### `cut` — 按列切割文本

```bash
cut -d':' -f1 /etc/passwd            # 以 : 分隔取第一列
cut -c1-5 file.txt                   # 取每行第 1-5 个字符
cut -f1,3 file.txt                   # 取第 1、3 列（默认 tab 分隔）
```

### `tr` — 字符替换

```bash
echo "hello" | tr 'a-z' 'A-Z'       # 小写转大写
cat file.txt | tr -d '\r'           # 删除 Windows 回车符
cat file.txt | tr -s ' '            # 压缩连续空格
```

### `xargs` — 将标准输入转为参数

```bash
find . -name "*.log" | xargs rm     # 找到并删除
cat urls.txt | xargs curl -O        # 批量下载
find . -type f | xargs wc -l        # 统计所有文件行数
```

---

## 排序与统计

### `sort` — 排序

```bash
sort file.txt                        # 按字母排序
sort -n file.txt                     # 按数字排序
sort -r file.txt                     # 倒序
sort -k2 file.txt                    # 按第 2 列排序
sort -t',' -k3 -n data.csv           # 逗号分隔，按第 3 列数字排序
sort -u file.txt                     # 排序并去重
```

### `uniq` — 去重（需先排序）

```bash
sort file.txt | uniq                 # 去重
sort file.txt | uniq -c              # 统计重复次数
sort file.txt | uniq -d              # 只显示重复行
```

### `wc` — 统计行、词、字符数

```bash
wc file.txt                          # 行数 / 词数 / 字节数
wc -l file.txt                       # 只统计行数
wc -w file.txt                       # 只统计词数
wc -c file.txt                       # 只统计字符数
wc -l *.txt                          # 统计多个文件
```

---

## 权限管理

### `chmod` — 修改文件权限

```bash
chmod 755 script.sh                  # rwxr-xr-x（数字模式）
chmod u+x script.sh                  # 为文件所有者添加执行权限
chmod g-w file.txt                   # 移除组写的权限
chmod -R 755 dir/                    # 递归修改目录权限
chmod a+r file.txt                   # 所有人可读
```

> 常用权限：`755`（可执行文件）, `644`（普通文件）, `600`（私密文件）

### `chown` — 修改文件所有者

```bash
chown user file.txt                  # 修改文件所有者
chown user:group file.txt            # 同时修改所有者和组
chown -R user:group dir/             # 递归修改目录
```

### `umask` — 设置默认权限掩码

```bash
umask                                # 查看当前 umask
umask 022                            # 设置默认权限（文件 644, 目录 755）
```

---

## 进程管理

### `ps` — 查看进程

```bash
ps aux                               # 查看所有进程
ps aux | grep nginx                  # 查找特定进程
ps -ef                               # 标准格式全进程列表
ps -eo pid,ppid,cmd,%mem,%cpu        # 自定义输出列
```

### `top` / `htop` — 实时进程监控

```bash
top                                  # 进程监控（按 q 退出）
top -o %MEM                          # 按内存排序
htop                                 # 增强版（更友好的交互）
```

> `top` 中常用：`1` 查看每个 CPU，`M` 按内存排序，`P` 按 CPU 排序

### `kill` — 终止进程

```bash
kill 1234                            # 正常终止（SIGTERM）
kill -9 1234                         # 强制杀死（SIGKILL，⚠️ 谨慎）
kill -15 1234                        # 优雅终止（SIGTERM，默认）
kill -HUP 1234                       # 重载配置（SIGHUP）
killall nginx                        # 按名称杀死进程
```

### `jobs` / `bg` / `fg` — 作业控制

```bash
command &                            # 后台运行
jobs                                 # 列出后台作业
bg %1                                # 将作业 1 放到后台继续运行
fg %1                                # 将作业 1 调回前台
Ctrl+Z                               # 暂停当前任务
```

### `nohup` — 退出会话后继续运行

```bash
nohup long-running.sh &              # 后台运行，忽略挂起信号
nohup command > output.log 2>&1 &    # 重定向输出到日志
```

---

## 系统信息

### `uname` — 查看系统信息

```bash
uname -a                             # 全部系统信息
uname -s                             # 内核名称
uname -r                             # 内核版本
uname -m                             # 架构（x86_64 / arm64）
```

### `df` — 查看磁盘使用情况

```bash
df -h                                # 人性化显示磁盘空间
df -h /                              # 查看特定分区
df -i                                # 查看 inode 使用情况
```

### `du` — 查看文件/目录大小

```bash
du -sh dir/                          # 目录总大小
du -h --max-depth=1                  # 显示第一级子目录大小
du -sh * | sort -h                   # 按大小排序显示所有项
```

### `free` — 查看内存使用

```bash
free -h                              # 人性化显示内存
free -m                              # 以 MB 为单位
free -s 2                            # 每 2 秒刷新一次
```

### `uptime` — 查看系统运行时间

```bash
uptime                               # 运行时间 + 负载
```

### `date` — 查看/设置日期时间

```bash
date                                 # 当前时间
date +%Y-%m-%d                       # 2024-01-01
date +%Y%m%d_%H%M%S                  # 20240101_120000（文件名友好）
```

### `which` / `whereis` — 定位命令路径

```bash
which python                         # 查找可执行文件路径
whereis python                       # 查找二进制、源码、man 页
```

---

## 磁盘与存储

### `mount` / `umount` — 挂载/卸载

```bash
mount                                # 查看已挂载设备
mount /dev/sdb1 /mnt/data            # 挂载设备到目录
umount /mnt/data                     # 卸载
umount -l /mnt/data                  # 强制卸载（lazy）
```

### `df`（见系统信息）

### `du`（见系统信息）

### `dd` — 磁盘拷贝/转换

```bash
dd if=/dev/zero of=file bs=1M count=100   # 创建 100MB 文件
dd if=/dev/sda of=backup.img bs=4M        # 备份磁盘（⚠️ 谨慎）
```

---

## 压缩与归档

### `tar` — 打包和解压

```bash
tar -cvf archive.tar dir/            # 打包目录（不压缩）
tar -xvf archive.tar                 # 解包
tar -czvf archive.tar.gz dir/        # 打包并 gzip 压缩
tar -xzvf archive.tar.gz             # 解压 tar.gz
tar -cjvf archive.tar.bz2 dir/       # 打包并 bzip2 压缩
tar -xjvf archive.tar.bz2            # 解压 tar.bz2
tar -tf archive.tar.gz               # 查看压缩包内容
```

> 参数含义：`c` 创建, `x` 解压, `z` gzip, `j` bzip2, `v` 显示过程, `f` 指定文件名, `t` 查看内容

### `gzip` / `gunzip` — gzip 压缩

```bash
gzip file.txt                        # 压缩为 file.txt.gz
gzip -d file.txt.gz                  # 解压
gzip -k file.txt                     # 压缩并保留原文件
gunzip file.txt.gz                   # 解压
```

### `zip` / `unzip` — ZIP 压缩

```bash
zip -r archive.zip dir/              # 压缩目录
zip archive.zip file1.txt file2.txt  # 压缩多个文件
unzip archive.zip                    # 解压
unzip -l archive.zip                 # 查看 ZIP 内容
unzip -d /target/ archive.zip        # 解压到指定目录
```

---

## 网络相关

### `ping` — 测试网络连通性

```bash
ping -c 4 google.com                 # 发送 4 个包后停止
ping -i 2 google.com                 # 每 2 秒发一个包
```

### `curl` — HTTP 请求工具

```bash
curl https://api.example.com         # GET 请求
curl -O https://example.com/file.zip # 下载文件并保存
curl -o custom.zip https://example.com/file.zip   # 指定保存文件名
curl -H "Authorization: Bearer xxx" https://api   # 带请求头
curl -d '{"key":"value"}' -H "Content-Type: application/json" https://api  # POST JSON
curl -L http://bit.ly/short          # 跟随重定向
curl -v https://example.com          # 显示详细请求/响应
```

### `wget` — 下载工具

```bash
wget https://example.com/file.zip    # 下载文件
wget -c https://example.com/big.zip  # 断点续传
wget -O out.zip https://example.com/file   # 指定输出文件名
wget -r -np https://example.com/dir/       # 递归下载目录
```

### `ssh` — 远程登录

```bash
ssh user@hostname                    # SSH 登录
ssh -p 2222 user@hostname            # 指定端口
ssh -i ~/.ssh/key.pem user@hostname  # 使用密钥登录
ssh user@hostname "ls -l"            # 远程执行命令
ssh -L 8080:localhost:80 user@host   # 本地端口转发
```

### `scp` — 远程拷贝文件

```bash
scp file.txt user@host:/remote/path           # 本地 → 远程
scp user@host:/remote/file.txt ./             # 远程 → 本地
scp -r dir/ user@host:/remote/path            # 递归拷贝目录
scp -P 2222 file.txt user@host:/remote/path   # 指定端口
```

### `rsync` — 高效同步/备份

```bash
rsync -av dir/ user@host:/backup/             # 同步目录到远程
rsync -av --delete dir/ user@host:/backup/    # 同步并删除远程多余文件
rsync -avz dir/ user@host:/backup/            # 压缩传输
```

### `netstat` / `ss` — 网络连接查看

```bash
netstat -tlnp                         # 查看 TCP 监听端口
netstat -an | grep :80                # 查看 80 端口连接
ss -tlnp                              # 新版（更快）
ss -s                                 # 网络统计摘要
```

### `ip` / `ifconfig` — 网络接口配置

```bash
ip addr                               # 查看 IP 地址（推荐）
ip link                               # 查看网络接口
ifconfig                              # 旧版查看网络信息
```

---

## 包管理

### `brew` — macOS 包管理

```bash
brew install wget                     # 安装包
brew uninstall wget                   # 卸载
brew update                           # 更新 Homebrew 自身
brew upgrade                          # 升级所有已安装包
brew search wget                      # 搜索包
brew list                             # 列出已安装包
brew info wget                        # 查看包信息
brew services start nginx             # 启动后台服务
```

### `apt` — Debian/Ubuntu 包管理

```bash
apt update                            # 更新软件源
apt install nginx                     # 安装包
apt remove nginx                      # 卸载包
apt purge nginx                       # 卸载并删除配置文件
apt upgrade                           # 升级所有包
apt search keyword                    # 搜索包
apt list --installed                  # 列出已安装包
```

### `dnf` / `yum` — Fedora/CentOS 包管理

```bash
dnf install nginx                     # 安装包
dnf remove nginx                      # 卸载
dnf update                            # 升级所有包
dnf search keyword                    # 搜索包
dnf list installed                    # 列出已安装包
```

### `npm` / `yarn` — Node.js 包管理

```bash
npm install package                   # 安装包
npm install -g package                # 全局安装
npm uninstall package                 # 卸载
npm update                            # 更新包
npm list --depth=0                    # 列出顶层依赖

yarn add package                      # 添加依赖
yarn remove package                   # 移除依赖
yarn upgrade package                  # 升级
yarn install                          # 安装所有依赖
```

---

## Shell 技巧

### 管道 `|` — 串联命令

```bash
cat file.txt | grep "error" | wc -l   # 查找 error 并统计行数
ps aux | grep nginx | awk '{print $2}' # 查找 nginx 进程 PID
```

### 重定向

```bash
command > output.txt                  # 标准输出 → 文件（覆盖）
command >> output.txt                 # 标准输出 → 文件（追加）
command 2> error.txt                  # 标准错误 → 文件
command &> output.txt                 # 全部输出 → 文件
command > /dev/null                   # 丢弃输出
command 2>&1                          # 合并错误到标准输出
```

### 通配符

```bash
*.txt                                 # 所有 .txt 文件
file??.txt                            # file 后跟两个任意字符
[abc]*.txt                            # 以 a/b/c 开头的 .txt 文件
```

### 命令组合

```bash
cmd1 && cmd2                          # cmd1 成功后才执行 cmd2
cmd1 || cmd2                          # cmd1 失败后才执行 cmd2
cmd1 ; cmd2                           # 顺序执行，无论成功失败
$(command)                            # 命令替换（将结果嵌入）
```

### `alias` — 命令别名

```bash
alias ll='ls -lh'                     # 设置别名
alias grep='grep --color=auto'
unalias ll                            # 移除别名
alias                                 # 查看所有别名
```

### `history` — 命令历史

```bash
history                               # 查看历史命令
!!                                    # 重复上一条命令
!100                                  # 执行第 100 条历史命令
!$                                    # 上一条命令的最后一个参数
Ctrl+R                                # 搜索历史命令
```

### 快捷键

| 快捷键 | 作用 |
|--------|------|
| `Ctrl+A` | 跳到行首 |
| `Ctrl+E` | 跳到行尾 |
| `Ctrl+U` | 删除光标前所有内容 |
| `Ctrl+K` | 删除光标后所有内容 |
| `Ctrl+W` | 删除前一个词 |
| `Ctrl+L` | 清屏 |
| `Ctrl+R` | 搜索历史命令 |
| `Ctrl+C` | 终止当前命令 |
| `Ctrl+Z` | 暂停当前命令 |
| `Tab` | 自动补全 |
| `Tab Tab` | 列出所有补全候选项 |

---

## 快速参考

### 权限数字速查

```
r=4  w=2  x=1
7=rwx  6=rw-  5=r-x  4=r--  0=---
755 = 所有者(7) + 组(5) + 其他人(5)
644 = 所有者(6) + 组(4) + 其他人(4)
```

### 特殊路径符号

```
.        当前目录
..       上级目录
~        Home 目录
-        上一个目录
/        根目录
```

---

> ⚠️ 提示：macOS 的 `sed`、`find` 等命令与 Linux 略有差异（如 BSD 版 vs GNU 版）。若在 macOS 上遇到问题，可安装 `coreutils` 获取 GNU 版本。
