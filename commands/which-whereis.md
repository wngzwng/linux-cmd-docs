
# which / whereis：命令在哪——排查 "command not found" 的第一步

你学了一个新命令，想试试——结果 Shell 说 "command not found"。你明明装了，为什么找不到？或者你找到了一个命令，想知道它到底执行的是哪个路径下的版本？

这就是 `which` 和 `whereis` 的事。它们不会帮你装东西，但会告诉你"它现在在哪"——以及为什么你找不到它。

---

## 场景引入：我明明装了 python3

```bash
python3 --version
# bash: python3: command not found

# 到底有没有？
which python3
# （空——PATH 里没找到）

whereis python3
# python3: /usr/local/bin/python3 /usr/share/man/man1/python3.1.gz
# 有！它在 /usr/local/bin/ 下，但你的 PATH 不包含这个目录
```

`whereis` 会搜索更广的范围（标准二进制目录 + man 路径），所以 `which` 找不到的东西，`whereis` 可能找到。

---

## 核心概念：which 查 PATH，whereis 查标准目录

| 命令 | 搜索范围 | 用途 |
|------|---------|------|
| `which` | 仅 `$PATH` | "如果我打 `python`，实际执行的是哪个文件？" |
| `whereis` | 标准二进制路径 + man 路径 + 源码路径 | "这个命令在哪里？（不管 PATH）" |

> 💡 **`which` 回答的是 Shell 的问题，`whereis` 回答的是文件系统的问题。**

---

## 核心参数

### which

```bash
which python3           # 显示匹配的第一个路径
which -a python3        # 显示所有匹配（比如 PATH 里有多个版本）
which ls                # 看 ls 实际执行的是哪个
```

### whereis

```bash
whereis python3         # 找二进制 + man + 源码
whereis -b python3      # 只找二进制
whereis -m python3      # 只找 man 手册
whereis -s python3      # 只找源码
```

---

## 场景驱动

### 1. 多版本冲突：到底执行的是哪个

```bash
# 系统装了 Python 2 和 Python 3
which python
# /usr/bin/python     ← 还是 Python 2

which -a python
# /usr/bin/python
# /usr/local/bin/python  ← 新版本也在这里
# 但 PATH 里 /usr/bin 在前面，所以执行的是旧的
```

### 2. 排查"command not found"

```bash
# 第一步：看看 PATH 里有没有
which some-command

# 第二步：文件系统里有没有（不在 PATH 也能搜到）
whereis some-command

# 第三步：如果 whereis 找到了，加 PATH
export PATH="/opt/some-app/bin:$PATH"
```

### 3. Shell 内置命令：which 找不到

```bash
which cd
# （空——cd 是 Shell 内置命令，不在 PATH 里）
# 用 type 来查看内置命令：
type cd
# cd is a shell builtin
```

### 4. 确认自己装没装某个工具

```bash
which docker       # 如果有输出 → 装了且在 PATH 里
which nvim         # 如果有输出 → 装了
```

---

## which vs type vs command -v

`which` 是外部命令，它在 PATH 里搜——但它不知道 Shell 的别名和内置命令。

```bash
alias ll='ls -lh'
which ll
# （空——which 不认别名）

type ll
# ll is aliased to 'ls -lh'

type cd
# cd is a shell builtin
```

> 💡 **在脚本里检查命令是否可用，用 `command -v` 而不是 `which`：**

```bash
# ✅ POSIX 标准，跨平台
if command -v docker &> /dev/null; then
  echo "docker 已安装"
fi

# ⚠️ 也能用，但不是 POSIX 标准
if which docker &> /dev/null; then
  echo "docker 已安装"
fi
```

---

## 新手踩坑总结

- **坑一：用 `which` 检查别名/内置命令。** which 只看 PATH 里的可执行文件。用 `type` 或 `command -v` 替代。
- **坑二：只想确认是否安装却用 whereis。** whereis 搜索范围比 PATH 广，找到了不代表能直接执行（PATH 可能没包含）。
- **坑三：which 只返回第一个匹配。** 如果 PATH 里有多个版本，用 `which -a` 才能全看到。
- **坑四：在脚本里用 which 判断命令存在。** 不可靠。用 `command -v`。

---

## 最后

`which` 和 `whereis` 是那种"平时用不到，出了问题第一个想起来的"命令。它们不解决任何实际问题——不装软件、不修配置——但它们是排查的第一步："这东西到底在不在？在的话在哪？"

下次 `command not found`，别急着 Google 安装命令。先 `whereis` 看看——它可能就在那里，只是你的 PATH 没看到它。
