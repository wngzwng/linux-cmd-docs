# tmux：一个 client-server 会话管理器，假装自己是终端分屏工具

你每天都在 `tmux new -s work`、`Ctrl+B "` 分屏、`Ctrl+B D` 断开。但如果问你：「为什么 `Ctrl+B D` 之后 SSH 断开了，脚本还在跑？tmux 到底把进程藏在了哪里？」——大多数人知道它能做到，但不知道为什么。

tmux 的「表面身份」是终端复用器（分屏、多窗口）。但它的**本质是一个 client-server 会话管理器**：一个后台守护进程（tmux server）管理着所有的 session/window/pane，你的终端只是一个「客户端」，通过 socket 连接到它。

---

## 第一层：内部模型

### 1.1 Client-Server 分离架构

```
你敲 tmux new -s work
    │
    ▼
┌──────────────────────────────────────────────────┐
│ tmux client (前台进程，在你的终端里运行)            │
│  - 接收你的键盘输入                                │
│  - 渲染屏幕到你的终端                               │
│  - 通过 Unix socket 和 server 通信                 │
└──────────┬───────────────────────────────────────┘
           │ Unix socket (/tmp/tmux-<uid>/default)
           ▼
┌──────────────────────────────────────────────────┐
│ tmux server (后台守护进程，独立于你的终端)           │
│  - 管理所有 session / window / pane                │
│  - 持有所有 shell 进程的 pty（伪终端）               │
│  - 即使所有 client 断开，server 继续运行            │
└──────────┬───────────────────────────────────────┘
           │ fork + exec
           ▼
┌──────────────────────────────────────────────────┐
│ Shell 进程 (如 bash / zsh)                        │
│  - 运行在 server 创建的 pty 里                     │
│  - 你跑的所有命令都是这个 shell 的子进程             │
│  - SSH 断开 → client 断开 → server 不受影响          │
│    → shell 继续跑 → 脚本继续执行                    │
└──────────────────────────────────────────────────┘
```

> 💡 **关键洞察：你的脚本从来不是在「tmux 里」跑的——它是在 tmux server 管理的 pty 里，由一个 shell 进程执行的。** tmux client 只是一个「监视器」——它观察并控制 server，但不参与进程的生命周期。你关掉监视器（Ctrl+B D / SSH 断开），server 和它管理的进程不受任何影响。

### 1.2 Session / Window / Pane 三层嵌套

这是 tmux 内部的对象层次：

```
tmux server (一台机器上只有一个)
  │
  ├─ session "work"                         ← 一个「项目」的上下文
  │   ├─ window 0: vim                      ← 一个「全屏」的终端
  │   │   ├─ pane 0: vim (占满整个 window)   ← 一个「终端面板」
  │   │   └─ pane 1: bash (分屏后新增)
  │   │
  │   └─ window 1: htop                     ← 另一个窗口
  │       └─ pane 0: htop
  │
  └─ session "logs"                         ← 另一个独立的会话
      └─ window 0: tail -f /var/log/syslog
```

对象的属性和操作：

```
Session  ← 拥有独立的「工作目录」和「窗口列表」
  ├─ attach / detach：client 连接到 session 或断开
  ├─ rename：给 session 换个名字
  └─ kill：销毁整个 session——里面所有的 window 和进程都会被终止

Window   ← 类似浏览器里的一个 tab
  ├─ 拥有自己的 layout（pane 的排列方式）
  ├─ 拥有自己的 current path（cd 到这个路径）
  └─ rename / kill / swap（和别的 window 换位置）

Pane     ← 最小的终端单元，对应一个 pty（伪终端）
  ├─ 有一个 shell 进程在里面运行
  ├─ split / resize / swap
  └─ 每个 pane 独立接收键盘输入
```

> 💡 **一个 pane = 一个 pty + 一个 shell 进程。** 这就是为什么你可以在一个 window 里同时跑 vim 和 htop——两个 pane 是两个完全独立的 pty，互不干扰。

### 1.3 状态栏：不是「装饰」，是数据源

tmux 的状态栏不是死的字符串——它是一个可编程的数据展示区：

```
#{session_name}    → 当前 session 的名字
#{window_index}    → 当前 window 的编号
#{pane_title}      → 当前 pane 的标题（可以被应用程序设置）
#{host}            → 主机名
#{?client_prefix,NORMAL,INSERT}  → 条件格式：如果 prefix 被按下显示 NORMAL
```

你可以把任何 tmux 内部状态渲染到状态栏上——不是靠外部脚本轮询，而是 tmux server 在状态变化时自动推送给 client。

---

## 第二层：行为机制

### 2.1 按键如何到达 pane 里的进程

```
你按下 'a'
  │
  ▼
终端 → tmux client (解析键序列)
  │
  ├─ 如果 prefix 键 (Ctrl+B) 已被按下：
  │   → client 进入「命令模式」，下一个按键被解释为 tmux 命令
  │   → 比如 'c' → new-window，'"' → split-window
  │
  └─ 否则：
      → client 将 'a' 发送给 server
      → server 将 'a' 写入当前 pane 的 pty
      → pty 的另一端，shell（bash/zsh）读到 'a'
      → shell 将 'a' 回显到 pty（所以你看到 'a' 出现在屏幕上）
      → shell 判断 'a' 是不是一个完整的命令
```

> 💡 **tmux 的 prefix 键（默认 Ctrl+B）不是「快捷键」——它是一个模式切换键。** 按下后 client 进入命令模式，所有输入被 tmux 消费而不是转发给 shell。这和 vim 的 normal/insert 模式是同一个设计思想。

### 2.2 SSH 断开 → 重连的完整链路

