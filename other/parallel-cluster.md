
# 为什么 parallel 能把三台服务器当一台用，长任务却没人敢直接跑？

很多人发现 `parallel -S` 能 SSH 到多台机器并行跑任务时，第一反应都是「这不就是免费的集群吗？」——把 10 台服务器的核数加一加，几百个槽位一起跑，相当于一台几百核的大机器。

然后真的去跑长任务——一个任务 10 小时那种。跑了 9 小时 50 分，网络闪断两秒，SSH 连接断了，任务白跑。重试又 10 小时。

其实 parallel 的集群调度本身没问题，真正的问题在于 **它把任务生死绑在了 SSH 连接的生死上**。这篇文章要讲的，就是如何解开这个绑定——用三个文件做「任务状态协议」，让 parallel 只管发射和收结果，任务自己在远端跑，再也不怕断网。

适用场景：单任务 ≥ 1 小时的 CPU/IO 密集型批处理，多台服务器共同消化同一批输入。

---

## 场景引入

你有三台服务器：

| 机器 | CPU 核数 | 脚本路径 | 数据路径 |
|---|---|---|---|
| server1 | 48 | `/opt/app/bin/heavy_task` | `/mnt/ssd/inputs/` |
| server2 | 72 | `/home/deploy/scripts/heavy_task` | `/data/pool/inputs/` |
| server3 | 72 | `/opt/app/bin/heavy_task` | `/data/pool/inputs/` |

一共 192 核，要处理 1000 个数据文件，每个文件跑 `heavy_task` 大概 3～8 小时。数据已经分别在各自的路径下了，脚本也是。没装 SLURM，也没有共享存储，只有 SSH。

新手的第一反应往往是：
- 把 1000 个文件手动切成 3 份，分别 scp 到三台机器，手动 ssh 过去跑 — 然后 server2 先跑完了干等着，server1 还在死磕
- 用 `parallel -S 48/server1,72/server2,72/server3 'heavy_task {}' ::: *.dat` — 结果半夜 VPN 断了，192 个 SSH 连接全断，全部白跑
- 干脆找运维装 SLURM，配了一周环境还没跑起来

而真正理解 parallel 的调度模型和 SSH 连接边界的人，会这样做：

```bash
# 第一步：发射全部任务到远端，SSH 只活几秒
./launch.sh

# 第二步：定期巡检状态，进程挂了的标记失败，跑完的标记完成
./status.sh

# 第三步：全部完成后一次性收集所有结果
./collect.sh
```

SSH 连接只在发射、巡检、收集时短暂存在。任务在远端由 `nohup` 守护，本机关机、断网、甚至重启，远端任务照跑不误。

---

## 核心问题：SSH 连接 ≠ 任务进程

parallel 的原生模型是这样工作的：

```
本机 parallel 进程
  │
  ├── ssh server1 'heavy_task file1.dat'  ← 这个 SSH 会一直活到 heavy_task 结束
  ├── ssh server1 'heavy_task file2.dat'
  ├── ssh server2 'heavy_task file3.dat'
  └── ...
```

一条 SSH 连接 = 一个任务。任务跑 10 小时 = SSH 连接维持 10 小时。

**SSH 连接是脆弱的。** 防火墙超时、NAT 表过期、机房交换机重启、本机 VPN 断开、笔记本合盖休眠——任何一次网络抖动都可能导致 SSH 断开。而 SSH 一断，parallel 收到非零退出码，标记任务失败，按 `--retries` 重试——9 小时 50 分的任务重跑就是又一个 10 小时。

**解决方案的核心思想只有一句话：让 heavy_task 和 SSH 解绑。** parallel 不再「等」任务结束，而是「发射」任务到远端后台，立即断开 SSH。任务的生命周期由远端操作系统管理，状态通过文件系统交流。

---

## 先排雷：SSH 连接的三层瓶颈

在写脚本之前，必须先把 SSH 层面的坑填了。192 个并发槽位的场景下，默认 sshd 配置根本扛不住。

