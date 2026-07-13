
# Neovim 深度剖析：结构、配置、操作、集成与扩展

> 本文从五个维度系统拆解 Neovim：**自身架构**、**可配置维度**、**操作体系**、**工具搭配**、**扩展接口**。适合已经度过新手期、想要深入理解 Neovim 到底怎么工作的读者。

---

## 目录

- [一、Neovim 的结构组成与工作方式](#一neovim-的结构组成与工作方式)
  - [1.1 C 核心与 Lua 运行时分层](#11-c-核心与-lua-运行时分层)
  - [1.2 事件循环（libuv）与异步机制](#12-事件循环libuv与异步机制)
  - [1.3 msgpack-RPC 协议与客户端-服务器架构](#13-msgpack-rpc-协议与客户端-服务器架构)
  - [1.4 缓冲区、窗口、标签页的内部数据模型](#14-缓冲区窗口标签页的内部数据模型)
  - [1.5 TUI 渲染层：如何把内容画到终端上](#15-tui-渲染层如何把内容画到终端上)
  - [1.6 内置组件一览](#16-内置组件一览)
  - [1.7 启动序列：从 nvim file.txt 到看见编辑器](#17-启动序列从-nvim-filetxt-到看见编辑器)
  - [1.8 与 Vim 的关键架构差异](#18-与-vim-的关键架构差异)
- [二、Neovim 的可配置维度](#二neovim-的可配置维度)
  - [2.1 核心选项：vim.opt](#21-核心选项vimopt)
  - [2.2 键映射系统：vim.keymap.set](#22-键映射系统vimkeymapset)
  - [2.3 自动命令：事件驱动的钩子系统](#23-自动命令事件驱动的钩子系统)
  - [2.4 用户命令：打造自己的 :Command](#24-用户命令打造自己的-command)
  - [2.5 高亮组与色彩方案](#25-高亮组与色彩方案)
  - [2.6 状态栏、标签栏与窗口顶栏](#26-状态栏标签栏与窗口顶栏)
  - [2.7 LSP 配置](#27-lsp-配置)
  - [2.8 补全系统](#28-补全系统)
  - [2.9 格式化器与检查器](#29-格式化器与检查器)
  - [2.10 插件管理与文件类型配置](#210-插件管理与文件类型配置)
  - [2.11 诊断显示配置](#211-诊断显示配置)
- [三、Neovim 的操作体系：从日常到专业](#三neovim-的操作体系从日常到专业)
  - [3.1 模式系统精要](#31-模式系统精要)
  - [3.2 Motions：光标的舞步](#32-motions光标的舞步)
  - [3.3 Text Objects：语义单元的精准操作](#33-text-objects语义单元的精准操作)
  - [3.4 Operators：操作符 + 动作 = 编辑指令](#34-operators操作符--动作--编辑指令)
  - [3.5 寄存器系统：十种寄存器各司其职](#35-寄存器系统十种寄存器各司其职)
  - [3.6 Marks：给位置打标签](#36-marks给位置打标签)
  - [3.7 宏录制：把重复劳动变成一键执行](#37-宏录制把重复劳动变成一键执行)
  - [3.8 搜索与替换进阶](#38-搜索与替换进阶)
  - [3.9 撤销树：时间旅行不只是 Ctrl+Z](#39-撤销树时间旅行不只是-ctrlz)
  - [3.10 Quickfix 与 Location List](#310-quickfix-与-location-list)
  - [3.11 折叠系统](#311-折叠系统)
  - [3.12 会话与视图](#312-会话与视图)
  - [3.13 Diff 模式](#313-diff-模式)
  - [3.14 拼写检查](#314-拼写检查)
  - [3.15 内置补全：Ctrl+X 的十几种模式](#315-内置补全ctrls的十几种模式)
  - [3.16 缩写与有向图](#316-缩写与有向图)
  - [3.17 从日常到专业的成长路径图](#317-从日常到专业的成长路径图)
- [四、Neovim 与其他工具的搭配](#四neovim-与其他工具的搭配)
  - [4.1 tmux：终端的"另一半"](#41-tmux终端的另一半)
  - [4.2 Git：版本控制的三种集成深度](#42-git版本控制的三种集成深度)
  - [4.3 Unix Shell 工具：编辑器与系统无缝打通](#43-unix-shell-工具编辑器与系统无缝打通)
  - [4.4 LSP 服务器：智能化的基石](#44-lsp-服务器智能化的基石)
  - [4.5 格式化器与检查器](#45-格式化器与检查器)
  - [4.6 调试器（DAP）](#46-调试器dap)
  - [4.7 AI 助手](#47-ai-助手)
  - [4.8 模糊查找器（Telescope / fzf-lua）](#48-模糊查找器telescope--fzf-lua)
  - [4.9 文件管理器](#49-文件管理器)
  - [4.10 数据库工具](#410-数据库工具)
  - [4.11 外部剪贴板与系统集成](#411-外部剪贴板与系统集成)
  - [4.12 Markdown 与文档](#412-markdown-与文档)
- [五、Neovim 的扩展接口](#五neovim-的扩展接口)
  - [5.1 Lua C API（vim.api）：操作编辑器的一切](#51-lua-c-apivimapi操作编辑器的一切)
  - [5.2 RPC API（msgpack）：外部世界的通道](#52-rpc-apimsgpack外部世界的通道)
  - [5.3 Lua 标准库（vim.*）：插件开发的基础设施](#53-lua-标准库vim插件开发的基础设施)
  - [5.4 插件架构与加载机制](#54-插件架构与加载机制)
  - [5.5 自动命令：70+ 个事件扩展点](#55-自动命令70-个事件扩展点)
  - [5.6 LSP 客户端 API】：构建语言服务插件](#56-lsp-客户端-api构建语言服务插件)
  - [5.7 Treesitter API】：语法树级别的代码操作](#57-treesitter-api语法树级别的代码操作)
  - [5.8 诊断 API】：发布与消费错误/警告](#58-诊断-api发布与消费错误警告)
  - [5.9 UI 扩展点】：浮动窗口、弹出菜单、状态栏](#59-ui-扩展点浮动窗口弹出菜单状态栏)
  - [5.10 远程插件（rplugin）：用其他语言写插件](#510-远程插件rplugin用其他语言写插件)
  - [5.11 文件类型系统扩展](#511-文件类型系统扩展)
  - [5.12 Runtime Path 与插件生命周期](#512-runtime-path-与插件生命周期)
  - [5.13 健康检查框架](#513-健康检查框架)
  - [5.14 测试基础设施](#514-测试基础设施)

---

# 一、Neovim 的结构组成与工作方式

## 1.1 C 核心与 Lua 运行时分层

Neovim 的代码库分三层，职责明确：

```
┌────────────────────────────────────────────┐
│  第三层：Lua 插件（runtime/plugin/）        │
│  用户可选功能：tutor、man、editorconfig …   │
├────────────────────────────────────────────┤
│  第二层：Lua 标准库（runtime/lua/vim/）    │
│  公开 API：vim.lsp、vim.treesitter、       │
│  vim.diagnostic、vim.ui、vim.filetype …    │
├────────────────────────────────────────────┤
│  第一层：C 核心（src/nvim/）               │
│  性能关键子系统：文本存储、屏幕绘制、       │
│  TUI、事件循环、msgpack-RPC、终端模拟器 …  │
└────────────────────────────────────────────┘
```

**C 核心** (`src/nvim/`) 实现所有性能敏感的底层子系统：

| 子系统 | 关键文件 | 职责 |
|--------|---------|------|
| 文本存储 | `memline.c` | 行段树（line-segment tree），`ml_get_buf()` 是全局文本读取入口 |
| 缓冲区管理 | `buffer.c`, `buffer_defs.h` | `buf_T`、`file_buffer` 结构体 |
| 窗口/框架 | `window.c` | `win_T`、`frame_T` 布局树 |
| 屏幕绘制 | `drawscreen.c`, `drawline.c`, `grid.c` | 从缓冲区内容计算出屏幕格点 |
| TUI 渲染 | `tui/tui.c`, `tui/ugrid.c` | 终端转义序列输出 |
| RPC 传输 | `msgpack_rpc/channel.c`, `msgpack_rpc/server.c` | msgpack 编解码与通道管理 |
| 事件循环 | `event/loop.c`, `event/multiqueue.c` | libuv 封装 |
| 终端模拟器 | `terminal.c` | 内嵌 `libvterm` |
| Extmarks | `extmark.c`, `marktree.c` | B+ 树实现的标记存储 |

**Lua 标准库** (`runtime/lua/vim/`) 是面向插件作者和用户的公开 API，采用惰性加载。核心模块包括：

- `vim.lsp` — LSP 客户端（启动服务、请求/响应处理、协议定义）
- `vim.treesitter` — 语法树高亮、折叠、注入、查询
- `vim.diagnostic` — 诊断信息的生产者/消费者 API
- `vim.filetype` — 文件类型检测（纯 Lua 实现）
- `vim.ui` — 可替换的 UI 接口（`select` / `input`）
- `vim.iter` — 泛型迭代器工具
- `vim.system` — 子进程管理
- `vim.lpeg` — LPEG 解析表达式文法

> **关键设计原则**：新的 ex 命令和函数优先用 Lua 实现。C 只在必须 `os_breakcheck()`（让出 CPU）的场景使用。

---

## 1.2 事件循环（libuv）与异步机制

与 Vim 经典的主循环 `readkey() → process → repeat` 不同，Neovim 的主循环是 **`read_next_event() → process → repeat`**。

### 核心数据结构

```c
// event/loop.h
struct loop {
  uv_loop_t uv;                // libuv 事件循环
  MultiQueue *events;          // 主事件队列
  MultiQueue *thread_events;   // 跨线程事件
  MultiQueue *fast_events;     // 快速事件（在返回前处理）
  kvec_t(Proc *) children;     // 子进程追踪
  uv_signal_t children_watcher;
  uv_timer_t children_kill_timer;
  uv_timer_t poll_timer;
  uv_async_t async;            // 唤醒句柄
  // ...
};
```

### 事件类型

一个"事件"可以是：
- 用户键盘输入
- RPC 请求（来自外部 UI 或 `--embed` 模式）
- 子进程输出（`:terminal` / `jobstart()`）
- 定时器到期
- 信号（如 SIGWINCH 终端窗口大小变化）

### 哨兵键 `K_EVENT`

当状态机在 `vgetc()` 中找不到用户输入、但事件队列非空时，返回哨兵值 `K_EVENT`。处理逻辑：

```c
// state.c — 简化逻辑
if (vpeekc() != NUL || typebuf.tb_len > 0) {
  key = safe_vgetc();                  // 有用户输入，正常处理
} else if (!multiqueue_empty(main_loop.events)) {
  ui_flush();                          // 先刷新屏幕
  key = K_EVENT;                       // 返回哨兵，触发事件处理
} else {
  input_get(NULL, 0, -1, ...);         // 阻塞等待输入
}
```

> **这意味着**：LSP 返回结果、终端输出、定时器回调——所有这些都不会阻塞你的键盘输入。你打字的同时，后台的一切都在并行运转。

---

## 1.3 msgpack-RPC 协议与客户端-服务器架构

Neovim 的一个核心架构决策是：**所有外部通信都走 msgpack-RPC**——包括内置的 TUI。

### 传输层

| 传输类型 | 用途 | 示例 |
|---------|------|------|
| stdio | 嵌入式使用 | `nvim --embed` |
| Unix socket | 本地监听 | `nvim --listen /tmp/nvim.sock` |
| TCP socket | 远程连接 | `nvim --listen 0.0.0.0:6666` |

### 消息格式

标准 msgpack-RPC 四元组：`[type, msgid, method, params]`

| Type | 值 | 含义 |
|------|---|------|
| Request | 0 | 期望响应 |
| Response | 1 | 携带结果或错误 |
| Notification | 2 | 即发即忘 |

### 内置 TUI 的分体架构

当你运行 `nvim` 时，实际上是启动了**两个进程**：

```
┌──────────────┐    msgpack-RPC (stdio)    ┌──────────────┐
│  TUI 客户端   │ ◄──────────────────────► │ 编辑器核心    │
│  (ui_client.c)│                           │  (服务器进程) │
│              │                            │              │
│  读键盘输入   │                            │  文本缓冲区   │
│  画终端转义序列│                           │  LSP 客户端   │
│              │                            │  Treesitter  │
└──────────────┘                            └──────────────┘
```

这也是为什么 `nvim --embed` 和外部 GUI（neovide、goneovim 等）使用**完全相同的协议**——内置 TUI 本身就是一个 msgpack-RPC 客户端。

### UI 事件 vs API

- **API 函数**（如 `nvim_buf_get_lines`）：客户端调用，服务器响应
- **UI 事件**（如 `grid_line`、`grid_resize`、`hl_attr_define`）：服务器在 `redraw` 通知批次中推送给客户端，由 `gen_api_ui_events.lua` 自动生成

---

## 1.4 缓冲区、窗口、标签页的内部数据模型

这三个概念的关系是 Neovim 最核心的心智模型。

### 缓冲区 `buf_T`

```c
struct file_buffer {
  handle_T handle;           // 唯一编号 b_fnum
  memline_T b_ml;            // 行段树存储（不是平凡数组！）
  buf_T *b_next, *b_prev;   // 全局双向链表
  int b_nwindows;            // 当前有多少窗口在展示这个 buffer
  MarkTree b_marktree;       // extmarks 的 B+ 树索引
  // …文件信息、选项、标记、语法状态…
};
```

### 窗口 `win_T`

```c
struct window_S {
  handle_T handle;
  buf_T *w_buffer;           // 当前展示的缓冲区
  frame_T *w_frame;          // 在布局树中的位置
  pos_T w_cursor;            // 光标位置
  linenr_T w_topline;        // 屏幕第一行对应缓冲区哪一行
  colnr_T w_leftcol;         // 水平滚动偏移
  bool w_floating;            // 是否为浮动窗口
  WinConfig w_config;         // 浮动窗口配置（锚点、相对位置、z-index、边框）
};
```

### 布局树 `frame_T`

每个标签页内部的窗口布局是一棵**二叉树**：

```
Tabpage
  └── tp_topframe (frame_T)
       ├── fr_child (frame_T) — 垂直分割
       │    ├── fr_win → win_T (左侧)
       │    └── fr_win → win_T (右侧)
       └── fr_child (frame_T) — 水平分割
            ├── fr_win → win_T (下方)
            └── fr_win → win_T (下方)
```

### 关键关系

```
Tabpage
├── tp_firstwin → win_T (双向链表 w_prev/w_next)
├── tp_topframe → frame_T (布局树根)
└── tp_next → 下一个 tabpage

Buffer（全局共享，多个窗口可展示同一 buffer）
├── b_nwindows = N
└── b_wininfo = MRU 列表（每个曾展示此 buffer 的窗口的光标/选项快照）
```

> **一句话总结**：缓冲区是"文档"，窗口是"视口"，标签页是"一组视口的布局"。同一个文档可以同时在多个视口、多个标签页中被查看。浮动窗口则游离于布局树之外，有独立的绝对定位。

---

## 1.5 TUI 渲染层：如何把内容画到终端上

TUI 的实现位于 `src/nvim/tui/`，核心文件：

| 文件 | 职责 |
|------|------|
| `tui/tui.c` | 主状态机；UI 事件 → 终端转义序列 |
| `tui/input.c` | 键盘输入（基于 `libtermkey`） |
| `tui/terminfo.c` | Terminfo 数据库查询（unibilium）+ 内置回退 |
| `tui/ugrid.c` | Grid diffing——只发送变化的格点 |

### 渲染流程

```
服务器 → msgpack grid_line 事件 → TUI 客户端
  └── UGrid diffing（只比较变化的格点）
       └── 转换为终端转义序列
            ├── 光标移动：cup
            ├── 属性变化：SGR（fg/bg/bold/underline/italic …）
            ├── 文字输出：UTF-8 原文
            └── 滚动：csr + scroll
  └── 输出缓冲（64KB OUTBUF_SIZE）→ uv_write()
```

### 同步输出（`'termsync'`）

每次刷新用 DEC 私有模式 2026 包裹（`\x1b[?2026h` … `\x1b[?2026l`），防止视觉撕裂。终端支持该协议的会等到收到结束标记才一起重绘。

### 终端能力检测

`augment_terminfo()` 会进行大量终端探测（Xterm, VTE, Kitty, iTerm2, tmux, Alacritty …），然后按需启用：
- **真彩色**（`38:2:…` 或 `38;2;…`）
- **光标形状**（DECSCUSR）
- **下波浪线**（Smulx）
- **焦点报告**（`\x1b[?1004h`）
- **Kitty 键盘协议**（渐进增强询问）

---

## 1.6 内置组件一览

Neovim 自带以下"无需安装插件"的内置组件：

### LSP 客户端 (`vim.lsp`)

- **纯 Lua 实现**，位于 `runtime/lua/vim/lsp/`
- 通过 `vim.uv.spawn()` 启动语言服务器，走 stdio/socket 通信
- 使用 LSP JSON-RPC 协议（基于 Neovim 的 msgpack 通道基础设施）
- 层级化配置系统：`vim.lsp.config()` 支持 `'*'` → `lsp/*.lua` → 用户配置的三级合并
- 提供的能力：跳转定义、查找引用、悬停信息、补全、重命名、格式化、Code Action、诊断、符号搜索

### Treesitter

- **C 侧**（`lua/treesitter.c`）：对 tree-sitter C 库的薄封装，暴露 `TSParser`、`TSTree`、`TSNode`、`TSQuery` 等 userdata 类型
- **Lua 侧**（`vim.treesitter`）：高层功能——语言注册、query 文件（`.scm`）、高亮、增量解析、注入、折叠
- 语法解析器是 `.so`/`.dylib` 动态库，通过 `uv_dlopen()` 加载
- `TSInput` 回调直接从缓冲区的 `memline` 读取文本，转译换行符为 NUL，实现零拷贝增量重解析

### 文件类型检测 (`vim.filetype`)

- 纯 Lua 实现（`runtime/lua/vim/filetype.lua` + `detect.lua`）
- 检测优先级：
  1. `filename` — 完整路径或基线名的字面匹配
  2. `pattern` — Lua 模式匹配（带父模式分组优化，快速跳过）
  3. `extension` — 文件扩展名字面匹配
- 内容级别检测（shebang、magic bytes）在 `detect.lua` 中

### 语法高亮

- **Legacy 路径**：Vim 正则语法（`syntax.c`），简单场景下可能比 Treesitter 更快
- **现代路径**：Treesitter 高亮器运行 query，将 `@capture → hl-group` 映射为高亮属性
- 两条路径最终都汇入相同的 `HlAttrs` 属性系统和屏幕绘制管线

### 诊断系统 (`vim.diagnostic`)

- 命名空间隔离的诊断存储
- 生产者 API：`vim.diagnostic.set()` / `reset()` / `hide()`
- 消费者 API：`get()` / `count()` / `get_next()` / `jump()` / `open_float()`
- 四种显示方式：virtual_text、virtual_lines、signs、underline——均可独立配置

---

## 1.7 启动序列：从 `nvim file.txt` 到看见编辑器

基于 `main()` 的启动流程：

```
01. main() 入口
02.   验证 $NVIM_APPNAME，解析 argv 到 mparams_T
03.   检查 --clean / --embed / --headless 等特殊模式
04.   event_init() — 初始化 libuv 事件循环
05.   init_home_dir() — 确定 $HOME
06.   load_start_packages() — 加载 start 包
07.   source_startup_scripts() — 执行 init.lua / init.vim
08.   处理 --cmd 参数
09.   create_windows() — 创建初始窗口
10.   打开命令行指定的文件（参数中的 file.txt）
11.   source_autocmds() — 触发 BufEnter、VimEnter 等自动命令
12.   normal_enter() — 进入主事件循环，开始处理用户输入
```

> 关键点：`init.lua` 在第 7 步执行，意味着你的配置在窗口创建前就已加载。文件类型检测、语法高亮、LSP 启动——这些都发生在第 11 步的自动命令阶段。

---

## 1.8 与 Vim 的关键架构差异

Neovim 从 Vim 7.4.160 分叉（fork），持续通过 `vim-patch.sh` 合并上游相关补丁。以下是 **Nvim 独有的架构革新**：

| 领域 | Vim | Neovim |
|------|-----|--------|
| 异步与任务 | `job_start()`, `channel`（独立实现） | libuv 子进程，与事件循环原生集成 |
| RPC 协议 | 无标准化 RPC | msgpack-RPC，`--embed` / `--listen` / `--server` |
| 脚本语言 | `if_lua`（可选编译特性），vim9script 是战略方向 | LuaJIT/Lua 5.1 始终编译在内，Vim9script 不适用，Lua 优先 |
| 浮动窗口 | `popup_create()`（有限、临时） | `nvim_open_win()`（完整集成到多格点架构） |
| 标记系统 | Text properties（`prop_add()`），范围受限 | Extmarks 存于 B+ 树（`MarkTree`），支持高亮、虚拟文字、signs、URL 链接、decoration provider |
| 屏幕架构 | 单一屏幕格点，GUI 内置 | 多格点架构——每个窗口有自己的 `ScreenGrid`，外部 UI 接收 `grid_line` 事件 |
| 终端模拟器 | `terminal.c`（API 不兼容） | `:terminal` 基于 `libvterm`，以缓冲区形式渲染 |
| 持久化数据 | `viminfo` | ShaDa 文件（msgpack 格式） |
| 其他独有 | 无 | `inccommand`（替换实时预览）、decoration provider、多 UI 同时附着、内置 LSP 客户端、内置 Treesitter |

---

# 二、Neovim 的可配置维度

Neovim 的配置系统从"改几个选项"到"写一个完整的 IDE"跨度极大。以下按配置的维度逐一拆解。

## 2.1 核心选项：vim.opt

`vim.opt` 是对传统 `:set` 的 Lua 封装，支持像操作普通 Lua 表一样读写选项。

### 选项分类

**外观类**：
```lua
vim.opt.number = true            -- 绝对行号
vim.opt.relativenumber = true    -- 相对行号
vim.opt.cursorline = true        -- 高亮当前行
vim.opt.colorcolumn = "80,120"   -- 竖线标记
vim.opt.signcolumn = "yes"       -- 始终显示标记列
vim.opt.termguicolors = true     -- 真彩色
```

**编辑行为类**：
```lua
vim.opt.shiftwidth = 2           -- 缩进宽度
vim.opt.tabstop = 2              -- Tab 视觉宽度
vim.opt.expandtab = true         -- Tab 转空格
vim.opt.smartindent = true       -- 智能缩进
vim.opt.wrap = false             -- 不自动换行
vim.opt.scrolloff = 8            -- 光标距边缘至少 8 行
vim.opt.sidescrolloff = 8        -- 水平滚动边距
```

**文件与缓冲区类**：
```lua
vim.opt.hidden = true            -- 允许未保存 buffer 切换
vim.opt.swapfile = false         -- 不生成 .swp
vim.opt.undofile = true          -- 持久化撤销（跨会话）
vim.opt.backup = false           -- 不生成 ~ 备份文件
```

**搜索类**：
```lua
vim.opt.ignorecase = true        -- 搜索忽略大小写
vim.opt.smartcase = true         -- 含大写则区分
vim.opt.hlsearch = true          -- 高亮所有匹配
vim.opt.incsearch = true         -- 增量搜索（边输入边跳转）
```

**窗口与分屏类**：
```lua
vim.opt.splitbelow = true        -- 横向分屏新窗口在下方
vim.opt.splitright = true        -- 纵向分屏新窗口在右侧
```

### 作用域

```lua
vim.opt.shiftwidth = 2          -- 全局
vim.opt_local.shiftwidth = 4    -- 当前缓冲区
vim.bo.shiftwidth = 4           -- buffer 作用域（简写）
vim.wo.cursorline = true        -- window 作用域（简写）
```

---

## 2.2 键映射系统：vim.keymap.set

### 基本语法

```lua
vim.keymap.set(mode, lhs, rhs, opts)
-- mode: 'n' | 'i' | 'v' | 'x' | 't' | 'c' | 'o' | '' （''=Normal+Visual+Op-pending）
```

### 模式速查

| 缩写 | 全称 | 使用场景 |
|------|------|---------|
| `n` | Normal | 普通模式下的映射 |
| `i` | Insert | 插入模式下的映射 |
| `v` | Visual + Select | 可视模式下的映射 |
| `x` | Visual only | 仅可视模式 |
| `t` | Terminal | 终端模式 |
| `c` | Command-line | 命令行模式 |
| `o` | Operator-pending | `d`/`y`/`c` 等待 motion 时 |

### 常用选项

```lua
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>",
  { desc = "保存文件", silent = true })

vim.keymap.set("n", "<leader>q", "<cmd>confirm q<cr>",
  { desc = "关闭窗口（有未保存改动时确认）", silent = true })

vim.keymap.set("n", "x", '"_x',
  { desc = "删除但不覆盖寄存器", silent = true })

-- 缓冲区局部映射
vim.keymap.set("n", "K", vim.lsp.buf.hover,
  { desc = "LSP 悬停", buffer = true, silent = true })
```

### Leader 键

```lua
vim.g.mapleader = " "       -- 设为空格键
vim.g.maplocalleader = "\\" -- 本地 leader（文件类型插件用）
```

---

## 2.3 自动命令：事件驱动的钩子系统

### 基本语法

```lua
vim.api.nvim_create_autocmd(event, opts)
```

### 常用事件

| 事件 | 触发时机 | 典型用途 |
|------|---------|---------|
| `BufReadPost` | 文件读取后 | 设置文件类型相关选项 |
| `BufWritePre` | 文件写入前 | 自动格式化 |
| `BufWritePost` | 文件写入后 | 触发外部工具、重新加载 |
| `InsertEnter` | 进入插入模式 | 禁用某些插件 |
| `InsertLeave` | 离开插入模式 | 自动保存 |
| `TextYankPost` | 文本被复制后 | 高亮复制区域 |
| `CursorHold` | 光标静止 n 秒 | 触发文档悬停 |
| `LspAttach` | LSP 客户端附着 | 设置 LSP 键映射 |
| `TermOpen` | 终端窗口打开 | 设置为插入模式 |
| `FileType` | 文件类型确定 | 加载文件类型插件 |
| `VimResized` | 终端窗口改变 | 重平衡分屏大小 |

### 自动命令组

```lua
local mygroup = vim.api.nvim_create_augroup("MyAutoGroup", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = mygroup,
  callback = function() vim.highlight.on_yank() end,
  desc = "高亮复制的文本",
})
```

---

## 2.4 用户命令：打造自己的 `:Command`

```lua
vim.api.nvim_create_user_command("MyCmd", function(opts)
  -- opts.args: 参数字符串
  -- opts.fargs: 按空格分割的参数表
  -- opts.range: [line1, line2]
  -- opts.bang: 是否有 ! 后缀
  print(vim.inspect(opts))
end, {
  nargs = "*",       -- 参数数量: 0, 1, *, ?, +
  range = true,      -- 接受行范围
  bang = true,       -- 允许 ! 后缀
  complete = "file", -- Tab 补全: file, dir, buffer, customlist, …
  desc = "我的自定义命令",
})
```

---

## 2.5 高亮组与色彩方案

### 高亮组

Neovim 的所有视觉元素都通过"高亮组"（highlight group）控制。内置组包括：
- `Normal`, `Comment`, `String`, `Number`, `Keyword`, `Function`, `Type`
- `CursorLine`, `CursorColumn`, `ColorColumn`, `SignColumn`
- `Search`, `IncSearch`, `Visual`, `MatchParen`
- `DiagnosticError`, `DiagnosticWarn`, `DiagnosticInfo`, `DiagnosticHint`
- `LspReferenceText`, `LspReferenceRead`, `LspReferenceWrite`

### 自定义高亮

```lua
-- 修改已有组
vim.api.nvim_set_hl(0, "Comment", { fg = "#6a9955", italic = true })

-- 新建组并链接
vim.api.nvim_set_hl(0, "MyCustomGroup", { fg = "#ff0000", bg = "#000000", bold = true })
vim.api.nvim_set_hl(0, "@variable.member", { link = "Identifier" })
```

### 色彩方案

```lua
vim.cmd.colorscheme("tokyonight")
-- 或
vim.api.nvim_command("colorscheme tokyonight")

-- 根据背景自适应
if vim.o.background == "dark" then
  vim.cmd.colorscheme("tokyonight")
end
```

---

## 2.6 状态栏、标签栏与窗口顶栏

### 状态栏 (`'statusline'`)

使用 `%` 转义项构建：

```lua
vim.opt.statusline = table.concat({
  "%f",        -- 文件名
  "%m",        -- 修改标记 [+]
  "%r",        -- 只读标记 [RO]
  "%=",        -- 左右分割
  "%y",        -- 文件类型
  "[%l,%c]",   -- 行号,列号
  "%p%%",      -- 百分比位置
}, "")
```

更好的方式是用 Lua 函数构建：

```lua
function _G.statusline()
  local diagnostics = vim.diagnostic.status(0)
  return string.format(" %s %s %%= %s [%%l,%%c] ",
    vim.fn.expand("%:t"),              -- 文件名
    vim.bo.modified and "[+]" or "",    -- 修改标记
    diagnostics                         -- "E:2 W:3"
  )
end
vim.opt.statusline = "%!v:lua.statusline()"
```

### 窗口顶栏 (`'winbar'`)

```lua
vim.opt.winbar = "%{%v:lua.winbar()%}"
-- 或直接用 Lua callback
vim.api.nvim_set_option_value("winbar",
  "%{%v:lua.require('myplugin').winbar()%}", { scope = "local" })
```

---

## 2.7 LSP 配置

### 配置层级

```lua
-- 全局默认（所有语言服务器生效）
vim.lsp.config("*", {
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
  root_markers = { ".git" },
})

-- 语言特定配置
vim.lsp.config.clangd = {
  cmd = { "clangd", "--background-index" },
  filetypes = { "c", "cpp" },
  root_markers = { ".clangd", "CMakeLists.txt", "compile_commands.json" },
}

vim.lsp.config.rust_analyzer = {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  settings = {
    ["rust-analyzer"] = {
      checkOnSave = { command = "clippy" },
    },
  },
}

-- 启用
vim.lsp.enable("clangd")
vim.lsp.enable("rust_analyzer")
```

### LspAttach 事件：设置键映射

```lua
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client == nil then return end

    local buf = args.buf
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc, silent = true })
    end

    map("n", "gd", vim.lsp.buf.definition, "跳转到定义")
    map("n", "gr", vim.lsp.buf.references, "查找引用")
    map("n", "K",  vim.lsp.buf.hover, "悬停文档")
    map("n", "<leader>rn", vim.lsp.buf.rename, "重命名")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "代码操作")
    map("n", "[d", vim.diagnostic.goto_prev, "上一个诊断")
    map("n", "]d", vim.diagnostic.goto_next, "下一个诊断")
  end,
})
```

---

## 2.8 补全系统

Neovim 有内置的补全系统（见 [3.15](#315-内置补全ctrls的十几种模式)），但第三方补全引擎（如 nvim-cmp）提供了更强大的体验：

```lua
-- 以 nvim-cmp 为例
local cmp = require("cmp")
cmp.setup({
  sources = cmp.config.sources({
    { name = "nvim_lsp" },     -- LSP 补全
    { name = "luasnip" },      -- 代码片段
    { name = "buffer" },       -- 缓冲区单词
    { name = "path" },         -- 文件路径
  }),
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping.select_next_item(),
    ["<S-Tab>"] = cmp.mapping.select_prev_item(),
  }),
})
```

---

## 2.9 格式化器与检查器

### 格式化器（conform.nvim 为例）

```lua
require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "black" },
    go = { "gofmt", "goimports" },
    javascript = { "prettierd", "prettier", stop_after_first = true },
  },
  format_on_save = true,    -- 保存时自动格式化
})
```

### 检查器（nvim-lint 为例）

```lua
require("lint").linters_by_ft = {
  python = { "ruff" },
  javascript = { "eslint_d" },
  go = { "golangcilint" },
}

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  callback = function() require("lint").try_lint() end,
})
```

---

## 2.10 插件管理与文件类型配置

### 插件管理器对比

| 管理器 | 特点 |
|--------|------|
| **lazy.nvim** | 当前主流；惰性加载、依赖管理、profiling、lockfile |
| packer.nvim | 先行者，已停止维护 |
| 内置 packages | `pack/*/start/` 和 `pack/*/opt/`，零依赖但功能少 |
| mini.deps | 极简，约 200 行代码 |

### 文件类型特定配置

```lua
-- 方式一：ftplugin 目录
-- ~/.config/nvim/after/ftplugin/python.lua
vim.bo.tabstop = 4
vim.bo.shiftwidth = 4

-- 方式二：在 init.lua 中用自动命令
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
  end,
})
```

### 文件类型检测扩展

```lua
vim.filetype.add({
  extension = { foo = "myfiletype" },
  filename = { [".myconfig"] = "myfiletype" },
  pattern = { [".*/etc/myapp/.*"] = "myfiletype" },
})
```

---

## 2.11 诊断显示配置

```lua
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",          -- 错误前缀图标
    spacing = 4,           -- 和代码的间距
    severity = { min = vim.diagnostic.severity.WARN },
  },
  virtual_lines = { only_current_line = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "✘",
      [vim.diagnostic.severity.WARN] = "⚠",
      [vim.diagnostic.severity.INFO] = "ℹ",
      [vim.diagnostic.severity.HINT] = "",
    },
  },
  underline = true,
  update_in_insert = false,    -- 插入模式下暂停更新（减少干扰）
  severity_sort = true,
  float = {
    border = "rounded",
    source = "always",
  },
})
```

---

# 三、Neovim 的操作体系：从日常到专业

> 这一节不是快捷键罗列，而是按"能力层级"组织——从你第 1 天用到第 1000 天用的东西，各自在什么阶段自然浮现。

## 3.1 模式系统精要

| 模式 | 进入方法 | 用途 | 会出现在你第几天 |
|------|---------|------|-----------------|
| **Normal** | 默认/`Esc` | 操控文本、移动光标 | 第 1 天 |
| **Insert** | `i` `a` `o` `I` `A` `O` | 输入文字 | 第 1 天 |
| **Command-line** | `:` `/` `?` | 执行命令、搜索 | 第 1 天 |
| **Visual** | `v` `V` `Ctrl+v` | 选中文本 | 第 3 天 |
| **Select** | `gh` `gH` `Ctrl+g` | 选中即替换（像普通编辑器） | 很少用 |
| **Replace** | `R` | 覆盖式替换 | 第 30 天 |
| **Terminal** | `:term` | 内嵌终端 | 第 30 天 |
| **Operator-pending** | `d`/`y`/`c` 后自动进入 | 等待操作范围 | 无感——你一直在用 |

> **核心纪律**：不是"打完字切回 Normal"，而是 **Normal 是默认状态，Insert 是临时状态**。打完后立刻 `Esc`。这条纪律是所有效率的基础。

---

## 3.2 Motions：光标的舞步

Motions 是"在 Normal 模式下移动光标的方式"，它们本身可以作为 `d`/`y`/`c` 的操作范围。

### 字符级

```lua
h j k l      -- 左 下 上 右
f{char}      -- 跳到本行下一个 {char} 处
F{char}      -- 跳到本行上一个 {char} 处
t{char}      -- 跳到本行下一个 {char} 前
T{char}      -- 跳到本行上一个 {char} 后
;            -- 重复上次 f/t/F/T
,            -- 反向重复
```

### 单词级

```lua
w W          -- 下一个单词开头（W 忽略标点）
b B          -- 上一个单词开头
e E          -- 单词末尾
ge gE        -- 上一个单词末尾
```

### 行级

```lua
0            -- 行首（硬）
^            -- 第一个非空字符
$            -- 行尾
g_           -- 行尾（非空）
```

### 屏幕级

```lua
H M L        -- 屏幕顶部/中部/底部
Ctrl+U Ctrl+D -- 上半页/下半页
Ctrl+B Ctrl+F -- 上一页/下一页
zt zz zb     -- 将当前行滚动到顶部/中部/底部
```

### 文件级

```lua
gg G         -- 文件首/尾
{count}G     -- 跳到第 count 行（如 42G）
{count}%     -- 跳到文件的 count%
```

### 搜索级

```lua
/pattern     -- 向后搜索（n 下一处，N 上一处）
?pattern     -- 向前搜索
*            -- 搜索光标下的单词（向后）
#            -- 搜索光标下的单词（向前）
g* g#        -- 同上但不要求单词边界
```

### Jumplist

```lua
Ctrl+O       -- 跳转到更早的位置
Ctrl+I       -- 跳转到更新的位置
:jumps       -- 查看跳转列表
```

---

## 3.3 Text Objects：语义单元的精准操作

Text objects 是 Vim/Neovim 区别于普通编辑器最本质的能力——你不是在"选一段文字"，你是在"指代一个语义单元"。

### 内置 text objects

```lua
-- 单词
iw           -- "inner word" — 当前单词
aw           -- "a word" — 当前单词 + 尾部空格
iW aW        -- 同上，但 WORD（忽略标点分隔）

-- 句子/段落
is as        -- sentence
ip ap        -- paragraph

-- 括号
i( i) a( a)  -- 圆括号内/含圆括号
i[ i] a[ a]  -- 方括号
i{ i} a{ a}  -- 花括号（也可以用 iB aB）
i< i> a< a>  -- 尖括号

-- 引号
i" a" i' a' i` a`

-- 标签（HTML/XML）
it at        -- tag 内/含 tag
```

### 组合使用

```lua
ciw          -- 改掉当前单词 (change inner word)
da(          -- 删掉一对圆括号及内容 (delete a parenthesis)
yi{          -- 复制花括号内所有内容
ca"          -- 改掉一对引号及内容（删引号 + 进插入模式）
dit          -- 删掉 HTML tag 内的内容
```

### 自定义 text objects

通过 `nvim-treesitter-textobjects` 或 `mini.ai` 可以定义更丰富的对象：
```lua
-- 函数体、类定义、参数列表、循环体 …
cif           -- 改掉函数体 (change inner function)
dac           -- 删掉整个类 (delete a class)
```

---

## 3.4 Operators：操作符 + 动作 = 编辑指令

```
公式：{operator}{count}{motion/text-object}
     做什么    多少次  对什么做
```

### 基本操作符

| 操作符 | 含义 | 示例 |
|--------|------|------|
| `d` | 删除 | `d2w` 删 2 个单词 |
| `c` | 修改（删+进插入） | `c$` 改到行尾 |
| `y` | 复制 | `yip` 复制当前段落 |
| `>` | 增加缩进 | `>G` 到文件尾全缩进 |
| `<` | 减少缩进 | `<<` 当前行减少缩进 |
| `=` | 格式化缩进 | `=ap` 格式化当前段落 |
| `gu` | 转小写 | `guw` 单词转小写 |
| `gU` | 转大写 | `gUw` 单词转大写 |
| `g~` | 翻转大小写 | `g~~` 当前行翻转 |
| `!` | 外部命令过滤 | `!ap sort` 段落交给 sort |
| `gq` | 格式化换行 | `gqap` 格式化段落 |

### 行级操作（双重击键）

```lua
dd           -- 删除整行
cc           -- 修改整行
yy           -- 复制整行
>> <<        -- 缩进/反缩进整行
```

---

## 3.5 寄存器系统：十种寄存器各司其职

| 寄存器 | 符号 | 何时更新 | 用途 |
|--------|------|---------|------|
| **无名** | `""` | 每次 d/c/s/x/y | 默认操作目标 |
| **编号 0** | `"0` | 每次 y | 最近一次复制的内容（不受删除污染） |
| **编号 1-9** | `"1`-`"9` | 每次 d/c（>1 行） | 删除历史（`"1` 最新，`"9` 最旧） |
| **小删除** | `"-` | 每次 <1 行的 d/c/s/x | 小碎片删除（不会被编号寄存器记录） |
| **命名 a-z** | `"a`-`"z` | 由你显式写入 | 按用途命名存储 |
| **只读寄存器** | `"%` `"#` `".` `":` `"/` | 自动 | 当前文件名/交替文件/上次插入/上次命令/上次搜索 |
| **表达式** | `"=` | 使用时求值 | 数学运算后粘贴 |
| **选择/拖放** | `"*` `"+` | 系统选择/剪贴板 | 与系统剪贴板交互 |
| **黑洞** | `"_` | 永远清空 | 彻底的删除（不影响任何寄存器） |
| **上次搜索** | `"/` | 每次 `/` 或 `?` | 最近搜索模式 |

### 常用模式

```lua
"_dd         -- 删除行但不影响任何寄存器
"ayiw        -- 把光标下的单词存到寄存器 a
"ap          -- 从寄存器 a 粘贴
"1p          -- 粘贴倒数第一次删除的内容
"+y          -- 复制到系统剪贴板
```

---

## 3.6 Marks：给位置打标签

```lua
ma           -- 在当前位置设置 mark a
'a           -- 跳到 mark a 的行首
`a           -- 跳到 mark a 的精确位置（行列都跳）
'' ``        -- 跳到上次跳转前的位置
```

### 特殊 marks

| Mark | 含义 |
|------|------|
| `'[` `` `[ `` | 上次修改/复制的起始位置 |
| `']` `` `] `` | 上次修改/复制的结束位置 |
| `'<` `` `< `` | 上次可视选择起始 |
| `'>` `` `> `` | 上次可视选择结束 |
| `'.` `` `. `` | 上次修改位置 |
| `'^` `` `^ `` | 上次插入模式退出位置 |

### 全局 vs 本地

- 小写字母 a-z：**文件本地** mark（只在当前 buffer 有效）
- 大写字母 A-Z：**全局** mark（跨文件跳转）

---

## 3.7 宏录制：把重复劳动变成一键执行

### 录制与播放

```lua
qa           -- 开始录制到寄存器 a
-- … 做操作 …
q            -- 停止录制
@a           -- 播放一次
5@a          -- 播放 5 次
100@a        -- 播放 100 次
@@           -- 重播最近一次宏
```

### 宏的可重复性原则

- **用相对跳转**（`w` `b` `e` `f{char}`）而非绝对行号（`5j` 不可靠）
- **用 `n`/`N` 搜索跳转**，宏会等到找到才继续
- **用 `0` 或 `^` 固定行起点**，确保每次起始位置一致
- 如果宏跑歪了：`u` 撤销 → 调整操作 → 重新录制

### 编辑宏

```lua
:let @a = "     -- 查看宏 a 的内容
"ap             -- 粘贴宏内容到缓冲区
-- 编辑后…
"ay$            -- 把修改后的内容写回寄存器 a
```

---

## 3.8 搜索与替换进阶

### 基本替换

```lua
:s/old/new/          -- 当前行第一个
:s/old/new/g         -- 当前行全部
:%s/old/new/g        -- 整个文件
:%s/old/new/gc       -- 整个文件（确认每次替换）
:5,15s/old/new/g     -- 第 5-15 行
```

### 正则特性

| 模式 | 含义 |
|------|------|
| `\<` `\>` | 单词边界 |
| `\zs` | 匹配起始（替换时从此处开始） |
| `\ze` | 匹配结束（替换时到此为止） |
| `\(…\)` | 捕获组，替换中用 `\1` `\2` … 引用 |
| `\v` | very magic 模式（减少转义，更像 PCRE） |
| `\V` | very nomagic（字面量匹配） |

### 实战示例

```lua
-- 给每行前面加 #
:%s/^/# /

-- 脱敏电话号码（保留前 3 位）
:%s/\(\d\{3}\)-\d\{4}/\1-****/g

-- 用 \zs\ze 精确替换 = 号后的值
:%s/=\zs.*\ze/42/g

-- 在每一行尾追加内容
:%s/$/,/

-- 交换两个捕获组
:%s/\(foo\),\(bar\)/\2,\1/g
```

### global 命令

```lua
:g/pattern/command     -- 对匹配行执行命令
:v/pattern/command     -- 对不匹配行执行命令

:g/TODO/p              -- 打印所有含 TODO 的行
:g/^$/d                -- 删除所有空行（等价于 :v/./d）
:g/debug/normal dd     -- 删除所有含 debug 的行
```

---

## 3.9 撤销树：时间旅行不只是 Ctrl+Z

Neovim 的撤销不是线性的。假设你先做了修改 A，撤销到之前，又做了修改 B——A 和 B 在撤销树上分叉了。

```lua
u            -- 撤销
Ctrl+R       -- 重做
:earlier 10m -- 回到 10 分钟前的状态
:later 30s   -- 前进 30 秒
:earlier 5f  -- 回到 5 次保存前的状态
:undolist    -- 查看撤销历史
g-           -- 在撤销分支间向"更早"跳转
g+           -- 在撤销分支间向"更新"跳转
```

> **推荐插件**：`mbbill/undotree` — `:UndotreeToggle` 可视化展示撤销树，像 git 分支图一样清晰。

---

## 3.10 Quickfix 与 Location List

| 特性 | Quickfix List | Location List |
|------|---------------|---------------|
| 作用域 | 全局（所有窗口共享） | 窗口本地 |
| 典型来源 | `:make`, `:grep`, `:vimgrep`, LSP diagnostics | 当前文件的诊断/引用 |
| 打开窗口 | `:copen` | `:lopen` |
| 跳到下一项 | `:cnext` | `:lnext` |
| 跳到上一项 | `:cprev` | `:lprev` |
| 直接跳转 | `:cc N` | `:ll N` |

### 填充 quickfix

```lua
-- make 输出
:make

-- grep
:grep -r "TODO" src/

-- vimgrep（跨文件正则搜索）
:vimgrep /pattern/g **/*.py

-- 从 LSP 诊断
vim.diagnostic.setqflist()
vim.diagnostic.setloclist()

-- 从 telescope / fzf-lua
-- 把模糊查找结果送入 quickfix
```

---

## 3.11 折叠系统

```lua
zf{motion}   -- 创建手动折叠
zo           -- 打开折叠
zc           -- 关闭折叠
za           -- 切换折叠
zR           -- 全部打开
zM           -- 全部关闭
```

### 六种折叠方法

| 方法 | `foldmethod` 值 | 原理 |
|------|----------------|------|
| 手动 | `manual` | 你手动标记折叠范围 |
| 缩进 | `indent` | 按缩进层级折叠 |
| 语法 | `syntax` | 按语法高亮定义折叠（legacy） |
| 标记 | `marker` | 在文本中用 `{{{` `}}}` 标记 |
| 表达式 | `expr` | 自定义函数返回折叠级别 |
| diff | `diff` | diff 模式下自动折叠未改部分 |

> **现代实践**：Treesitter 折叠（`vim.treesitter.foldexpr()`）替代 legacy 语法折叠，比 indent 和 syntax 准确得多。

---

## 3.12 会话与视图

```lua
:mksession ~/.nvim/sessions/project.vim    -- 保存会话（窗口、标签页、缓冲区列表）
:mksession!                                -- 覆盖保存
:source ~/.nvim/sessions/project.vim       -- 恢复会话
nvim -S ~/.nvim/sessions/project.vim       -- 启动时恢复

:mkview                                     -- 保存当前窗口视图（折叠、光标）
:loadview                                   -- 恢复
```

> **推荐插件**：`rmagatti/auto-session` 或 `folke/persistence.nvim` 自动管理会话。

---

## 3.13 Diff 模式

```lua
nvim -d file1 file2        -- 启动 diff 模式
:diffthis                  -- 将当前窗口加入 diff
:diffoff                   -- 退出 diff
:diffupdate                -- 重新计算 diff
]c [c                      -- 下一处/上一处差异
dp                         -- diff put：把当前差异推送到另一侧
do                         -- diff obtain：从另一侧获取差异
```

---

## 3.14 拼写检查

```lua
:set spell                 -- 启用拼写检查
]s [s                      -- 下一个/上一个拼写错误
z=                         -- 显示建议
zg                         -- 添加到好词词典
zw                         -- 添加到坏词词典
zug zuw                    -- 撤销词典操作
:set spelllang=en,fr       -- 指定语言
```

---

## 3.15 内置补全：Ctrl+X 的十几种模式

即使不装 nvim-cmp，Neovim 也有强大的内置补全：

| 快捷键 | 补全来源 | 场景 |
|--------|---------|------|
| `Ctrl+N` `Ctrl+P` | 当前缓冲区及其他缓冲区 | 单词补全 |
| `Ctrl+X Ctrl+L` | 整行 | 重复代码行 |
| `Ctrl+X Ctrl+F` | 文件路径 | 写 import / require |
| `Ctrl+X Ctrl+K` | 字典 | `'dictionary'` 指定的单词表 |
| `Ctrl+X Ctrl+T` | 同义词 | `'thesaurus'` 指定的同义词库 |
| `Ctrl+X Ctrl+I` | 包含文件 | 当前文件及 `#include` 的文件 |
| `Ctrl+X Ctrl+]` | 标签 | ctags 跳转 |
| `Ctrl+X Ctrl+O` | Omni 补全 | 语言特定（由 `'omnifunc'` 决定，LSP 启用后可用） |
| `Ctrl+X Ctrl+S` | 拼写建议 | 纠正拼写错误 |
| `Ctrl+X Ctrl+V` | Vim 命令 | 补全命令行 |

---

## 3.16 缩写与有向图

### 缩写

```lua
:iabbrev teh the           -- 插入模式下，输入 "teh" 自动变 "the"
:iabbrev @@ wngzwng@gmail.com
:abbreviate                -- 列出所有缩写
:iunabbreviate teh         -- 删除缩写
```

### 有向图（Digraphs）

```lua
Ctrl+K a: → ä
Ctrl+K e' → é
Ctrl+K co → ©
Ctrl+K != → ≠
:digraphs                  -- 列出所有有向图
```

---

## 3.17 从日常到专业的成长路径图

```
第 1 周    hjkl, i/a/o, :wq, dd, yy, p, u, /搜索
          └── 目标：能生存，不"卡死"

第 2 周    w/b/e, ciw, f/F/t/T, 可视模式 v/V/Ctrl+v, :%s
          └── 目标：不需要鼠标，不被方向键拖慢

第 1 月    text objects (ci{, da", yip…), 寄存器, marks, 
          Ctrl+W 分屏, buffer 管理 (:bn :bp :b :ls)
          └── 目标：能用操作符+文本对象"说话"

第 3 月    宏录制 q/@, quickfix, :grep/:vimgrep, 折叠,
          diff 模式, :term, Ctrl+X 补全, 内置 LSP
          └── 目标：一整套开发工作流都在编辑器里

第 6 月    init.lua 系统配置, lazy.nvim, LSP + cmp 全链路,
          telescope, Treesitter text objects, 自定义 text objects
          └── 目标：编辑器是你自己设计的工作环境

第 1 年    DAP 调试, 写自己的插件, Treesitter queries,
          远程插件, 对 :help 的每个角落都了如指掌
          └── 目标：你不再"使用" Neovim——你在"编程" Neovim
```

---

# 四、Neovim 与其他工具的搭配

## 4.1 tmux：终端的"另一半"

> 详细配置见项目中的 `tmux.md`、`nvim-tmux.md` 和 `tmux-nvim-setup.md`。

### 为什么需要组合

| 对比 | Neovim `:term` | tmux 分屏 + Neovim |
|------|----------------|---------------------|
| 终端独立性 | Neovim 子进程，关掉 Neovim 就没了 | 独立进程，关了 Neovim 终端还在 |
| 滚动历史 | 受限于 Neovim 缓冲区大小 | tmux 独立回滚缓冲区（可设到 50000 行） |
| SSH 断连恢复 | 丢失 :term 内的进程 | tmux detach 后一切照跑 |

### 黄金组合：autocmd + send-keys

```lua
-- 保存 Python 测试文件时自动在 tmux 右 pane 跑测试
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "*_test.py", "test_*.py" },
  callback = function()
    local file = vim.fn.expand("%:t")
    vim.fn.system("tmux send-keys -t right 'pytest " .. file .. "' Enter")
  end,
})
```

### 一键启动工作区

```bash
#!/bin/bash
# ~/bin/dev-session.sh
tmux new-session -d -s myapp -n code
tmux send-keys -t myapp 'nvim .' Enter
tmux split-window -h -t myapp
tmux send-keys -t myapp:0.1 'npm run dev' Enter
tmux select-pane -t myapp:0.0
tmux attach -t myapp
```

---

## 4.2 Git：版本控制的三种集成深度

### 第一层：`:term` + git 命令行

```lua
:term git diff
:term git log --oneline
```

### 第二层：Neovim 内置

```lua
:!git blame %              -- 在底部显示 blame（Enter 清除）
:r !git log --oneline -5   -- 把 git log 插入缓冲区
```

### 第三层：专用插件

| 插件 | 定位 |
|------|------|
| **vim-fugitive** | Git 的"瑞士军刀"：`:Git` 在任何地方可用，`:Gblame` 在侧边显示，`:Gdiffsplit` 分屏比较 |
| **gitsigns.nvim** | 在 signcolumn 显示 git 改动标记（增/改/删），行内 blame、hunk 预览、stage/reset hunk |
| **neogit** | 类似 lazygit 的交互式 Git 界面，在 Neovim 浮动窗口中使用 |
| **diffview.nvim** | 强大的 diff 查看器，支持文件历史和分支比较 |

### 典型工作流

```lua
-- 用 gitsigns 查看改动
-- ]c [c 跳转 hunk
-- <leader>hs stage hunk
-- <leader>hr reset hunk
-- <leader>hb 行内 blame

-- 用 fugitive 做复杂操作
-- :Git commit
-- :Git push
-- :Gdiffsplit HEAD~1 查看上次提交的改动
```

---

## 4.3 Unix Shell 工具：编辑器与系统无缝打通

### 三种 Shell 交互方式

```lua
-- 1. 执行命令，查看输出（不改变缓冲区）
:!ls -la

-- 2. 把命令输出插入缓冲区
:r !date                   -- 插入当前时间
:r !cat ~/template.py      -- 插入模板文件
:r !curl -s https://api.example.com/data

-- 3. 把缓冲区内容交给外部命令处理（过滤）
:%!sort                    -- 全文排序
:%!jq .                    -- JSON 格式化
:1,5!column -t             -- 1-5 行按列对齐
:'<,'>!sort -u             -- 选中的行去重排序
```

### 与其他 Unix 工具的组合

```lua
:grep -r "TODO" src/       -- 内置 grep（调用系统 grep）
:vimgrep /pattern/g **/*.py -- 跨文件搜索（纯 Vim 实现）
:copen                      -- 打开 quickfix 查看结果

-- ripgrep + fzf 集成在 telescope.nvim 中
-- fd 用作 telescope 的文件查找后端
```

---

## 4.4 LSP 服务器：智能化的基石

### 各语言推荐服务器

| 语言 | LSP 服务器 | 备注 |
|------|-----------|------|
| C/C++ | clangd | 需要 `compile_commands.json` |
| Rust | rust-analyzer | 事实标准 |
| Python | pyright / basedpyright | pyright 是官方，basedpyright 是社区 fork |
| Go | gopls | Go 官方工具链 |
| TypeScript/JS | tsserver / vtsls | tsserver 是 VSCode 同款 |
| Lua | lua-language-server | 可以对 Neovim 配置自身提供补全 |
| Java | jdtls | Eclipse JDT 语言服务器 |
| Zig | zls | |
| Nix | nil / nixd | |
| YAML/JSON | yamlls / jsonls | |

### LSP 能力一览

| 能力 | 命令 | 描述 |
|------|------|------|
| 跳转定义 | `vim.lsp.buf.definition()` | `gd` |
| 查找引用 | `vim.lsp.buf.references()` | `gr` |
| 悬停文档 | `vim.lsp.buf.hover()` | `K` |
| 签名帮助 | `vim.lsp.buf.signature_help()` | `Ctrl+K`（在插入模式） |
| 重命名 | `vim.lsp.buf.rename()` | `<leader>rn` |
| 代码操作 | `vim.lsp.buf.code_action()` | `<leader>ca` |
| 格式化 | `vim.lsp.buf.format()` | |
| 文档符号 | `vim.lsp.buf.document_symbol()` | |
| 工作区符号 | `vim.lsp.buf.workspace_symbol()` | |
| 类型定义 | `vim.lsp.buf.type_definition()` | |
| 实现跳转 | `vim.lsp.buf.implementation()` | |
| 调用层次 | `vim.lsp.buf.incoming_calls()` / `outgoing_calls()` | |

---

## 4.5 格式化器与检查器

### 格式化器推荐

| 格式化器 | 适用语言 |
|---------|---------|
| stylua | Lua |
| black / ruff format | Python |
| gofmt / goimports | Go |
| prettier / prettierd | JS/TS/HTML/CSS/JSON/YAML |
| rustfmt | Rust |
| clang-format | C/C++ |
| shfmt | Shell |

### 检查器推荐

| 检查器 | 适用语言 |
|--------|---------|
| luacheck / selene | Lua |
| ruff / mypy | Python |
| golangci-lint | Go |
| eslint | JS/TS |
| shellcheck | Shell |
| clang-tidy | C/C++ |

### 配置策略

```lua
-- 用 conform.nvim 统一管理和编排
-- 用 nvim-lint 异步运行检查器
-- 用 LSP 的 textDocument/formatting 作为主要格式化路径
-- 外部工具作为补充（fallback）
```

---

## 4.6 调试器（DAP）

Neovim 通过 `nvim-dap` 实现 Debug Adapter Protocol。

### 架构

```
Neovim (nvim-dap) ──DAP JSON──► Debug Adapter (debugpy/lldb-vscode/…)
                                      │
                                      ▼
                              被调试进程
```

### 各语言适配器

| 语言 | 适配器 |
|------|--------|
| Python | debugpy |
| C/C++/Rust | lldb-vscode / cpptools |
| Go | delve |
| JS/TS (Node) | js-debug |
| Java | java-debug |

### 基本使用

```lua
-- 设置断点
vim.keymap.set("n", "<leader>db", require("dap").toggle_breakpoint)

-- 开始调试
vim.keymap.set("n", "<leader>dc", require("dap").continue)

-- 单步
vim.keymap.set("n", "<leader>do", require("dap").step_over)
vim.keymap.set("n", "<leader>di", require("dap").step_into)
vim.keymap.set("n", "<leader>dO", require("dap").step_out)

-- 查看变量（配合 nvim-dap-ui）
-- :lua require("dapui").toggle()
```

---

## 4.7 AI 助手

| 工具 | 类型 | 特点 |
|------|------|------|
| **Copilot** | 代码补全（闭源） | VSCode 同款体验，Neovim 官方支持（`github/copilot.vim`） |
| **Codeium** | 代码补全（闭源） | 免费个人使用，个人版不限量 |
| **avante.nvim** | 对话式（开源） | 类似 Cursor 的 AI 面板，需要自己的 LLM API key |
| **codecompanion.nvim** | 对话式（开源） | 内联对话、代码生成、agent 模式 |

---

## 4.8 模糊查找器（Telescope / fzf-lua）

| 功能 | 描述 |
|------|------|
| 查找文件 | 基于 fd/ripgrep |
| 实时 grep | 基于 ripgrep |
| 缓冲区列表 | 所有打开的文件 |
| LSP 引用/定义/符号 | 搜索代码库 |
| Git 文件 | 查看改动的文件 |
| 帮助标签 | 搜索 `:help` |
| 命令历史 | 搜索最近执行的命令 |
| 诊断 | 列出所有错误/警告 |

```lua
-- telescope 示例
vim.keymap.set("n", "<leader>ff", require("telescope.builtin").find_files)
vim.keymap.set("n", "<leader>fg", require("telescope.builtin").live_grep)
vim.keymap.set("n", "<leader>fb", require("telescope.builtin").buffers)
vim.keymap.set("n", "<leader>fh", require("telescope.builtin").help_tags)
```

---

## 4.9 文件管理器

| 插件 | 风格 | 备注 |
|------|------|------|
| **neo-tree** | 侧边栏树形 | VS Code 风格，最流行 |
| **oil.nvim** | 缓冲区编辑 | 把目录当普通文本编辑——这是最 vim 的方式 |
| **nvim-tree** | 侧边栏树形 | neo-tree 的前身 |
| **mini.files** | 双栏 | 轻量极简 |
| **yazi.nvim** | 集成终端文件管理器 | 把 yazi（Rust 写的）集成进 Neovim |

---

## 4.10 数据库工具

- **dadbod** (`tpope/vim-dadbod`)：在 Neovim 里连接数据库、写 SQL、看结果——同一个 buffer 里操作
- 支持 PostgreSQL、MySQL、SQLite 等

```lua
:DB postgres://user:pass@host/db
-- 在 buffer 里写 SQL
-- 选中 → :'<,'>DB 执行
```

---

## 4.11 外部剪贴板与系统集成

```lua
vim.opt.clipboard = "unnamedplus"   -- 与系统剪贴板双向同步

-- macOS: pbcopy / pbpaste
-- Linux (X11): xclip / xsel
-- Linux (Wayland): wl-copy / wl-paste
```

在 tmux 中还需要额外的配置（如 `tmux-yank` 或 osc52 集成）来打通 tmux → 系统的剪贴板路径。

---

## 4.12 Markdown 与文档

| 插件 | 功能 |
|------|------|
| **render-markdown.nvim** | 在 Neovim 里渲染 Markdown（加粗、斜体、标题、表格、代码块着色） |
| **markdown-preview.nvim** | 在浏览器中实时预览 |
| **markview.nvim** | 轻量替代，无需浏览器 |

---

# 五、Neovim 的扩展接口

> 这一节面向"我想写 Neovim 插件"或者"我想理解 Neovim 可以被怎样扩展"的读者。

## 5.1 Lua C API（vim.api）：操作编辑器的一切

`vim.api` 是对 C 层 `nvim_*` 函数的直接暴露，是操作 Neovim 的最底层 Lua 接口。

### 缓冲区

```lua
vim.api.nvim_create_buf(listed, scratch)       -- 创建缓冲区
vim.api.nvim_buf_get_lines(bufnr, start, end, strict_indexing)
vim.api.nvim_buf_set_lines(bufnr, start, end, strict_indexing, lines)
vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, lines)
vim.api.nvim_buf_get_name(bufnr)               -- 获取路径
vim.api.nvim_buf_set_option(bufnr, name, value) -- 设置选项
vim.api.nvim_buf_del_keymap(bufnr, mode, lhs)  -- 删除映射
```

### 窗口

```lua
vim.api.nvim_open_win(bufnr, enter, config)    -- 打开窗口（包括浮动）
vim.api.nvim_win_set_config(winid, config)     -- 调整窗口配置
vim.api.nvim_win_close(winid, force)
vim.api.nvim_win_get_cursor(winid)
vim.api.nvim_win_set_cursor(winid, {row, col})
vim.api.nvim_win_get_buf(winid)
vim.api.nvim_set_current_win(winid)
```

### Extmarks（扩展标记）

```lua
-- 创建 extmark
local id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
  end_row = row, end_col = col + 5,
  hl_group = "Search",
  virt_text = { {"Hello", "Comment"} },
  virt_text_pos = "overlay",      -- 或 "inline", "right_align", "eol"
  sign_text = "▶",
  sign_hl_group = "DiagnosticError",
  priority = 10,
  right_gravity = false,
})

-- 删除
vim.api.nvim_buf_del_extmark(bufnr, ns_id, id)

-- 获取
local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, start, end, opts)
```

**Extmarks 是现代 Neovim 插件基础设施的核心**——它允许你在缓冲区中的任意位置附着虚拟文字、高亮、signs，而无需修改实际文本内容。LSP 诊断、gitsigns、indent-blankline 等都是基于 extmarks 实现的。

### Namespace（命名空间）

```lua
local ns = vim.api.nvim_create_namespace("my_plugin")
-- 之后所有 extmark、诊断、高亮都绑定到这个 namespace
-- 可以一次性清除该 namespace 下的所有内容
vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
```

### Keymaps & Commands

```lua
vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
vim.api.nvim_del_keymap(mode, lhs)
vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)  -- buffer 局部
```

---

## 5.2 RPC API（msgpack）：外部世界的通道

### 连接方式

```bash
# 启动时监听
nvim --listen /tmp/nvim.sock

# 或对已运行的实例
nvim --server /tmp/nvim.sock --remote-send "<C-\\><C-N>:echo 'hello'<CR>"
```

### 编程方式

```python
# Python 示例（需要 pip install pynvim）
from pynvim import attach

nvim = attach("socket", path="/tmp/nvim.sock")
nvim.command("echo 'Hello from Python!'")
buf = nvim.current.buffer
buf[0] = "First line modified from remote"
nvim.funcs.setline(1, "Another way")
```

### API 发现

```lua
:lua = vim.api.nvim_get_api_info()  -- 列出所有可用的 API 函数
```

### 远程 UI（GUI）

所有 Neovim GUI 都是通过这个 RPC 协议实现的：
- **neovide**（Rust，GPU 加速）
- **goneovim**（Go + Qt）
- **nvui**（C++ + Qt）
- **firenvim**（在浏览器中嵌入 Neovim）
- **neovim-qt**

它们都作为 msgpack-RPC 客户端连接到 Neovim 服务器，接收 `grid_line` 和 `hl_attr_define` 等 UI 事件来渲染自己的界面。

---

## 5.3 Lua 标准库（vim.*）：插件开发的基础设施

### vim.fn

调用所有 Vimscript 内置函数：

```lua
vim.fn.expand("%:t")           -- 当前文件名
vim.fn.getline(".")            -- 当前行内容
vim.fn.setline(1, "hello")     -- 设置第 1 行
vim.fn.system("ls")            -- 执行系统命令
vim.fn.strftime("%Y-%m-%d")    -- 格式化时间
vim.fn.json_decode(str)        -- JSON 解析
vim.fn.json_encode(tbl)        -- JSON 序列化
```

### vim.cmd

执行 Vimscript 命令：

```lua
vim.cmd("colorscheme tokyonight")
vim.cmd([[autocmd BufWritePre *.go lua vim.lsp.buf.format()]])
vim.cmd.highlight({ "Comment", "guifg=#6a9955" })  -- 结构化方式
```

### vim.opt / vim.bo / vim.wo

见 [2.1 核心选项](#21-核心选项vimopt)。

### vim.keymap

见 [2.2 键映射系统](#22-键映射系统vimkeymapset)。

### vim.ui.select / vim.ui.input

可替换的 UI 接口——插件可以覆盖为 telescope、fzf-lua、mini.pick 或 dressing.nvim：

```lua
vim.ui.select({"a", "b", "c"}, {
  prompt = "Choose:",
  format_item = function(item) return "→ " .. item end,
}, function(choice)
  print("You chose: " .. choice)
end)

vim.ui.input({ prompt = "Enter name: " }, function(input)
  print("Hello, " .. input)
end)
```

### vim.inspect

类似 Python 的 `repr()` / `pprint()`：

```lua
print(vim.inspect({ a = 1, b = { c = 2 } }))
-- { a = 1, b = { c = 2 } }
```

### vim.iter

泛型迭代器工具：

```lua
local doubled = vim.iter({ 1, 2, 3 }):map(function(x) return x * 2 end):totable()
-- { 2, 4, 6 }
```

### vim.system

现代的子进程管理（替代 `vim.fn.system()`）：

```lua
local obj = vim.system({ "rg", "pattern" }, { text = true }):wait()
print(obj.stdout)
```

### vim.version

```lua
print(vim.version().major, vim.version().minor)
-- 0 10
if vim.fn.has("nvim-0.10") == 1 then … end
```

### vim.lpeg

LPEG 解析表达式文法（功能强大的 Lua 解析库）：

```lua
local lpeg = vim.lpeg
local patt = lpeg.P("hello") * lpeg.P(" ") * lpeg.P("world")
patt:match("hello world")  --> 13 (匹配长度)
```

---

## 5.4 插件架构与加载机制

### 标准目录结构

```
my-plugin/
├── lua/my_plugin/          -- Lua 模块（require("my_plugin") 会找这里）
│   ├── init.lua
│   └── utils.lua
├── plugin/                 -- 启动时自动加载
│   └── my_plugin.lua       -- 设置命令、自动命令、键映射
├── ftplugin/               -- 文件类型特定
│   └── python.lua
├── after/                  -- 在所有其他插件之后加载（最后覆盖权）
│   └── plugin/
├── autoload/               -- 惰性加载的 Vimscript 函数
├── doc/                    -- :help 文档
│   └── my_plugin.txt
├── syntax/                 -- 语法文件（legacy）
├── indent/                 -- 缩进表达式
└── ftdetect/               -- 文件类型检测规则
```

### 启动加载顺序

```
1. 处理 --cmd 参数
2. 加载 init.lua / init.vim
3. 所有 plugin/**/*.{vim,lua} 按 rtp 顺序加载
4. 所有 ftdetect/**/*.{vim,lua}
5. packages: pack/*/start/<name> 的 rtp 被扩展 → plugins 加载
6. after/ 目录最后加载（用于安全地覆盖默认值）
```

### 惰性加载（lazy-loading）

`lazy.nvim` 提供丰富的惰性加载触发条件：

```lua
{
  "plugin/name",
  event = "BufReadPost",       -- 第一个文件打开后加载
  cmd = "MyCommand",           -- :MyCommand 触发
  keys = "<leader>x",          -- 按键触发
  ft = "python",               -- 文件类型触发
  dependencies = { "dep1" },   -- 先加载依赖
}
```

---

## 5.5 自动命令：70+ 个事件扩展点

所有可用的自动命令事件（部分）：

| 类别 | 事件 |
|------|------|
| **启动** | `VimEnter`, `UIEnter`, `GUIEnter`, `VimLeavePre`, `VimLeave` |
| **文件读写** | `BufReadPre`, `BufReadPost`, `BufWritePre`, `BufWritePost`, `FileReadPre`, `FileAppendPost` |
| **缓冲区** | `BufEnter`, `BufLeave`, `BufNew`, `BufAdd`, `BufDelete`, `BufWipeout` |
| **窗口** | `WinEnter`, `WinLeave`, `WinNew`, `WinClosed`, `WinResized` |
| **标签页** | `TabEnter`, `TabLeave`, `TabNew`, `TabClosed` |
| **模式切换** | `InsertEnter`, `InsertLeave`, `InsertCharPre`, `CmdlineEnter`, `CmdlineLeave`, `TermOpen`, `TermClose` |
| **文本变更** | `TextChanged`, `TextChangedI`, `TextChangedP`, `TextYankPost` |
| **文件类型** | `FileType` |
| **LSP** | `LspAttach`, `LspDetach`, `LspProgress`, `LspTokenUpdate` |
| **诊断** | `DiagnosticChanged` |
| **颜色** | `ColorScheme` |
| **其他** | `CursorHold`, `CursorHoldI`, `CursorMoved`, `VimResized`, `FocusGained`, `FocusLost`, `OptionSet`, `QuickFixCmdPre` |

---

## 5.6 LSP 客户端 API：构建语言服务插件

### 启动服务器

```lua
local client_id = vim.lsp.start({
  name = "my-lsp",
  cmd = { "my-language-server", "--stdio" },
  root_dir = vim.fs.root(0, { ".git" }),
})
```

### 发送请求

```lua
-- 请求
local result = vim.lsp.buf_request_sync(bufnr, "textDocument/definition", params, timeout_ms)

-- 异步请求
vim.lsp.buf_request(bufnr, "textDocument/references", params, function(err, result, ctx)
  if err then return end
  -- 处理结果
end)
```

### 自定义 Handler

```lua
-- 覆盖默认的 hover handler
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
  vim.lsp.handlers.hover,
  { border = "rounded", max_width = 80 }
)
```

### Client Capabilities

```lua
local capabilities = vim.lsp.protocol.make_client_capabilities()
-- 混合 nvim-cmp 的补全能力
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
-- 混合其他能力
capabilities.textDocument.foldingRange = { dynamicRegistration = false, lineFoldingOnly = true }
```

---

## 5.7 Treesitter API：语法树级别的代码操作

### Query 语法示例

```
; queries/python/highlights.scm
(function_definition
  name: (identifier) @function)

(class_definition
  name: (identifier) @type)

; Text objects 查询
(function_definition
  body: (block) @function.inner) @function.outer
```

### 编程式查询

```lua
local query = vim.treesitter.query.parse("python", [[
  (function_definition
    name: (identifier) @func_name
    parameters: (parameters) @params)
]])

local parser = vim.treesitter.get_parser(0, "python")
local tree = parser:parse()[1]
local root = tree:root()

for id, node, metadata in query:iter_captures(root, 0) do
  local name = query.captures[id]  -- "func_name" or "params"
  local text = vim.treesitter.get_node_text(node, 0)
  print(name, text, node:range())
end
```

### 自定义 Predicate

```lua
vim.treesitter.query.add_predicate("my-contains?", function(match, pattern, bufnr, pred)
  local node = match[pred[2]]
  local text = vim.treesitter.get_node_text(node, bufnr)
  return text:find(pred[3]) ~= nil
end)

-- 在 query 中使用
-- ((identifier) @var (#my-contains? @var "foo"))
```

---

## 5.8 诊断 API：发布与消费错误/警告

### 生产者——发布诊断

```lua
local ns = vim.api.nvim_create_namespace("my_linter")

vim.diagnostic.set(ns, bufnr, {
  {
    lnum = 0,           -- 0-based 行号
    col = 0,            -- 0-based 列号
    end_lnum = 0,
    end_col = 10,
    severity = vim.diagnostic.severity.ERROR,
    message = "Unexpected token",
    source = "my_linter",
    code = "E001",
  },
})

-- 清理
vim.diagnostic.reset(ns, bufnr)
vim.diagnostic.hide(ns, bufnr)
```

### 消费者——读取诊断

```lua
-- 获取所有诊断
local diags = vim.diagnostic.get(bufnr)

-- 快速计数（比 get() 快）
local count = vim.diagnostic.count(bufnr)
-- count == { [severity] = N }

-- 跳转
vim.diagnostic.get_next()
vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })
```

### 自定义 Display Handler

```lua
vim.diagnostic.handlers.my_handler = {
  show = function(namespace, bufnr, diagnostics, opts)
    -- 自定义显示逻辑
  end,
  hide = function(namespace, bufnr)
    -- 自定义隐藏逻辑
  end,
}

vim.diagnostic.config({
  virtual_text = false,
  signs = { "my_handler" },  -- 只使用自定义 handler
})
```

---

## 5.9 UI 扩展点：浮动窗口、弹出菜单、状态栏

### 浮动窗口

```lua
local bufnr = vim.api.nvim_create_buf(false, true)  -- scratch 缓冲区
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Hello", "World" })

local winid = vim.api.nvim_open_win(bufnr, false, {
  relative = "cursor",       -- 相对于光标
  row = 1,                   -- 光标下方 1 行
  col = 0,                   -- 光标同列
  width = 40,
  height = 10,
  border = "rounded",        -- "single" | "double" | "solid" | "shadow" | "none" | custom table
  title = "Info",
  title_pos = "center",
  footer = "Press q to close",
  footer_pos = "left",
  style = "minimal",         -- 无行号、无 cursorline……
  zindex = 50,
})

-- 关闭
vim.api.nvim_win_close(winid, true)
```

### 弹出菜单（wildmenu）

```lua
vim.opt.wildmenu = true
vim.opt.wildmode = "longest:full,full"
vim.opt.wildoptions = "pum"  -- 与插入补全共用弹出菜单样式
```

### Statusline 组件——来自诊断

```lua
local status = vim.diagnostic.status(0)
-- 返回 "E:3 W:2 I:1 H:0" 或空字符串
```

### Winbar

```lua
vim.api.nvim_set_option_value("winbar",
  "%{%v:lua.require('myplugin').winbar()%}", { scope = "local" })
```

### Images（实验性）

```lua
-- 需要 Kitty 图形协议支持的终端
vim.ui.img.set(data, {
  row = 0, col = 0,
  width = 40, height = 20,
  zindex = 10,
})
```

---

## 5.10 远程插件（rplugin）：用其他语言写插件

远程插件作为**独立进程**运行，通过 msgpack-RPC 与 Neovim 通信。

### Python 示例（pynvim）

```python
import pynvim

@pynvim.plugin
class MyPlugin:
    def __init__(self, nvim):
        self.nvim = nvim

    @pynvim.command("HelloWorld", nargs="0", sync=True)
    def hello(self):
        self.nvim.command('echo "Hello from Python!"')

    @pynvim.autocmd("BufEnter", pattern="*.py", sync=False)
    def on_python_file(self):
        self.nvim.out_write("Opened a Python file\n")

    @pynvim.function("Sum", sync=True)
    def sum(self, args):
        return sum(args)
```

### Manifest 生成

```bash
# 扫描 rplugin/{python3,ruby,node}/ 目录
:UpdateRemotePlugins

# Manifest 位置
~/.local/share/nvim/rplugin.vim
```

### 同步 vs 异步

- `sync=True`：使用 `rpcrequest()`，阻塞 Neovim 等待返回值，异常会抛回
- `sync=False`（默认）：使用 `rpcnotify()`，即发即忘

---

## 5.11 文件类型系统扩展

### 添加检测规则

```lua
vim.filetype.add({
  extension = {
    foo = "myfiletype",
    templ = "template",
  },
  filename = {
    [".envrc"] = "sh",
    ["Justfile"] = "make",
  },
  pattern = {
    [".*/templates/.*%.html"] = "htmldjango",
    ["Dockerfile%..*"] = "dockerfile",
  },
})
```

### 编写文件类型插件

```
~/.config/nvim/after/ftplugin/python.lua:

-- 设置 buffer 局部选项
vim.bo.tabstop = 4
vim.bo.shiftwidth = 4
vim.bo.textwidth = 88

-- 设置 buffer 局部映射
vim.keymap.set("n", "<leader>r", "<cmd>!python %<CR>",
  { buffer = true, desc = "运行当前 Python 文件" })

-- 撤销设置（filetype 改变时）
vim.b.undo_ftplugin = "setlocal tabstop< shiftwidth< textwidth<"
```

---

## 5.12 Runtime Path 与插件生命周期

### Runtime Path 结构

```
'packpath' / 'runtimepath' 中的子目录及作用：

plugin/       → 启动时自动 source
ftdetect/     → 文件类型检测规则（启动时 source）
ftplugin/     → 文件类型确定后加载（buffer 作用域）
indent/       → 设置 'indentexpr'
syntax/       → legacy 语法高亮定义
autoload/     → 惰性加载函数（调用时才 source）
after/        → 最后加载，用于安全覆盖
compiler/     → :compiler 命令使用
doc/          → :help 文档
lua/          → Lua require() 搜索路径
colors/       → 色彩方案
pack/*/start/ → 启动时加载（类似 plugin/）
pack/*/opt/   → 可选包（:packadd 加载）
```

### require() 搜索顺序

```lua
-- require("my_plugin.utils") 会按 'runtimepath' 顺序搜索：
-- 1. ~/.config/nvim/lua/my_plugin/utils.lua
-- 2. ~/.config/nvim/lua/my_plugin/utils/init.lua
-- 3. $VIMRUNTIME/lua/my_plugin/utils.lua
-- 4. ... (每个 rtp 条目，含 after/)
```

### 调试 require

```lua
:lua = package.searchpath("my_plugin.utils", package.path)
-- 查看模块实际从哪里加载

:scriptnames
-- 列出所有已 source 的文件
```

---

## 5.13 健康检查框架

### 创建健康检查

```lua
-- lua/my_plugin/health.lua
local M = {}

function M.check()
  vim.health.start("my_plugin 检查报告")

  -- OK
  if my_feature_works() then
    vim.health.ok("核心功能正常")
  else
    vim.health.error("核心功能异常", {
      "请检查: brew install xxx",
      "然后重启: :checkhealth my_plugin",
    })
  end

  -- Warning
  if my_feature_slow() then
    vim.health.warn("性能可能有问题", "尝试调大 buffer size")
  end

  -- Info
  vim.health.info("插件版本: " .. vim.version())
end

return M
```

### 运行

```bash
:checkhealth                  # 全部
:checkhealth my_plugin         # 特定插件
:checkhealth vim*              # 所有 vim.* 子模块
```

---

## 5.14 测试基础设施

Neovim 的测试框架能启动嵌入式 Neovim 实例并通过 RPC 驱动它。

### 内置测试工具

```lua
-- 在嵌入式 Neovim 中执行 Lua
exec_lua([[
  require("my_plugin").setup({})
  return vim.bo.filetype
]])

-- 执行 :command
nvim_command("e test.py")

-- 断言
eq("expected", actual)
neq(a, b)
ok(condition)

-- 重置
clear()
```

### 测试文件组织

```
my_plugin/
├── tests/
│   ├── my_plugin_spec.lua     -- 集成测试
│   └── minimal_init.lua       -- 最小化 init.lua（减少噪音）
```

### 使用 busted 运行

```bash
# 需要 nvim --headless
nvim --headless -u tests/minimal_init.lua \
  -c "lua require('plenary.test_harness').test_directory('tests/')"
```

### vim.validate

用于在插件边界做类型检查：

```lua
function M.setup(opts)
  vim.validate({
    opts = { opts, "table", true },       -- optional table
    name = { opts.name, "string" },       -- required string
  })
end
```

---

## 参考资源

- [Neovim 官方文档](https://neovim.io/doc/)
- [Neovim 源代码](https://github.com/neovim/neovim)
- [Dev Architecture](https://github.com/neovim/neovim/blob/master/src/nvim/README.md)（`src/nvim/README.md`）
- `:help lua-guide` — Neovim 内置的 Lua 编程指南
- `:help api` — 完整 API 文档
- `:help lsp` — LSP 相关帮助
- `:help treesitter` — Treesitter 相关帮助
- 本项目中的其他相关文档：`nvim.md`（新手入门）、`tmux.md`、`nvim-tmux.md`、`tmux-nvim-setup.md`

---

> **Neovim 不是"另一个 Vim"。** 它是用现代软件工程重构的"vim 思想的下一代实现"——C 核心跑得快，Lua 运行时跑得灵活，msgpack-RPC 让外部世界能与之对话。你用到的每一个 LSP 跳转、每一块 Treesitter 高亮、每一个浮动窗口，背后都是这套架构在运转。理解它，你就不再只是"使用 Neovim"，而是在"驾驭 Neovim"。
