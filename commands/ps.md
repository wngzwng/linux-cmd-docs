# 为什么 ps 很强，但大多数人只会 `ps aux | grep xxx`？

> `ps aux` 是每个运维的口头禅。但 `aux` 这三个字母是什么意思？`ps -ef` 又是什么？BSD 风格和 UNIX 风格有什么区别？ps 其实是一个进程查询引擎——你不需要记 `aux`，需要理解 ps 的查询维度。

## 一、你会遇到的场景

某天 CPU 飙到 100%，你需要找出是哪个进程干的。

新手的做法：`ps aux` → 刷屏 → `ps aux | grep java` → 找到 PID → 再用 `top -p PID` 看看实时 CPU。三个命令绕了一圈。

而真正理解 ps 的人：

```bash
ps aux --sort=-%cpu | head -10     # Linux：按 CPU 降序，只显示前 10
ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -10   # 更精确：自己选字段
```

**这就是 ps 的核心价值：查看当前进程的快照，按任意维度过滤、排序、选择显示字段。** ps = **p**rocess **s**tatus，它不是 `top` 的替代品，而是进程维度的"SQL 查询"。

## 二、语法骨架——BSD vs UNIX 风格

ps 有两套语法（历史原因），可以混用但建议固定一种：

```
BSD 风格（选项无 -）：
ps  aux            # a=所有终端用户进程, u=用户格式, x=含无终端的进程

UNIX 风格（选项有 -）：
ps  -ef            # -e=所有进程, -f=全格式
ps  -eo pid,cmd    # -e=所有, -o=自定义输出字段
```

> ⚠️ **`ps aux` 和 `ps -ef` 都能看所有进程，但输出列不同。** `aux` 显示 %CPU、%MEM、VSZ、RSS、TTY、STAT、START、TIME；`-ef` 显示 UID、PID、PPID、C、STIME、TTY、TIME、CMD。选哪个取决于你想看什么信息。

## 三、核心能力逐轴拆解

ps 的能力沿 4 个轴展开——每个轴回答一个独立问题，自由组合。

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 范围轴 | 看哪些进程？ | `-e`(所有)、`-p`(指定PID)、`-u`(指定用户)、`-C`(按命令名，Linux) |
| 格式轴 | 显示哪些列？ | `-f`(全格式)、`-l`(长格式)、`-o`(自定义)、`u`(用户格式) |
| 排序轴 | 按什么排序？ | `--sort=-%cpu`(Linux)、`-r`(BSD按CPU) |
| 层级轴 | 显示父子关系吗？ | `-H`(层级树)、`--forest`(ASCII树，Linux)、`-o ppid`(只显示PPID) |

---

### 轴 1：范围轴——"看哪些进程？"

```bash
# Linux: 所有进程（BSD 风格）
ps aux

# Linux: 所有进程（UNIX 风格）
ps -ef

# 指定 PID
ps -p 1234,5678 -f

# 指定用户的进程
ps -u root

# 只看某条命令启动的进程（Linux 特有）
ps -C nginx

# 只看某个终端上的进程
ps -t pts/0
```

---

### 轴 2：格式轴——"显示哪些列？"

> 场景：你不需要所有默认列，只想看 PID、CPU 使用率、命令行。

```bash
# 自定义输出列（最强大的功能！）
ps -eo pid,ppid,user,%cpu,%mem,cmd --sort=-%cpu | head

# 常用列名速查：
# pid, ppid(父进程), user, %cpu, %mem, vsz(虚拟内存), rss(物理内存)
# stat(进程状态), start(启动时间), time(累计CPU时间), cmd(命令行)
# etime(运行了多久), nice(NI值), comm(命令名不含参数)
```

> 💡 **`-o`（自定义列）才是 ps 真正的杀手级功能。** 你不需要接受 `aux` 或 `-ef` 的固定列宽和固定顺序——选你关心的字段，按你需要的顺序排列。

---

### 轴 3：排序轴——"按什么排？"

```bash
# Linux: 按 CPU 降序
ps aux --sort=-%cpu

# Linux: 按内存降序
ps aux --sort=-%mem

# BSD/macOS: 按 CPU 排序
ps aux -r    # 注：BSD 版行为可能不同

# 多级排序
ps aux --sort=-%cpu,-%mem
```

---

### 轴 4：层级轴——"谁 fork 了谁？"

```bash
# Linux: 树形显示进程关系
ps auxf    # BSD 风格的 forest
ps -ef --forest   # UNIX 风格的 forest

# 只显示进程树（指定 PID）
ps -eo pid,ppid,cmd --forest

# 只看某个进程及其所有子进程
ps --ppid 1234
```

---

## 四、Pipeline 组合——ps 天然配合 grep 和 kill

```bash
# 找到 nginx 的 PID 并杀掉
ps aux | grep nginx | grep -v grep | awk '{print $2}' | xargs kill
# 注：更安全的方式是 pidof nginx 或 pgrep nginx

# 统计某个进程有多少实例
ps -C nginx --no-headers | wc -l

# 看 Java 进程的 PID 和内存
ps -eo pid,rss,cmd | grep java | sort -rnk2 | head
```

> ⚠️ `ps | grep` 的经典陷阱：grep 本身会出现在 ps 输出里（它的命令行里含了你搜的关键词）。加 `grep -v grep` 或者用 `pgrep`（不需要 grep 技巧）。

## 五、踩坑清单

- **坑一：`ps aux` 中 grep 进程会匹配自己** → `ps aux | grep nginx` 会看到 grep 进程本身。加 `| grep -v grep` 或用 `pgrep nginx`。
- **坑二：BSD 和 UNIX 风格的选项混用可能出问题** → `ps aux -f` 的行为在不同系统上可能不一致。固定用一种风格。
- **坑三：ps 是快照，不是实时监控** → 要看实时变化用 `top` 或 `htop`。ps 是离散采样。
- **坑四：`%CPU` 是自进程启动以来的平均值** → 不是"当前 CPU 使用率"。短期 CPU 飙升在 ps 里看不出来——用 top 或 pidstat。
- **坑五：Linux 上 `ps -C` 按命令名筛选很方便，但 BSD/macOS 不支持** → 跨平台脚本用 `ps -eo pid,cmd | grep` 代替。

## 六、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 查进程快照、按字段筛选 | ps | 这正是 ps 的设计领域 |
| 实时监控 CPU/内存 | `top` / `htop` | ps 是快照，不更新 |
| 按名字找 PID | `pgrep` | 比 `ps \| grep` 更精确，不会有 grep 自己 |
| 按名字发信号 | `pkill` | 比 `ps \| awk \| xargs kill` 简洁得多 |
| 查看进程树 | `pstree` | 比 ps --forest 更直观的树形展示 |

---

> **核心观点：** 学 ps 不是为了记住 `aux` 三个字母，而是理解它的 **4 个能力轴**（范围、格式、排序、层级）。ps 的本质是一个进程维度的查询工具——你想看哪些进程（范围）、展示哪些字段（格式）、按什么排序、是否显示父子关系。这四个问题答上来，命令自然生成。
>
> 今天就把 `ps -eo pid,ppid,user,%cpu,%mem,cmd --sort=-%cpu | head` 存为你的 alias 吧。