### 坑一：MaxStartups 默认才 10

parallel 启动时瞬间开 192 个 SSH 连接，服务端 sshd 的 `MaxStartups` 默认只允许 10 个并发认证，超出部分直接拒绝。你会看到：

```
ssh_exchange_identification: Connection closed by remote host
```

在**三台机器**的 `/etc/ssh/sshd_config` 里加上（需 root）：

```bash
MaxStartups 200:30:256
MaxSessions 200
```

然后 `systemctl reload sshd`（不影响当前连接）。

### 坑二：NAT/防火墙空闲断开

SSH 连接即使没断，长时间无输出可能被中间设备当死连接杀掉。在本机 `~/.ssh/config` 加上心跳：

```
Host server1 server2 server3
    ServerAliveInterval 30
    ServerAliveCountMax 6
    TCPKeepAlive yes
```

每 30 秒发一次心跳，连续 6 次（3 分钟）没回应才断开。

### 坑三：频繁 SSH 握手的开销

即使我们用短连接（发射、巡检、收集），频繁握手也有开销。用 SSH multiplexing 复用 TCP 连接：

```
Host server1 server2 server3
    ControlMaster auto
    ControlPath /tmp/ssh-mux-%r@%h:%p
    ControlPersist 24h
```

这样物理上只有 3 条 TCP 连接（一台一条），所有 SSH session 复用这三条。`ControlPersist 24h` 让复用通道保留 24 小时不用重建。

---

## 文件协议：三个文件管理任务生命周期

前面说了，解开 SSH 绑定后需要一个中间人记录状态。最简单的方法就是文件系统——每个任务一个目录，里面三个文件：

```
/opt/jobs/                      ← 远端工作根目录
├── file1/
│   ├── pid                     ← 进程号
│   ├── status                  ← 当前状态 + 时间戳
│   ├── result.out              ← heavy_task 输出的结果文件
│   ├── stdout.log              ← 标准输出日志
│   └── stderr.log              ← 标准错误日志
├── file2/
│   └── ...
└── file3/
    └── ...
```

| 文件 | 写入者 | 内容示例 |
|---|---|---|
| `pid` | launch 脚本 | `12345` |
| `status` | launch 写 `RUNNING`，status 脚本更新 | `RUNNING 1718000000` / `DONE 1718036000` / `FAILED 1718036000` |
| `result.out` | heavy_task 自己写 | 计算结果 |
| `stdout.log` / `stderr.log` | heavy_task 重定向 | 任务日志 |

「协议」就两条约定：

**约定一：status 文件的取值**

```
RUNNING <启动时间戳>    ← 任务在跑
DONE <完成时间戳>       ← 正常结束，result.out 存在
FAILED <检测时间戳>     ← 进程没了且没找到 result.out
```

**约定二：判断进程是否还活着的规则**

```bash
pid=$(cat pid)
if kill -0 $pid 2>/dev/null; then
    # 还在跑，别动
else
    # 进程没了
    if [ -f result.out ]; then
        echo "DONE $(date +%s)" > status
    else
        echo "FAILED $(date +%s)" > status
    fi
fi
```

没有消息队列，没有 RPC，没有数据库。就是文件系统 + shell 内置命令。下面把整个流程拆成三个可独立运行的脚本。

---

## 准备工作：ssh_wrapper

由于三台机器的脚本路径和数据路径不同，需要一个 wrapper 在 SSH 之前注入正确的环境变量。放在本机，`chmod +x`：

```bash
#!/bin/bash
# ssh_wrapper —— 根据目标主机注入路径
# 用法: parallel --ssh ./ssh_wrapper -S 48/server1,72/server2,72/server3 '...'

HOST="$1"
shift

case "$HOST" in
    server1)
        ssh "$HOST" "export BIN=/opt/app/bin DATA=/mnt/ssd/inputs; $*"
        ;;
    server2)
        ssh "$HOST" "export BIN=/home/deploy/scripts DATA=/data/pool/inputs; $*"
        ;;
    server3)
        ssh "$HOST" "export BIN=/opt/app/bin DATA=/data/pool/inputs; $*"
        ;;
    *)
        ssh "$HOST" "$@"
        ;;
esac
```

