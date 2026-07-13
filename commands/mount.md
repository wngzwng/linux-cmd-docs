# mount：把磁盘"挂"到目录树上——Linux 文件系统的核心动作

> 在 Linux/Unix 里，所有文件都在一棵树里——从 `/` 开始。但你以为 `/mnt/usb` 是 `/` 的子目录？不对——它可能来自一个完全独立的物理磁盘。`mount` 就是把一个文件系统"嫁接"到目录树某个节点上的操作。

## 一、你会遇到的场景

某天你插了一个 U 盘，Linux 没自动挂载。你需要手动把它挂载到一个目录才能访问里面的文件。或者你想把 `/tmp` 挂到内存里（tmpfs）来加速临时文件读写。

```bash
# 查看当前所有挂载
mount

# 把 U 盘 /dev/sdb1 挂到 /mnt/usb
sudo mount /dev/sdb1 /mnt/usb

# 挂载 ISO 镜像文件（loop 设备）
sudo mount -o loop ubuntu.iso /mnt/iso
```

**这就是 mount 的核心价值：把块设备（磁盘分区、U盘、ISO镜像）挂载到文件系统的某个目录，使其内容可访问。**

## 二、核心概念——文件系统树 vs 物理设备

```
文件系统树（逻辑）              物理设备（实际）
─────────────────              ─────────────
/                              /dev/sda1 (SSD 分区 1)
├── /boot                      /dev/sda2 (SSD 分区 2)
├── /home                      /dev/sdb1 (HDD)
├── /mnt/usb                   /dev/sdc1 (U 盘)
├── /mnt/iso                   ubuntu.iso (镜像文件)
└── /tmp                       tmpfs (内存)
```

> 💡 理解这个模型：**Linux 没有 C: D: E: 盘符。** 只有一个 `/` 树，所有磁盘都挂在树的某个分支上。`mount` 决定哪个设备挂在哪个分支。

## 三、核心用法

```bash
# 查看所有挂载
mount
mount | column -t         # 对齐输出

# 挂载设备到目录（需要 root）
sudo mount /dev/sdb1 /mnt/usb

# 指定文件系统类型
sudo mount -t ext4 /dev/sdb1 /mnt/usb
sudo mount -t ntfs /dev/sdb1 /mnt/windows
sudo mount -t vfat /dev/sdb1 /mnt/fat32

# 挂载 ISO 镜像
sudo mount -o loop ubuntu.iso /mnt/iso

# 挂载 tmpfs（内存文件系统——重启后数据消失，速度快）
sudo mount -t tmpfs -o size=512M tmpfs /tmp/ramdisk

# 重新挂载为只读
sudo mount -o remount,ro /

# 重新挂载为可读写
sudo mount -o remount,rw /

# 卸载
sudo umount /mnt/usb
sudo umount /dev/sdb1
```

## 四、`-o` 常用挂载选项

| 选项 | 含义 |
|------|------|
| `ro` | 只读挂载 |
| `rw` | 读写挂载（默认） |
| `noexec` | 禁止执行该文件系统上的程序 |
| `nosuid` | 忽略 SUID/SGID 位（安全加固） |
| `noatime` | 不更新访问时间（减少磁盘 IO，SSD 推荐） |
| `defaults` | rw, suid, dev, exec, auto, nouser, async |

```bash
# SSD 优化挂载（减少写入）
sudo mount -o noatime,discard /dev/sdb1 /mnt/ssd
```

## 五、`/etc/fstab`——让挂载在重启后依然生效

手动 `mount` 在重启后失效。持久化挂载配置写在 `/etc/fstab`：

```
# 设备        挂载点     文件系统  选项               dump  fsck
/dev/sdb1    /mnt/data   ext4      defaults,noatime   0     2
//server/share /mnt/nas  cifs      credentials=/etc/smbcreds,uid=1000  0 0
tmpfs        /tmp/ram    tmpfs     size=256M,mode=1777  0  0
```

修改后测试（不重启验证）：

```bash
sudo mount -a    # 挂载所有 fstab 条目
```

## 六、卸载失败：`device is busy`

```bash
# 报错：umount: /mnt/usb: device is busy
# 原因：有进程正在使用该目录

# 找出是谁
lsof +D /mnt/usb
fuser -v /mnt/usb

# 强制卸载（慎用——可能导致数据丢失）
sudo umount -l /mnt/usb    # lazy unmount：立即从目录树分离，后台慢慢清理
sudo umount -f /mnt/usb    # force unmount
```

## 七、踩坑清单

- **坑一：mount 命令在重启后失效** → 持久化挂载必须写 `/etc/fstab`。
- **坑二：`mount` 不加参数输出几十行** → 先 `mount | grep /dev/sd` 只看磁盘设备，或用 `df -h` 看挂载情况（df 更简洁）。
- **坑三：umount 时提示 busy** → 先 `cd /` 离开那个目录再 umount。自己站在目录里时当然卸不掉。
- **坑四：`mount -a` 只会挂载未挂载的条目，不会重新挂载已挂载的** → 要重新应用 fstab 选项用 `mount -o remount /mountpoint`。
- **坑五：挂载点目录必须存在** → `mount` 不会自动创建 `/mnt/usb` 这个目录。先用 `mkdir -p`。

## 八、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 手动挂载/卸载 | mount/umount | 标准工具 |
| 查看磁盘和挂载概览 | `df -h` | 比 mount 输出更简洁 |
| 查看磁盘分区 | `lsblk` | 树形显示设备关系 |
| 自动挂载插入的 U 盘 | udev / udisks / 桌面环境 | mount 是手动操作 |
| 网络文件系统挂载 | mount -t nfs / mount -t cifs | 还是 mount，只是类型不同 |

---

> **核心观点：** `mount` 不需要记很多参数——掌握三个场景就够了：① `mount` 查看当前挂载（或 `df -h`），② `mount /dev/xxx /path` 手动挂载设备，③ 持久化配置写 `/etc/fstab`（然后 `mount -a` 验证）。最后记住——**`umount` 之前先退出那个目录。**
