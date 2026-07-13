`nvim`、`tmux`、`docker` 这三个命令非常适合验证你提出的「五步模型」，因为它们刚好代表三种不同范式：

| 命令     | 类型          | 核心抽象         |
| ------ | ----------- | ------------ |
| nvim   | 编辑器 / 状态型工具 | **编辑状态机**    |
| tmux   | 会话管理器       | **终端对象层级管理** |
| docker | 容器控制器       | **资源生命周期管理** |

它们不像 `grep/find/tar` 那样是纯数据流工具。

学习它们，第二步 IO 模型需要升级：

```
数据型命令：

Input → Transform → Output


状态型命令：

Current State
      ↓
  用户意图
      ↓
 Desired State
      ↓
 Action
```

---

# 一、nvim：不是文本编辑器，而是「编辑状态机」

## 1. Purpose

一句话：

> nvim 是一个管理文本缓冲区、窗口、模式、插件状态的可编程编辑环境。

很多人理解：

```
nvim = 打开文件 → 修改 → 保存
```

这个理解太浅。

更准确：

```
文件
 ↓
Buffer
 ↓
Window
 ↓
Mode
 ↓
Command
 ↓
File
```

nvim 管的是：

```
编辑状态
```

---

# 2. Object Model（对象模型）

nvim 必须先画对象：

```
Neovim Instance
        |
        |
    ┌───┴────┐
    |        |
 Buffer    Window
    |        |
 文件内容   显示区域


 Tab
 |
 多窗口布局
```

还有：

```
Buffer
 |
 Text State

Window
 |
 View State

Mode
 |
 Interaction State
```

所以：

```
:e file.txt
```

不是：

```
打开文件
```

而是：

```
创建/切换一个 Buffer
```

---

# 3. IO 模型

nvim：

```
File
 |
 ↓
Buffer
 |
 ↓
Edit Operation
 |
 ↓
Buffer
 |
 ↓
Write
 |
 ↓
File
```

注意：

编辑过程中：

```
磁盘文件 ≠ 当前内容
```

中间有：

```
Buffer
```

这解释很多命令：

例如：

```
:w
```

不是保存编辑器。

它是：

```
Buffer → File
```

---

# 4. Grammar（语法骨架）

nvim 命令主要有三种 DSL：

---

## A. Normal Mode DSL

对象：

```
光标
```

语法：

```
动作 + 对象
```

例如：

删除：

```
d + motion
```

移动：

```
w
```

组合：

```
dw
```

含义：

```
delete
+
word
```

---

更多：

```
d$
```

=

```
delete
+
to end of line
```

核心：

```
Verb + Motion
```

类似：

```
Linux command + option
```

---

## B. Ex Command DSL

形式：

```
:
command arguments
```

例如：

```
:e file
```

结构：

```
:
动作
目标
```

类似：

```
docker run image
```

---

## C. Plugin DSL

例如：

```
:Telescope find_files
```

结构：

```
插件命令
+
动作
+
参数
```

---

# 5. Capability Axis

nvim 能力轴：

| 能力         | 问题   | 命令     |
| ---------- | ---- | ------ |
| Buffer     | 编辑什么 | :e     |
| Window     | 怎么显示 | :split |
| Motion     | 怎么移动 | w,f,$  |
| Edit       | 怎么修改 | d,c,y  |
| Search     | 怎么定位 | /      |
| Replace    | 怎么替换 | :s     |
| Automation | 怎么扩展 | Lua    |

---

# 场景：

## "快速修改代码"

需求：

```
定位
 ↓
修改
 ↓
格式化
 ↓
保存
```

nvim：

```
/
搜索

c
修改

=
格式化

:w
保存
```

不是记命令。

是：

```
定位能力
+
编辑能力
+
转换能力
```

---

# 二、tmux：真正的对象模型命令

tmux 是非常典型的：

> 状态管理型命令

---

# 1. Purpose

一句话：

> tmux 管理持久化终端会话，并提供窗口和面板复用。

不是：

```
开多个terminal
```

而是：

```
管理terminal状态
```

---

# 2. Object Model

tmux 必须先画：

```
tmux server

    |
    |
 sessions

    |
    |
 windows

    |
    |
 panes

    |
    |
 shell process
```

完整：

```
Server
 |
 +-- Session
        |
        +-- Window
              |
              +-- Pane
                    |
                    +-- Process
```

所以：

```
tmux send-keys -t dev:0.1
```

拆：

```
send-keys

目标:

dev
 |
 session

:
0
 |
 window

.
1
 |
 pane
```

就是：

```
给 dev session
第0窗口
第1面板
发送键盘事件
```

---

# 3. IO 模型

tmux：

不是：

```
Input → Output
```

而是：

```
User Command

      ↓

tmux Server State

      ↓

Terminal Layout Change

      ↓

Process Event
```

例如：

```
tmux split-window
```

