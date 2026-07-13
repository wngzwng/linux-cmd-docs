# Command: tmux

## 1. Purpose（功能认知）

一句话：

> **tmux 是一个终端会话管理器，让你在一个终端中创建、管理多个持久化终端环境。**

解决的问题：

普通 SSH：

```text
SSH 登录服务器
        |
        ↓
运行程序
        |
        ↓
网络断开
        |
        ↓
程序结束 / 状态丢失
```

tmux：

```text
SSH 登录
   |
   ↓
进入 tmux session
   |
   ↓
运行任务
   |
   ↓
断开 SSH
   |
   ↓
任务继续运行
   |
   ↓
重新连接 session
```

核心价值：

* 保持远程任务运行
* 多窗口管理
* 一个终端拆多个工作区域
* 快速切换工作环境

典型场景：

```bash
ssh server

tmux

dotnet run
```

断开：

```bash
Ctrl+b d
```

重新回来：

```bash
tmux attach
```

---

# 2. IO Model（输入输出模型）

tmux 不属于传统：

```
Input → Transform → Output
```

的数据处理型命令。

它属于：

```
状态管理型命令
```

模型：

```
Current State
      |
      ↓
tmux Server 状态
      |
      ↓
Desired State
      |
      ↓
Action
```

---

## tmux 内部模型

理解 tmux 最重要的一张图：

```
tmux server
    |
    |
    +── session
          |
          +── window
          |       |
          |       +── pane
          |       +── pane
          |
          +── window
                  |
                  +── pane
```

关系：

```
Server
  └── Session
          └── Window
                 └── Pane
```

---

## 四个核心对象

| 对象      | 作用     | 类比        |
| ------- | ------ | --------- |
| server  | 后台管理进程 | tmux 引擎   |
| session | 一个工作环境 | 项目        |
| window  | 一个终端标签 | 浏览器 Tab   |
| pane    | 窗口里的分屏 | 编辑器 split |

例如：

开发项目：

```
Session: three-tile

Window 1:
    nvim

Window 2:
    dotnet run

Window 3:
    logs

Window 4:
    git
```

---

# 3. Grammar（语法骨架）

tmux 基础句型：

```bash
tmux [command] [options] [arguments]
```

结构：

```
tmux
 |
 +-- command
 |
 +-- option
 |
 +-- target
```

例如：

创建：

```bash
tmux new -s work
```

拆解：

```
tmux

command:
    new

option:
    -s

argument:
    work
```

---

# 4. Capability Space（能力轴）

tmux 参数不要背。

按能力展开：

---

# 能力轴 1：Session 管理

问题：

> 我要创建、进入、删除哪个工作环境？

| 能力         | 命令              |
| ---------- | --------------- |
| 创建 session | `new`           |
| 查看 session | `ls`            |
| 进入 session | `attach`        |
| 切换 session | `switch-client` |
| 删除 session | `kill-session`  |

---

## 创建

最常用：

```bash
tmux new -s dev
```

创建：

```
session:
    dev
```

---

## 查看

```bash
tmux ls
```

输出：

```
dev: 3 windows
test: 2 windows
```

---

## 进入

```bash
tmux attach -t dev
```

简写：

```bash
tmux a -t dev
```

---

## 删除

```bash
tmux kill-session -t dev
```

---

# 能力轴 2：Window 管理

问题：

> 一个 session 里面管理多个终端？

| 能力    | 快捷键          |
| ----- | ------------ |
| 新建窗口  | `Ctrl+b c`   |
| 下一个窗口 | `Ctrl+b n`   |
| 上一个窗口 | `Ctrl+b p`   |
| 选择窗口  | `Ctrl+b 0~9` |
| 关闭窗口  | `exit`       |

例如：

```
session dev

window 0:
    vim

window 1:
    server

window 2:
    shell
```

---

# 能力轴 3：Pane 分屏

问题：

> 一个窗口里面拆几个终端？

| 动作      | 快捷键              |
| ------- | ---------------- |
| 左右分屏    | `Ctrl+b %`       |
| 上下分屏    | `Ctrl+b "`       |
| 切换 pane | `Ctrl+b 方向键`     |
| 关闭 pane | exit             |
| 调整大小    | `Ctrl+b Alt+方向键` |

