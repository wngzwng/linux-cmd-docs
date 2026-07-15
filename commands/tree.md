
# tree：给目录拍一张"X 光片"——新项目接手的第一分钟

如果你接手一个新项目，第一件事是干什么？八成是 "看看目录结构"。

然后新手做的事是这样的：`ls` 看一眼，`cd` 进去，`ls` 再看一眼，`cd ..` 出来，`cd` 进另一个目录…… 就这么一层层翻了十分钟，最后在纸上画了个目录树。

但 Linux 上早就有个命令叫 `tree`，它做的事只有一件：**把一个目录变成一张地图，让你一眼看清整个项目的地形。**

而且它很可能不在你的系统上——这是本文要先讲的事。

---

## 场景引入：接手一个陌生项目的第一分钟

你 `git clone` 了一个新项目，想快速理解代码组织结构。这个项目的目录大概有 50 个文件夹，嵌套了三四层。

新手做法：

```bash
ls              # 看到 10 个目录
ls src/         # 进 src 看看
ls src/utils/   # 再进一层
ls src/utils/helpers/   # ……
```

十分钟后你画出了一张目录树，但其中有几个目录根本没用到，白翻了。

老手做法：

```bash
tree -L 2       # 只看两层，两秒出结果
```

立刻看到全景：
- `src/` 下面有 `api/`、`utils/`、`components/`
- `tests/` 结构和 `src/` 一一对应
- `docs/` 里有 `api/` 和 `guides/`
- 根目录有 `Dockerfile`、`Makefile`、`package.json`

不用进任何一个目录，你已经对整个项目的结构有了整体认知。

---

## 安装：为什么你的系统大概率没有 tree

是的，tree 不是默认安装的。但装它只需要一行：

```bash
# macOS
brew install tree

# Debian / Ubuntu
sudo apt install tree

# Fedora / CentOS / RHEL
sudo dnf install tree

# Arch Linux
sudo pacman -S tree
```

---

## 核心概念：tree 不是 ls -R，是 structurize

tree 的核心逻辑：**递归遍历目录树，用缩进和线条画出层级关系。**

`ls -R` 也能递归列出内容，但输出是扁平的——你分不清层级。tree 做的是把层级关系**可视化**。

```
# ls -R 的输出（扁平，难以阅读）
src:
api  components  utils

src/api:
auth.go  user.go

# tree 的输出（层级清晰）
src
├── api
│   ├── auth.go
│   └── user.go
├── components
└── utils
```

> 💡 tree 的输出是"你可以直接截个图发给同事"级别的可读性。

---

## 核心参数拆解

### 第 1 层：控制深度 `-L`

**这是 tree 最重要的参数，没有之一。** 不加 `-L`，tree 会把整个目录的所有文件全部展开——一个大型项目能刷几十屏。

```bash
tree -L 2          # 只看两层：顶层目录 + 子目录
tree -L 3          # 三层：够看清楚"目录下有什么目录"
```

经验法则：**接手的项目先用 `-L 2` 看整体架构，需要深入某一块再 `cd` 进去。**

---

### 第 2 层：只看目录 `-d`

```bash
tree -d            # 只列目录，不列文件
tree -d -L 2       # 只列目录且限制深度——最常见组合
```

当你只是想了解"代码是怎么组织的"，根本不需要看文件。`-d` 过滤掉文件后，输出清爽到可以截图放进 README。

---

### 第 3 层：排除干扰 `-I`

```bash
# 排除 node_modules——不讲道理的大
tree -I node_modules

# 排除多个模式（用 | 分隔）
tree -I "node_modules|.git|*.log"

# 排除多个：每个 -I 一个
tree -I node_modules -I .git -I dist
```

> ⚠️ 坑：`-I` 后面的模式是 **glob 模式**，不是正则表达式。`*.log` 能匹配所有 .log 文件，但 `^node` 这种正则语法不生效。

---

### 第 4 层：输出文件大小/权限

```bash
tree -h            # 显示文件大小（人类可读：K/M/G）
tree -p            # 显示权限（如 drwxr-xr-x）
tree -u            # 显示文件所有者
tree -D            # 显示最后修改时间
```

这些通常不需要，但在做安全审计或迁移准备时有用。

---

### 第 5 层：输出到文件

```bash
# 把树形结构写到文件里（带颜色的终端字符也被写进去了）
tree > structure.txt

# 干净输出（不带颜色控制字符）
tree --charset=ascii > structure.txt
```

> 💡 如果你要把 tree 的输出写进 Markdown 文档，用 `--charset=ascii` 可以避免出现乱码的连线字符。

---

## 场景驱动：tree 的四个实战位置

### 1. 新项目考古

```bash
git clone https://github.com/something/big-project.git
cd big-project
tree -L 2 -I node_modules
```

30 秒内了解：这是个 frontend + backend 的 monorepo？测试放哪？配置文件散落在哪里？

### 2. 确认备份/同步是否完整

```bash
# 把原目录结构存下来
tree -d /data/project > /tmp/before.txt

# 复制/同步完成后
tree -d /backup/project > /tmp/after.txt

# 对比
diff /tmp/before.txt /tmp/after.txt
```

### 3. 展示给团队看

```bash
# 生成项目的结构说明，直接丢进 README
tree -L 2 -I "node_modules|.git|dist|build" --charset=ascii >> README.md
```

### 4. 排查"某个目录为什么这么大"

```bash
# 显示目录和文件大小，快速定位大头
tree -h -L 2 -d /var/log
# 一眼看出：nginx 占了 2G，其他都小
```

---

## 新手踩坑总结

- **坑一：没装 tree。** 很多人不知道有 tree 这个命令的存在，一直在用 `ls -R` 凑合。
- **坑二：不限制深度。** `tree` 不加 `-L` 在一个大项目里能输出几万行，终端直接卡死或刷屏。
- **坑三：`-I` 用的是 glob 不是正则。** 写 `-I "^node"` 不会生效。
- **坑四：输出带颜色控制字符。** 直接 `tree > file.txt` 后打开文件可能看到乱码。用 `--charset=ascii` 或 `-A` 解决。

---

## 什么时候换工具

| 需求 | tree 行不行 | 替代方案 |
|------|----------|---------|
| 快速看目录全貌 | 行 | `ls -R` 但输出没有层级感 |
| 只想看某个目录是否为空 | 杀鸡用牛刀 | `ls dir/` 或者 `find dir -maxdepth 0 -empty` |
| 需要统计文件数量/大小 | 不专业 | `du -sh * | sort -h` |
| 需要程序化遍历目录 | 不适合 | Python 的 `os.walk()` 或 shell 的 `find` |
| 展示给非技术人员 | 非常合适 | — |

---

## 最后

tree 是那种"装了就回不去"的命令——没装之前你觉得 `ls` 和 `cd` 凑合凑合也能用，装了之后你再也受不了没有 map 的探索。

下次接手一个新项目，别一层层翻目录了。先装 tree，然后 `tree -L 2 -I node_modules`——给你自己一个俯瞰视角。
