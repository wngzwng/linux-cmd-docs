
# tmux：终端复用器——断开重连、多窗格、会话保持

很多人用了好几年 Linux，tmux 永远只会一种用法——`tmux new -s work` 进去，干活，`Ctrl+B D` 出来，再 `tmux attach -t work` 回去。再复杂一点，比如分屏、同步、脚本化，就直接放弃了。其实 tmux 真正的威力，远不止"后台挂会话"这么简单。

---

## 场景引入

某天你在服务器上跑一个数据迁移脚本，预计要跑 40 分钟。你不敢关终端，因为一关 SSH 会话就断了，脚本也挂了。你只能开着电脑干等，手机不敢玩，怕锁屏。

新手的第一反应往往是：
- 用 `nohup` 加 `&` 丢后台 — 然后发现没法实时看进度
- 用 `screen` — 然后被它上古时代的快捷键劝退
- 干脆不关电脑，通宵挂着

而真正熟悉 tmux 的人，只会敲三行：

```bash
tmux new -s migration
# 在里面跑脚本...
Ctrl+B D   # 断开会话，回家睡觉
# 第二天回来
tmux attach -t migration
```

脚本还在跑，输出完好无损，像从未断开过一样。

---

## 核心概念

tmux 的核心逻辑只有一句话：**它是一个终端复用器 — 在同一个 SSH 连接里管理多个终端窗口，且断开后进程不终止。**

听起来和 `nohup` 有点像，但本质完全不同：**nohup 只是让单个进程忽略 SIGHUP 信号，而 tmux 是一个完整的会话管理器，可以同时管理窗口、分屏、协作、脚本化。** 这也是为什么排障时它们经常组合使用（nohup+tmux），而不是互相替代。

---

## 先排雷：最常见的坑

在讲具体能力之前，必须先讲一个新手几乎一定会踩的坑。

```bash
# ❌ 在 tmux 里还用鼠标选中 + 右键复制
# 你会发现：根本选不中！选的不是想要的！

# ✅ 正确的复制方式
Ctrl+B [     # 进入复制模式
Space         # 开始选择（或 v 逐字、V 逐行）
移动光标      # 选择文本
Enter         # 复制到 tmux 剪贴板
Ctrl+B ]     # 粘贴
```

**为什么？** tmux 接管了你的终端缓冲区，鼠标选中是你本地终端的选区，和 tmux 内部的内容不在一个层面。用 `Ctrl+B [` 进入"复制模式"后，你实际上是在 tmux 的缓冲区里操作。

> 💡 如果你不习惯，可以在 `.tmux.conf` 里启用鼠标支持：`set -g mouse on`，之后就可以直接用鼠标选中 + 滚轮了。

---

## 核心能力逐个拆解

### 1. 会话管理（最核心的能力）

场景：你有三个不同的工作任务同时在跑。

```bash
# 创建会话
tmux new -s work       # 命名会话
tmux new -s logs       # 另一个会话

# 断开会话（不终止）
Ctrl+B D   # detach，进程继续跑

# 查看所有会话
tmux ls
tmux list-sessions

# 重新连回
tmux attach -t work
tmux a -t work         # 简写

# 重命名会话
Ctrl+B $

# 关闭会话
tmux kill-session -t logs
tmux kill-server       # 关闭所有（慎用）
```

**关键细节：**
- `tmux new` 和 `tmux attach` 是最常用的两个命令
- 会话名用 `-t` 指定，不是参数位置
- `detach` ≠ `kill`：detach 后进程继续跑，kill 才真的结束

> ⚠️ 纠正一个常见误解：**`Ctrl+B D` 不是退出 tmux，只是断开会话。** 如果直接关掉终端窗口，tmux 会话还在后台好好活着。真正退出 tmux 是在里面输入 `exit` 或 `Ctrl+D`（就像退出普通 shell 一样）。

### 2. 窗口管理（一个会话里多个窗口）

场景：调试一个 web 服务，需要同时看日志、编辑配置、测试 API。

```bash
# 创建新窗口
Ctrl+B c          # create
Ctrl+B ,          # 重命名当前窗口
Ctrl+B 0-9        # 切换到指定编号的窗口
Ctrl+B n / p      # 下一个 / 上一个
Ctrl+B w          # 窗口列表（可视化选择）
Ctrl+B &          # 关闭当前窗口（会提示确认）
```

```bash
# 也可以用命令行操作，适合脚本化：
tmux new-window -t work -n editor
tmux rename-window -t work:1 logs
tmux select-window -t work:2
```

**关键细节：**
- 窗口编号从 0 开始
- 窗口名最好用有意义的名称（`Ctrl+B ,`），不要让它显示默认的"bash"

### 3. 分屏（Pane — 杀手级功能）

场景：一边编辑代码，一边实时看编译输出，一边看文档。

```bash
# 水平分屏（上下）
Ctrl+B "          # 注意是双引号

# 垂直分屏（左右）
Ctrl+B %

# 分屏间跳转
Ctrl+B 方向键     # 往哪个方向就按哪个方向
Ctrl+B o          # 依次切换
Ctrl+B 空格       # 切换布局（循环四种布局）

# 调整分屏大小
Ctrl+B Ctrl+方向键    # 按方向调整
Ctrl+B Alt+方向键     # 按 5 个单元格步进调整（macOS 上可能需要额外配置）

# 关闭当前分屏
Ctrl+B x          # 会提示确认
exit              # 也可以直接 exit
```

