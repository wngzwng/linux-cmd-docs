# ssh：一个加密隧道引擎，假装自己是远程登录工具

你每天都在 `ssh user@host` 登录服务器。但如果问你：「SSH 连接建立的完整握手过程是什么？为什么第一次连接会问『Are you sure you want to continue connecting』？`ssh -L 8080:localhost:80` 的数据包到底怎么走的？」——大多数人只能回答「安全连接」。

ssh 的「表面身份」是安全远程登录。但它的**本质是一个加密隧道引擎**：在不可信网络上建立一条端到端加密的 TCP 隧道，然后在这条隧道上跑任何东西——shell 会话、文件传输、端口转发、SOCKS 代理，甚至图形界面（X11 forwarding）。

---

## 第一层：内部模型

### 1.1 SSH 协议的三层结构

SSH 不是「一个协议」——它是三层协议的组合：

```
┌──────────────────────────────────────────┐
│ SSH Connection Protocol (连接层)          │  ← 多路复用：在一条 TCP 连接上
│  多个 channel：shell / sftp / forward     │     同时跑多个「频道」
├──────────────────────────────────────────┤
│ SSH User Authentication Protocol (认证层) │  ← 证明你是谁
│  password / publickey / keyboard-interactive│
├──────────────────────────────────────────┤
│ SSH Transport Protocol (传输层)           │  ← 加密 + 完整性
│  密钥交换 → 对称加密 → MAC 校验           │
└──────────────────────────────────────────┘
         ↕ TCP (通常端口 22)
```

> 💡 **一条 TCP 连接 = 多个 SSH channel。** 这就是为什么你可以在一个 SSH 会话里同时跑 shell + sftp + 端口转发——它们共享同一条加密隧道，但在连接层被多路复用为独立的 channel。这也是 `ControlMaster` 的理论基础。

### 1.2 握手的完整过程

当你第一次 `ssh new-server` 时，背后发生了：

```
① TCP 连接 (3-way handshake)
   你 → new-server: SYN
   new-server → 你: SYN-ACK
   你 → new-server: ACK

② 协议版本协商
   双方交换 SSH 版本字符串："SSH-2.0-OpenSSH_9.6"

③ 密钥交换 (Key Exchange — Diffie-Hellman)
   你 ↔ new-server：用 DH 算法在不安全通道上协商出一个共享秘密
   → 这个共享秘密双方都知道，但中间窃听者不知道
   → 用共享秘密派生三个密钥：
      加密密钥（对称加密：AES/ChaCha20）
      认证密钥（HMAC/UMAC：防篡改）
      初始化向量

④ 主机认证（Host Key Verification）
   new-server 发送它的 host key（公钥）
   你的 SSH client 检查 ~/.ssh/known_hosts：
   ├─ 找到匹配 → 验证通过 → 继续
   ├─ 没找到 → 提示 "Are you sure you want to continue connecting?"
   │   （你确认后，host key 被写入 known_hosts）
   └─ 找到但 key 不匹配 → ⚠️ WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
       （可能是中间人攻击，也可能是服务器重装了）

⑤ 用户认证 (User Authentication)
   你 → new-server: 尝试用 publickey 登录
   new-server → 你: 发送一个随机 challenge
   你：用私钥签名 challenge → 发送签名结果
   new-server：用你之前上传的公钥验证签名 → 通过！

⑥ 加密通道建立
   后续所有通信使用步骤③协商的对称密钥加密
```

> 💡 **那个「Are you sure」提示不是在演戏。** 如果你点了 yes，就把 new-server 的 host key 写进了 known_hosts。下次连接时 SSH 会自动验证——如果 key 变了，说明要么是中间人攻击，要么服务器重装了。这是 SSH 防中间人攻击的核心机制：**首次信任（TOFU: Trust On First Use）**。

### 1.3 多路复用：一条 TCP，N 个会话

```
一条 SSH TCP 连接（到 server:22）
    │
    ├─ Channel 0: shell session（你的终端）
    ├─ Channel 1: sftp（文件传输）
    ├─ Channel 2: port forward（ssh -L 8080:localhost:80）
    └─ Channel 3: port forward（ssh -R 9090:localhost:3000）

每个 channel 独立收发数据，互不干扰
所有 channel 的数据通过同一条加密隧道传输
```

你能复用的方式：

