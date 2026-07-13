# head + tail：文件头尾——排查日志的第一步和最后一步

> `head` 和 `tail` 是最简单的文件查看命令——一个看头，一个看尾。它们不需要教程。但有一个 `tail -f` 选项，和一个 `head` 的 `-c` 字节截取，值得单独讲清楚。

## head：显示文件开头

```bash
# 看前 10 行（默认）
head file.log

# 看前 N 行
head -n 20 file.log
head -20 file.log          # 简写

# 看前 N 字节
head -c 1024 file.bin

# 从管道取数据
find . -name '*.log' | head -5

# 多个文件：每个文件前会打印文件名头
head -n 3 file1.txt file2.txt
# → ==> file1.txt <==
# → line1
# → line2
# → line3
```

## tail：显示文件末尾（+ 实时跟踪）

```bash
# 看最后 10 行（默认）
tail file.log

# 看最后 N 行
tail -n 50 file.log

# 看最后 N 字节
tail -c 1024 file.bin

# -f：实时跟踪——文件有新内容追加时自动显示（Ctrl+C 退出）
tail -f /var/log/nginx/access.log

# -F：和 -f 类似，但文件被删除/重命名后会自动重试（更适合日志轮转场景）
tail -F /var/log/nginx/access.log

# 跟踪多个文件
tail -f file1.log file2.log

# 从第 N 行开始显示（前面全部跳过）
tail -n +50 file.log    # 从第 50 行开始到末尾
```

## head + tail 组合

```bash
# 看第 100 到 110 行（head 取前 110 行，tail 取最后 10 行）
head -n 110 file.log | tail -n 10

# 等价于 sed
sed -n '100,110p' file.log
```

## tail -f vs less +F

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 只追踪不浏览 | `tail -f` | 轻量、启动快 |
| 先浏览再追踪 | `less +F` | 可以在同一个界面内：搜索 → 过滤 → 追踪 |
| 中断追踪翻看历史 | `Ctrl+C` | 在 less 里退出 F 模式后可以上下翻；tail 只能退出重启 |

## 踩坑清单

- **坑一：`tail -f` 不会自动处理日志轮转** → logrotate 把 `app.log` 改名为 `app.log.1`，tail -f 仍然监视旧的 inode，新日志不会显示。用 `tail -F`（大写）自动跟踪文件名。
- **坑二：`head -n -5`（排除最后 N 行）是 GNU 扩展** → BSD head/macOS 不支持负数。跨平台用 `sed` 或 `head | ...` 组合。
- **坑三：`tail -f` + grep 的组合要注意缓冲** → `tail -f file | grep ERROR` 中 grep 默认有输出缓冲，可能延迟显示。加 `grep --line-buffered ERROR`。

---

> **核心观点：** head 和 tail 不需要学——它们两个加起来只有 `-n` 和 `-f` 两个值得记住的选项。**`tail -F`（大写）记住它——日志轮转时它能自动重新追踪。**
