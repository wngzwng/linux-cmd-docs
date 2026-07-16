# docker：一个 OCI 运行时栈，假装自己是容器命令

你每天都在 `docker run`、`docker build`、`docker-compose up`。但如果问你：「`docker run nginx` 敲下去之后，从你的终端到 Nginx 进程开始监听 80 端口，中间经过了哪些进程、哪些层？」——大多数人只能说出「启动了一个容器」。

docker 的「表面身份」是容器管理工具。但它的**本质是一个 OCI 运行时栈**：一个五层调用链，每一层有明确的职责和接口边界。理解了这五层，你就理解了不仅 docker，还包括 podman、containerd、cri-o——因为它们共享同一套底层标准。

---

## 第一层：内部模型

### 1.1 五层运行时栈

`docker run` 不是 docker 一个进程的事——它是一条调用链：

```
docker CLI                        ← 你敲命令的地方
    │  HTTP (Unix Socket: /var/run/docker.sock)
    ▼
dockerd (Docker Daemon)           ← 核心调度进程，root 权限运行
    │  gRPC
    ▼
containerd                        ← 容器生命周期管理（启动/停止/暂停）
    │  OCI Runtime Spec
    ▼
runc                              ← OCI 运行时参考实现
    │  clone() + unshare()         （创建 namespace + cgroups）
    ▼
Container Process                 ← 你的 nginx/redis/app 进程
    （运行在隔离的 namespace 中）
```

> 💡 **每一层都可以被替换。** Docker CLI 可以换成 nerdctl，dockerd 可以换成 podman（它甚至不需要 daemon），containerd 可以换成 cri-o，runc 可以换成 kata-containers（安全容器）。这个分层架构是 OCI 标准化的结果——Linux 基金会定义了「容器镜像格式」和「容器运行时接口」，各家实现可以互换。

### 1.2 镜像：不是「虚拟机快照」，是分层文件系统

Docker 镜像不是一个大文件。它是一组**只读层**的栈，每层是一个文件系统的变更集：

```
镜像 nginx:latest
┌──────────────────────┐
│ Layer 6: CMD nginx   │  ← 元数据层（不算文件系统层）
├──────────────────────┤
│ Layer 5: COPY nginx  │  ← 复制 nginx 可执行文件
├──────────────────────┤
│ Layer 4: apt install │  ← 安装依赖
├──────────────────────┤
│ Layer 3: apt update  │  ← 更新包列表
├──────────────────────┤
│ Layer 2: FROM ubuntu │  ← Ubuntu 基础镜像
├──────────────────────┤
│ Layer 1: scratch     │  ← 空层（最底层）
└──────────────────────┘

每一层 = 一个目录（在 /var/lib/docker/overlay2/ 下）
每一层有唯一的 SHA-256 内容哈希
两个镜像可以共享同一个基础层 → 不会重复存储
```

> 💡 **关键洞察：Docker 镜像的层模型和 git 的 blob 模型是同构的。** 两者都是「内容寻址存储」：内容相同 → hash 相同 → 共享一个存储对象。Docker 的层 = git 的 blob，Docker 的镜像 tag = git 的分支（指向当前最新层）。拉取一个 200MB 的镜像，如果前 5 层和已有镜像完全相同，实际只下载第 6 层。

### 1.3 容器 = 镜像 + 可写层

```
容器（运行中的实例）
┌──────────────────────┐
│ 可写层 (R/W)          │  ← 容器运行时的所有修改写在这里
│ (Container Layer)     │     每个容器有自己独立的可写层
├──────────────────────┤
│ Layer 6              │
├──────────────────────┤     ← 以下都是只读的镜像层
│ Layer 5              │     所有容器共享
├──────────────────────┤
│ ...                  │
└──────────────────────┘
```

> 💡 这就是 CoW（Copy-on-Write）：容器读取文件时，从上往下逐层查找；写入文件时，先把原文件从只读层复制到可写层，然后在可写层修改。初始时容器几乎不占额外磁盘空间——它共享了所有的镜像层。

### 1.4 隔离的三大支柱：namespace + cgroups + UnionFS

docker 的「隔离」不是虚拟化——它没有模拟硬件。它靠的是 Linux 内核的三个特性：

