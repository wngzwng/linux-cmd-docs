# systemctl：一个依赖拓扑驱动的进程生命周期管理器，假装是 service start/stop

你每天都在 `systemctl start nginx`、`systemctl status sshd`、`systemctl enable docker`。但如果问你：「`systemctl start nginx` 敲下去之后，systemd 怎么知道 nginx 依赖网络？如果网络没就绪它是等还是报错？启动失败后它会重试吗？」——大多数人只能回答「会启动 nginx」。

systemctl 的「表面身份」是服务管理工具。但它的**本质是一个依赖拓扑驱动的进程生命周期管理器**：unit 文件不是「配置文件」而是声明式状态机，systemd 负责解析依赖图、按拓扑顺序启动、监控健康状态、处理失败策略。

---

## 第一层：内部模型

### 1.1 Unit：一切皆单元

systemd 的世界里，一切被管理的东西都是 unit。unit 不是进程——它是**对系统资源的一种声明式描述**：

```
Unit 类型          管理对象              声明了什么
─────────────────────────────────────────────────────────────
.service           一个进程             怎么启动、怎么停止、失败了怎么办
.socket            一个 socket          监听哪个端口、权限是什么
.timer             一个定时任务          什么时候触发、触发哪个 service
.mount             一个挂载点           挂载哪个设备到哪个路径
.device            一个设备             udev 自动创建
.target            一组 unit 的集合      类似「运行级别」：multi-user.target
.slice             一个 cgroup 切片      资源限制的边界
```

> 💡 **Unit 文件不是「配置文件」——它是声明式状态机。** 你不写「先启动网络、再启动 nginx、如果网络挂了就停 nginx」这种命令式流程。你写：「nginx 依赖 network.target（Wants=）和 network-online.target（After=），Type=forking 表示 nginx 自己 fork 到后台，Restart=on-failure 表示挂了要重启」。systemd 自己推导执行顺序和失败策略。

### 1.2 依赖关系的四种声明

一个 unit 文件里，依赖关系不是「启动顺序」而是四种独立维度的声明：

```
[Unit]
Wants=network.target              ← 「想要」：我启动时尽量把它也拉起来
                                   它失败了不影响我启动
                                    
Requires=network.target           ← 「需要」：我启动时需要它存在
                                   它失败了我也失败
                                    
After=network.target              ← 「排在我后面」：我在它之后启动
                                   但不要求它一定成功
                                   
Before=shutdown.target            ← 「排在我前面」：我在它之前停止
```

这四个可以组合：

```
[Unit]
Wants=postgresql.service          # 我需要 PostgreSQL 起来
After=postgresql.service          # 但我必须等 PostgreSQL 先启动完
# 含义：先启动 PostgreSQL，如果它失败了，我的 Wants 不会导致我也失败
# （因为 Wants 不强制——但如果 PostgreSQL 没起来，我的应用也连不上）
```

> 💡 **Wants/Requires = 资源依赖，After/Before = 时序依赖，它们是正交的。** 最常见的误解是把 After 当成 Requires。`Wants= + After=` 才是「需要它，且等它先启动完」的正确组合。

### 1.3 cgroups：systemd 的「牢笼」

每一个 service unit 启动时，systemd 不是简单 `fork + exec`——它在 cgroup 里创建一个「笼子」：

```
/sys/fs/cgroup/system.slice/nginx.service/
  ├── cgroup.procs         ← 这个 cgroup 里所有的 PID
  ├── memory.max           ← nginx 能用的最大内存
  ├── cpu.weight           ← nginx 的 CPU 权重
  ├── pids.max             ← nginx 最多能 fork 多少子进程
  └── ...

systemctl stop nginx
  → 不是 kill 主进程
  → 是直接杀死整个 cgroup——nginx 主进程 + 所有子进程，一个都跑不掉
```

> 💡 **`systemctl stop` 不需要知道进程树——它杀的是整个 cgroup。** 这就是 systemd 比传统 init 脚本可靠的核心原因：传统 `kill $(cat /var/run/nginx.pid)` 杀不死 fork 出去的子进程，systemd 直接把笼子端了。

---

## 第二层：行为机制

### 2.1 systemctl start 的完整流程

```bash
systemctl start nginx
```

```
Step 1：解析 unit 文件
  systemd 在以下路径按优先级搜索 nginx.service：
  /etc/systemd/system/ > /run/systemd/system/ > /usr/lib/systemd/system/
  → 找到后解析 [Unit] [Service] [Install] 三个段落

Step 2：解析依赖图
  Wants=network.target       → 如果 network.target 没启动，先启动它
  Requires=network.target    → 如果启动失败，nginx 也标记为 failed
  After=network.target       → 等待 network.target 启动完成
  Before=shutdown.target     → 关闭时先停 nginx，再停其他

Step 3：创建 cgroup
  mkdir /sys/fs/cgroup/system.slice/nginx.service/
  → 写入 CPU、内存、PID 限制

Step 4：执行 ExecStart
  Type=simple（默认）：systemd fork → exec ExecStart 命令
  Type=forking：systemd fork → exec ExecStart → 等主进程 fork 到后台
    → 读 PIDFile 或用猜测算法找到主进程
  Type=oneshot：ExecStart 运行完就退出（服务不是常驻进程）
  Type=notify：服务启动后会通过 sd_notify() 通知 systemd「我好了」

Step 5：监控
  systemd 监控主进程 → 如果主进程退出：
    Restart=no           → 不重启
    Restart=on-failure   → 异常退出时重启
    Restart=always       → 无论如何都重启
```

### 2.2 Type=forking 的陷阱

