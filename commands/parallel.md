# 为什么 parallel 是 xargs 的完全体，而你还在手写 for 循环？

> 很多人用了好几年 Linux，处理批量任务还是写 `for f in *.mp4; do ffmpeg …; done`，CPU 16 个核心，常年只用 1 个。后来学会了 `xargs -P`，觉得已经"会并行"了——其实离「真正的并行调度引擎」还差得远。

## 一、你会遇到的场景

某天你要把 500 个 `.wav` 音频文件转成 `.mp3`。你的第一反应可能是：

```bash
# 新手写法：串行一个一个来，500 个文件要跑半小时
for f in *.wav; do
    ffmpeg -i "$f" "${f%.wav}.mp3"
done
```

稍微进阶一点的，想到多核：

```bash
# 勉强并行：xargs -P，但没有进度、不能重试、出错看不出来
ls *.wav | xargs -P4 -I {} ffmpeg -i {} {}.mp3
```

而真正理解 parallel 的人，敲的是：

```bash
# 一行：4 个并行、带进度条、失败可重试、跑完有审计日志
parallel --bar -j4 --joblog convert.log --retries 2 \
    'ffmpeg -i {} {.}.mp3' ::: *.wav
```

几分钟跑完，`cat convert.log` 能看到每个文件的退出码和耗时——哪个漏了、哪个挂了，一目了然。

**这就是 parallel 的核心价值：它不是"xargs 加了个 -P"，而是一个完整的并行任务调度引擎——含多路输入、进度监控、失败重试、执行审计、远程分发。**

## 二、它是怎么工作的——IO 模型

parallel 的本质不是 `命令 + 参数`，而是 `多路输入 → 配对组合 → 构造命令 → 并发调度 → 输出归并`：

```
输入源 1（::: 语法 / 管道 stdin / -a 文件）
输入源 2（::: 语法）  ← 可以有多个输入源！
    │
    ↓ 配对组合：默认笛卡尔积（每路各取一条），--link 改为一对一
    │
    ↓ 占位符替换：{} {.} {/} {/.} {#} {n} → 每条数据填入对应位置
    │
    ↓ 并发调度：-j 控制同时跑几个，--load/--memfree 限制资源
    │   每个任务 fork 一个子 shell，互不干扰
    │
    ↓ 输出归并：--group（任务内不乱序）、--line-buffer（行级不乱序）、--ungroup（即时输出）
    │
输出：各任务 stdout/stderr 按归并策略汇总，--joblog 另记审计日志
```

> 💡 理解了 IO 模型，`::: `、`--link`、`-j`、`--bar`、`--joblog` 这些参数就自然出现了——它们分别控制"输入从哪里来""怎么配对""怎么调度""怎么监控"和"怎么审计"。parallel 不是在做"并行版 xargs"——它是在把"任务列表"抽象成"可调度的作业流"。

## 三、语法骨架——先把句型刻进脑子里

```
parallel  [调度选项]  命令模板  :::  输入源1  :::  输入源2  ...
          ───┬───     ──┬──    ───       ─┬──
         控制行为槽    命令槽              多个输入槽（空格分隔）
```

快捷替代写法：

```
# 管道输入（最常见）
输入列表 | parallel 命令模板

# 文件输入
parallel -a 文件列表.txt 命令模板
```

属于**骨架模式 E**：`输入 → 转换(构造命令) → 并发执行 → 输出归并`。和 xargs 同源但扩展了三个维度——**多路输入**（笛卡尔积/一对一配对）、**执行生命周期**（重试/暂停/恢复）、**可观测性**（进度/ETA/审计日志）。

⚠️ **在讲具体能力之前，先排一个新手几乎必踩的雷：**

```bash
# ❌ 错误：以为 {} 会被 shell 先展开——其实 parallel 用 {} 时需要用引号保护
parallel ffmpeg -i {} {.}.mp3 ::: *.wav
# 问题：{ 和 } 在某些 shell（如 fish）中有特殊含义

# ✅ 正确：命令模板用单引号包起来，让 parallel 自己解释 {}
parallel 'ffmpeg -i {} {.}.mp3' ::: *.wav
```

