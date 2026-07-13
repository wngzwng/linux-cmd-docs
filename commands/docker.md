# 为什么 docker 很强，但大多数人只会 `run` 和 `ps`？

> 很多人用 Docker 两年了，日常工作就是 `docker run`、`docker ps`、`docker stop`，排查问题时还是切回传统方式——进去容器里 ps、top、cat。其实 Docker CLI 本身就是一套完整的容器诊断工具，你不必每次都 exec 进去。

## 一、你会遇到的场景

某天线上容器挂了，你需要知道：它为什么挂？退出码是多少？挂之前最后输出了什么？重启了几次？

新手的做法：`docker start` 重新拉起来，然后 `docker exec -it <id> bash` 进去翻日志——但容器可能已经无法启动了。

而真正理解 docker 的人，一行都不用进容器：

```bash
docker logs --tail 50 <container>     # 看最后的日志
docker inspect <container> | jq '.[0].State'   # 看完整状态：退出码、重启次数、OOM 标记
```

**这就是 Docker CLI 的核心价值：管理容器的完整生命周期——创建、运行、暂停、停止、删除、诊断、清理，一条命令链完成。** 它不是 `docker run` + 进容器改东西，而是一个容器生命周期管控系统。

## 二、对象模型——Docker 的世界里有什么

Docker 管理的不只是"容器"，而是四个层级的对象：

```
Registry（镜像仓库）
    │
    ↓ pull / push
    │
Image（镜像 —— 只读模板）
    │
    ↓ run / create
    │
Container（容器 —— 镜像的运行实例）
    │   ├─ 存储层（可写层 + volumes 挂载）
    │   ├─ 网络层（bridge / host / overlay）
    │   └─ 运行时状态（running / paused / stopped / dead）
    │
Volumes & Networks（独立于容器的持久化资源）
```

每个容器有一个生命周期：

```
created → running → paused → running → stopped → removed
                    ↘ OOM killed ↗
                    ↘ exited (error) ↗
```

> 💡 理解了这个层级，`docker rm` vs `docker rmi` 就清楚了：`rm` 删容器（Container），`rmi` 删镜像（Image）。两者是不同的对象，不能混淆。

## 三、语法骨架——先把句型刻进脑子里

```
docker  对象  动作  [参数]
        ─┬─   ─┬─
        名词   动词
```

属于**骨架模式 C**：`动作 + 目标`。但 docker 的独特性在于它把"对象"提到了第一位——`docker container start`、`docker image ls`、`docker volume prune`。这是一种资源-操作分离的 CLI 设计。

⚠️ **在讲具体能力之前，先排一个新手几乎必踩的雷：**

### 雷一：`docker run` 每次都会创建新容器

```bash
# ❌ 每次 run 都创建一个新容器——十天下来可能有几百个 Exited 容器
docker run -d nginx

# ✅ 第二次启动用 start（不创建新容器）
docker start <existing-container-name>

# ✅ 如果想替换旧的，先 rm 再 run；或者用 --rm 自动清理
docker run --rm -d nginx    # 容器退出后自动删除
```

> ⚠️ **`run` = `create` + `start`。** 很多人以为 `docker run` 就是"启动容器"，忘了它每次都会新建。堆积的 Exited 容器会占磁盘（它们的可写层不会自动删除），定期 `docker container prune` 是个好习惯。

---

## 四、核心能力逐轴拆解

Docker CLI 的能力沿 5 个轴展开，分别对应不同的对象层级。

| 能力轴 | 问题 | 核心子命令 |
|--------|------|-----------|
| 镜像轴 | 有哪些镜像？怎么获取？ | `pull`、`images`、`rmi`、`build`、`tag`、`push` |
| 容器轴 | 容器怎么跑/停/删？ | `run`、`ps`、`start`、`stop`、`restart`、`rm`、`exec` |
| 状态轴 | 容器/镜像的详细信息？ | `logs`、`inspect`、`stats`、`top`、`port` |
| 网络轴 | 容器之间怎么通信？ | `network ls/inspect/create/prune` |
| 清理轴 | 怎么回收磁盘？ | `prune`、`system df`、`system prune` |

---

### 轴 1：镜像轴——"镜像是哪来的？有哪些？"

> 场景：你想看看本地有哪些镜像、它们多大。

```bash
# 列出本地镜像
docker images

# 拉取镜像
docker pull nginx:alpine

# 查看镜像的层结构
docker history nginx:alpine

# 删除镜像
docker rmi nginx:alpine

# 给镜像打标签
docker tag nginx:alpine myrepo/nginx:latest
```

> 💡 `docker images` 显示的 SIZE 是"虚拟大小"，不是实际磁盘占用。实际占用用 `docker system df`——它会显示共享层的去重情况。

---

### 轴 2：容器轴——"怎么跑、停、进去？"

> 场景：这是日常最高频的操作。

```bash
# 运行容器（前台 / 后台）
docker run -d --name web -p 8080:80 nginx:alpine

# 查看运行中的容器
docker ps

# 查看所有容器（包括已停止的）
docker ps -a

# 停止 / 启动 / 重启
docker stop web
docker start web
docker restart web

# 进入运行中的容器
docker exec -it web sh

# 删除容器（先 stop 或加 -f 强制）
docker rm web
```

