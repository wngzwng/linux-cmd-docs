
# mkdir / rmdir：每个 Linux 用户都用过，但 90% 的人只用了一半

如果你问 Linux 用户"mkdir 怎么用"，答案都是 `mkdir dir`。再问"还有呢"，大部分人沉默了。

mkdir 和 rmdir 是那种"太简单以至于没人去查 help"的命令——但也正因如此，它身上藏着几个你每天都在错过的能力。比如，很多人写过 `mkdir dir 2>/dev/null` 来避免"目录已存在"的报错，却不知道 mkdir 自带这个功能。比如，很多人一层层 `mkdir` 然后一层层 `cd`，却不知道一行 `mkdir -p` 就能递归创建到底。

这篇文章把两个命令合在一起讲，因为它们互为逆操作——但逆得并不对称。

---

## 场景引入：两个"本来想省事，结果更麻烦"的瞬间

### 场景一：创建一个深的目录路径

你需要为项目创建 `/data/app/logs/2025/07/13` 这个目录结构。

```bash
# 新手做法：一层层来
mkdir /data/app
mkdir /data/app/logs
mkdir /data/app/logs/2025
mkdir /data/app/logs/2025/07
mkdir /data/app/logs/2025/07/13
# 5 条命令，而且如果中间某层已存在，后面还可能报错

# 老手做法：一行搞定
mkdir -p /data/app/logs/2025/07/13
```

### 场景二：删一个空目录

你创建了一个临时目录，用完想删掉，但不确定里面是不是还有东西。

```bash
# 新手直觉：用 rm -rf
rm -rf /tmp/my-temp/

# 老手做法：用 rmdir
rmdir /tmp/my-temp/
# 如果目录非空，rmdir 会拒绝删除并报错——
# 这个"报错"其实是保护机制：防止你不小心删了还有用的文件
```

> 💡 rmdir 的"非空拒删"不是 bug，是功能。它给你一个安全网——rm -rf 没有。

---

## 核心概念：不只是 create 和 remove

mkdir 的核心逻辑：**在文件系统里创建一个新的目录入口。**

rmdir 的核心逻辑：**删除一个空目录的入口——仅当目录为空时才执行。**

两个命令的"逆操作"并不对称：mkdir 可以递归创建（`-p`），rmdir 也只能递归删除**空的**父目录（`-p`）——如果里面有文件，它不会碰。这种不对称其实是一种安全设计。

---

## 先排雷：`mkdir -p` 是你最需要的参数，但很多人并不知道

最常见的一个场景：

```bash
# ❌ 新手写法
mkdir /opt/myapp/logs 2>/dev/null
# 用 2>/dev/null 吞掉"目录已存在"的错误——粗暴但不够干净

# ✅ 正确写法
mkdir -p /opt/myapp/logs
# -p 有两个作用：
#   1. 递归创建所有不存在的父目录
#   2. 目录已存在也不报错
```

> 💡 **`mkdir -p` 是脚本里创建目录的唯一正确姿势。** 它同时解决了"父目录不存在"和"目标目录已存在"两个问题，不管你跑第一次还是第一百次都能正确执行。这是幂等操作的典范。

---

## 核心能力逐层拆解

### mkdir：创建目录

#### 1. 基础用法

```bash
mkdir new_dir                   # 在当前目录下创建
mkdir /absolute/path/new_dir    # 用绝对路径创建
mkdir ../relative/path/new_dir  # 用相对路径创建
```

#### 2. 递归创建 `-p`（三星推荐）

```bash
mkdir -p a/b/c/d                # 一次创建整个路径链
mkdir -p /var/log/myapp/archive # 目录已存在不报错，父目录不存在就创建
```

`-p` 是 mkdir 最重要、最被低估、出现频率最高的参数。记住它。

#### 3. 创建时指定权限 `-m`

```bash
mkdir -m 755 public_dir         # 创建并设权限为 rwxr-xr-x
mkdir -m 700 private_dir        # 创建并设权限为 rwx------
mkdir -m 1777 /tmp/shared       # 创建并设 sticky bit（任何人都能写，但不能删别人的文件）
```

不用创建后再 `chmod`，一步到位。

#### 4. 显示过程 `-v`