```
① SSH 会话断开
   → 你的 SSH client 进程终止
   → SSH server 关闭 pty
   → tmux client 的 stdin/stdout 被关闭
   → tmux client 退出

② tmux server 不受影响
   → server 是一个独立的后台进程
   → client 只是它的一个「观察窗口」
   → 窗口关了，被观察的东西继续存在

③ 你重新 SSH 登录
   → tmux attach -t work
   → 新的 tmux client 启动
   → 通过 Unix socket 连接到 server
   → server 把 session "work" 的当前屏幕状态发送给新 client
   → client 渲染到你的终端
   → 你看到的和断开前一模一样
```

> 💡 **你断开再重连时看到的那个「一模一样的屏幕」，不是录屏回放——它是 tmux server 在断开期间持续维护的「屏幕缓冲区」。** 即使你不在，vim 的输出、htop 的刷新、tail -f 的新行——全都被 server 记录在 pane 的 scrollback buffer 里。

### 2.3 复制模式：不是操作系统剪贴板

tmux 有自己的复制粘贴系统，和操作系统剪贴板独立：

```
① 进入复制模式：Ctrl+B [
   → client 切换到 scrollback buffer 的导航模式
   → 你可以用 vim 键（或 emacs 键，取决于配置）在历史输出中移动光标

② 选择文本：Space 开始，移动光标，Enter 复制
   → 被选中的文本进入 tmux 的 paste buffer（server 内存中）

③ 粘贴：Ctrl+B ]
   → server 把 paste buffer 的内容写入当前 pane 的 pty
   → 就像你在键盘上敲出了这些字符
```

> 💡 可以通过 `set -g set-clipboard on` 把 tmux paste buffer 同步到系统剪贴板（需要 OSC 52 终端支持）。这个配置让 tmux 复制 = 系统复制，不再需要额外的桥接工具。

---

## 第三层：高级模式

### 3.1 脚本化 tmux：把布局写成代码

```bash
#!/bin/bash
# dev-env.sh —— 一键启动开发环境

SESSION="dev"

# 创建 session（detached：不在当前终端 attach）
tmux new-session -d -s "$SESSION" -n "editor"

# window 0 (editor)：vim + 测试运行器
tmux send-keys -t "$SESSION:editor" 'vim .' Enter
tmux split-window -h -t "$SESSION:editor"
tmux send-keys -t "$SESSION:editor.1" 'npm test -- --watch' Enter

# window 1 (server)：开发服务器 + 日志
tmux new-window -t "$SESSION" -n "server"
tmux send-keys -t "$SESSION:server" 'npm run dev' Enter
tmux split-window -v -t "$SESSION:server"
tmux send-keys -t "$SESSION:server.1" 'tail -f logs/development.log' Enter

# window 2 (git)：git 操作 + git log
tmux new-window -t "$SESSION" -n "git"

# attach 到 session
tmux attach -t "$SESSION"
```

> 💡 不需要手动分屏——脚本里 `send-keys` 可以像打字一样把命令「敲」进 pane。团队成员 clone 项目后 `./dev-env.sh` 就能得到一模一样的开发布局。

### 3.2 同步多个 pane 的输入

```bash
# 在 tmux 里
Ctrl+B :
:setw synchronize-panes on
# 现在你在任意 pane 敲的任何东西 → 同时发送到当前 window 的所有 pane
```

> 场景：你 SSH 到了 4 台服务器，需要在所有 4 台上执行同样的命令。开 4 个 pane，同步输入，一起敲——比 Ansible 重，比手动重复 4 次轻，刚好适合救火场景。

### 3.3 嵌套 tmux：本地 + 远程

```
本地 tmux session:
  ├─ window 0: ssh server1
  │   └─ 远程 tmux session (Ctrl+B B 是远程的 prefix，Ctrl+B 是本地的)
  └─ window 1: ssh server2
      └─ 远程 tmux session
```

> 💡 嵌套 tmux 的秘诀：**给外层和内层设置不同的 prefix 键。** 比如外层保持 `Ctrl+B`，内层（远程的 `.tmux.conf`）设置为 `Ctrl+A`。这样 Ctrl+B → 操作本地 tmux，Ctrl+A → 操作远程 tmux，互不干扰。

### 3.4 插件管理：tpm 和 resurrect

```bash
# ~/.tmux.conf
set -g @plugin 'tmux-plugins/tpm'                    # 插件管理器本身
set -g @plugin 'tmux-plugins/tmux-resurrect'          # 保存/恢复 session
set -g @plugin 'tmux-plugins/tmux-continuum'          # 自动保存 + 启动恢复

run '~/.tmux/plugins/tpm/tpm'                         # 初始化 tpm
```

`tmux-resurrect`：`Ctrl+B Ctrl+S` 保存当前所有 session/window/pane 的布局和运行的程序 → `Ctrl+B Ctrl+R` 恢复——重启机器后一键还原整个工作区。

> 本质：resurrect 做的事不是「冻结进程」（那需要 CRIU 级别的技术），而是「记住布局 + 重新启动你告诉它的命令」。它把 tmux 的对象状态序列化到一个文本文件里，恢复时重建 session/window/pane 结构并重新 `send-keys`。

---

## 一句话

> tmux 不是终端分屏工具。tmux 是一个 client-server 架构的会话管理器：server 管理 session/window/pane 三层对象和它们内部的 shell 进程，client 只是一个通过 socket 连接到 server 的「监视器」。你的脚本从来不在 tmux 里跑——它们在 tmux server 创建的 pty 里，由 shell 执行。关掉监视器（SSH 断开 / Ctrl+B D），server 继续运行，这就是 tmux 能抗断连的全部秘密。
