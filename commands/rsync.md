# rsync：增量同步——只传差异部分，比 scp 更适合大目录和重复同步

> 很多人用 rsync 同步文件，永远一个固定咒语：`rsync -avz source/ dest/`。能用，但遇到「只同步新文件」「排除 node_modules」「先看看会删什么」这些场景就卡住了。其实 rsync 是一个带增量算法的文件同步引擎——`avz` 只是它的默认皮肤。

## 一、你会遇到的场景

某天你要把 50GB 的日志目录从生产服务器同步到备份服务器。上一次同步是昨天——大部分文件没变。

新手的做法：`scp -r /var/log backup-server:/backup/`——50GB 全部重传，2 小时过去了。

而真正理解 rsync 的人，一行搞定：

```bash
rsync -av --progress /var/log/ backup-server:/backup/logs/
```

只传有变化的部分，3 分钟完成。

**这就是 rsync 的核心价值：高效同步本地或远程文件——只传输差异部分，支持增量、断点续传、按条件过滤。** 它是 `scp` 的升级版，是 `cp` 的网络增强版。

## 二、它是怎么工作的——IO 模型

rsync 的本质是 `源 → 差异计算 → 增量传输 → 目标`：

```
源端（本地或远程）
    │
    ↓ 扫描源文件列表（大小、修改时间）
    │  与目标端比对——哪些文件变了？哪些是新的？哪些已删除？
    │
    ↓ 差异计算：只对变化了的文件做块级增量传输
    │  （rsync 算法：分块 → 校验和 → 只传不同的块）
    │
    ↓ 按过滤规则筛选（--exclude / --include）
    │
    ↓ 写入目标端（先写到临时文件，完成后再原子重命名）
    │
目标端（本地或远程）
```

> 💡 rsync 的核心优势是**增量传输**——一个 1GB 的日志文件，如果只追加了 1KB，rsync 只传这 1KB。它不是传整个文件然后覆盖，而是在块级别比较校验和，只传变化的块。`scp` 做不到这一点。

## 三、语法骨架——先把句型刻进脑子里

```
rsync  [选项]  源  目标
       ──┬──   ─┬   ─┬
        选项    从哪   到哪
```

属于**骨架模式 A**：`源 → 过滤 → 目标`。和 find 同族。rsync 的"过滤"体现在选项（`--exclude`、`--delete`、`--max-size`）而不是显式的过滤槽位。

⚠️ **在讲具体能力之前，先排两个新手几乎必踩的雷：**

### 雷一：源路径末尾的 `/` 决定了行为——有 `/` 和没有 `/` 完全不同

```bash
# ❌ 不带 /：把 src 目录本身复制到 dest 里
rsync -av src dest/
# 结果：dest/src/file1, dest/src/file2

# ✅ 带 /：把 src 里面的内容复制到 dest 里
rsync -av src/ dest/
# 结果：dest/file1, dest/file2
```

> ⚠️ **这是 rsync 最经典、最容易被忽视的陷阱。** `src` 和 `src/` 不是"加不加都行"——它们表示完全不同的语义。记住口诀：**带 `/` = 复制里面的内容；不带 `/` = 连目录一起复制。**

### 雷二：不加 `--dry-run` 就直接跑危险操作

```bash
# ❌ 危险：--delete 会删除目标端多余的文件。先预览！
rsync -av --delete src/ dest/

# ✅ 先用 --dry-run 看看会做什么
rsync -av --delete --dry-run src/ dest/
# 确认无误后再去掉 --dry-run 执行
rsync -av --delete src/ dest/
```

> ⚠️ `--delete` 是 destructive 操作——它会删除目标端有但源端没有的文件。**先用 `--dry-run` 预览，再用 `-i` 看详细变化，确认无误后才执行。** 这条铁律在所有涉及删除的 rsync 场景下都适用。

---

## 四、核心能力逐轴拆解

rsync 的能力沿 5 个轴展开。

