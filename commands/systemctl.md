# 为什么 systemctl 很强，但大多数人只会 `start` 和 `stop`？

> 很多人用 systemd 管服务，永远只会 `systemctl start/stop/restart nginx` 这三板斧。其实 systemctl 是一套完整的服务生命周期管理工具——查状态、看日志、设开机启动、分析依赖，一个命令搞定。

## 一、你会遇到的场景

某天你改了 nginx 配置，执行 `systemctl restart nginx`——结果起不来。日志在哪？依赖的 PHP-FPM 是不是也死了？开机后会自动启动吗？

新手的做法：`ps aux | grep nginx`、`/var/log/nginx/` 翻日志、`chkconfig --list`——三个不同的命令，各自为政。

而真正理解 systemctl 的人，三个动作一个命令：

```bash
systemctl status nginx    # 状态 + 最近 10 行日志 + 进程信息，一个命令全看到
```

**这就是 systemctl 的核心价值：统一管理 systemd 单元（unit）——服务、定时器、socket、挂载点，全部用同一套命令管控。** 它是一个状态管理器，不是一个简单的 `service start` 替代品。

> ⚠️ systemctl 是 Linux systemd 特有的命令，macOS/BSD 上不存在。本文以 Linux + systemd 环境为准。

## 二、对象模型——systemd 的世界里有什么

systemctl 管理的不是"服务"，而是 **unit（单元）**。一个 unit 可以是：

```
Unit（单元）
  ├─ service     —— 守护进程（nginx, sshd, docker）
  ├─ socket      —— 套接字激活（收到连接时才启动服务）
  ├─ timer       —— 定时任务（cron 的替代）
  ├─ mount       —— 挂载点
  ├─ target      —— 一组 unit 的集合（类似运行级别 runlevel）
  ├─ device      —— 设备
  ├─ slice       —— 资源分组（cgroup）
  └─ scope       —— 外部创建的进程组
```

每个 unit 有一个 **状态**：
```
inactive → activating → active → deactivating → inactive
                               ↘ failed
```

> 💡 理解了这个层级，`systemctl enable nginx` 就自然能解释了：它创建了一个符号链接，让 nginx.service 在系统启动时随 `multi-user.target` 一起激活。`enable` 和 `start` 是两个独立的轴——enable 控制开机启动，start 控制当前运行。

## 三、语法骨架——先把句型刻进脑子里

```
systemctl  动作  单元名
           ─┬─   ──┬──
           操作    目标
```

属于**骨架模式 C**：`动作 + 目标`。和 kill、docker 同族。它的模式非常固定——一个动词（动作）+ 一个名词（unit 名称）。

⚠️ **在讲具体能力之前，先排一个新手几乎必踩的雷：**

### 雷一：`enable` ≠ `start`，`disable` ≠ `stop`

```bash
# ❌ 误解：以为 enable 就是启动
systemctl enable nginx    # 只是设置开机自启，现在不会启动

# ✅ 正确认知：
systemctl start nginx     # 现在启动 nginx
systemctl enable nginx    # 设置开机自启（创建符号链接）
systemctl enable --now nginx   # 同时 enable + start（推荐！）
```

> ⚠️ **`enable` 和 `start` 是两个完全独立的维度。** enable 改变的是"开机后是否自动启动"（状态是 static/enabled/disabled），start 改变的是"现在跑没跑"（状态是 active/inactive）。这个误解几乎 100% 的新手都会碰。

---

## 四、核心能力逐轴拆解

systemctl 的能力沿 4 个轴展开。

| 能力轴 | 问题 | 核心子命令 |
|--------|------|-----------|
| 生命周期轴 | 启动/停止/重启/重载？ | `start`、`stop`、`restart`、`reload`、`kill` |
| 状态轴 | 现在什么状态？为什么挂了？ | `status`、`is-active`、`is-enabled`、`is-failed`、`list-units` |
| 启动轴 | 开机后自动启动吗？ | `enable`、`disable`、`reenable`、`mask`、`unmask` |
| 日志轴 | 最近输出了什么？ | `journalctl -u`（虽然不是 systemctl 子命令，但和它紧密配合） |

---

### 轴 1：生命周期轴——"让服务跑起来或停下来"

> 场景：改了配置文件后要让服务生效。

```bash
# 启动 / 停止 / 重启（完全停止再启动）
systemctl start nginx
systemctl stop nginx
systemctl restart nginx

# 重载配置（不中断服务——不是所有服务都支持 reload）
systemctl reload nginx

# 强制终止（SIGTERM → 等待超时 → SIGKILL）
systemctl kill -s SIGKILL nginx
```

> 💡 `reload` vs `restart`：**先尝试 `reload`。** 如果服务支持（nginx、haproxy 都支持），reload 不会断开现有连接——这在生产环境是巨大的差别。只有改了影响启动参数的配置时才需要 restart。