```
namespace（命名空间）          ← 「只能看到什么」
  ├─ PID namespace    → 容器里 PID 1 就是容器里的第一个进程，看不到宿主机的进程
  ├─ NET namespace    → 容器有自己独立的网卡、IP、端口空间
  ├─ MNT namespace    → 容器有自己的 / 根文件系统（就是那个镜像层栈）
  ├─ UTS namespace    → 容器有自己的 hostname
  ├─ IPC namespace    → 容器有自己的共享内存/信号量
  └─ USER namespace   → 容器里的 root 不是宿主机的 root

cgroups（控制组）               ← 「最多能用多少资源」
  ├─ cpu.max          → 容器最多用几个核
  ├─ memory.max       → 容器最多用多少内存（超了就 OOM Kill）
  ├─ blkio            → 磁盘 I/O 限制
  └─ pids.max         → 容器里最多能创建多少个进程

UnionFS（联合文件系统）          ← 「文件系统怎么叠加」
  └─ overlay2         → 把多个只读层 + 一个可写层合并成一个目录树
```

> 💡 **容器 = namespace（隔离视线）+ cgroups（限制资源）+ UnionFS（叠加文件系统）**。这三个概念是理解所有容器技术的基础——不管你用 docker、podman 还是 kubernetes，底层都是它们。

---

## 第二层：行为机制

### 2.1 docker run 的完整生命周期

```bash
docker run -d -p 8080:80 --name web nginx
```

这一行命令背后发生了：

```
Step 1：CLI → Daemon
  docker CLI 将命令序列化为 REST API 请求
  → POST /containers/create (with image=nginx, ports=8080:80, ...)
  → 发送到 /var/run/docker.sock

Step 2：Daemon 拉取镜像（如果需要）
  检查本地是否有 nginx:latest
  → 没有 → 向 registry (Docker Hub) 发送 GET /v2/nginx/manifests/latest
  → 获取 manifest（列出所有层的 hash）
  → 逐层下载：对每个层检查本地是否已有 → 没有就 GET /v2/nginx/blobs/<hash>
  → 验证每一层的 SHA-256

Step 3：Daemon → containerd
  dockerd 通过 gRPC 调用 containerd
  → "创建一个容器：镜像=nginx, 参数=..."

Step 4：containerd → runc
  containerd 把容器配置翻译为 OCI Runtime Spec（JSON 文件）
  → 调用 runc create
  → runc 执行：
      ├─ clone() + CLONE_NEWPID|CLONE_NEWNET|CLONE_NEWNS|... → 创建 namespace
      ├─ 写入 cgroup 限制文件 (/sys/fs/cgroup/...)
      ├─ 挂载 overlay2 联合文件系统作为容器的根文件系统
      ├─ 设置网络：创建 veth pair，一端在宿主机，一端在容器内
      └─ exec nginx → 容器内 PID 1 就是 nginx 进程

Step 5：端口映射
  宿主机的 iptables DNAT 规则：
  → 所有到达宿主机 8080 端口的流量 → DNAT 到容器的虚拟网卡 IP:80

Step 6：Daemon → CLI
  返回容器 ID
```

> 💡 **你看到的一个 `docker run`，实际上是 4 个进程（docker CLI → dockerd → containerd → runc）+ Linux 内核 namespace/cgroups/UnionFS 的协调结果。** 任何一层出问题都会导致容器启动失败——排查时逐层检查。

### 2.2 docker build 的缓存机制

```dockerfile
FROM ubuntu:22.04                    # Layer 1
RUN apt update                       # Layer 2
RUN apt install -y python3           # Layer 3
COPY requirements.txt .              # Layer 4
RUN pip install -r requirements.txt  # Layer 5
COPY . .                             # Layer 6
```

每一条指令 = 一个镜像层。docker build 的缓存规则：

- 如果某条指令的**输入**和上次完全一样 → 使用缓存（跳过该层）
- 如果某条指令的输入变了 → 该层和**之后所有层**都重新构建
- `COPY . .` 在最后一行意味着：只要任何源码变了，Layer 6 就会重建 → Layer 5 能用缓存（因为 requirements.txt 没变，pip install 不用重跑）

> 💡 **这就是为什么 Dockerfile 的最佳实践是「先复制依赖文件，再复制源码」。** 如果 `COPY . .` 在 `RUN pip install` 之前，每次改一行代码都要重装所有依赖。