parallel 会自动把 `$BIN` 和 `$DATA` 代入命令模板。新加机器只改这一个 `case`。

---

## launch.sh：发射全部任务

核心逻辑：parallel 连接到每台机器 → 创建任务目录 → `nohup &` 把 heavy_task 丢到后台 → 记录 PID 和 RUNNING 状态 → SSH 立即退出。

parallel 的每个「任务」只活几秒，192 个任务很快全部发射完毕。

```bash
#!/bin/bash
# launch.sh —— 将所有任务发射到三台服务器
# 依赖: ssh_wrapper（同目录下，已 chmod +x）
# 远端需存在 $BIN/heavy_task 和 $DATA/*.dat

set -euo pipefail

JOBS="48/server1,72/server2,72/server3"
WORKDIR="/opt/jobs"
INPUTS=(/path/to/local/inputs/*.dat)   # 输入文件名列表（只要文件名，不要路径）

parallel \
    --ssh ./ssh_wrapper \
    -S "$JOBS" \
    --workdir "$WORKDIR" \
    --sshdelay 0.05 \
    --joblog launch_log.tsv \
    --eta \
    'JOB_DIR="'"$WORKDIR"'/{/.}"
     mkdir -p "$JOB_DIR"
     nohup $BIN/heavy_task \
         --input "$DATA/{}" \
         --output "$JOB_DIR/result.out" \
         > "$JOB_DIR/stdout.log" \
         2> "$JOB_DIR/stderr.log" &
     PID=$!
     echo "$PID" > "$JOB_DIR/pid"
     echo "RUNNING $(date +%s)" > "$JOB_DIR/status"
     echo "LAUNCHED {} → PID=$PID on $(hostname)"' \
    ::: "${INPUTS[@]}"

echo "✅ 全部任务已发射。查看进度: ./status.sh"
echo "   完成后收集结果: ./collect.sh"
```

逐段解释：

| 代码 | 目的 |
|---|---|
| `{/.}` | 去掉扩展名：`file1.dat` → `file1`，用作任务目录名 |
| `mkdir -p "$JOB_DIR"` | 为每个任务创建独立目录 |
| `nohup ... &` | 把 heavy_task 丢到远端后台，脱离 SSH 会话 |
| `PID=$!` | 抓取后台进程的 PID（`$!` 是 shell 内置变量，返回上一个后台命令的 PID） |
| `echo "$PID" > pid` | 写入 PID 文件，后续 status.sh 用来检查进程是否还活着 |
| `echo "RUNNING $(date +%s)" > status` | 写入初始状态 + 时间戳 |
| `--sshdelay 0.05` | SSH 连接间隔 0.05 秒，避免瞬间 192 并发撞上 sshd 的 MaxStartups |

`--joblog launch_log.tsv` 记录了每条发射命令的退出码——正常应该全是 0。如果有非零，说明那台机器的 SSH 或路径有问题，对应任务没发射成功。

---

## status.sh：巡检任务状态

定期运行，检查每台机器上所有任务目录的 status 文件：

- 如果 `RUNNING` 但 `kill -0 $pid` 失败 → 进程已消失，根据 result.out 是否存在判 DONE 或 FAILED
- 如果已经是 `DONE` 或 `FAILED` → 跳过
- 统计汇总输出