---

### 轴 2：状态轴——"现在什么情况？"

> 场景：你怀疑 nginx 挂了，或者想知道它为什么挂了。

```bash
# 完整状态：最近日志 + 进程树 + 状态 + 启动时间
systemctl status nginx

# 只判断是否在运行（脚本里用——退出码 0=运行中）
systemctl is-active nginx

# 是否设了开机自启
systemctl is-enabled nginx

# 查看所有 failed 的 unit
systemctl list-units --state=failed

# 列出所有 service 类型的 unit（含已停止的）
systemctl list-units --type=service --all
```

> 💡 `systemctl status` 是排障第一站——它会显示最近 10 行日志，这比你先敲 `systemctl status` 再敲 `journalctl -u` 快得多。

---

### 轴 3：启动轴——"开机后自动启动吗？"

> 场景：机器重启后，服务能自己起来吗？

```bash
# 设开机自启
systemctl enable nginx

# 取消开机自启
systemctl disable nginx

# 同时 enable + start（推荐）
systemctl enable --now nginx

# 重新创建符号链接（改了 unit 文件后）
systemctl reenable nginx

# mask：禁止启动——连手动 start 都不行（比 disable 更强）
systemctl mask nginx
systemctl unmask nginx
```

> 💡 `mask` 的原理是把 unit 的符号链接指向 `/dev/null`，这样无论手动还是自动都无法启动——适合"这个服务绝对不该在这台机器上跑"的场景。

---

### 轴 4：日志轴——"服务最近输出了什么？"

> 场景：服务挂了，你想看它的日志——但不直接去 `/var/log/` 翻。

虽然日志查看是 `journalctl` 的命令，但它和 systemctl 紧密配合：

```bash
# 查看某个 unit 的日志
journalctl -u nginx

# 实时跟踪（等同于 tail -f）
journalctl -u nginx -f

# 只看本次启动以来的日志
journalctl -u nginx -b

# 只看最近的
journalctl -u nginx --since "10 minutes ago"

# 只看错误级别
journalctl -u nginx -p err
```

---

## 五、真实排障全流程复盘

场景：改完 nginx 配置后，`restart` 失败了。

**第一步：看状态——为什么挂了？**
```bash
systemctl status nginx
```
状态行直接显示 `failed` 和退出码，下面 10 行日志通常就能看出原因（端口冲突？语法错误？）。

**第二步：如果状态输出不够——深入日志**
```bash
journalctl -u nginx --since "5 minutes ago" -p err
```

**第三步：修复后重新加载**
```bash
nginx -t                      # 先测试配置文件语法
systemctl reload nginx        # 优雅重载（先试试 reload）
# 如果 reload 也失败，说明配置损坏严重
systemctl restart nginx       # 再试 restart
```

**第四步：确认恢复正常**
```bash
systemctl is-active nginx     # 返回 active
systemctl status nginx        # 看一眼确认
```

---

## 六、踩坑清单

- **坑一：`enable` ≠ `start`** → enable 只改开机自启，不改当前状态。用 `enable --now` 一次搞定两件事。
- **坑二：`systemctl daemon-reload` 忘了执行** → 改了 unit 文件后，必须先 `systemctl daemon-reload` 让 systemd 重新读取配置，否则 start/enable 用的还是旧配置。
- **坑三：`restart` 会断开所有连接** → 生产环境能 reload 绝不 restart。nginx、haproxy、apache 都支持 reload。
- **坑四：`stop` 后进程不一定立刻消失** → systemd 会给进程一个超时窗口（默认 90s），超时才 SIGKILL。`systemctl status` 里可以看到进程处于 `deactivating` 状态。
- **坑五：`list-units` 默认不显示已停止的 unit** → 加 `--all` 才能看到全部。排查"为什么开机自启设了但没跑"时需要用 `--all` 看看 unit 是不是 `inactive`。

## 七、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 管理 systemd 服务 | systemctl | 这是 systemctl 的设计领域 |
| SysV init 系统（老 Linux） | `service` / `chkconfig` | systemctl 不存在 |
| 容器化服务 | `docker` / `kubectl` | systemd 管宿主机上的服务，不管容器 |
| 查看系统日志 | `journalctl` | systemctl status 只显示最近 10 行，完整日志要 journalctl |
| 查进程信息 | `ps` / `top` | systemctl 只看 unit 管理下的进程 |

---

> **核心观点：** 学 systemctl 不是为了记住 `start/stop/enable` 三个子命令，而是理解 systemd 的 **对象模型**（unit → service/socket/timer/target）和 **4 个能力轴**（生命周期、状态、启动、日志）。systemd 做的不只是"管服务"，它是在管"系统里所有守护进程的生命周期"。
>
> 下次你敲 `service nginx restart` 的时候，想想——systemctl 能做的不止这些。