### 2.3 docker stop 的信号链

```bash
docker stop web
```

```
Step 1：Daemon 给容器内 PID 1 发送 SIGTERM (15)
  → 给容器进程 10 秒的「体面退出」窗口
  → Nginx 收到 SIGTERM → 停止接受新连接 → 等当前连接处理完 → 退出

Step 2：10 秒超时后
  → 如果 PID 1 还没退出 → 发送 SIGKILL (9)
  → SIGKILL 不可捕获，内核直接终止进程

Step 3：containerd 清理
  → 删除容器的 cgroup
  → 删除容器的可写层（如果没有用 volume）
  → 删除容器的 veth pair 网络设备
```

> ⚠️ **如果容器内的 PID 1 是一个 shell 脚本（不是真正的进程管理器），它可能不会转发 SIGTERM 给子进程。** 这就是为什么 Dockerfile 里建议用 `CMD ["nginx", "-g", "daemon off;"]`（exec 形式，PID 1 直接是 nginx），而不是 `CMD nginx -g 'daemon off;'`（shell 形式，PID 1 是 /bin/sh）。

---

## 第三层：高级模式

### 3.1 多阶段构建

```dockerfile
# 阶段 1：编译
FROM golang:1.21 AS builder
WORKDIR /src
COPY . .
RUN go build -o /app

# 阶段 2：运行
FROM alpine:3.19
COPY --from=builder /app /app    # ← 只从阶段 1 拷贝编译产物
CMD ["/app"]
```

> 本质：阶段 1 的 Go 编译器、依赖包、源码——这些几百 MB 的东西在最终镜像里**全部丢弃**。最终镜像只有 alpine + 一个二进制文件，可能就 15MB。这不是「压缩」——这是「选择性拷贝」，理解了层模型就能自己推理出来。

### 3.2 docker-compose 网络的 DNS 魔法

```yaml
# docker-compose.yml
services:
  web:
    image: nginx
  api:
    image: my-api
  db:
    image: postgres
```

在这个 compose 里，`api` 容器可以直接用 `db:5432` 连接 PostgreSQL。不需要 IP，不需要配置服务发现。

> 本质：docker-compose 为每个 compose 文件创建一个独立的 bridge 网络，并内置了一个 DNS 服务器（`127.0.0.11`）。容器内的 `/etc/resolv.conf` 指向这个 DNS。当 `api` 解析 `db` 时，DNS 返回 `db` 容器的内网 IP。这就是为什么容器名就是 DNS 名——不需要 etcd、Consul 或手动 hosts 文件。

### 3.3 volume vs bind mount

```bash
# bind mount：宿主机的具体路径映射到容器内
docker run -v /home/user/data:/data nginx
# 直接映射宿主机目录 → 容器内外共享同一个文件系统节点

# volume：docker 管理的存储空间
docker run -v my_volume:/data nginx
# docker 在 /var/lib/docker/volumes/ 下创建和管理这个目录
```

> 💡 bind mount 适合开发（改宿主机代码，容器内立即生效）。volume 适合生产（docker 管理生命周期，不会被误删，支持跨容器共享和数据备份）。它们的本质区别不是「路径写没写死」，而是**谁拥有这个目录的生命周期**。

### 3.4 镜像瘦身检查清单

```
1. 基础镜像选最小的
   alpine:3.19 (7MB) 而不是 ubuntu:22.04 (77MB)
   
2. 多阶段构建
   编译阶段用重量级镜像 + 工具链 → 运行阶段只拷贝产物
   
3. 合并 RUN 指令
   RUN apt update && apt install -y pkg && rm -rf /var/lib/apt/lists/*
   （三条命令在一个层里完成 + 清理缓存 → 一层搞定）
   
4. .dockerignore
   node_modules/ .git/ *.log
   （不把这些文件发到 build context → COPY 指令更快）
```

---

## 一句话

> docker 不是容器引擎。docker 是一个分层的 OCI 运行时栈（CLI → dockerd → containerd → runc → container），容器只是这个栈的最终产物。镜像 = 内容寻址的只读层栈（和 git 同构），容器 = 镜像 + 可写层 + namespace + cgroups。理解了这五层架构和三大隔离支柱，所有容器技术——docker、podman、kubernetes——都是同一个模型的不同实现。
