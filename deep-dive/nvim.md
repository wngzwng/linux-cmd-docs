# nvim：一个可编程的终端 UI 框架，假装自己是编辑器

你打开 nvim，按 `i` 进入插入模式，敲代码，`:w` 保存，`:q` 退出。这是每个 nvim 用户的基本操作。但如果你问：「当我按下 `j` 时，从键盘到屏幕上的光标下移，中间经过了哪些层？」——大多数人回答不上来。

nvim 的「表面身份」是一个文本编辑器。但它的**本质是一个可编程的终端 UI 框架**：一个事件驱动的 Lua 运行时，暴露了 buffer、window、tabpage 等 UI 原语的完整 API，让用户（和插件作者）可以编程控制编辑器的每一个行为。

---

## 第一层：内部模型

### 1.1 架构分层

nvim 从底层到顶层是四层结构：

```
┌──────────────────────────────────────────┐
│  TUI (Terminal UI)                       │  ← 终端渲染层
│  接收键盘输入，渲染屏幕网格到终端            │
└────────────────┬─────────────────────────┘
                 │ msgpack-RPC（同一进程内的 API 调用）
┌────────────────▼─────────────────────────┐
│  API Layer                               │  ← 所有操作通过 API
│  nvim_buf_set_lines / nvim_win_set_cursor │     Lua API / RPC API 共享同一套
│  nvim_create_autocmd / nvim_set_keymap   │     函数名
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│  Core (C)                                │  ← 高性能核心
│  buffer 管理 / 语法高亮引擎 / undo tree   │
│  regex 引擎 / 文件 I/O / 事件循环          │
└──────────────────────────────────────────┘
```

> 💡 **关键洞察：你在 `init.lua` 里写的 `vim.keymap.set()`、`vim.api.nvim_create_autocmd()`，和 nvim 内部 C 代码用的是同一套 API。** 这就是为什么 Lua 配置不是「补丁」——它是 nvim 的一等公民。API 层的存在意味着你可以用 Lua 做到 nvim 能做的**任何事情**，不需要等插件作者暴露某个选项。

### 1.2 三组核心对象

nvim 的 UI 原语只有三组：

```
buffer（缓冲区）                      ← 一个文件的内存表示
  ├─ 持有文本内容（行数组）
  ├─ 持有语法高亮树（treesitter）
  ├─ 持有 undo tree（不是线性撤销！）
  ├─ 持有 mark / sign / extmark
  └─ 不直接显示——必须通过 window 展示

window（窗口）                        ← buffer 的一个视口
  ├─ 每个 window 显示**一个** buffer
  ├─ 一个 buffer 可以显示在**多个** window 里
  ├─ 持有：光标位置、滚动偏移、折叠状态
  └─ :split / :vsplit = 创建新 window（可以指向同一个 buffer）

tabpage（标签页）                      ← 一组 window 的布局
  ├─ 每个 tab 包含一个或多个 window
  ├─ 类似 tmux 的 window 概念
  └─ :tabnew = 新建一个布局
```

```
nvim 实例
  └─ tabpage 1
  │    ├─ window 1 → buffer A (main.lua)
  │    └─ window 2 → buffer A (同一个文件，不同位置)
  └─ tabpage 2
       └─ window 1 → buffer B (config.lua)
```

> 💡 这就是为什么你可以 `:split` 后在两个窗口看同一个文件的不同位置——两个 window 映射到同一个 buffer，各自持有独立的光标和滚动位置。修改 buffer 内容，两个 window 立即同步更新。

### 1.3 事件驱动模型

nvim 不是「轮询式」的——它是完全事件驱动的：

```
事件源                      事件                  消费者
─────────                  ──────                ────────
键盘输入          →    keypress event     →    keymap 映射
                                          →    vim.keymap.set()
                                          
文件变化          →    BufWritePre         →    autocmd（auto-command）
                  →    BufWritePost        →    用户/插件注册的回调函数
                  
LSP 服务器        →    LspAttach           →    on_attach 回调
                  →    textDocument/publishDiagnostics
                  
用户调用 API      →    立即执行            →    nvim_buf_set_lines()
```