| 能力轴 | 问题 | 核心选项 |
|--------|------|---------|
| 模式轴 | 怎么传？保留什么属性？ | `-a`(归档)、`-v`(详细)、`-z`(压缩)、`-P`(进度+断点) |
| 过滤轴 | 传哪些？不传哪些？ | `--exclude`、`--include`、`--max-size`、`--min-size` |
| 同步轴 | 目标端多余的文件删不删？ | `--delete`、`--delete-excluded`、`--existing` |
| 安全轴 | 预览还是执行？带宽限制？ | `--dry-run`、`--bwlimit`、`-i`(输出变更详情) |
| 传输轴 | 源和目标在哪？ | 本地路径、`user@host:path`、`rsync://` |

---

### 轴 1：模式轴——"怎么传？保留什么属性？"

> 场景：同步项目目录，保留权限和时间戳，显示进度，压缩以节省带宽。

```bash
# -a: 归档模式 = -rlptgoD（保留所有属性：递归、符号链接、权限、时间、组、所有者、设备文件）
rsync -a src/ dest/

# -v: 详细输出（显示传输了哪些文件）
rsync -av src/ dest/

# -z: 传输时压缩（网络慢时有用，局域网不需要）
rsync -avz src/ dest/

# -P: 等同于 --partial --progress（显示进度 + 保留未完成文件以便断点续传）
rsync -avP src/ dest/

# 终极日常组合
rsync -avP src/ dest/
```

> 💡 `-a` 是最重要的选项——它不只是"归档"，而是一个包含了 7 个子选项的快捷方式。对大多数场景：**`-avP` 是你需要记住的唯一组合。** 其他选项按需附加。

---

### 轴 2：过滤轴——"传哪些？跳过哪些？"

> 场景：同步项目目录，但排除 `.git`、`node_modules`、`*.log`。

```bash
# 排除单个模式
rsync -av --exclude='node_modules' src/ dest/

# 排除多个模式
rsync -av --exclude='node_modules' --exclude='.git' --exclude='*.log' src/ dest/

# 从文件读取排除列表
rsync -av --exclude-from='.rsyncignore' src/ dest/

# 排除特定大小的文件
rsync -av --max-size='100M' src/ dest/
rsync -av --min-size='1k' src/ dest/
```

> 💡 `--exclude` 的模式是基于路径的，不是正则——`*` 匹配任意字符（除了 `/`），`**` 匹配任意路径层级。建一个 `.rsyncignore` 文件（格式和 `.gitignore` 一样）然后用 `--exclude-from` 是最干净的做法。

---

### 轴 3：同步轴——"目标端多了什么？要删掉吗？"

> 场景：你希望目标端和源端完全一致——源端删了文件，目标端也要删。

```bash
# ⚠️ 先预览！--delete 会删除目标端多余的文件
rsync -av --delete --dry-run src/ dest/

# 确认后执行：目标端变成源端的精确镜像
rsync -av --delete src/ dest/

# 只同步已存在的文件（不创建新文件）
rsync -av --existing src/ dest/

# 不覆盖目标端更新的文件
rsync -av --update src/ dest/
```

> ⚠️ `--delete` 会让目标变成源的精确副本——目标端独有的文件会丢失。**这是 rsync 最危险也最有用的功能。永远先用 `--dry-run` 预览待删列表。**

---

### 轴 4：安全轴——"执行前怎么确认？"

> 场景：这是 rsync 的正确使用方式——从不盲目执行。

```bash
# --dry-run: 只模拟，不动手
rsync -av --delete --dry-run src/ dest/

# -i: 逐项显示变更（每个文件一行，标明是新增/修改/删除）
rsync -av -i src/ dest/

# --stats: 最后输出统计信息
rsync -av --stats src/ dest/

# --bwlimit: 限制带宽（避免把生产带宽占满）
rsync -av --bwlimit=10000 src/ dest/    # 10MB/s

# --progress: 显示每个文件的传输进度
rsync -avP src/ dest/
```

> 💡 **rsync 的安全习惯三连：** ① `--dry-run` 预览 → ② `-i` 查看变更详情 → ③ 确认后去掉 `--dry-run` 执行。批量删除/覆盖场景，这应该是肌肉记忆。