```bash
#!/bin/bash
# status.sh —— 检查所有远端任务状态
# 可以反复运行，只更新状态，不修改运行中的任务
# 依赖: ssh_wrapper

set -euo pipefail

JOBS="48/server1,72/server2,72/server3"
WORKDIR="/opt/jobs"

# ── 在每台机器上巡检所有任务目录 ──
# 注意: 这里只需要传一个 dummy 参数，让 parallel 每台机器跑一次
# 实际逻辑在命令字符串内部遍历该机器上的所有任务目录
parallel \
    --ssh ./ssh_wrapper \
    -S "$JOBS" \
    --workdir "$WORKDIR" \
    --sshdelay 0.1 \
    'TOTAL=0; RUNNING=0; DONE=0; FAILED=0
     for JOB_DIR in "$PWD"/*/; do
         [ -d "$JOB_DIR" ] || continue
         TOTAL=$((TOTAL + 1))
         STATUS_FILE="${JOB_DIR}status"
         PID_FILE="${JOB_DIR}pid"
         RESULT_FILE="${JOB_DIR}result.out"

         STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "UNKNOWN")

         case "$STATUS" in
             RUNNING*)
                 PID=$(cat "$PID_FILE" 2>/dev/null || true)
                 if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
                     RUNNING=$((RUNNING + 1))
                 else
                     # 进程没了
                     if [ -f "$RESULT_FILE" ]; then
                         echo "DONE $(date +%s)" > "$STATUS_FILE"
                         DONE=$((DONE + 1))
                     else
                         echo "FAILED $(date +%s)" > "$STATUS_FILE"
                         FAILED=$((FAILED + 1))
                     fi
                 fi
                 ;;
             DONE*)   DONE=$((DONE + 1)) ;;
             FAILED*) FAILED=$((FAILED + 1)) ;;
             *)       RUNNING=$((RUNNING + 1)) ;;  # 未知状态，保守算运行中
         esac
     done
     echo "$(hostname): 总 $TOTAL | 运行中 $RUNNING | 完成 $DONE | 失败 $FAILED"'
```

输出示例：

```
server1: 总 48 | 运行中 12 | 完成 34 | 失败 2
server2: 总 72 | 运行中 28 | 完成 44 | 失败 0
server3: 总 72 | 运行中 71 | 完成 1  | 失败 0
```

可以配合 `watch` 定期刷新：

```bash
watch -n 60 ./status.sh   # 每 60 秒刷新一次
```

---

## collect.sh：收集所有结果

全部任务 `DONE`（或 `FAILED`）后，把 result.out 收回到本机：

```bash
#!/bin/bash
# collect.sh —— 收集所有远端结果文件到本机
# 前提: 所有任务状态为 DONE 或 FAILED（status.sh 确认过）
# 依赖: ssh_wrapper

set -euo pipefail

JOBS="48/server1,72/server2,72/server3"
WORKDIR="/opt/jobs"
LOCAL_OUT="./results"
mkdir -p "$LOCAL_OUT"

# ── 在每台机器上找所有 result.out，返回路径列表 ──
parallel \
    --ssh ./ssh_wrapper \
    -S "$JOBS" \
    --workdir "$WORKDIR" \
    'find "$PWD" -name "result.out" -type f' \
    ::: dummy \
    > /tmp/remote_results.txt

# ── 逐个 scp 回来（每个 result.out 放到 results/<任务目录名>.out） ──
while IFS= read -r REMOTE_PATH; do
    # REMOTE_PATH 形如: server1:/opt/jobs/file1/result.out
    # 提取服务器名和任务名
    SERVER="${REMOTE_PATH%%:*}"
    REMOTE_FILE="${REMOTE_PATH#*:}"
    TASK_NAME="$(basename "$(dirname "$REMOTE_FILE")")"
    LOCAL_NAME="${LOCAL_OUT}/${TASK_NAME}.out"

    echo "📥 $SERVER → $LOCAL_NAME"
    scp "$REMOTE_PATH" "$LOCAL_NAME"
done < /tmp/remote_results.txt

echo "✅ 结果已收集到 $LOCAL_OUT/ ($(ls "$LOCAL_OUT" | wc -l) 个文件)"
```

---

## 完整工作流

