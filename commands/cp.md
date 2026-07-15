
# cp：你知道它慢，但可能不知道为什么慢——以及什么时候不该用它

cp 是那种"看似简单，实则暗藏玄机"的命令。每个人都用它来复制文件，但如果你问"cp 到底做了什么"，大部分人只能回答"复制呗"。

然而在排障和运维中，`cp` 的很多行为如果没搞清楚，后果不是浪费时间（等一个不必要的全量复制），就是丢失关键元数据（权限丢了、时间戳变了、软链接变成了实际文件）。这篇文章讲的全是这些"你以为不对但其实很正常"的 cp 行为。

---

## 场景引入：备份了一个目录，部署后权限全乱了

你把生产服务器的 `/etc/nginx/` 目录复制到备份盘：

```bash
cp -r /etc/nginx/ /backup/
```

一个月后你需要恢复，把备份复制回来，启动 nginx——报错：`nginx: [emerg] open() "/etc/nginx/nginx.conf" failed (13: Permission denied)`。

你查看权限：所有文件的所有者变成了 root:root（备份时你用的是 root），原来精心配置的 `www-data` 组权限全丢了。

如果你当初用的是：

```bash
cp -a /etc/nginx/ /backup/
```

`-a`（archive mode）会保留**所有权、权限、时间戳、软链接**——恢复后和原目录一模一样。

---

## 核心概念：cp 的四种行为模式

cp 的核心逻辑：**复制文件数据块，创建新的目录条目。**

但关键在于**复制多少元数据**，这决定了你应该用哪个参数组合：

| 参数 | 复制内容 | 保留的元数据 | 适用场景 |
|------|---------|-------------|---------|
| `cp file dest` | 文件数据 | 几乎没有 | 日常小文件复制 |
| `cp -p file dest` | 文件数据 | 权限、时间戳 | 复制后不希望改变"看起来"的属性 |
| `cp -a dir dest` | 目录树 + 数据 | 权限、时间戳、所有者、软链接 | **备份专用** |
| `cp -r dir dest` | 目录树 + 数据 | 几乎没有 | 复制时不需要保留原始属性 |

> ⚠️ 最常见的混乱：`cp dir dest` 会报错（"omitting directory"），必须加 `-r`。但 mv 移动目录不需要 `-r`。这是 cp 和 mv 最大的语法差异之一。

---

## 先排雷：`cp -r` 和 `cp -a` 的差别比你想象得大

```bash
# 场景：备份一个包含软链接的目录
ls -la /opt/app/
# lrwxrwxrwx config.yml -> /etc/app/config.yml
# -rw-r--r-- app.log

# 用 -r：软链接变成了硬文件
cp -r /opt/app/ /backup/
ls -la /backup/config.yml
# -rw-r--r-- config.yml    ← 软链接变成了实际的副本！

# 用 -a：软链接保持为软链接
cp -a /opt/app/ /backup/
ls -la /backup/config.yml
# lrwxrwxrwx config.yml -> /etc/app/config.yml   ← 正确
```

> 💡 **`cp -a` 的 `-a` = archive（归档）。它的设计目标就是"完整地保留一切可以保留的属性"。** 做备份时如果不确定该用什么参数，用 `-a` 是最安全的选择。

---

## 核心能力逐层拆解

### 1. 基础复制

```bash
cp file.txt /tmp/                # 复制文件到目录
cp file.txt /tmp/new_name.txt    # 复制并重命名
cp file1.txt file2.txt /tmp/     # 复制多个文件到同一个目标
```

### 2. 复制目录

```bash
cp -r dir/ /tmp/                 # 递归复制目录
cp -R dir/ /tmp/                 # 同上（-R 和 -r 等价）
cp -a dir/ /tmp/                 # 归档复制：保留一切
```

### 3. 保留属性

```bash
cp -p file.txt /tmp/             # 保留权限、时间戳、所有者
cp -a dir/ /tmp/                 # 保留一切（-p + -r + 保留软链接）
```

