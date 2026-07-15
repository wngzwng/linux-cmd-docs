
# history：命令历史——Ctrl+R 搜索、`!!` 复用、排障时先翻旧账

你接手一台出问题的服务器。第一件事不是 `top`，不是 `df`——是 `history`。

看看刚才有人执行过什么命令。也许问题根源就在最后三行里。

history 不只是"翻旧账"。它是一台时间机器——`Ctrl+R` 能让你从几千条历史里瞬间找到三个月前敲过的那条魔鬼命令。

---

## 场景引入：有人刚刚在这台服务器上干了什么

```bash
history
# ......
# 1023  cd /etc/nginx/
# 1024  vim nginx.conf       ← 改了配置
# 1025  rm -rf sites-enabled/* ← 删了所有站点配置！
# 1026  nginx -s reload      ← 重载（然后全站 404）
```

就这几行，你知道了问题是怎么发生的——有人在改 nginx 配置时误删了 `sites-enabled/`。

---

## 核心概念：history 是 Shell 的"操作日志"

history 不是系统审计日志（那是 `auditd` 的事），它是 Shell 的**命令记忆**。

关键属性：
- 每个用户有独立的 history（存在 `~/.bash_history` 或 `~/.zsh_history`）
- 默认只记录命令本身，不记录时间、不记录输出
- 在 Shell 退出时才写入文件（所以当前会话的命令在文件里看不到）

---

## 核心用法

### 查看历史

```bash
history                           # 列出所有历史
history 20                        # 最后 20 条
history | grep "ssh"              # 搜包含 ssh 的历史
```

### 执行历史命令

```bash
!!                                # 重复上一条命令（最常用！）
!100                              # 执行第 100 条
!-2                               # 执行倒数第 2 条
!ssh                              # 执行最近一条以 ssh 开头的命令
sudo !!                           # 以 sudo 重新执行上一条命令（🔥 超常用）
```

### 搜索历史：Ctrl+R

```bash
# 按 Ctrl+R 进入反向搜索模式
(reverse-i-search)`tar': tar -czf backup.tar.gz ./project
# 继续按 Ctrl+R 看更早的匹配
# 按 Ctrl+G 退出搜索
```

> 💡 **`Ctrl+R` 是 history 的最高效用法。** 与其翻几百行历史，不如搜关键词立刻定位。

### 历史扩展（参数复用）

```bash
!$                                # 上一条命令的最后一个参数
# 例：mkdir /very/long/path/name
#     cd !$                      → cd /very/long/path/name

!^                                # 上一条命令的第一个参数
!*                                # 上一条命令的所有参数（不含命令名）
```

---

## 配置：让 history 更好用

```bash
# 在 ~/.bashrc 中添加以下配置

# 增加历史记录上限（默认 500/1000 太小了）
export HISTSIZE=10000             # 内存中保存的条数
export HISTFILESIZE=20000         # 文件中保存的条数

# 记录时间戳
export HISTTIMEFORMAT="%F %T "

# 不记录重复命令
export HISTCONTROL=ignoredups     # 连续相同命令只记一次

# 不记录某些命令（如带密码的命令）
export HISTIGNORE="ls*:cd*:exit:clear"
```

---

## 场景驱动

### 1. 排障：看看之前的人做了什么

```bash
# SSH 到出问题的服务器
history | tail -50        # 看最近 50 条
history | grep -E "rm|chmod|chown|kill"   # 看危险操作
```

### 2. 找回刚才用了但忘了的复杂命令

```bash
# 你刚才敲了一个很长的 find 命令，现在又要用了
Ctrl+R → 输入 "find" → 直到找到

# 或者
history | grep "find" | tail -5
```

### 3. 把操作记录成笔记

```bash
# 调试完成后，把有用的命令导出
history 100 | grep -v "ls\|cd\|cat" > debug-notes.sh
# 过滤掉 ls/cd/cat 等噪音，保留关键步骤
```

### 4. sudo 上一条命令

```bash
# 敲了一条需要 root 的命令，发现没加 sudo
apt install nginx
# Permission denied

# 不用重新打一遍
sudo !!
# 等价于 sudo apt install nginx
```

---

## 新手踩坑总结

- **坑一：当前会话的 history 在另一个终端看不到。** 默认在 Shell 退出时才写入文件。要立即共享，执行 `history -a`（追加到文件）然后在另一个终端 `history -r`（重新加载）。
- **坑二：history 不记录时间戳（默认）。** 想排查"几点几分执行了什么"，需要设 `HISTTIMEFORMAT`。
- **坑三：用 `!100` 执行历史命令前不确认。** 先 `history` 看编号，确认是那条再 `!100`。可以在执行前用 `:p` 只打印不执行：`!100:p`。
- **坑四：敏感信息（密码、密钥）被记在 history 里。** 用 `HISTIGNORE` 过滤，或以空格开头执行命令（`HISTCONTROL=ignorespace` 时以空格开头的命令不记录）。

---

## 最后

history 是 Shell 给你的一台时间机器。它能让你找回三天前用过的 `tar` 命令、查看别人在这台机器上干了什么、甚至帮你重现一个完整的问题排查过程。

如果你还只会按 `↑` 箭头一行行翻——试试 `Ctrl+R`。用一次就会上瘾。