---

### 轴 5：传输轴——"源和目标在哪？"

> 场景：本地到远程、远程到本地、远程到远程。

```bash
# 本地 → 远程（通过 SSH）
rsync -avP src/ user@host:/path/dest/

# 远程 → 本地
rsync -avP user@host:/path/src/ dest/

# 指定 SSH 端口
rsync -avP -e 'ssh -p 2222' src/ user@host:/dest/

# 远程 → 远程（数据不经过本地！直接从 A 到 B）
rsync -avP user@hostA:/src/ user@hostB:/dest/
```

> 💡 远程同步时，rsync 默认用 SSH 传输。不需要额外配置 SSH key 之外的任何东西。`-e 'ssh -p 2222'` 可以自定义 SSH 参数（非标准端口、特定密钥等）。

---

## 五、Pipeline 组合——rsync 的周围

rsync 通常不是管道的一环，而是独立的工具——但它的前后可以配合其他命令：

```bash
# 同步前：先看看源端有多大
du -sh /var/log

# 同步：执行 rsync
rsync -avP --delete --dry-run /var/log/ backup:/backup/logs/

# 同步后：验证两边是否一致
diff <(ls -l /var/log/) <(ssh backup 'ls -l /backup/logs/')
```

或者用 rsync 本身做备份的增量轮转：

```bash
# 硬链接快照式备份（类似 Time Machine）
rsync -av --delete --link-dest=../backup-1 /data/ /backups/backup-0/
# --link-dest：不变的文件用硬链接指向旧备份，不占额外空间
```

---

## 六、踩坑清单

- **坑一：源路径末尾 `/` 的问题** → `src` ≠ `src/`。前者复制目录本身，后者复制目录内容。这是 rsync 里最容易出错的地方。
- **坑二：`--delete` 不先预览** → 先用 `--dry-run` 仔细看过，确认待删列表没有误伤。
- **坑三：`--exclude` 的路径是相对于传输根目录的** → `rsync -av --exclude='build' src/ dest/` 排除的是 `src/build`，不是任意叫 `build` 的目录。多层嵌套的 `build/` 要用 `--exclude='**/build'`。
- **坑四：远程路径格式错误** → `user@host:/path` 不能写成 `user@host/path`——少了 `:` 会被当成本地路径。
- **坑五：大文件传输不给 `--partial`** → 100GB 的文件传到 99GB 时断了，没有 `--partial` 就得从头来。用 `-P`（包含 `--partial`）确保断点续传。
- **坑六：`rsync` 在 macOS 上是 `openrsync`** → 行为和 Linux 上的 GNU rsync 有细微差别。跨平台脚本要确保都有 GNU rsync 或都用 `openrsync`。

## 七、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 增量同步、镜像目录、定期备份 | rsync | 这正是 rsync 的设计领域——增量传输 + 过滤 + 镜像 |
| 一次性的文件传输 | `scp` | 更简单，不需要考虑增量——传完就完 |
| 持续实时同步 | `lsyncd` | rsync 是手动/定时触发的，不是实时监听 |
| 云端对象存储同步 | `aws s3 sync` / `rclone` | rsync 不适合操作 S3/OSS 等对象存储 |
| 大文件分发自多个源 | `btsync` / `syncthing` | rsync 是 1:1 同步，不是 P2P |
| 版本历史备份 | `restic` / `borg` | rsync 做快照，不做去重版本管理 |

---

> **核心观点：** 学 rsync 不是为了记住 `-avz` 这个固定组合，而是理解它的 **IO 模型**（扫描 → 差异计算 → 增量传输）和 **5 个能力轴**（模式、过滤、同步、安全、传输）。rsync 的增量算法是它的灵魂——它不是"能显示进度的 scp"，而是一个"只传差异的文件同步引擎"。
>
> 下一次你准备敲 `scp -r` 的时候，想一下——源端和目标端之间，有多少数据其实没变过？