---

### 轴 3：状态轴——"容器里发生了什么？"

> 场景：这是排查问题的核心——不进入容器就获取诊断信息。

```bash
# 查看日志（容器 stdout/stderr）
docker logs --tail 100 web
docker logs -f web         # 实时跟踪
docker logs --since 10m web

# 查看完整元数据（JSON 格式——配合 jq 精确提取）
docker inspect web

# 实时资源使用（CPU、内存、网络 IO）
docker stats web

# 容器内进程列表
docker top web

# 查看端口映射
docker port web
```

> 💡 **故障排查优先用 `docker logs` + `docker inspect`，不要一上来就 exec 进去。** logs 告诉你容器看到了什么（stdout/stderr），inspect 告诉你容器的状态（退出码、OOM、重启次数、挂载信息）。这两个命令能解决 80% 的问题，剩下的 20% 才需要 exec。

---

### 轴 4：网络轴——"容器之间怎么通信？"

> 场景：你要看容器在哪个网络里、IP 是什么。

```bash
# 列出网络
docker network ls

# 查看网络的详细信息（连接了哪些容器）
docker network inspect bridge

# 创建自定义网络（容器可以用名字互相发现）
docker network create mynet
docker run -d --net=mynet --name app1 nginx
```

---

### 轴 5：清理轴——"磁盘怎么又满了？"

> 场景：Docker 用久了，磁盘被镜像、容器、volume 占满。

```bash
# 查看磁盘占用（去重后的真实占用）
docker system df

# 清理所有未使用的资源（镜像、容器、网络、构建缓存）
docker system prune -a

# 单独清理
docker container prune    # 停止的容器
docker image prune        # 无标签的镜像
docker volume prune       # 未使用的 volume
```

> 💡 `docker system df` 是被严重低估的命令——它告诉你 Docker 到底占了多少磁盘，而且按类型细分。定期 `docker system prune` 是个好习惯，但生产环境要确认没有重要数据在 Exited 容器里。

---

## 五、真实排障全流程复盘

场景：线上 nginx 容器反复重启。

**第一步：看容器状态——它跑了多久？重启了几次？**
```bash
docker ps -a | grep nginx
# STATUS 列显示 "Restarting (1) 5 seconds ago"——退出码 1，刚重启过
```

**第二步：看详细状态——为什么退出码是 1？**
```bash
docker inspect nginx | jq '.[0].State'
# 显示 ExitCode: 1, OOMKilled: false, Restarting: true
```

**第三步：看日志——最后一次挂掉前输出了什么？**
```bash
docker logs --tail 50 nginx
# nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)
```
原因清楚了——端口冲突。

**第四步：修复——换端口重启**
```bash
docker stop nginx && docker rm nginx
docker run -d --name nginx -p 8080:80 nginx:alpine
```

**第五步：复查**
```bash
docker ps | grep nginx      # STATUS: Up 10 seconds
docker logs --tail 5 nginx   # 确认没有报错
```

> 整个过程没有 exec 进容器，没有 `curl localhost`。Docker CLI 本身就是一个足够强大的诊断工具。

---

## 六、踩坑清单

- **坑一：`run` 每次创建新容器** → 用 `start` 重新启动已有容器；临时容器加 `--rm`。
- **坑二：`rm` vs `rmi` 搞混** → `rm` 删容器，`rmi` 删镜像。删镜像前要删掉所有使用该镜像的容器（包括已停止的）。
- **坑三：`docker ps` 默认只看运行中的** → 排查"挂了"的问题要 `docker ps -a`，否则找不到已停止的容器。
- **坑四：`docker logs` 不自动截断** → 一个跑了几个月没重启的容器，logs 可能几 GB。加 `--tail` 限制行数或配置 logging driver。
- **坑五：Exited 容器堆积占磁盘** → 它们的可写层还在，`docker container prune` 定期清理。
- **坑六：`latest` 标签的行为依赖 pull 时间** → 两个机器上的 `nginx:latest` 可能是不同版本。生产环境显式指定版本号：`nginx:1.25-alpine`。

## 七、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 单机容器管理 | docker | 这正是 Docker CLI 的设计领域 |
| 多机容器编排 | `kubectl` / `docker compose` | docker 只管单机，多机用 K8s 或 docker swarm |
| 构建镜像 | `docker build` | Dockerfile 是标准方案 |
| 更现代的容器运行时 | `podman` / `nerdctl` | 不需要 daemon、rootless、兼容 Docker CLI |
| 容器安全问题排查 | `docker scout` / `trivy` | docker inspect 不扫描漏洞 |

---

> **核心观点：** 学 Docker CLI 不是为了记住 `run -d -p 8080:80` 这些固定组合，而是理解 Docker 的 **对象模型**（Registry → Image → Container → Volume/Network）和 **5 个能力轴**（镜像、容器、状态、网络、清理）。Docker CLI 是一套容器生命周期管理系统——你不需要 exec 进容器才能排障，CLI 本身就是诊断工具。
>
> 你平时是不是也习惯 `docker exec` 进去看一切？