> ⚠️ **parallel 的 {} 不是 shell 变量，是 parallel 自己的占位符。** 命令模板用单引号包起来是最安全的——防止 shell 在你还没反应过来时把 `{}`、`{.}`、`$变量` 等吃掉。这条规则和 `find -exec` 要引号保护 `{}` 是同一个道理。

另一个高频踩坑：**函数要用 `export -f` 导出**。

```bash
# ❌ 直接引用函数——子 shell 里根本看不到这个函数
do_task() { echo "处理: $1"; }
parallel do_task ::: a b c
# /bin/bash: do_task: command not found

# ✅ 导出后再用
do_task() { echo "处理: $1"; }
export -f do_task
parallel do_task ::: a b c
```

parallel 的每个任务跑在独立的子 shell 里——父 shell 里定义的函数、别名默认不可见。`export -f` 把函数的定义体复制给子 shell。

## 四、核心能力逐轴拆解

parallel 的能力沿 6 个轴展开。不要背参数——每个轴回答一个具体问题，各轴正交，自由组合。

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 输入源 | 数据从哪来？怎么配对？ | `::: ` 多路、管道 stdin、`-a` 文件、`--link` 一对一 |
| 并发控制 | 同时跑几个？资源够吗？ | `-j N`、`--load`、`--memfree` |
| 输出归并 | 多个任务的输出怎么排？ | `--group`(默认)、`--line-buffer`、`--ungroup` |
| 失败处理 | 失败了怎么办？能重试吗？ | `--halt`、`--retries`、`--joblog`、`--resume-failed` |
| 可观测性 | 跑了多少？还剩多少？ | `--bar`、`--eta`、`--joblog`、`--progress` |
| 执行位置 | 在本地跑还是远程跑？ | `-S`、`--sshlogin`、`--slf`、`--transfer` |

---

### 轴 1：输入源——"数据从哪来，怎么配对？"

> 场景：你有 3 个环境和 4 个服务，想给每个环境的每个服务都执行一个健康检查。3×4=12 个组合，你不想写嵌套循环。

```bash
# 笛卡尔积：3 个环境 × 4 个服务 = 12 个命令
parallel 'curl -s http://{1}/health/{2}' ::: dev staging prod ::: api gateway worker redis

# 一一配对：用 --link 让两个输入源按位置对应
parallel --link 'scp {1} user@{2}:/deploy/' ::: app.jar config.yml ::: server1 server2
# app.jar → server1, config.yml → server2
```

输入源的三种写法及其适用场景：

```bash
# 方式 1：::: 多路输入——适合"组合"场景
parallel echo ::: A B C ::: 1 2 3

# 方式 2：管道 stdin——适合前一个命令的输出
find . -name "*.log" | parallel gzip

# 方式 3：-a 从文件读——适合固定的任务列表
parallel -a urls.txt 'wget {}'
```

> ⚠️ **`:::` 后面的内容是 parallel 自己展开的，不经 shell。** 也就是说 `::: *.wav` 里的 `*` 是 parallel 在做 glob 匹配，不是 shell。这是 parallel 和 xargs 的一个重要区别——parallel 会自己处理通配符，xargs 依赖 shell 先展开。

---

### 轴 2：并发控制——"同时跑几个？资源够吗？"

> 场景：你在一台 4 核服务器上跑批量转换，跑了 8 个并行后发现机器卡到 ssh 都连不上了——因为 CPU 被吃满了。

```bash
# 固定并发数：只跑 4 个（留一些资源给系统和 ssh）
parallel -j4 'ffmpeg -i {} {.}.mp4' ::: *.mov

# 按 CPU 负载动态控制：负载超过 80% 就不启动新任务
parallel --load 80% 'ffmpeg -i {} {.}.mp4' ::: *.mov

# 按可用内存控制：已用内存超 200M/task 就减并发
parallel --memfree 200M 'java -Xmx128m -jar processor.jar {}' ::: *.dat
```