### 4. 安全选项

```bash
cp -i file.txt /tmp/             # 覆盖前提示确认
cp -n file.txt /tmp/             # 不覆盖已存在的文件
cp -b file.txt /tmp/             # 覆盖前自动备份原文件（加 ~ 后缀）
cp -u file.txt /tmp/             # 只复制更新的文件（update）
```

### 5. 显示过程

```bash
cp -v file.txt /tmp/             # 显示正在复制什么
cp -rv dir/ /tmp/                # 递归 + 显示每一条
```

---

## 场景驱动

### 1. 全量备份：用 `-a`

```bash
# 完整备份网站目录
cp -av /var/www/mysite/ /backup/mysite_$(date +%Y%m%d)/
# -a：保留权限、所有者、时间戳、软链接
# -v：显示进度
# 结果：备份目录和原目录在 ls -l 下看不出差别
```

### 2. 增量同步：用 `-u`

```bash
# 把源码里的新文件同步到测试目录
cp -uv src/*.py /tmp/test/
# -u：只复制源比目标新的文件
# -v：告诉你哪些文件被复制了
```

### 3. 安全覆盖：用 `-i` 或 `-n`

```bash
# 发布配置文件，不覆盖已有的
cp -nv /tmp/new_configs/*.conf /etc/myapp/
# -n：已存在的配置不受影响
# -v：告诉我哪些放了进去、哪些跳过了
```

### 4. 复制时保留目录结构

```bash
# 错误示范：想把 a/b/file.txt 复制到 /tmp/，仅 file.txt 过去
cp a/b/file.txt /tmp/

# 如果想保留 a/b/ 的层级结构：
cp --parents a/b/file.txt /tmp/
# 结果：/tmp/a/b/file.txt
```

> 💡 `--parents` 用于需要保留相对路径的场景。但它有个坑：源路径必须是相对路径且不能包含 `..`。

---

## 新手踩坑总结

- **坑一：复制目录忘了 `-r`。** `cp dir/ /tmp/` 报 "omitting directory"。记住：cp 需要 `-r`，mv 不需要。
- **坑二：备份不用 `-a`，权限丢失。** `cp -r` 不保留权限和时间戳，备份还原则可能权限错乱。做备份永远用 `cp -a`。
- **坑三：`-r` 会让软链接变成实际文件。** 源目录里的软链接被展开成副本。用 `-a` 可保留软链接。
- **坑四：cp 覆盖不提示。** 和 mv 一样，默认静默覆盖。建议 `alias cp='cp -i'`。
- **坑五：macOS 上 `cp -a` 的行为和 Linux 略有不同。** macOS 的 `-a` 不会保留扩展属性（xattr）。跨平台注意。
- **坑六：`cp -r dir/` 和 `cp -r dir` 的区别。** 前者复制目录**内容**到目标，后者复制目录**本身**到目标。多一个 `/`，结果完全不一样。

---

## 什么时候换工具

| 需求 | cp 行不行 | 替代方案 |
|------|----------|---------|
| 本地复制文件/目录 | 行 | — |
| 增量同步到大目录 | 效率低 | `rsync -av` |
| 跨主机复制 | 不行 | `scp` 或 `rsync` |
| 移动文件（不保留原文件） | 麻烦（cp + rm） | `mv` |
| 创建文件副本而不占双倍空间 | 不行 | `cp --reflink=always`（CoW 文件系统如 Btrfs/XFS） |

---

## 最后

cp 和 mv 是"看起来像一对，但其实是两口子"的命令——表面相似，内部逻辑完全不同。mv 只是改标签（同文件系统），cp 是真的要抄一遍数据。

而 cp 自己的参数也有"深浅"之分：`-r` 只复制表面，`-a` 复制灵魂。下次备份目录时，别 `cp -r` 了，试试 `cp -a`——你的权限、时间戳和软链接会感谢你的。
