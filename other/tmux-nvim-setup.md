
# tmux + Neovim 配置指南

将 `nvim.md`、`tmux.md`、`ssh.md` 中涉及的配置集中到一处，方便直接复制使用。按顺序配好后，一行命令就能连上远程服务器、进入 tmux 会话、打开 Neovim，直接开始写代码。

---

## 一、`.tmux.conf` — tmux 配置

```tmux
# 修改前缀键（可选，很多人把 Caps Lock 映射成 Ctrl，用 Ctrl+A 更顺手）
# set -g prefix C-a
# unbind C-b
# bind C-a send-prefix

# 鼠标支持（开启后可直接用鼠标选 pane、滚轮回滚）
set -g mouse on

# 分屏快捷键 —— 更直观
bind | split-window -h   # 竖分（左右），用 | 符号
bind - split-window -v   # 横分（上下），用 - 符号

# pane 跳转 —— 用 Ctrl+ hjkl，不用先按前缀
bind -n C-h select-pane -L
bind -n C-j select-pane -D
bind -n C-k select-pane -U
bind -n C-l select-pane -R

# 重载配置
bind r source-file ~/.tmux.conf \; display "Reloaded!"

# 设置 pane 标题（方便区分哪个是 Neovim）
set -g pane-border-status top
set -g pane-border-format "#{pane_index} #{pane_title}"

# 增大回滚缓冲区
set -g history-limit 50000

# 状态栏美化（可选）
set -g status-bg colour235
set -g status-fg white
set -g status-left '#[fg=green]#S '
set -g status-right '#[fg=yellow]%Y-%m-%d %H:%M'
```

---

## 二、`~/.ssh/config` — SSH 配置

这是整套远程开发的基础。配好之后，ssh、scp、rsync、tmux 全都不需要再敲 IP 和端口。

```sshconfig
# ~/.ssh/config

# 保活：防止空闲连接被防火墙切断
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3

# 跳板机
Host jump
    HostName 192.168.1.100
    User wngzwng
    Port 22
    IdentityFile ~/.ssh/id_ed25519

# 内网开发机（通过跳板机直连）
Host dev
    HostName 10.0.1.50
    User wngzwng
    ProxyJump jump
    IdentityFile ~/.ssh/id_ed25519

# 生产数据库（只读，转发 agent）
Host db-prod
    HostName 10.0.3.20
    User admin
    ProxyJump jump
    ForwardAgent yes
```

**使用示例：**

```bash
ssh dev                # 自动走跳板机到内网开发机
scp file dev:/tmp/     # 传文件也自动走跳板机
ssh dev -t "tmux new-session -A -s work 'nvim .'"
# 一行命令：连开发机 → 创建或 attach tmux 会话 → 启动 Neovim
```

---

## 三、Neovim `init.lua` — 从基础到 tmux 集成

### 基础设置（每位 Neovim 用户必备）

```lua
-- ~/.config/nvim/init.lua

-- 基础选项
vim.opt.number = true          -- 显示行号
vim.opt.relativenumber = true   -- 相对行号（配合 motion 更直观）
vim.opt.shiftwidth = 2          -- 缩进宽度
vim.opt.tabstop = 2             -- Tab 宽度
vim.opt.expandtab = true        -- Tab 转空格
vim.opt.smartindent = true      -- 智能缩进
vim.opt.wrap = false            -- 不自动换行
vim.opt.hidden = true           -- 允许未保存 buffer 切换
vim.opt.ignorecase = true       -- 搜索忽略大小写
vim.opt.smartcase = true        -- 但如果搜索含大写字母则区大小写
vim.opt.swapfile = false        -- 不生成 .swp 文件
vim.opt.undofile = true         -- 持久化撤销历史
vim.opt.mouse = 'a'            -- 鼠标支持（分屏调整大小、选 pane）
vim.opt.clipboard = 'unnamedplus' -- 系统剪贴板互通

-- 基础快捷键
local map = vim.keymap.set

-- leader 键设为空格
vim.g.mapleader = ' '

-- 退出插入模式
map('i', 'jj', '<Esc>')

-- 窗口跳转（兼容 tmux 的 Ctrl+hjkl）
map('n', '<C-h>', '<C-w>h')
map('n', '<C-j>', '<C-w>j')
map('n', '<C-k>', '<C-w>k')
map('n', '<C-l>', '<C-w>l')

-- 保存
map('n', '<leader>w', ':w<CR>')
map('n', '<leader>q', ':q<CR>')

-- 清除搜索高亮
map('n', '<leader>h', ':noh<CR>')

-- 终端模式按 Esc 退出
map('t', '<Esc>', '<C-\\><C-n>')
```

### tmux 集成（置于上述基础设置之后）

