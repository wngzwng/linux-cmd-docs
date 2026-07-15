# curl：HTTP 请求的瑞士军刀——`-v` 调试、`-L` 重定向、`-d` POST

> `curl` 是命令行里的 HTTP 客户端，也是 API 调试的第一工具。但大多数人只用它来"看一下返回内容"——`curl https://example.com`。其实 curl 能做的不只是 GET——POST、Header 定制、上传下载、代理、cookie、重定向跟踪，它几乎是命令行里最全能的网络工具。

## 一、你会遇到的场景

某天你调试一个 REST API，想知道 POST 请求返回了什么、响应头里有什么、状态码是多少。

新手的做法：打开 Postman 或写 Python `requests` 脚本——三分钟搭环境。

而真正理解 curl 的人：

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{"key":"value"}' https://api.example.com/endpoint
```

一秒看到状态码，然后加 `-v` 看完整握手过程。

**这就是 curl 的核心价值：通过 URL 传输数据——支持 HTTP/HTTPS/FTP/SFTP 等数十种协议，是命令行里最通用的网络客户端。**

## 二、语法骨架

```
curl  [选项]  [URL]
      ──┬──   ──┬─
       控制     目标
```

属于**骨架模式 E**：`输入 → 传输 → 输出`。curl 的选项（`-X` 方法、`-H` 头、`-d` 数据）完整描述一个 HTTP 请求。

## 三、核心能力逐轴拆解

curl 的能力沿 5 个轴展开。它选项很多（`curl --help` 有几页），按轴分类就不会迷失。

| 能力轴 | 问题 | 核心选项 |
|--------|------|---------|
| 方法轴 | GET/POST/PUT/DELETE？ | `-X`(方法)、`-d`(POST 数据)、`-G`(强制 GET 传数据) |
| 头部轴 | 发什么头？看什么头？ | `-H`(自定义头)、`-i`(显示响应头)、`-I`(只拿头) |
| 输出轴 | 结果去哪？看什么信息？ | `-o`(存文件)、`-O`(按远程名存)、`-s`(安静)、`-v`(详细)、`-w`(自定义格式) |
| 连接轴 | 超时？代理？重定向？ | `-L`(跟随重定向)、`--connect-timeout`、`-x`(代理)、`-k`(跳过证书) |
| 认证轴 | 怎么登录？ | `-u`(Basic Auth)、`-H 'Authorization: Bearer ...'`、cookie |

---

### 轴 1：方法轴——"做什么操作？"

```bash
# GET（默认）
curl https://api.example.com/users

# POST JSON 数据
curl -X POST -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com"}' \
  https://api.example.com/users

# POST 表单数据
curl -d 'name=Alice&email=alice@example.com' https://api.example.com/users

# PUT
curl -X PUT -d '{"name":"Updated"}' https://api.example.com/users/1

# DELETE
curl -X DELETE https://api.example.com/users/1
```

> 💡 `-d` 会自动把方法设为 POST（不需要显式写 `-X POST`）。但加上 `-X` 更明确，减少歧义。

---

### 轴 2：头部轴——"发什么头？看什么头？"

```bash
# 显示响应头 + 响应体
curl -i https://example.com

# 只显示响应头（HEAD 请求）
curl -I https://example.com

# 自定义请求头
curl -H 'Authorization: Bearer token123' \
     -H 'X-Custom-Header: value' \
     https://api.example.com

# 查看完整请求/响应过程（DEBUG 神器）
curl -v https://api.example.com
```

> 💡 **`-v`（verbose）是调试 API 时最有用的选项。** 它显示 DNS 解析、TCP 握手、TLS 协商、请求头和响应头——整个过程一目了然。不需要 Wireshark，不需要 Postman。

---

### 轴 3：输出轴——"结果怎么处理？"

```bash
# 下载文件并保存
curl -o output.html https://example.com

# 按远程文件名保存（-O 大写）
curl -O https://example.com/file.tar.gz

# 安静模式（不显示进度条）
curl -s https://api.example.com

# 只显示 HTTP 状态码
curl -s -o /dev/null -w '%{http_code}' https://example.com