⚠️ 这个功能有一个容易混淆的地方：
> **分屏的方向和常见直觉相反。** `"` 是水平分（上下），视觉上是横向切一刀。`%` 是垂直分（左右），视觉上是纵向切一刀。如果你觉得反直觉，在 `.tmux.conf` 里换掉它：
> ```
> bind | split-window -h    # 改成 | 垂直分
> bind - split-window -v    # 改成 - 水平分
> ```

### 4. 同步输入（Pair Debugging 神器）

场景：同时操作多台机器，或者一个命令需要在多个 pane 里都跑一遍。

```bash
Ctrl+B :         # 进入命令模式
set synchronize-panes on    # 打开同步
# 现在在一个 pane 里打字，所有 pane 都收到
set synchronize-panes off   # 关闭同步
```

**什么时候用：**
- 多台服务器同步执行同一个排查命令
- 多个目录同时做同样的操作
- 教学演示时

> ⚠️ **安全警告：** 同步模式下你在 root shell 里敲 `rm -rf /`，所有 pane 都会执行！**先 dry-run 确认你在正确的位置，再开同步。**

---

## 组合用法：把分屏和会话连起来

```bash
# 一个 tmux 会话 + 三个分屏的典型开发布局
tmux new -s dev          # 创建开发会话
Ctrl+B %                 # 垂直分屏：左边编辑器
Ctrl+B "                 # 水平分下屏：右下跑测试

# 或者用命令行一步到位：
tmux new-session -s dev -d                # 后台创建
tmux send-keys -t dev 'nvim .' Enter      # pane 0 启动编辑器
tmux split-window -h -t dev               # 垂直分
tmux send-keys -t dev:0.1 'npm run dev' Enter  # 右侧跑 dev server
tmux split-window -v -t dev:0.1           # 右下再分
tmux send-keys -t dev:0.2 'tail -f logs/app.log' Enter
tmux attach -t dev
```

这条组合里：
- `new-session -d` 在后台创建会话，不给键盘
- `send-keys` 往指定 pane 发送命令，模拟键盘输入
- `split-window -h/-v` 控制分屏方向
- `-t dev:0.1` 表示：`dev` 会话、窗口 `0`、pane `1`

**这才是 tmux 的真实用法 — 把它当开发环境启动脚本用。**

---

## 真实排障流程：连接断了，会话丢了？

**场景**：你在服务器上用 tmux 跑了一夜的数据处理，第二天回来发现 SSH 断了（Wi-Fi 断过、电脑休眠过、公司 VPN 切换过），重新连上去之后…

```
第一步：ssh 连上服务器
第二步：tmux ls       → 确认会话还在（输出：migration: 1 windows）
第三步：tmux attach   → 连回去，看到脚本还在跑，输出停在昨晚离开的地方
第四步：检查进度      → 跑完了没？报错没？日志最后几行是什么？
第五步：exit          → 确认没后续任务后，退出 tmux
```

**整个过程没有丢失任何进度，没有重新跑一次，没有 `nohup` 遗留的进程追踪问题。**

---

## 新手踩坑总结

- **误以为 Ctrl+B D 是退出 tmux** → 它是 detach，进程继续跑；真正退出是 `exit` 或 `Ctrl+D`
- **分屏方向反直觉** → `"` 是上下分，`%` 是左右分
- **复制粘贴失败** → 进入复制模式 `Ctrl+B [`，不要用鼠标
- **同步模式下敲危险命令** → 先确认所有 pane 的目录都对了再操作
- **窗口编号记不住** → 用 `Ctrl+B w` 可视化选择，或用 `Ctrl+B ,` 重命名窗口
- **退出时关掉最后一个窗口会丢会话** → 如果还有窗口在跑，不要 `exit` 最后一个 pane，先 detach

---

## 面试题（可选）

**问题：** 面试官说"我在服务器上跑一个任务，怕断网丢失，用了 `tmux`。但我 detach 之后不小心关掉了终端，第二天 SSH 回来发现会话还在，这是为什么？"

**考察点：**
1. `SIGHUP` 信号机制 — SSH 断开时 shell 收到 SIGHUP 退出，但 tmux 是独立的进程树，不受影响
2. tmux 的 C/S 架构 — `tmux server` 在后台运行，客户端（你看到的界面）可以随时断开重连
3. detach vs kill 的区别 — detach 只是分离客户端，服务器进程继续运行

---

## 什么时候换工具

tmux 不是万能的：

- 如果你只是在本地 Mac 上需要分屏，**macOS 自带的 Split View 或者 iTerm2 的分屏标签页**通常更方便，不需要额外学习一套快捷键
- 如果你只需要在后台跑一个命令然后看输出，**`nohup` + 日志重定向** 比 tmux 轻量得多
- 如果你需要多人实时协作编辑代码，**VS Code Live Share** 比 tmux 多人会话友好得多
- 如果团队都用 VS Code，**Remote-SSH + Terminal 标签页** 不需要学 tmux

tmux 真正不可替代的场景是：**SSH 进服务器、需要长时间运行的进程、需要在一个连接里管理多个终端、且你不想被 SSH 断连打断工作流程。**

---

## 结尾

tmux 是一把钥匙——它不是让你多一个"炫技"的工具，而是帮你消除"SSH 断了就全完了"这种焦虑。有了它，你在服务器上做事的心态会从"赶紧搞完赶紧走"变成"跑着吧，我先去喝杯咖啡"。

你平时在服务器上跑耗时任务，是用什么方案处理断连的？