```bash
mkdir -pv a/b/c/d
# 输出：
# mkdir: created directory 'a'
# mkdir: created directory 'a/b'
# mkdir: created directory 'a/b/c'
# mkdir: created directory 'a/b/c/d'
```

在脚本里加 `-v`，让你知道它到底做了什么事——排查脚本异常时非常有用。

---

### rmdir：删除空目录

#### 1. 基础用法

```bash
rmdir empty_dir                 # 删除空目录
rmdir -p a/b/c/d                # 递归向上删除空的父目录
```

#### 2. `-p` 的行为：向上逐层删除

```bash
# 假设 a/b/c/d 每个目录都是空的
rmdir -p a/b/c/d
# 删除顺序：d → c → b → a
# 如果某一层非空，停止并报错——不会跳过
```

#### 3. rmdir vs rm -rf —— 什么时候用哪个

| | rmdir | rm -rf |
|---|---|---|
| 删除空目录 | ✅ 安全，非空拒删 | ⚠️ 可以但危险，不区分空/非空 |
| 删除非空目录 | ❌ 拒绝 | ✅ |
| 失误恢复成本 | 零——删不掉至少说明里面有东西 | 极高——删了就没了 |
| 脚本中使用 | ✅ 安全 | ⚠️ 需要极强的确认逻辑 |

> 💡 经验法则：**删你自己建的临时目录用 rmdir；清理旧日志用 find + -delete；只有你 100% 确定要彻底清理时才用 rm -rf。**

---

## 场景驱动

### 1. 脚本里的幂等目录创建

```bash
#!/bin/bash
# 不管跑多少次，下面这行都不会报错
mkdir -p /var/log/myapp/$(date +%Y/%m/%d)
```

### 2. 批量创建项目结构

```bash
# 一次创建标准的项目目录结构
mkdir -p project/{src/{components,utils,styles},tests,docs,scripts}

# 展开后等价于：
# project/
# ├── src/
# │   ├── components/
# │   ├── utils/
# │   └── styles/
# ├── tests/
# ├── docs/
# └── scripts/
```

> 💡 **花括号展开 `{a,b,c}`** 是 Shell 的特性不是 mkdir 的，但和 `mkdir -p` 配合极其好用。

### 3. 验证清理结果

```bash
# 清理临时目录
rmdir /tmp/build-* 2>/dev/null
# 2>/dev/null 只吞掉"目录非空"的错误
# 如果有东西删不掉，说明里面有残留——你应该去检查
```

### 4. 创建带特殊权限的共享目录

```bash
# 创建 /tmp/shared：任何人都能读写，但不能删除别人的文件
mkdir -m 1777 /tmp/shared
# 1 = sticky bit
# 777 = rwxrwxrwx
```

---

## 新手踩坑总结

- **坑一：不知道 `-p`，手写错误处理。** `mkdir dir 2>/dev/null` 不如 `mkdir -p dir` 干净。
- **坑二：不知道花括号展开。** `mkdir -p src/{a,b,c}` 一次创建三个子目录，很多人还在写三次 mkdir。
- **坑三：`rmdir` 删不掉就换 `rm -rf`。** rmdir 删不掉恰恰说明目录里有东西——这不是 rmdir 的问题，是你该先确认内容。
- **坑四：`rmdir -p` 期望递归删所有。** 中间有一层非空就会停，不是你期望的"跳过继续"。要清空用 find。

---

## 什么时候换工具

| 需求 | mkdir/rmdir 行不行 | 替代方案 |
|------|-------------------|---------|
| 递归创建嵌套目录 | 行（`-p`） | — |
| 删除非空目录 | 不行 | `rm -rf`（要非常确定） |
| 按条件批量删除目录 | 不行 | `find -type d -empty -delete` |
| 创建带特殊权限的目录 | 行（`-m`） | — |

---

## 最后

mkdir 和 rmdir 可能是 Linux 里最被低估的命令对——不是因为它们有多难，而是大家太"熟悉"了反而从不查文档。如果你到现在还以为 mkdir 只能一次创建一个目录，试试 `mkdir -p`。如果你到现在还在用 `rm -rf` 删临时目录，试试 `rmdir`。

三个字母的参数，区别在于写脚本时跑一次还是跑一百次都不报错。