# 显示详细的性能数据
curl -s -o /dev/null -w 'time_total: %{time_total}s\nhttp_code: %{http_code}\n' https://example.com

# 静默模式 + 失败时显示错误
curl -sf https://api.example.com
```

> 💡 **`-w`（write-out）是 curl 的隐藏大招。** 它可以输出各种请求元数据：`http_code`（状态码）、`time_total`（总耗时）、`time_connect`（连接耗时）、`size_download`（下载字节数）、`redirect_url`（重定向目标）。API 性能测试不需要外部工具。

---

### 轴 4：连接轴——"超时、重定向、代理、证书"

```bash
# 跟随重定向（HTTP 301/302）
curl -L https://google.com

# 连接超时（默认可能等很久）
curl --connect-timeout 5 --max-time 10 https://api.example.com

# 跳过 SSL 证书验证（⚠️ 仅测试环境）
curl -k https://self-signed.example.com

# 通过代理访问
curl -x http://proxy:8080 https://api.example.com

# 使用 SOCKS5 代理
curl --socks5 127.0.0.1:1080 https://api.example.com
```

---

### 轴 5：认证轴——"怎么证明身份？"

```bash
# HTTP Basic Auth
curl -u username:password https://api.example.com

# Bearer Token
curl -H 'Authorization: Bearer eyJhbGciOi...' https://api.example.com

# 发送 cookie
curl -b 'session=abc123' https://api.example.com

# 保存 cookie 到文件（用于后续请求）
curl -c cookies.txt -d 'user=alice&pass=secret' https://example.com/login
curl -b cookies.txt https://example.com/dashboard
```

---

## 四、实用速查组合

```bash
# 测试 API 是否可达 + 返回状态码
curl -s -o /dev/null -w '%{http_code}\n' https://api.example.com/health

# 测量 API 响应时间
curl -s -o /dev/null -w 'dns: %{time_namelookup}s, connect: %{time_connect}s, ttfb: %{time_starttransfer}s, total: %{time_total}s\n' https://api.example.com

# 下载文件 + 断点续传
curl -C - -O https://example.com/largefile.iso

# 上传文件
curl -F 'file=@/path/to/image.png' https://api.example.com/upload
```

---

## 五、踩坑清单

- **坑一：`curl URL` 默认输出到 stdout** → 下载文件却终端刷屏——忘了加 `-o` 或 `-O`。
- **坑二：POST 的 `-d` 会自动加 `Content-Type: application/x-www-form-urlencoded`** → POST JSON 必须显式加 `-H 'Content-Type: application/json'`，否则服务端可能解析失败。
- **坑三：`-I`（HEAD 请求）不一定返回和 GET 一样的头** → 某些服务器对 HEAD 的处理不同。要验证 GET 的响应头用 `-i`。
- **坑四：`-L` 忘了加，重定向后拿不到最终内容** → HTTP 301/302 不跟进的话只能拿到一个 Location 头。
- **坑五：`-k`（跳过证书验证）在生产脚本里是大忌** → 中间人攻击的大门。只是本地测试时方便。

## 六、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| API 调试/测试 | curl | 快速、灵活、嵌入脚本友好 |
| 可视化 API 工具 | Postman / Insomnia | curl 输出是文本，图形化工具更容易看大 JSON |
| 下载大文件/整站镜像 | wget | wget 支持递归下载、更智能的重试机制 |
| Web 性能压测 | `ab` / `wrk` | curl 一次一个请求，不是压测工具 |
| 持续 API 监控 | `curl` + cron | 最简单的健康检查方案 |

---

> **核心观点：** 学 curl 不是为了记住 `-X -H -d` 三个选项，而是理解它的 **5 个能力轴**（方法、头部、输出、连接、认证）。curl 的"可选项爆炸"只是因为每一轴都有很多选项——你不需要全记住。熟练三个组合就够用：**① `curl URL`（GET 快速看）② `curl -s -o /dev/null -w '%{http_code}' URL`（状态码检查）③ `curl -v -X POST -H 'Content-Type: application/json' -d '{...}' URL`（API 调试）。**