```bash
# 一次性配好（新集群只需做一次）
# 1. 三台机器的 /etc/ssh/sshd_config 改 MaxStartups + MaxSessions
# 2. 本机 ~/.ssh/config 加 ServerAliveInterval + ControlMaster
# 3. 写好 ssh_wrapper, launch.sh, status.sh, collect.sh

# ─── 日常使用 ───

# 步骤 1：发射
./launch.sh
# 输出: 1000 个任务全部发射完毕，耗时约 20 秒

# 步骤 2：巡检（可反复运行）
./status.sh
# 也可以 watch 自动刷新
watch -n 120 ./status.sh

# 步骤 3：等全部 DONE 后收集
./collect.sh
# 输出: 1000 个 .out 文件进入 ./results/

# 步骤 4（可选）：清理远端
parallel --ssh ./ssh_wrapper -S 48/server1,72/server2,72/server3 \
    'rm -rf /opt/jobs' ::: dummy
```

---

## 这个方案和原生 parallel 的对比

| | parallel 原生 `-S` + `--trc` | 发射 + 巡检 + 收集 |
|---|---|---|
| SSH 连接时长 | 与任务等长（最长 10h+） | 几秒到几分钟 |
| 网络闪断影响 | 该连接上的任务白跑，需重试 | 零影响——任务自己在远端跑 |
| 本机关机/休眠 | 全部销毁，重来 | 任务继续跑，回来收结果 |
| 自动重试 | `--retries 2` 自动重试 | 要手动重发射 FAILED 的 |
| parallel 的价值 | 调度 + 等结果 + 回传文件一体化 | 调度（发射 + 巡检 + 收集都是 parallel 做的） |
| 复杂度 | 一条命令 | 三个脚本，约 80 行 shell |
| 适用场景 | 任务 ≤ 30 分钟，网络稳定 | 任务 ≥ 1 小时，或网络不可靠 |

---

## 常见问题

### Q: 为什么不让 parallel 直接 nohup，然后 `--retries 0` 不重试？

因为即使 `--retries 0`，parallel 仍然会等 SSH 退出才认为任务结束。SSH 不退出（被 nohup 的子进程卡住），parallel 就一直挂着，等同于废了。

### Q: SSH multiplexing 加上 ControlPersist 24h，不就能维持连接了吗？

`ControlPersist` 维持的是**复用通道**（TCP 隧道），不是某个 session。如果本机网络中断（比如 VPN 断开），TCP 连接还是会断，所有复用它的 session 一起挂。multiplexing 解决的是「频繁连接的性能开销」，解决不了「连接本身的可靠性」。

### Q: 为什么不在远端用 systemd service 管理？

systemd 需要 root 配 service 文件，每台机器都要写。如果你已经在用 systemd 管理服务，当然更好。但对临时计算任务来说，三文件的方案零配置、零依赖。

### Q: 如果 heavy_task 自己 OOM 被 kill 了，怎么区分 OOM 和正常结束？

`kill -0 $pid` 只能判断进程是否活着，无法区分退出原因。如果需要区分，可以在巡检时检查 `dmesg` 或 `journalctl`：

```bash
if dmesg | tail -20 | grep -q "Out of memory.*heavy_task"; then
    echo "OOM $(date +%s)" > "$STATUS_FILE"
fi
```

### Q: 任务量巨大（比如 100 万个小任务），还适用吗？

不适用。文件协议适合**单任务 ≥ 几分钟**的场景。100 万个 1 秒的任务，建目录写文件的开销比任务本身还大，直接用 parallel 原生模式更好——短任务断一次重跑也很快。

---

## 总结

> parallel 的 `-S` 给你免费的集群调度，但不给你免费的连接可靠性。当任务远超 SSH 连接的存活时间，把「调度」和「执行」分离——parallel 只负责把任务发射到远端、巡检状态、收结果，任务自己 nohup 跑。中间的联系就是三个文件：pid、status、result.out。没有依赖，没有守护进程，只有文件系统。