不是创建shell。

流程：

```
tmux server
 |
 创建 pane
 |
 fork shell
 |
 attach terminal
```

---

# 4. Grammar

tmux：

```
tmux command [target] [options]
```

例如：

创建：

```
tmux new-session -s dev
```

结构：

```
动作
+
目标名称
```

发送：

```
tmux send-keys \
-t dev:0.1 \
"dotnet test" Enter
```

结构：

```
动作
+
目标对象
+
事件
```

---

# 5. Capability Axis

| 能力轴       | 问题   | 命令           |
| --------- | ---- | ------------ |
| Session   | 管理会话 | new-session  |
| Window    | 管理窗口 | new-window   |
| Pane      | 管理布局 | split-window |
| Target    | 指定对象 | -t           |
| Input     | 注入事件 | send-keys    |
| Output    | 获取状态 | capture-pane |
| Lifecycle | 销毁   | kill-session |

---

# tmux 最重要能力：

## 自动化

例如：

CI：

```
tmux new-session -d -s build

tmux send-keys \
-t build \
"./build.sh" Enter
```

本质：

```
程序控制终端
```

所以 tmux 是：

```
Terminal API
```

---

# 三、docker：状态控制器

docker 是最典型的：

```
Current State → Desired State
```

---

# 1. Purpose

一句话：

> docker 管理容器生命周期和运行环境。

---

# 2. Object Model

docker：

```
Docker Engine

 |
 +-- Image

 |
 +-- Container

 |
 +-- Volume

 |
 +-- Network
```

核心：

```
Image
  |
 create
  |
Container
  |
 start
  |
Running Process
```

---

# 3. IO 模型

docker：

不是：

```
文件 → 转换 → 文件
```

而是：

```
声明目标

docker run nginx


当前:

没有container


Action:

create + start


结果:

running container
```

---

# 4. Grammar

docker：

```
docker <object> <action> <options>
```

现代 docker CLI：

```
docker container run nginx
```

或者：

```
docker run nginx
```

拆：

```
docker

对象:
container

动作:
run

参数:
nginx
```

---

# 5. Capability Axis

| 能力        | 问题   | 命令                 |
| --------- | ---- | ------------------ |
| Image     | 从哪里来 | pull               |
| Container | 创建运行 | run                |
| Lifecycle | 状态变化 | start/stop/restart |
| Inspect   | 查看状态 | inspect            |
| Logs      | 查看输出 | logs               |
| Exec      | 进入内部 | exec               |
| Network   | 连接   | network            |
| Volume    | 持久化  | volume             |

---

# 场景：

## 启动一个服务

需求：

```
运行 nginx
```

docker：

```
docker run nginx
```

背后：

```
寻找image

nginx image
       |
创建container
       |
启动process
       |
绑定network
```

---

# 四、三个命令放一起比较

## 抽象层不同

```
nvim

管理：
文本状态


tmux

管理：
终端状态


docker

管理：
系统资源状态
```

---

## 都是状态机

### nvim

```
Buffer State

NORMAL
INSERT
VISUAL
COMMAND
```

---

### tmux

```
Server State

Session
 Window
  Pane
```

---

### docker

```
Engine State

Image
Container
Network
Volume
```

---

# 五、对应你的五步模型

| 步骤              | nvim               | tmux                 | docker                  |
| --------------- | ------------------ | -------------------- | ----------------------- |
| Purpose         | 编辑文本               | 管理终端会话               | 管理容器                    |
| IO              | File→Buffer→File   | Command→Server State | Desired→Current         |
| Grammar         | 动作+对象              | 命令+target            | 对象+动作                   |
| Capability Axis | Buffer/Edit/Motion | Session/Window/Pane  | Image/Container/Network |
| Scenario        | 编辑任务               | 终端自动化                | 部署服务                    |

---

# 六、一个重要结论

你的模型里面其实还可以增加一个前置判断：

```
Step 0:

这个命令属于哪种世界？
```

目前 Linux 命令至少分：

```
1. 数据流 DSL

grep
find
sed
awk
tar


2. 文件系统 DSL

cp
mv
rsync


3. 状态管理 DSL

tmux
docker
systemctl
kubectl


4. 查询观察 DSL

ps
top
ss
lsof


5. 交互编辑 DSL

vim/nvim
```

不同类型：

* 数据流命令：先理解 IO
* 状态命令：先理解对象模型
* 编辑命令：先理解状态机

所以：

**nvim + tmux + docker 是 Linux 工具学习中的三个“分水岭”。**

掌握这三个之后，你对 Linux 命令的理解会从：

```
记命令
```

升级到：

```
理解一个系统的控制语言
```

这也是为什么高级 Linux 用户看命令时，第一反应不是：

> "这个参数是什么？"

而是：

> "这个命令管理的对象是什么？状态如何变化？语法只是如何描述这个变化。"