```lua
-- 保存 Python 测试文件时，自动在 tmux 右 pane 跑 pytest
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = {"*_test.py", "test_*.py"},
  callback = function()
    local file = vim.fn.expand("%:t")
    vim.fn.system("tmux send-keys -t right 'pytest " .. file .. "' Enter")
  end,
})

-- 保存 Go 文件时，自动在 tmux 右 pane 跑 go test
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = {"*_test.go"},
  callback = function()
    local file = vim.fn.expand("%:t")
    vim.fn.system("tmux send-keys -t right 'go test -run " .. file .. "' Enter")
  end,
})

-- 在 Neovim 中快速向 tmux pane 发送命令
-- :TmuxSend <command> 发送到右边 pane
vim.api.nvim_create_user_command("TmuxSend", function(opts)
  vim.fn.system("tmux send-keys -t right '" .. opts.args .. "' Enter")
end, { nargs = 1 })
```

---

## 四、`dev-session.sh` — 一键启动远程开发环境

将此脚本放在 `~/bin/dev-session.sh`，赋予执行权限，每次开工只需：

```bash
bash ~/bin/dev-session.sh

或者直接通过 SSH 远程执行：

```bash
ssh dev -t 'bash -l -c "~/bin/dev-session.sh"'
```
```

脚本内容：

```bash
#!/bin/bash
SESSION_NAME="${1:-myapp}"  # 默认会话名 myapp，可传参覆盖

tmux new-session -d -s "$SESSION_NAME" -n code

# pane 0: Neovim
tmux send-keys -t "$SESSION_NAME" 'nvim .' Enter

# pane 1: 右侧分屏 — dev server
tmux split-window -h -t "$SESSION_NAME"
tmux send-keys -t "$SESSION_NAME":0.1 'npm run dev' Enter

# pane 2: 右下分屏 — 日志
tmux split-window -v -t "$SESSION_NAME":0.1
tmux send-keys -t "$SESSION_NAME":0.2 'tail -f logs/app.log' Enter

# pane 3: 左下分屏 — git 或 shell
tmux split-window -v -t "$SESSION_NAME":0.0
tmux send-keys -t "$SESSION_NAME":0.3 'git status' Enter

# 回到 Neovim pane
tmux select-pane -t "$SESSION_NAME":0.0
tmux attach -t "$SESSION_NAME"
```

布局效果：

```
┌───────────────────┬────────────────────┐
│                   │                    │
│  0: Neovim        │  1: npm run dev    │
│                   │                    │
├───────────────────┼────────────────────┤
│                   │                    │
│  3: git/shell     │  2: tail -f logs   │
│                   │                    │
└───────────────────┴────────────────────┘
```

---

## 五、Caps Lock → Esc/Ctrl（macOS）

Neovim 用得顺手的第一件事——把 Caps Lock 改成 Ctrl（按住时）/ Esc（单击时）。

**系统设置方式（macOS）：**

```
系统设置 → 键盘 → 键盘快捷键 → 修饰键
→ Caps Lock 键 → 选择 「Control」
```

**更推荐：用 Karabiner-Elements：**

1. 安装 `brew install --cask karabiner-elements`
2. 导入规则：Caps Lock → Escape on single press, Control on hold
3. 这样单击是 Esc（退出插入模式），按住是 Ctrl（tmux 前缀键）

---

## 六、快速参考卡

| 要做的事 | tmux 快捷键 | Neovim 快捷键 | SSH Config 等价 |
|---------|-------------|---------------|----------------|
| 竖分屏 | `prefix` `|` | `Ctrl+W v` | — |
| 横分屏 | `prefix` `-` | `Ctrl+W s` | — |
| 跳左 pane | `prefix` `h` 或 `Ctrl+h` | `Ctrl+W h` | — |
| 跳右 pane | `prefix` `l` 或 `Ctrl+l` | `Ctrl+W l` | — |
| 跳上 pane | `prefix` `k` 或 `Ctrl+k` | `Ctrl+W k` | — |
| 跳下 pane | `prefix` `j` 或 `Ctrl+j` | `Ctrl+W j` | — |
| 连服务器 | — | — | `ssh dev` |
| 走跳板机连服务器 | — | — | `~/.ssh/config` 配 `ProxyJump` |
| 一行连上开始干活 | — | — | `ssh dev -t "tmux new -A -s work nvim ."` |
| 传文件 | — | — | `scp file dev:/tmp/` |
| 本地连远程数据库 | — | — | `ssh -L 3306:127.0.0.1:3306 dev` |
| 保存文件 | — | `:w` | — |
| 保存退出 | — | `ZZ` | — |
| 发送命令到隔壁 pane | `tmux send-keys -t right 'cmd' Enter` | `:TmuxSend cmd` | — |
