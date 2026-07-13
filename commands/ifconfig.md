# 为什么 ifconfig 还在用，但你应该开始学 ip 了？

> `ifconfig` 是网络配置的鼻祖命令——查 IP、看 MAC、看流量统计。但它已经被 `ip` 命令取代了（Linux iproute2 套件的一部分）。尽管如此，大多数人在排查第一个网络问题时条件反射敲的仍然是 `ifconfig`。这篇文章说清它的核心用法，同时告诉你什么时候该换 `ip`。

## 一、你会遇到的场景

某天你的服务连不上数据库，你需要确认：本机 IP 是什么？网卡状态正常吗？有没有丢包？RX/TX 的流量正常吗？

```bash
ifconfig
# 或者只看特定网卡
ifconfig eth0
```

三秒后你看到 `inet 192.168.1.100`、`status: active`、丢了 0 个包——网络层没问题，问题在应用层或防火墙。

**这就是 ifconfig 的核心价值：查看和配置网络接口——IP 地址、MAC 地址、MTU、流量统计，一眼看完。**

> ⚠️ ifconfig 在 Linux 上已被 `ip` 命令取代（属于 net-tools，很多发行版不再预装）。macOS 上 ifconfig 仍然可用。本文介绍的用法在两种平台上都有效，但最后会告诉你 `ip` 的等价命令。

## 二、语法骨架

```
ifconfig  [接口名]  [参数]
          ──┬──    ──┬──
           看哪个    看什么/改什么
```

属于**骨架模式 D**：`查询 + 展示`。不加参数 = 显示所有活跃接口。

## 三、核心用法——4 个场景

### 场景 1：查看所有网络接口

```bash
ifconfig              # 只显示活跃接口（up 状态）
ifconfig -a           # 显示所有接口（含 down 的）
ifconfig -l           # 只列出接口名（macOS）
```

输出解读——每个接口的关键字段：

```
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
      inet 192.168.1.100  netmask 255.255.255.0  broadcast 192.168.1.255
      inet6 fe80::...  prefixlen 64
      ether 00:11:22:33:44:55
      RX packets 123456  bytes 98765432 (94.1 MiB)
      TX packets 78901   bytes 45678901 (43.5 MiB)
```

| 字段 | 含义 |
|------|------|
| `flags=UP` | 接口已启用；DOWN 表示禁用 |
| `mtu` | 最大传输单元（1500 是标准以太网值） |
| `inet` | IPv4 地址 + 子网掩码 |
| `inet6` | IPv6 地址 |
| `ether` | MAC 地址 |
| `RX/TX packets/bytes` | 接收/发送的包数和字节数（丢了几个包看 errors/dropped） |

---

### 场景 2：查看特定接口

```bash
ifconfig eth0          # 只看 eth0
ifconfig lo            # 回环接口（127.0.0.1）
```

---

### 场景 3：启用/禁用接口

```bash
# 禁用网卡（需要 root）
sudo ifconfig eth0 down

# 启用网卡
sudo ifconfig eth0 up
```

---

### 场景 4：配置 IP 地址（知道就行，用 ip 命令更好）

```bash
# ifconfig 方式（老派，仍可用）
sudo ifconfig eth0 192.168.1.200 netmask 255.255.255.0 up

# ip 命令方式（推荐）
sudo ip addr add 192.168.1.200/24 dev eth0
```

> ⚠️ 用 ifconfig 配 IP 是临时生效的——重启后丢失。持久化配置需要改网络配置文件（`/etc/network/interfaces`、`/etc/netplan/`、NetworkManager 等）。

---

## 四、网卡命名：eth0？enp0s3？lo？这都是什么？

| 名称 | 含义 |
|------|------|
| `lo` | 回环接口（127.0.0.1，本机自通信） |
| `eth0` / `eth1` | 传统以太网命名（老 Linux） |
| `enp0s3` / `ens33` | Predictable Network Interface Names（新 Linux） |
| `en0` / `en1` | macOS 以太网/Wi-Fi 命名 |
| `wlan0` / `wlp2s0` | Wi-Fi 接口 |
| `docker0` / `br-*` | Docker 虚拟网桥 |
| `tun0` / `tap0` | VPN 隧道接口 |

> 💡 不知道网卡叫什么？`ifconfig -a` 列出全部，再根据 IP 地址和流量大小判断哪个是你的主网卡。

---

## 五、从 ifconfig 迁移到 ip

ifconfig 和 ip 的命令对应关系：

| 要做的事 | ifconfig | ip |
|---------|----------|-----|
| 查看所有接口 | `ifconfig` | `ip addr` 或 `ip a` |
| 查看特定接口 | `ifconfig eth0` | `ip addr show eth0` |
| 启用接口 | `ifconfig eth0 up` | `ip link set eth0 up` |
| 禁用接口 | `ifconfig eth0 down` | `ip link set eth0 down` |
| 设置 IP | `ifconfig eth0 192.168.1.100/24` | `ip addr add 192.168.1.100/24 dev eth0` |
| 查看路由表 | `route -n`（不是 ifconfig） | `ip route` |
| 查看 ARP 表 | `arp -a`（不是 ifconfig） | `ip neigh` |

> 💡 一条 `ip a` 替代 `ifconfig`，一条 `ip route` 替代 `route -n`，一条 `ip neigh` 替代 `arp -a`。三个老命令合一了。

---

## 六、踩坑清单

- **坑一：`ifconfig` 在最新 Linux 发行版上可能不存在** → `apt install net-tools` 安装，或者直接学 `ip` 命令。
- **坑二：`ifconfig` 默认不显示 down 掉的接口** → 接口是 down 状态时在 `ifconfig` 里看不到，用 `ifconfig -a` 或 `ip link`。
- **坑三：`ifconfig -a` 在 Linux 上有效，在 macOS 上行为不同** → macOS 的 `ifconfig -a` 显示所有接口（实际上不加也显示了），`-l` 只列名字。
- **坑四：RX/TX 计数器是自接口启动以来的累计值** → 需要看"最近"的流量？看两次数据的变化量，或者用 `nload` / `iftop` / `bmon` 等实时工具。
- **坑五：`ifconfig` 配的 IP 重启后丢失** → 这是临时配置。持久化需要改系统的网络配置文件。

## 七、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 快速看一眼网卡信息 | `ifconfig` / `ip a` | 够用了 |
| Linux 上需要改网络配置 | `ip` | 更强大、更现代、发行版推荐 |
| 实时流量监控 | `nload` / `iftop` | ifconfig 只有累计值，没有实时速率 |
| 无线网络管理 | `iwconfig` / `iw` | ifconfig 不显示 Wi-Fi 信号强度、频道等 |
| macOS 图形化网络诊断 | 系统设置 → 网络 → 高级 | ifconfig 在 macOS 上也工作，但图形界面更全面 |
| 带宽占用按进程分析 | `nethogs` | 想看哪个进程在吃带宽，不看网卡总量 |

---

> **核心观点：** `ifconfig` 是最简单的网络诊断起点——一个命令看到 IP、MAC、状态、丢包率。但要知道：**在 Linux 上它已经被 `ip` 取代了。** 花 5 分钟学一下 `ip a` 和 `ip link`，你的网络排查工具链就升级了。