这是最经典的 systemd 坑——Type=forking 用于 nginx、php-fpm 这类「自己 fork 到后台」的传统守护进程：

```ini
[Service]
Type=forking
ExecStart=/usr/sbin/nginx
PIDFile=/run/nginx.pid
```

问题：systemd 怎么知道 nginx 的「真正 PID」？

- 如果正确配置了 PIDFile → systemd 等 nginx 写入 PID 文件 → 读取 → 这就是主 PID
- 如果没有 PIDFile → systemd 用启发式算法猜测（可能猜错）
- 如果 nginx 在写 PID 文件之前就退出了 → systemd 永远等不到 → 超时 → 标记 failed

> 💡 **能改的应用程序，用 Type=notify 或 Type=simple。** `Type=notify` 让服务主动告诉 systemd「我准备好了」，不需要 systemd 猜。`Type=simple` 让 systemd 自己 fork+exec 的进程就是主进程（不 fork 到后台），推荐所有新写的服务使用。

### 2.3 timer unit 替代 cron

```ini
# /etc/systemd/system/cleanup.timer
[Unit]
Description=Run cleanup every hour

[Timer]
OnCalendar=hourly
RandomizedDelaySec=60       # 随机延迟 0-60 秒（避免惊群）
Persistent=true             # 如果机器在触发时间关机，启动后立即补跑

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/cleanup.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/cleanup.sh
```

```
systemctl enable cleanup.timer    # 激活定时器
systemctl start cleanup.timer
systemctl list-timers             # 查看所有定时器状态
```

> 💡 timer unit 相比 cron 的优势：
> - **日志进 journalctl**：不需要自己重定向 `>> /var/log/script.log 2>&1`
> - **依赖管理**：`After=network.target` 确保网络就绪才触发
> - **随机延迟**：`RandomizedDelaySec` 避免 100 台机器同时跑同一个任务
> - **Persistent**：错过了不跳过，启动后补跑

---

## 第三层：高级模式

### 3.1 drop-in 覆盖：不修改原文件

```bash
# 你不想改 /usr/lib/systemd/system/nginx.service（下次更新会被覆盖）
# 也不想复制到 /etc/systemd/system/（断了跟上游的同步）

systemctl edit nginx.service
# 创建 /etc/systemd/system/nginx.service.d/override.conf
```

```ini
# override.conf
[Service]
Environment="NGINX_WORKER_COUNT=8"
RestartSec=5s
```

> 💡 **原 unit 文件不动，你的修改在一个独立的 override.conf 里。** 系统更新 nginx 包 → 更新原 unit 文件 → 你的 override 继续生效。这是 Linux 配置管理的最佳实践：不是「改文件」，而是「叠加变更」。

### 3.2 资源限制直接在 unit 里声明

```ini
[Service]
# CPU
CPUQuota=200%                  # 最多用 2 个核
CPUWeight=100                  # 相对权重（默认 100）

# 内存
MemoryMax=512M                 # 硬限制：超过就 OOM Kill
MemoryHigh=400M                # 软限制：超过就 throttle（尽量不杀）

# 进程数
TasksMax=64                    # 最多 fork 64 个子进程

# I/O
IOWeight=100
IOReadBandwidthMax=/dev/sda 10M
```

不需要 `ulimit`、不需要 `cgexec`、不需要 wrapper 脚本——systemd 直接帮你写进 cgroup。systemctl show nginx 可以看到所有限制的实际生效值。

### 3.3 故障排查三板斧

```bash
# 1. 查看完整状态（含最近 10 行日志）
systemctl status nginx

# 2. 只看这个 unit 的日志
journalctl -u nginx -n 50 --no-pager

# 3. 跟踪日志（类似 tail -f）
journalctl -u nginx -f

# 4. 查看依赖关系
systemctl list-dependencies nginx          # nginx 依赖谁
systemctl list-dependencies nginx --reverse  # 谁依赖 nginx

# 5. 查看 unit 文件的实际生效内容（含 drop-in）
systemctl cat nginx

# 6. 查看所有运行时属性
systemctl show nginx | grep -E 'MainPID|MemoryCurrent|CPUUsage'
```

### 3.4 编写一个生产级 service unit

```ini
[Unit]
Description=My Web Application
Documentation=https://docs.example.com
Wants=network.target postgresql.service redis.service
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/server
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
RestartSec=5s

# 安全加固
NoNewPrivileges=yes           # 禁止通过 suid/sudo 提权
ProtectSystem=strict          # /usr /boot /etc 只读
ProtectHome=yes               # 隔离 /home /root
PrivateTmp=yes                # 独立的 /tmp
ReadOnlyPaths=/opt/myapp/conf # 配置文件只读

# 资源限制
MemoryMax=256M
CPUQuota=100%
TasksMax=32

# 日志
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myapp

[Install]
WantedBy=multi-user.target
```

> 💡 这个 unit 文件不只是「启动命令」——它集成了资源限制、安全加固、日志管理、重启策略。过去这些分布在 init 脚本、ulimit、sudoers、logrotate、crontab 六七个地方，现在全在一个文件里。

---

## 一句话

> systemctl 不是 service start/stop。systemctl 是一个依赖拓扑驱动的进程生命周期管理器：unit 文件是声明式状态机（不是配置文件），systemd 解析依赖图、按拓扑顺序启动、用 cgroup 做容器式的隔离和监控。理解了 unit 的四种依赖声明（Wants/Requires + After/Before）和 cgroup 的隔离机制，systemd 就不再是「比 init.d 方便一点」——它是 Linux 进程管理的终极抽象。