> 💡 `-j` 的值建议：**纯 CPU 任务用核心数，I/O 密集任务用核心数的 2~3 倍。** 不确定时用 `-j -1`（比总核心数少一个），至少给系统留一口喘息的。

---

### 轴 3：输出归并——"多个任务的输出怎么排？"

> 场景：并行跑 50 个任务，每个任务输出多行日志。默认情况下 parallel 会等一个任务完全结束后才打印它的输出——保证不乱。但你会觉得"卡住了，什么都没发生"。

三种归并模式，应付不同场景：

```bash
# --group（默认）：按任务分组输出。任务完成前不打印，完成后一次性输出。
# 适合：需要"每个任务的输出是完整的"不可打断的场景
parallel --group 'echo "Task {} start"; sleep 1; echo "Task {} done"' ::: A B C

# --line-buffer：按行归并。一行输出不会被打断，但不同任务的行可以交错。
# 适合：实时看进度，但不想一行内部被截断
parallel --line-buffer 'echo "{}: line1"; echo "{}: line2"' ::: A B C

# --ungroup：即时输出。最快，但输出可能交错成一团糟。
# 适合：纯调试、不在乎输出是否混乱
parallel --ungroup 'echo {}' ::: A B C
```

| 模式 | 输出速度 | 完整度 | 适用场景 |
|------|---------|--------|---------|
| `--group`（默认） | 慢（要等） | 任务内完整不乱 | 批量下载、数据转换 |
| `--line-buffer` | 适中 | 行内不乱，行间可能交叉 | 实时看日志进度 |
| `--ungroup` | 最快 | 可能全乱了 | 快速调试 |

---

### 轴 4：失败处理——"挂了怎么办？"

> 场景：批量下载 100 个文件，跑到第 73 个时网络断了。你希望断网的任务自动重试，而不是整批重跑——前 72 个已经下好了。

```bash
# 每个任务失败后自动重试 3 次
parallel --retries 3 'wget -q {}' ::: $(cat urls.txt)

# 发现失败立即停掉所有任务（默认是跑完再汇报）
parallel --halt now,fail=1 'critical_task {}' ::: inputs

# ⭐ 关键能力：joblog + retry-failed——失败了可以从日志中挑出失败的重新跑
parallel --joblog myjob.log 'wget {}' ::: $(cat urls.txt)
# 跑完后，只重试失败的（退出码非 0 的那些）
cat myjob.log | parallel --retry-failed 'wget {}'
```

`--joblog` 是 parallel 最被低估的能力。它记录的每一列：

```
Seq	Host	Starttime	JobRuntime	Send	Receive	Exitval	Signal	Command
1	:	1623456789.123	3.456		0	1024	0	0	wget file1
2	:	1623456789.234	error		0	0	1	0	wget file2
```

- `Exitval=0`：成功
- `Exitval≠0`：失败，可用 `--retry-failed` 重跑
- `JobRuntime` 显示每个任务花了多少秒——性能瓶颈一目了然

> 💡 **把 `--joblog` 当成并行任务的"审计日志"。** 批量操作后看一眼 joblog，哪些成功了、哪些耗时异常、哪些悄无声息地失败了——不用猜，数据说话。

---

### 轴 5：可观测性——"跑了多少？还剩多少？"

> 场景：500 个文件在转码，你盯着终端 10 分钟了，不知道还要多久。

```bash
# 进度条（最直观）
parallel --bar 'ffmpeg -i {} {.}.mp4' ::: *.mov

# ETA 预估剩余时间
parallel --eta 'ffmpeg -i {} {.}.mp4' ::: *.mov

# 两者结合
parallel --bar --eta 'ffmpeg -i {} {.}.mp4' ::: *.mov
```

输出示例：

```
25% |████████░░░░░░░░| 125/500  [ETA: 3m12s]
```

> 💡 `--bar` 只在终端交互时好用。如果是 cron 定时任务或 CI 管道，用 `--joblog` + `--progress` 把进度写到文件，避免 tty 检测导致 `--bar` 直接没输出。