```bash
# ~/.ssh/config
Host myserver
    HostName 10.0.0.5
    ControlMaster auto          # 自动复用已有连接
    ControlPath /tmp/ssh-mux-%r@%h:%p  # 复用通道的 socket 路径
    ControlPersist 10m          # 最后一个 session 退出后，保留连接 10 分钟

# 第一个 ssh myserver → 建立 TCP 连接
# 第二个 ssh myserver → 复用已有 TCP（秒连，不需要重新握手）
# 第三个 ssh myserver -L 8080:localhost:80 → 复用 + 加一个 channel
```

> 💡 **`ControlMaster` 把「重新握手 2-3 秒」变成了「复用已有连接 0.01 秒」。** 对频繁 SSH 到同一台机器（比如 ansible 批量执行）效果显著。但代价是：如果 master 连接断开，所有复用的 session 一起挂。

---

## 第二层：行为机制

### 2.1 端口转发：数据包的旅程

**本地转发（`-L`）**：把你本机的端口映射到远端能访问的地址。

```bash
ssh -L 8080:db-internal:3306 user@bastion
# 你 → localhost:8080 → SSH 加密隧道 → bastion → db-internal:3306
```

```
你的浏览器请求 localhost:8080
    │
    ▼
SSH client 监听 localhost:8080
    │  收到 TCP 连接
    ▼
SSH client 把数据包塞进 SSH channel
    │  加密 → 通过隧道发送
    ▼
SSH server (bastion) 收到 → 解密
    │  建立到 db-internal:3306 的 TCP 连接 → 转发数据
    ▼
db-internal:3306 收到请求，返回响应
```

**远程转发（`-R`）**：把远端的端口映射回你本机能访问的地址。

```bash
# 在办公电脑上执行（没有公网 IP），让服务器把 9090 转发回来
ssh -R 9090:localhost:3000 user@public-server
# public-server:9090 → SSH 隧道 → 你的办公电脑 → localhost:3000
```

**动态转发（`-D`）**：SOCKS 代理，把你本机变成代理服务器。

```bash
ssh -D 1080 user@remote
# 浏览器设置 SOCKS5 代理 → localhost:1080
# → SSH 隧道 → remote → 以 remote 的身份访问互联网
```

> 💡 `-D` 是一个完整的 SOCKS5 代理——比 `-L` 更灵活，因为不需要为每个目标地址建一个转发。浏览器里配置一次 `127.0.0.1:1080`，之后所有流量都以远端机器的身份发出。

### 2.2 SSH agent：私钥的守护进程

```bash
# 启动 agent（通常由系统自动启动）
eval $(ssh-agent)

# 把私钥加入 agent（输入一次密码）
ssh-add ~/.ssh/id_rsa

# 之后所有 ssh 连接不用再输密码
ssh user@host1
ssh user@host2
scp file user@host3:/tmp/
```

```
你的 SSH client
    │  需要签名 → 请求 agent
    ▼
ssh-agent (后台进程，运行在你的机器上)
    │  持有解密后的私钥（在内存中）
    │  用私钥签名 challenge → 返回签名
    │  私钥本身永远不会离开 agent 进程
    ▼
SSH client 把签名发送给 server（server 用公钥验证）
```

> 💡 **ssh-agent 的核心价值：你的私钥只需要解密一次（ssh-add 时输入密码），之后所有 SSH 操作都不需要再碰私钥文件或输密码。** agent 通过 Unix socket（`$SSH_AUTH_SOCK`）和你本机上的 SSH client 通信——私钥永远不会写到磁盘或通过网络传输明文。

**Agent forwarding（`-A`）**：把本机的 agent 能力借给远端机器。

```bash
ssh -A user@bastion
# 从 bastion 再 ssh 到 db-server 时，bastion 上没有你的私钥——
# 但 SSH agent forwarding 让 db-server 的认证请求
# 被转发回你本机的 ssh-agent
```

> ⚠️ Agent forwarding 有安全风险：如果 bastion 被入侵，攻击者可以在你连接期间通过转发 socket 使用你的私钥签名任意内容。只在可信的中间机器上使用 `-A`。

### 2.3 known_hosts 的原理