> 💡 `autocmd` 不是「配置文件里的特殊语法」——它是 nvim 的事件订阅系统。你写的 `vim.api.nvim_create_autocmd("BufWritePre", { callback = ... })`，本质上就是「当 BufWritePre 事件触发时，调用我的回调函数」。这和 JavaScript 的 `addEventListener` 是同一个模式。

---

## 第二层：行为机制

### 2.1 按键 → 动作的完整链路

当你按下 `j`（在 normal 模式下）：

```
Step 1：终端 → nvim
  TUI 层从终端接收到按键序列（可能是 <Esc>[B 或纯 'j'）
  → 解析为 nvim 内部 keycode → 放入输入队列

Step 2：keymap 匹配
  nvim 遍历当前 buffer 的 keymap 表（先匹配 buffer-local，再 global）
  → 'j' 匹配到默认映射 → 动作 = "向下移动光标一行"

Step 3：执行动作
  nvim_win_set_cursor(window, row+1, col)
  → Core 更新 window 的 cursor 位置

Step 4：触发事件
  CursorMoved 事件触发 → 所有订阅此事件的 autocmd 被执行
  （比如 statusline 插件用这个事件来更新状态栏）

Step 5：屏幕重绘
  TUI 层计算受影响的屏幕区域 → 发送 ANSI 控制序列到终端
  → 光标从 (3,10) 移到 (4,10)
```

> 💡 **延迟的来源只有两步：** keymap 匹配（O(n) 遍历映射表——通常忽略不计）和 autocmd 回调（如果某个插件在 CursorMoved 上做了耗时操作）。了解这条链路后，排查「nvim 为什么卡」就有了方向：大概率是某个 autocmd 回调太重。

### 2.2 LSP 客户端模型

nvim 从 0.5 开始内置了 LSP 客户端——不需要 coc.nvim 这类中间层。

```
你的 nvim                       LSP Server (独立进程)
    │                                  │
    │  ① nvim 启动 LSP server           │
    │  (通过 cmd 配置启动外部进程)        │
    │─────────────────────────────────→│
    │                                  │
    │  ② 打开文件 → 发送 didOpen        │
    │  { textDocument: { uri,           │
    │    languageId, text } }           │
    │─────────────────────────────────→│
    │                                  │
    │  ③ LSP 分析 → 返回诊断结果         │
    │  { diagnostics: [                │
    │    { range, severity, message }   │
    │  ] }                             │
    │←─────────────────────────────────│
    │                                  │
    │  ④ nvim 将诊断结果存入 buffer      │
    │  → 用 extmark + namespace 标记     │
    │  → 红色波浪线通过 highlight 组渲染   │
    │                                  │
    │  ⑤ 用户修改代码 → 发送 didChange    │
    │─────────────────────────────────→│
    │  (通常有 debounce，200ms 内不重复)   │
    │                                  │
    │  ⑥ 返回更新后的诊断 → 渲染          │
    │←─────────────────────────────────│
```

> 💡 **LSP 通信是异步的。** nvim 不会因为等待 LSP 响应而卡住——它用协程（luv 事件循环 + libuv）处理所有 I/O。你敲代码 → nvim 发 didChange → LSP 处理中 → 你继续敲 → LSP 返回结果 → nvim 更新高亮。全程无阻塞。

### 2.3 Treesitter：从正则高亮到语法树

传统的语法高亮基于正则表达式（`syntax match` / `syntax region`），只能做简单的文本模式匹配。Treesitter 完全不同：

```
传统 regex 高亮：                    Treesitter 高亮：
"识别到 'function' 这个词           "解析出这是一个函数声明节点
 后面跟了一串字符"                      节点类型: function_declaration
                                      ├─ name: "myFunc"
                                      ├─ params: (a, b)
                                      └─ body: { ... }
                                      
结果：只能高亮关键字                 每个节点有类型 → 可以精确高亮
      嵌套结构经常出错                 嵌套结构从 AST 推导 → 100% 准确
```

Treesitter 的工作流程：