---

### 轴 6：远程执行——"任务分发到多台机器"

> 场景：你的批量任务太重了，一台机器跑不动——或者你想同时检查 10 台服务器的健康状态。

```bash
# 在多台远程机器上同时执行同一个命令
parallel -S server1,server2,server3 'hostname; uptime'

# 按各机器的 CPU 核心数自动分配任务量（不给 1 核机器派 8 个活）
parallel -S 4/server1,8/server2 'heavy_task {}' ::: inputs

# : 表示本机，和远程机器混编
parallel -S :,server1,server2 'process {}' ::: inputs

# 传输文件到远程再执行（-tf 先传文件）
parallel -S server1 --transferfile {} 'md5sum {}' ::: bigfile.dat
```

> ⚠️ 远程执行依赖 SSH 免密登录（密钥认证）。先确保 `ssh server1 echo ok` 能跑通，再试 `parallel -S`。

## 五、Pipeline 组合——把命令串起来

```
find（解决：找到哪些文件需要处理）
    │  输出：NUL 分隔的文件路径列表
    ↓
parallel --bar -j4 --joblog job.log（解决：并发调度、进度监控、执行审计）
    │  输入：NUL 分隔的文件路径 ← find -print0 的输出
    │  输出：每个文件的处理结果 + joblog 文件
    ↓
ffmpeg / gzip / convert（解决：对单个文件执行具体操作）
```

```bash
# 完整示例：找到所有超过 5MB 的视频，并行转码，带进度条和审计日志
find ./videos -name "*.mp4" -size +5M -print0 \
  | parallel -0 --bar -j4 --joblog transcode.log \
      'ffmpeg -i {} -c:v libx264 -preset fast {.}_h264.mp4'
```

> 💡 这里能串起来的关键是：`find -print0` 输出的 NUL 分隔正好是 `parallel -0` 接受的格式——和 xargs 完全一致的约定。理解 IO 模型之后，`find | xargs` 和 `find | parallel` 只是把"执行引擎"从 xargs 换成 parallel——**调用方（find）的接口不变，被调用方（ffmpeg）的接口不变，只有中间的调度层升级了。**

## 六、真实排障全流程复盘——批量图片压缩

> 场景：运营团队上传了 5000 张产品图片，你需要把它们都压缩成 webp 格式，压缩后删除原图。每张图几百 KB 到几十 MB 不等。

```
第一步【定位】 → ls ./uploads/*.{jpg,png,jpeg} | wc -l
                 统计文件总数，预估工作量：5000 张，单张约 2s，串行需要 3 小时

第二步【测试】 → parallel --dry-run 'cwebp -q 80 {} -o {.}.webp' ::: ./uploads/test*.jpg
                 先 dry-run 看 3 个测试文件会执行的命令是否正确

第三步【试跑】 → parallel -j4 --joblog test.log 'cwebp -q 80 {} -o {.}.webp' ::: ./uploads/test*.jpg
                 小批量（几个文件）实际跑，验证输出质量、确认 joblog 记录正常

第四步【预览】 → parallel --dry-run 'cwebp -q 80 {} -o {.}.webp && rm {}' ::: ./uploads/*.jpg 2>&1 | head -20
                 dry-run 看前 20 条，确认转码+删除的语法无误
                 ⚠️ 重点：确认 rm {} 的 {} 确实指向原图，不是 .webp 文件

第五步【执行】 → parallel --bar -j4 --joblog compress.log \
                   'cwebp -q 80 {} -o {.}.webp && rm {}' ::: ./uploads/*.jpg
                 带进度条执行，joblog 记录每一张的转码结果

第六步【审计】 → cat compress.log | awk '$7 != 0'
                 查看有哪些文件失败了（退出码非 0），手动排查

第七步【复查】 → ls ./uploads/*.webp | wc -l
                 确认 webp 数量和预期一致；再检查还有没有残留的 .jpg
```