```
~/.ssh/known_hosts 的每一行：
hostname,ip algorithm public_key

每次 SSH 连接：
1. server 发送它的 host key（公钥）
2. SSH client 在 known_hosts 里查找这个 hostname 的记录
3. 找到 → 对比公钥是否一致
   ├─ 一致 → 通过（这就是你知道的那个 server）
   └─ 不一致 → ⚠️ 报警（server 公钥变了 = 可能是中间人攻击）
4. 没找到 → 提示 "Are you sure"
```

> 💡 **这个机制不依赖 CA（证书颁发机构）。** 它是 TOFU（Trust On First Use）：第一次你选择信任，之后的变化会被检测到。SSH 也有 CA 模式（`TrustedUserCAKeys`），大型组织可以用 CA 签名 host key，省去每个用户第一次手动确认。

---

## 第三层：高级模式

### 3.1 ProxyJump：跳过跳板机

```bash
# 传统方式：先 SSH 到跳板机，再在跳板机上 SSH 到目标
ssh user@bastion
ssh user@db-internal

# ProxyJump：一行直达
ssh -J user@bastion user@db-internal

# 多层跳板
ssh -J user@bastion1,user@bastion2 user@target

# 配置文件方式
# ~/.ssh/config
Host db-internal
    HostName 10.0.1.50
    User admin
    ProxyJump bastion
```

> 本质：SSH client 先连到 bastion，通过 bastion 的 SSH server 建立到 db-internal 的 TCP 转发通道，然后在这个通道上再跑一次 SSH 握手。你看到的是一个直达的 shell，但底层经过了 bastion 的中转——对 bastion 的 SSH server 来说是透明的转发，bastion 看不到你的数据内容（因为内层是另一个 SSH 会话）。

### 3.2 SSH 隧道做穷人的 VPN

```bash
# 通过一台有公网 IP 的服务器，让你能访问内网的一切
ssh -D 1080 -f -N user@bastion
# -D 1080: SOCKS 代理
# -f: 后台运行
# -N: 不执行远程命令（只建隧道）

# 浏览器设置 SOCKS5 → 127.0.0.1:1080
# 现在你可以访问 bastion 能访问的所有内网服务
```

如果需要代理所有流量（不只是浏览器）：

```bash
# 创建 TUN 设备级别的 VPN（需要 sshuttle 或 ssh -w）
sshuttle -r user@bastion 10.0.0.0/8
# 把整个 10.0.0.0/8 网段的流量都通过 bastion 转发
```

### 3.3 免密登录的完整方案

```bash
# 1. 生成密钥对（推荐 ed25519）
ssh-keygen -t ed25519 -C "your-email@example.com"

# 2. 把公钥复制到服务器
ssh-copy-id user@server
# 等价于：cat ~/.ssh/id_ed25519.pub | ssh user@server 'cat >> ~/.ssh/authorized_keys'

# 3. 服务器端检查（通常是默认配置，但值得确认）
# /etc/ssh/sshd_config:
# PubkeyAuthentication yes
# PasswordAuthentication no   ← 禁掉密码登录（可选但推荐）

# 4. 本地配置简化
# ~/.ssh/config
Host myserver
    HostName 192.168.1.100
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    # 现在只需要 ssh myserver
```

### 3.4 调试 SSH 连接问题

```bash
# -v: 详细（看握手过程）
ssh -v user@host
# -vv: 更详细（看密钥交换细节）
ssh -vv user@host
# -vvv: 最详细（看每个包）
ssh -vvv user@host

# 典型问题排查：
# "Permission denied (publickey)"
#   → ssh -vv user@host | grep -i auth
#   → 看 server 收到了什么公钥、server 在 authorized_keys 里匹配了什么
#
# "Connection refused"
#   → sshd 没在跑？端口不对？防火墙拦了？
#   → nc -zv host 22
#
# "Connection timed out"
#   → 网络不通或防火墙
#   → traceroute host
```

---

## 一句话

> ssh 不是远程登录工具。ssh 是一个三层协议的加密隧道引擎：传输层做加密和密钥交换，认证层证明身份，连接层在一根 TCP 隧道上多路复用 shell/sftp/端口转发。理解了 host key 的 TOFU 信任模型（防中间人攻击）、ControlMaster 的多路复用、和 -L/-R/-D 三种转发的数据包旅程，你就不是在「用 ssh 登录」——你是在「用 SSH 协议在不可信网络上构建可信通信基础设施」。