1. **Parser（解析器）**：将源码文本解析为 CST（具体语法树）
2. **Query（查询）**：用 scheme 语法在 CST 上做模式匹配，为每个节点分配 highlight 组
3. **Rendering（渲染）**：nvim 用 extmark 在文本上标记 highlight，TUI 层渲染颜色

> 💡 Treesitter 不只是更好的高亮。它还暴露了语法树 API，你可以用 Lua 查询——比如「选中当前函数体」「跳转到下一个 if 语句」。这是 `vim-textobj` 等插件的基础。

---

## 第三层：高级模式

### 3.1 用 Lua 重写你的配置

从 `init.vim` 到 `init.lua` 不是「换一种语法」——是获得了完整的编程语言能力：

```lua
-- 不再是全局变量和字符串拼接，而是真正的数据结构和逻辑

-- Vimscript 方式：
-- let g:my_plugin_option = 'value'

-- Lua 方式：
vim.g.my_plugin_option = 'value'       -- 全局变量的 Lua 映射
vim.opt.number = true                   -- 选项的 Lua 映射
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2

-- keymap 不再是 exec 'nmap <leader>f :Telescope find_files<CR>'
vim.keymap.set('n', '<leader>f', '<cmd>Telescope find_files<CR>', { desc = 'Find files' })

-- autocmd 不再是 augroup + autocmd! + autocmd ...
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function()
    vim.opt_local.tabstop = 4
  end,
})
```

> 💡 `vim.keymap.set()` 的第三个参数 `{ desc = 'Find files' }` ——这个描述字符串会显示在 `:Telescope keymaps` 里。Lua 配置不只是更好写，它是让配置**可发现**。

### 3.2 内置 LSP 的零插件配置

nvim 0.8+ 的内置 LSP 已经不需要插件管理器来配置：

```lua
-- 用 mason.nvim 管理 LSP Server 的安装
-- 用 nvim-lspconfig 做最小配置

local lspconfig = require('lspconfig')

-- 为每种语言配置 LSP server
lspconfig.lua_ls.setup({})
lspconfig.pyright.setup({})
lspconfig.rust_analyzer.setup({})

-- 统一的 on_attach 回调：所有 LSP server 共享同一个 keymap
local on_attach = function(client, bufnr)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = bufnr })
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = bufnr })
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { buffer = bufnr })
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = bufnr })
end

lspconfig.lua_ls.setup({ on_attach = on_attach })
lspconfig.pyright.setup({ on_attach = on_attach })
```

> 💡 `on_attach` 回调在 LSP server 成功连接到 buffer 时触发。你在这里设置的是**每个 buffer 独立的 keymap**——不会影响其他文件类型。

### 3.3 理解插件不是「装补丁」

当你看一个 nvim 插件的源码，你会发现它只做三件事：

1. **注册 autocmd**：在特定事件触发时执行回调
2. **调用 API**：操作 buffer / window / cursor
3. **渲染 UI**：通过 extmark（文本标记）或 floating window（浮窗）

```lua
-- 一个「番茄钟插件」的骨架
local M = {}

local timer = nil

M.start = function(minutes)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor', width = 20, height = 1,
    row = 0, col = vim.o.columns - 20,
    style = 'minimal',
  })
  -- 每分钟更新一次浮窗显示
  timer = vim.loop.new_timer()
  timer:start(60000, 60000, vim.schedule_wrap(function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {'⏰ 还有 25 分钟'})
  end))
end

return M
```

> 💡 **一个插件就是一段注册了事件回调的 Lua 代码。** nvim 的 API 是完备的——没有「插件才能做到的事」，只有「你还没写的代码」。这个认知把 nvim 从「配插件」变成了「写工具」。

---

## 一句话

> nvim 不是编辑器。nvim 是一个暴露了 buffer / window / tabpage API 的可编程终端 UI 框架，编辑器行为只是这些 API 的默认 UI。理解了四层架构（TUI → API → Core）和事件驱动模型（autocmd = 事件订阅），你就不是在「配 nvim」——你是在「给 nvim 写功能」。