> 整个过程没有手动看任何一个文件，全程靠 parallel 的 `--dry-run`、`--bar`、`--joblog` 完成测试→预览→执行→审计→复查。

## 七、踩坑清单

- **坑一：命令模板没加引号** → `parallel echo {} ::: *` 中如果命令含 `$`、`>`、`|` 等特殊字符，shell 会先解释它们。**命令模板始终用单引号包起来。**
- **坑二：函数没 export** → 函数在子 shell 里不可见。用 `export -f 函数名` 导出，或者把逻辑写进脚本文件再调用。
- **坑三：`--bar` 在 cron/CI 中不显示** → `--bar` 需要 tty，非交互环境自动禁用。后台任务用 `--joblog` + `--progress` 替代。
- **坑四：笛卡尔积爆炸** → `parallel cmd ::: 100个A ::: 100个B` = 10000 个任务。输入源很多时先用 `--dry-run | wc -l` 看清任务数。
- **坑五：`:` 和 `:::` 混淆** → `:::` 是参数分隔符（后面跟输入），单个 `:` 在 `-S` 中表示本机。不要搞混。
- **坑六：文件名含空格或特殊字符时不用 `-0`** → 和 xargs 一样的道理：`find … -print0 | parallel -0 …` 是唯一的安全写法。
- **坑七：`{}` 在命令中被多条引用时** → `parallel 'cp {} /backup/{}' ::: *.txt` 没问题，但要注意 `{/}` `{.}` `{/.}` 的语义——它们是从输入行的**最后一个路径组件**派生的，不是从 `{}` 所在位置派生的。

## 八、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 简单的 `cmd arg1 arg2 …` 一次性调用 | `xargs` | xargs 更轻，大多数系统自带，没有额外依赖 |
| 需要复杂流程控制（条件判断、变量累加） | `while read` 循环 | parallel 的任务是独立的——任务间不能通信，不能累加全局状态 |
| 构建系统（文件依赖、增量编译） | `make -j` | parallel 不理解"这文件已处理过可以跳过"，每次都是全量执行 |
| 分布式计算（跨集群调度、数据分片） | Hadoop/Spark | parallel 的远程执行只是 SSH 多机分发，没有分布式文件系统、容错和调度策略 |
| 一个命令跑全量输入就够了（不需要每个输入单独执行） | 直接管道 | `cat *.log | grep ERROR` 比 `parallel grep ERROR ::: *.log` 简单且高效 |
| 需要和 parallel 一样的功能但用 Python | `xargs -P` 或 `pueue` | `xargs -P` 零依赖；`pueue` 是 Rust 写的并行任务队列，UI 更现代 |

## 九、换个命令你会了吗？

parallel 属于**骨架模式 E**：`输入 → 构造命令 → 并发执行 → 输出归并`。同一模式的命令还有：

- **xargs**：管道的"最后一公里"——把 stdin 变成命令参数。parallel 可以看作 xargs 的超集，拥有相同的 IO 模型，但在并发调度、多路输入、可观测性上完全碾压。
- **`find … -exec cmd {} +`**：find 内置的批量执行模式，思路一致（收集参数 → 批量执行），但没有并行能力和占位符变换。

学完 parallel，你其实已经把「数据 → 命令 → 执行」这个模式推到了最高级别。下次遇到任何"一堆数据要逐条处理"的需求，先判断：需要并行吗？需要进度监控吗？需要失败重试吗？——如果三个问题有一个是 yes，parallel 就是答案。

---

> **核心观点：** 学 parallel 不是为了记住 `-j --bar --joblog :: : --link`，而是理解它的 **IO 模型**（多路输入→配对→构造命令→并发调度→输出归并）和 **6 个能力轴**（输入源、并发控制、输出归并、失败处理、可观测性、执行位置）。一旦这两个立住了，`find -print0 | parallel -0 --bar -j8 --joblog log.txt 'cmd {}'` 这种组合就是肌肉记忆。
>
> 你平时批量处理任务，是还在写 for 循环、还是只会 `xargs -P`？
