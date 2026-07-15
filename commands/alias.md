
# alias：你的手指在喊累，但你还在敲全称

如果你每天敲 `ls -lh` 十几次，说明你该设一个别名了。alias 是 Linux 里最简单的生产力提升工具——没有之一。它不改变命令的行为，只改变你调用命令的方式。

---

## 场景引入：你每天至少浪费了 100 次按键

```bash
# 你每天这样敲
git status
git log --oneline --graph --decorate -20
ls -lh
grep --color=auto -n "error" app.log
```

但你可以：

```bash
alias gs='git status'
alias gl='git log --oneline --graph --decorate -20'
alias ll='ls -lh'
alias grep='grep --color=auto'
```

键盘寿命翻倍，输入速度翻倍。

---

## 核心概念：alias = 命令的"昵称"

alias 的核心逻辑：**在 Shell 解析命令之前，把别名展开成完整命令。** 它是纯文本替换，不涉及任何命令执行。

```bash
alias ll='ls -lh'
# 当你输入 ll → Shell 自动替换成 ls -lh → 执行
```

---

## 核心用法

### 设置别名

```bash
alias ll='ls -lh'                     # 基本形式
alias ..='cd ..'                      # 无空格
alias ports='ss -tlnp'                # 复杂命令
alias untar='tar -xzvf'               # 带参数的别名
```

### 查看别名

```bash
alias                                 # 列出当前所有别名
alias ll                              # 查看某个别名的定义
```

### 删除别名

```bash
unalias ll                            # 删除单个别名
unalias -a                            # 删除所有别名
```

### 让别名永久生效

```bash
# 编辑 ~/.bashrc 或 ~/.zshrc
alias ll='ls -lh'
alias la='ls -la'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
```

---

## 场景驱动

### 1. 安全别名：防误操作

```bash
# 覆盖危险命令，强制加确认
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
# 每次覆盖操作都会提示确认——多一层保护
```

### 2. Git 快捷键

```bash
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'
# 日常 Git 操作减半
```

### 3. 快捷导航

```bash
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias www='cd /var/www'
alias logs='cd /var/log'
```

### 4. 辅助记忆复杂命令

```bash
# 不想每次背 tar 参数
alias untar='tar -xzvf'
alias tartar='tar -czvf'

# 查找大文件
alias bigfiles='find . -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -rh'
```

---

## 先排雷：alias 不会进子 Shell，不会进脚本

```bash
# 你在 ~/.bashrc 里设了
alias ll='ls -lh'

# 但在脚本里
#!/bin/bash
ll
# bash: ll: command not found
# 因为非交互式 shell 不加载 .bashrc
```

解决方法：
- 脚本里不要用 alias——用函数或写全命令
- 如果非要让脚本用 alias，脚本开头加 `shopt -s expand_aliases` 并 source 配置文件

---

## 新手踩坑总结

- **坑一：别名只存在当前会话。** `alias ll='ls -lh'` 只对当前终端窗口有效。新窗口要重新设或写进 `.bashrc`。
- **坑二：脚本里 alias 无效。** 非交互式 Shell 不加载别名。脚本中写全命令。
- **坑三：覆盖了原生命令。** `alias ls='ls -lh'` 没问题，但如果你 `alias ls='rm -rf'`——这是个恶作剧，别干。
- **坑四：alias 名称和命令名冲突。** `alias grep='grep --color=auto'` 是安全的。但如果你设了奇怪的别名覆盖原生命令，排查问题时会非常困惑。

---

## 什么时候换工具

| 需求 | alias 行不行 | 替代方案 |
|------|------------|---------|
| 简化命令输入 | ✅ 首选 | — |
| 需要参数化 | 不行 | Shell 函数（`function name() { ... }`） |
| 跨脚本复用 | 不行 | 写成独立的脚本放进 PATH |
| 临时会话用 | 行 | — |

---

## 最后

alias 是命令行里最"性价比高"的生产力提升工具。没有任何学习成本，没有任何副作用（只要别覆盖关键命令），没有任何依赖——但你每天能少敲几百次键盘。

如果你还没整理过自己的 aliases，现在就可以打开 `~/.bashrc`。把每天敲最多的五个命令设上别名——明天你会感谢今天的自己。
