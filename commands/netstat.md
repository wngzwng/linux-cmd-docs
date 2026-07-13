# netstat：你还记得它，但它已经被替代了

> `netstat` 是网络排查的元老命令。一代运维看到 `netstat -anp | grep 8080` 会有肌肉记忆。但它已经被 `ss` 取代了——你可以在没装 `ss` 的老系统上用它，但新机器请换 `ss`。

## 语法骨架

```
netstat  [协议/状态选项]  [过滤]
```

## 核心用法

```bash
# 所有 TCP 连接
netstat -ant

# 所有监听中的 TCP 端口
netstat -antl

# 显示进程名和 PID
netstat -antlp

# 路由表
netstat -r

# 网卡统计（流量、丢包）
netstat -i
```

## netstat → ss 迁移表

| 要做的事 | netstat | ss |
|---------|---------|-----|
| 所有 TCP 连接 | `netstat -ant` | `ss -tan` |
| 监听端口 + 进程 | `netstat -antlp` | `ss -tlnp` |
| UDP 端口 | `netstat -anu` | `ss -uan` |
| 路由表 | `netstat -r` | `ip route` |
| 网卡统计 | `netstat -i` | `ip -s link` |

> 💡 选项名几乎一一对应：netstat 的 `-a`(all) `-n`(numeric) `-t`(tcp) `-l`(listen) `-p`(process) 和 ss 完全一致——只是命令名从 `netstat` 换成了 `ss`。

## 踩坑清单

- **坑一：netstat 在现代 Linux 上可能不存在** → `apt install net-tools`，但更推荐直接学 `ss`。
- **坑二：输出行数爆炸，不加过滤没法看** → 永远加 `| grep` 或直接用 `ss` 的过滤表达式。netstat 没有内置过滤。
- **坑三：`-p` 需要 root 权限才能看其他用户的进程** → 没 sudo 时进程列为空，不是 bug。

## 什么时候该彻底抛弃它

**现在。** 除非你在维护一台 10 年前的 CentOS 5 且没有安装 iproute2。否则一律用 `ss`。

---

> **核心观点：** 把 netstat 当成 `ss` 的别名来学——选项名几乎一致，只是 ss 更快、有过滤表达式、不需要 grep。肌肉记忆从 `netstat -antlp` 换成 `ss -tlnp`，只需要改两个字母。
