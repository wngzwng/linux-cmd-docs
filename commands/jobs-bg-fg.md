
# jobs / bg / fg / Ctrl+Z：被 screen/tmux 掩盖的真正实用的作业控制

现在提到"后台运行"，大多数人第一反应是 tmux 或 screen。但 Shell 内建了一套存在了几十年的作业控制系统——`jobs`、`bg`、`fg`、Ctrl+Z——它们不需要装任何东西，而且在你没开 tmux 时能救命。

---

## 场景引入：你启动了一个编辑器，但不想退出 SSH

你 SSH 到服务器，用 vim 修改 nginx 配置，改到一半突然需要查一个日志里的错误信息。你不想退出 vim——改了一半的配置怎么办？

```bash
# 在 vim 里按 Ctrl+Z
# vim 被挂起到后台，回到 Shell

# 查看日志
tail -50 /var/log/nginx/error.log

# 回到 vim 继续编辑
fg
# 恢复 vim，光标位置、修改状态全在
```

这就是作业控制——你可以暂停、后台运行、恢复前台，不需要新开一个终端窗口。

---

## 核心概念：前台进程 vs 后台进程 vs 暂停

Shell 的作业控制围绕三个状态展开：

| 状态 | 含义 | 如何进入 |
|------|------|---------|
| **前台** (foreground) | 占用终端，你能和它交互 | `command`（默认） |
| **后台** (background) | 运行但不占用终端 | `command &` 或 `bg` |
| **暂停** (stopped) | 暂时冻结，不消耗 CPU | Ctrl+Z |

三个命令在这三种状态之间切换：

```
前台 ←→ 后台：fg（拉到前台） / bg（推到后台）
前台 → 暂停：Ctrl+Z
暂停 → 后台：bg
暂停/后台 → 前台：fg
```

---

## 先排雷：后台进程会在你退出 Shell 时被杀

```bash
# 你这样做
./long-task.sh &

# 然后退出 SSH
exit
# 后台进程被 SIGHUP 信号杀掉——任务跑了一半丢了
```

这个问题有两个解法：

```bash
# 方案一：用 nohup 让进程忽略 SIGHUP
nohup ./long-task.sh &

# 方案二：用 disown 让 Shell "忘掉"这个作业
./long-task.sh &
disown
# Shell 退出时不会再给这个作业发 SIGHUP
```

---

## 核心能力逐层拆解

### 1. 后台启动 `&`

```bash
./server.sh &                 # 直接在后台启动
sleep 100 &                   # 任何命令都行
tar -czf backup.tar.gz /data/ &   # 耗时任务放后台
```

启动后 Shell 输出类似：

```
[1] 12345
# [1] = 作业编号（job ID）
# 12345 = 进程 ID（PID）
```

### 2. 查看后台作业 `jobs`

```bash
jobs
# [1]-  Running   ./server.sh &
# [2]+  Stopped   vim nginx.conf
```

`+` 表示"当前作业"（`fg` 不加编号时恢复它），`-` 表示"上一个当前作业"。

常用选项：

```bash
jobs -l        # 显示 PID
jobs -p        # 只显示 PID
jobs -r        # 只看正在运行的
jobs -s        # 只看暂停的
```

### 3. 把作业拉回前台 `fg`

```bash
fg             # 恢复当前作业
fg %1          # 恢复作业 1
fg %vim        # 恢复命令名含 vim 的作业
fg %?nginx     # 恢复命令行含 nginx 的作业
```

### 4. 让暂停的作业在后台继续 `bg`

```bash
# 一个命令在前台跑着，你按 Ctrl+Z 暂停它
# 然后让它去后台跑
bg             # 让当前作业去后台继续
bg %2          # 让作业 2 去后台继续
```

### 5. 挂起前台进程 Ctrl+Z

```bash
# 任何前台运行的命令，按 Ctrl+Z：
# 进程被暂停（不是终止！），回到 Shell
```

> 💡 很多人只知道 Ctrl+C（终止），不知道 Ctrl+Z（暂停）。后者更优雅——你可以随时恢复。

### 6. 脱离 `disown`

```bash
./long-task.sh &
disown         # 移除最近的后台作业（Shell 退出不影响它）
disown %1      # 移除作业 1
disown -a      # 移除所有后台作业
disown -h %1   # 标记作业 1 使 Shell 不发送 SIGHUP，但保留在 jobs 列表
```

---

## 场景驱动

### 1. 临时退出编辑器查东西

```bash
vim config.json       # 改到一半需要查个东西
# Ctrl+Z              # 挂起 vim

grep "port" config.json  # 查到了
fg                    # 回到 vim
```

### 2. 同时跑多个测试

```bash
./test-api.sh &
./test-db.sh &
./test-cache.sh &
jobs -l               # 看看三个测试的进度
# 做完后可以 fg 拉回来看日志
```

### 3. 一个命令跑太久了，让它去后台

```bash
tar -czf huge-backup.tar.gz /data/
# 跑了 10 分钟还没完，你想干点别的
# Ctrl+Z → bg
# 它去后台跑了，你继续用 Shell
jobs                  # 偶尔看看它还在不在
```

### 4. 退出终端但不丢后台任务

```bash
./critical-job.sh &
disown
exit
# Shell 退出，critical-job.sh 继续运行
```

---

## 与 nohup / tmux / screen 的对比

| 方案 | 适用场景 | 优点 | 缺点 |
|------|---------|------|------|
| `&` + `disown` | 临时后台任务 | 零依赖，快速 | 退出后无法 reconnect 查看输出 |
| `nohup` | 确保任务不被 SIGHUP 杀 | 简单，输出写文件 | 无法交互 |
| `tmux` / `screen` | 需要 reconnect + 交互 | 最强，可断开重连 | 需要安装，有学习成本 |

> 💡 经验法则：**改配置时临时切出来 → Ctrl+Z/fg；跑一个长任务 → `&` + disown；需要断开重连 + 看日志 → tmux。**

---

## 新手踩坑总结

- **坑一：后台用 `&` 就直接退出 SSH。** Shell 退出会给后台任务发 SIGHUP，任务可能被终止。用 `disown` 或 `nohup`。
- **坑二：不知道 Ctrl+Z 的存在。** 只知道 Ctrl+C 终止，不知道可以暂停并恢复。
- **坑三：混淆作业号和 PID。** `fg %1` 用的是 jobs 里的作业号（`[1]`），不是 PID。
- **坑四：用 `bg` 但进程需要 stdin。** 后台进程尝试读 stdin 会被暂停。确保后台任务不需要交互输入。

---

## 最后

jobs / bg / fg 是 Shell 里最被低估的功能组。它们不需要安装、不需要配置、不占额外终端——而且你已经有了。如果你平时还在开两个 SSH 窗口一个编辑一个查日志，试试 Ctrl+Z → 查东西 → fg，你会发现自己的终端使用效率突然翻了一倍。
