# dd：不是"数据删除"，是"数据搬运工"

> `dd` 的名字容易让人误解——它不是"delete data"，是 **d**ata **d**escription / **d**ata **d**uplicator。它的本质是：按块读取输入，按块写入输出。它可以复制磁盘、制作 ISO、生成测试文件、擦除数据——但它也是一把"没有确认提示"的手术刀。

## 一、你会遇到的场景

某天你需要把一个 U 盘的 ISO 镜像烧录到另一个 U 盘，或者生成一个 1GB 的随机数据文件做测试。

新手的做法：找图形化工���或者写 Python 脚本。

dd 的做法：

```bash
dd if=/dev/disk2 of=~/backup.dmg bs=1m status=progress
```

**这就是 dd 的核心价值：按指定块大小在输入和输出之间复制数据——可以做磁盘克隆、文件生成、数据擦除。**

> ⚠️ dd 是 destructive 操作中最危险的一种——它沉默地覆盖任何目标，没有任何确认提示。**`of=` 写错一个字母可能毁掉整个磁盘。永远先确认 `if=` 和 `of=` 的指向。**

## 二、语法骨架

```
dd  if=输入  of=输出  [bs=块大小]  [count=块数]  [其他操作数]
    ───┬───  ───┬───  ─────┬─────  ─────┬─────
      从哪读    写到哪     多大块     读多少块
```

dd 不使用 `-x` 风格的选项，而是 `key=value` 格式的操作数。

## 三、核心操作数

| 操作数 | 含义 | 常用值 |
|--------|------|--------|
| `if=` | 输入文件/设备 | `/dev/zero`、`/dev/urandom`、磁盘设备 |
| `of=` | 输出文件/设备 | 文件名、磁盘设备 |
| `bs=` | 块大小 | `1M`、`4M`、`512` |
| `count=` | 复制块数 | `100`（配合 bs=1M = 100MB） |
| `status=` | 显示进度 | `progress`（macOS）、`status=progress`（Linux） |
| `conv=` | 转换选项 | `notrunc`、`noerror`、`sync` |

## 四、实用场景

### 场景 1：生成测试文件
```bash
# 生成 100MB 的空文件（全是 0）
dd if=/dev/zero of=test.bin bs=1m count=100

# 生成 1GB 的随机数据文件
dd if=/dev/urandom of=random.bin bs=1m count=1024
```

### 场景 2：磁盘克隆/备份
```bash
# ⚠️ 先确认设备名！
diskutil list                    # macOS
lsblk                            # Linux

# 克隆整个磁盘到镜像文件
sudo dd if=/dev/disk2 of=~/disk-backup.img bs=4m status=progress

# 从镜像恢复到磁盘（⚠️ 方向别搞反！）
sudo dd if=~/disk-backup.img of=/dev/disk2 bs=4m status=progress
```

### 场景 3：制作启动 U 盘
```bash
# ⚠️ 确认 U 盘设备名！写错一个字母毁掉整个硬盘
diskutil list

# macOS: 先卸载再写入
diskutil unmountDisk /dev/disk2
sudo dd if=ubuntu.iso of=/dev/disk2 bs=1m status=progress
```

### 场景 4：安全擦除磁盘（填零）
```bash
# ⚠️ 不可逆！
sudo dd if=/dev/zero of=/dev/disk2 bs=4m status=progress
```

### 场景 5：测试磁盘写入速度
```bash
# 写 1GB 到磁盘，看速度
dd if=/dev/zero of=./speedtest bs=1m count=1024
# 输出：1073741824 bytes transferred in 2.5 secs (429496729 bytes/sec)
```

## 五、踩坑清单

- **坑一：`of=` 写错覆盖整个磁盘** → 永远先 `lsblk` / `diskutil list` 确认设备名，执行前再读一遍命令。dd 没有任何二次确认。
- **坑二：`bs=` 太小导致极慢** → 默认 512 字节，大文件复制用 `bs=1M` 或 `bs=4M`。但也不能太大（可能超过可用内存）。
- **坑三：`count=` 和 `bs=` 的关系容易算错** → `bs=1M count=100` = 100MB。如果 `bs=512` 且 `count=100`，只有 51KB。
- **坑四：if/of 方向搞反** → `if` 是输入（源），`of` 是输出（目标）。从磁盘备份 = `if=/dev/disk`，恢复到磁盘 = `of=/dev/disk`。
- **坑五：没有进度提示** → 老版本 dd 卡住可能是在写数据也可能是在等超时。加 `status=progress`（Linux）或按 `Ctrl+T`（macOS 发送 SIGINFO 显示进度）。

## 六、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 块级复制/磁盘克隆 | dd | 这正是 dd 的设计领域 |
| 文件级复制（保留元数据） | `cp -a` / `rsync` | dd 做全盘逐块复制，不做文件级增量 |
| 制作启动 U 盘（更安全的） | `balenaEtcher` / `Rufus` | 图形化工具，有设备确认保护，避免 dd of= 的灾难 |
| 查看复制进度（更方便的） | `pv` | `pv file.iso > /dev/disk2` 比 dd 的 progress 更友好 |

---

> **核心观点：** dd 是裸块复制工具——它不理解文件系统，不理解目录结构，只认得"从第 N 块读到第 M 块"。**使用 dd 的核心安全原则：执行前读三遍 `if=` 和 `of=` 的方向和指向。** 误操作不可撤销。