例如：

```
+-------------+
|    vim      |
+------+------+ 
| shell| log |
+------+------+
```

---

# 能力轴 4：Session 脱离与恢复

这是 tmux 最核心能力。

进入：

```
tmux
```

运行：

```bash
./solver
```

脱离：

```
Ctrl+b d
```

结果：

```
SSH退出

solver继续运行
```

回来：

```bash
tmux attach
```

---

# 能力轴 5：复制模式

问题：

> 查看历史输出、复制文本

进入：

```
Ctrl+b [
```

移动：

```
↑ ↓
PageUp
```

复制：

```
Space
Enter
```

---

# 能力轴 6：命令模式

所有快捷键最终都会进入：

```
Ctrl+b :
```

例如：

调整窗口：

```text
Ctrl+b :
resize-pane -D 10
```

查看帮助：

```text
Ctrl+b ?
```

---

# 5. Common Composition（场景组合）

---

# 场景 1：SSH服务器跑长期任务

需求：

```
服务器跑模拟1000次
不能因为SSH断开停止
```

模型：

```
状态管理

创建 session
    ↓
运行任务
    ↓
detach
    ↓
恢复
```

命令：

```bash
ssh server

tmux new -s solve

dotnet run -c Release

Ctrl+b d
```

回来：

```bash
tmux attach -t solve
```

---

# 场景 2：开发环境

一个项目：

```
session:
three-tile

window 0:
    nvim

window 1:
    dotnet run

window 2:
    logs

window 3:
    git
```

创建：

```bash
tmux new -s three-tile
```

增加窗口：

```
Ctrl+b c
```

---

# 场景 3：服务器监控

```
window 0:
top

window 1:
tail -f log

window 2:
shell
```

---

# 场景 4：并行任务

例如：

```
session batch

pane1:
    parallel job1

pane2:
    parallel job2

pane3:
    monitor
```

---

# 6. Pitfalls（常见错误）

---

## 错误 1：不知道前缀键

tmux 所有快捷键：

```
Prefix + command
```

默认：

```
Ctrl+b
```

例如：

新窗口：

不是：

```
Ctrl+c
```

而是：

```
Ctrl+b
然后 c
```

---

## 错误 2：把 window 和 pane 混淆

错误理解：

```
window = 分屏
```

实际：

```
session
 |
 window
      |
      pane
```

关系：

```
浏览器
 |
 Tab
 |
 页面区域
```

类似：

```
tmux
 |
 window
 |
 pane
```

---

## 错误 3：直接关闭SSH

如果没有 tmux：

```bash
dotnet run
```

SSH断：

```
进程结束
```

tmux：

```
tmux server
    |
    +-- 程序继续运行
```

---

## 错误 4：不知道 session 名称

不要：

```bash
tmux attach
```

猜。

先：

```bash
tmux ls
```

再：

```bash
tmux attach -t name
```

---

# 7. 五类骨架定位

tmux 属于：

```
C 类：动作 + 目标
```

但是更准确：

```
状态控制器
```

句型：

```bash
tmux 动作 对象
```

例如：

创建：

```bash
tmux new -s work
```

进入：

```bash
tmux attach -t work
```

删除：

```bash
tmux kill-session -t work
```

---

# 8. tmux 心智模型总结

不要记：

```
new
attach
kill-session
switch-client
split-window
select-pane
resize-pane
```

应该记能力轴：

```
tmux

├── Session
│     创建 / 查看 / 进入 / 删除
│
├── Window
│     新建 / 切换 / 关闭
│
├── Pane
│     分屏 / 切换 / 调整
│
├── Lifecycle
│     attach / detach
│
└── Copy
      查看历史 / 复制
```

最终：

```bash
tmux new -s project
```

不是背下来的。

它来自：

```
我要一个工作环境
        ↓
创建 session
        ↓
名字叫 project
        ↓
tmux new -s project
```

tmux 的核心不是「终端分屏工具」。

它更像：

> **一个管理终端工作状态的操作系统。**

理解：

```
server
 └── session
       └── window
             └── pane
```

之后，90% 的 tmux 操作都会自然推导出来。
