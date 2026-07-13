
# Neovim + tmux：两只手比一只手强

分开说，tmux 是"终端会话管理器"，Neovim 是"文本编辑器"。各自都是各自领域的神器。但把它们放在一起时，有些场景是单独任何一个都做不到的。

---

## 场景一：在 tmux 分屏里跑 Neovim + 终端

这是最直观的组合。一个 tmux 会话，两个 pane：左边 Neovim，右边 Shell。

```
┌───────────────────┬────────────────────┐
│                   │                    │
│    Neovim         │    Shell / 终端    │
│    (编辑代码)     │    (跑测试/查日志) │
│                   │                    │
└───────────────────┴────────────────────┘
```

**典型用法：**

```
Ctrl+B %        # 垂直分屏
# 左 pane 启动 Neovim
# 右 pane 跑 dev server 或 tail -f logs
```

在 Neovim 里改了代码，`:w` 保存，切到右 pane（`Ctrl+B 右`），跑测试。不需要 `:term`，不需要退出编辑器，两个 pane 各自独立。

**比 Neovim 内置终端好在哪里？**

| 对比 | Neovim `:term` | tmux 分屏 + Neovim |
|------|----------------|---------------------|
| 终端独立性 | 在 Neovim 进程内，关掉 Neovim 就没了 | 独立进程，关了 Neovim 终端还在跑 |
| 滚动历史 | 受限于 Neovim 缓冲区 | tmux 有自己的回滚缓冲区，可以翻更大历史 |
| 多会话 | 只有当前 Neovim 里的终端 | tmux 窗口可以在不同会话间共享 |

---

## 场景二：tmux 的"发送命令" + Neovim

tmux 可以**从命令行直接往指定 pane 里发送内容**，这意味着你可以用脚本控制终端。配合 Neovim 的自动命令，可以实现"保存文件后自动在隔壁 pane 跑测试"。

**在 `.tmux.conf` 里定义一个按键：**

```tmux
# 把当前 Neovim 文件路径发送到 pane 1
bind-key T send-keys -t 1 "nvim " Enter
```

**实际的黄金组合：用 Neovim 的 `autocmd` + tmux 的 `send-keys`**

在 Neovim 的配置里（`init.lua`）：

```lua
-- 保存 Python 文件时自动在 tmux 右 pane 跑测试
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = {"*_test.py", "test_*.py"},
  callback = function()
    local file = vim.fn.expand("%:t")
    vim.fn.system("tmux send-keys -t right 'pytest " .. file .. "' Enter")
  end,
})
```

> 💡 实际效果：你在 Neovim 里改了测试代码，`:w` 保存，隔壁 pane 自动开始跑测试，你不用切过去、不用手动敲命令。盯着 Neovim 写代码，余光瞟一眼右边就知道过没过。

---

## 场景三：tmux 保存 Neovim 的崩溃现场

这是 tmux 最被低估的价值。

你在 Neovim 里改了三个文件，还没保存，SSH 断了。如果没有 tmux：

- 没保存的改动全丢
- Neovim 的 swap 文件可能留下残影，下次打开提示"恢复？"

如果有 tmux：

```
SSH 断 → tmux 会话还在跑 → 重新 SSH 连上 → tmux attach
→ Neovim 还在，光标停在断线前的位置，unsaved changes 还在
```

**这不是理论**，这是实际效果。因为 tmux 的 server 在你 SSH 断开时**不会收到 SIGHUP**，里面的 Neovim 进程连"连接断了"都不知道，一切照常运行。你再连回去时，就像什么都没发生过。

---

## 场景四：tmux + Neovim 远程协作

一个人用 Neovim 编辑，另一个人 `tmux attach` 到同一个会话看——这是最简单粗暴的"远程结对编程"。

```
# 用户 A 在服务器上
tmux new -s pair
nvim main.py

# 用户 B SSH 到同一台机器
tmux attach -t pair
# 现在两人看到同一个 tmux 会话，同一个 Neovim 窗口
```

**局限：**
- 两人共享键盘控制权（谁打字谁控制）
- 没有独立的 cursor（看的人只能干看）
- 没有语音？需要额外开一个语音通道

**比什么好：** 比 screen 的 multiuser 模式简单，比 VS Code Live Share 轻量（不需要装任何东西，有 SSH 和 tmux 就行）。

---

## 场景五：tmux 作为 Neovim 的"程序启动台"

一个 tmux 窗口布局对应一个项目的工作区：

```
┌───────────────────┬────────────────────┐
│                   │                    │
│    Neovim         │   npm run dev      │
│                   │                    │
├───────────────────┼────────────────────┤
│                   │                    │
│    tail -f logs   │   git log --oneline│
│                   │                    │
└───────────────────┴────────────────────┘
```

然后把这个布局落地成脚本：

```bash
#!/bin/bash
# ~/bin/dev-session.sh

tmux new-session -d -s myapp -n code
tmux send-keys -t myapp 'nvim .' Enter

tmux split-window -h -t myapp
tmux send-keys -t myapp:0.1 'npm run dev' Enter

tmux split-window -v -t myapp:0.1
tmux send-keys -t myapp:0.2 'tail -f logs/app.log' Enter

tmux select-pane -t myapp:0.0
tmux attach -t myapp
```

每次开始工作，只需要 `bash ~/bin/dev-session.sh`，tmux 自动创建好布局、自动启动 Neovim、自动跑 dev server。你进去就开始写代码。

> **这才是 Neovim + tmux 的真正价值：它们不是两个工具各干各的，而是通过 tmux 的脚本化 pane 控制 + Neovim 的自动命令，组成一个你可以用脚本描述和复现的开发环境。**

---

## 新手踩坑总结

- **在 tmux 的 Neovim 里复制粘贴双重痛苦** → 先 `Ctrl+B [` 进 tmux 复制模式，再在里面用 Neovim 的 `y` 复制。更简单：`set -g mouse on` 让 tmux 支持鼠标选择复制
- **分屏方向混乱** → 建议统一：tmux 的 `Ctrl+B |`（竖分）和 `Ctrl+B -`（横分），Neovim 的 `Ctrl+W v/s`，让两边的分屏方向习惯一致
- **快捷键冲突** → Neovim 的 `Ctrl+W`（窗口跳转）和 tmux 的 `Ctrl+B` 前缀不冲突，但如果你把 tmux 前缀改成 `Ctrl+A`，注意和行首快捷键别撞
- **忘了哪个 pane 是 Neovim 哪个是 Shell** → 给 pane 设置颜色或标题。tmux：`tmux select-pane -t 0 -T "nvim"`

---

## 什么时候不用组合

- **如果你只在本地开发**，iTerm2 + macOS 自带的分屏就够用了，不需要 tmux 那层抽象
- **如果你只用 VS Code**，Remote-SSH 插件内置了终端管理，不需要 tmux
- **如果你用 Neovim 内置 `:term` 已经满足**，不需要再引入 tmux 的 pane 管理

需要 Neovim + tmux 在一起的标志性信号是：**你在 SSH 远程服务器上写代码，且你的工作流里需要一个"编辑器旁边始终有一个独立终端"的固定布局。**
