# tar：打包 + 压缩——`-czvf` 和 `-xzvf` 的速记口诀，不再每次都查

> 很多人用了好几年 Linux，tar 永远靠肌肉记忆——`tar -xzf` 解压、`tar -czf` 压缩，一旦参数顺序换一下就蒙了。其实 tar 的四个字母不是咒语，每个字母回答一个独立问题。

## 一、你会遇到的场景

某天你从服务器下载了一个 `.tar.gz` 文件，想解压。

新手的做法：打开搜索引擎，输入"tar 解压命令"，然后复制 `tar -xzvf file.tar.gz`，从不理解那几个字母什么意思。下次遇到 `.tar.bz2`，又去搜"tar 解压 bz2"。循环往复。

而真正理解 tar 的人，看到任何压缩包格式，都能直接写出命令——因为 ta 知道那四个字母分别控制什么。

```bash
tar -xf archive.tar.gz    # 解压（自动检测压缩格式！）
tar -czf archive.tar.gz dir/   # 创建 gzip 压缩包
tar -cjf archive.tar.bz2 dir/  # 创建 bzip2 压缩包
```

**这就是 tar 的核心价值：把一堆文件捆成一个归档，可选压缩——动作模式、压缩方式、文件名、详细度各自独立，组合出所有场景。** 它不是压缩工具（那是 gzip/bzip2 的事），它是归档工具。

## 二、它是怎么工作的——IO 模型

tar 的本质是 `文件集合 → 归档/压缩 → 打包文件`（或反向）：

```
创建模式（-c）：
  文件/目录集合
      │
      ↓ 递归收集所有文件
      ↓ 写入归档格式（tar 格式——保留权限、所有者、目录结构）
      ↓ 可选：管道给压缩程序（gzip/bzip2/xz）
      │
  输出：archive.tar[.gz/.bz2/.xz]

解压模式（-x）：
  archive.tar.gz
      │
      ↓ 可选：管道给解压程序
      ↓ 读取 tar 格式 → 还原文件/目录/权限
      │
  输出：原始文件集合
```

> 💡 tar 本身不压缩。`-z`（gzip）、`-j`（bzip2）、`-J`（xz）是告诉 tar 在归档之后/之前调用压缩程序。**现代 tar（GNU tar 1.15+, BSD tar）可以自动检测压缩格式，所以 `-xzf` 可以简写为 `-xf`——tar 会自己判断是不是 gzip 压缩的。** 但老版本不完全支持，所以 `-xzf` 仍然常见。

## 三、语法骨架——先把句型刻进脑子里

```
tar  [动作+压缩]  -f  [归档文件名]  [操作对象...]
      ────┬────    ──┬───────────    ───┬──
        模式+选项     文件槽             对象槽
```

属于**骨架模式 B**：`模式 + 对象`。和 grep 同族——先说什么动作，再说什么文件。

⚠️ **在讲具体能力之前，先排两个新手几乎必踩的雷：**

### 雷一：`-f` 必须紧挨着文件名！

```bash
# ❌ 错误：-f 后面跟了 -v，tar 以为你的归档文件名叫 "-v"
tar -cfv archive.tar dir/

# ✅ 正确：-f 必须是最后一个选项字母，后面紧跟文件名
tar -cvf archive.tar dir/
```

`-f` 是一个需要参数的选项——它后面的第一个词就是归档文件名。如果你在 `-f` 和文件名之间插了别的选项字母，tar 会把那个字母当成文件名。

### 雷二：BSD tar 和 GNU tar 对选项前 `-` 的态度不同

```bash
# BSD tar（macOS）：- 可有可无
tar xzf archive.tar.gz     # ✅
tar -xzf archive.tar.gz    # ✅

# GNU tar：同样都行
# 但建议始终加 -，可读性更好且跨平台一致
```

> 💡 两条铁律：① `-f` 后面紧跟文件名；② 解压前先用 `-t` 查看内容，别盲解。

## 四、核心能力逐轴拆解

tar 的能力沿 4 个轴展开。每个轴回答一个独立问题：

| 能力轴 | 问题 | 选项 |
|--------|------|------|
| 动作轴 | 做什么？ | `-c`(创建), `-x`(解压), `-t`(查看内容), `-r`(追加) |
| 压缩轴 | 压不压缩？用什么压？ | 不指定(无压缩), `-z`(gzip), `-j`(bzip2), `-J`(xz) |
| 输出轴 | 输出什么？ | `-v`(详细), `-C`(指定解压目录), `-f`(指定文件名) |
| 过滤轴 | 选哪些文件？ | `--exclude`(排除), `--include`(包含) |

---

### 轴 1：动作轴——"创建还是解压还是查看？"

> 场景：这是最核心的轴——同一个 tar 命令，不同动作完全不同。

```bash
# 创建归档
tar -cf archive.tar dir/

# 查看归档内容（不解压！安全预览）
tar -tf archive.tar

# 解压归档
tar -xf archive.tar

# 追加文件到已有归档（只能追加到未压缩的归档）
tar -rf archive.tar newfile.txt
```

> 💡 **永远先 `-t` 后 `-x`！** 解压前用 `-t` 看一眼归档里有什么，防止解压出一堆文件覆盖当前目录。有些恶意或粗心的 tar 包会把文件解压到奇怪的位置。

---

### 轴 2：压缩轴——"用什么压缩算法？"

> 场景：你创建一个备份，要在体积和速度之间取舍。

```bash
tar -czf archive.tar.gz dir/     # gzip：速度快，体积适中（最常用）
tar -cjf archive.tar.bz2 dir/    # bzip2：体积更小，速度较慢
tar -cJf archive.tar.xz dir/     # xz：体积最小，速度最慢
```

> 💡 现代 tar 解压时能自动检测压缩格式——`tar -xf archive.tar.gz` 和 `tar -xf archive.tar.bz2` 都可以（不需要 `-z` 和 `-j`）。但创建时必须指定压缩格式。

---

### 轴 3：输出轴——"解压到哪里？要不要看过程？"

> 场景：解压到指定目录，而不是当前目录；或者想看解压了哪些文件。

```bash
tar -xvf archive.tar.gz         # -v：显示每个文件（看过程）
tar -xf archive.tar.gz -C /opt  # -C：解压到 /opt 而不是当前目录
tar -czvf archive.tar.gz dir/   # -v：创建时也显示文件列表
```

---

### 轴 4：过滤轴——"哪些文件不要？"

> 场景：打包整个项目但不包含 `node_modules` 和 `.git`。

```bash
tar -czf project.tar.gz --exclude='node_modules' --exclude='.git' project/
tar -czf backup.tar.gz --exclude='*.log' --exclude='*.tmp' /var/log/
```

> 💡 `--exclude` 的模式匹配的是文件路径中的任意部分，不是完整路径也不是文件名。`--exclude='*.log'` 会排除任意目录下的 `.log` 文件。

## 五、Pipeline 组合——tar 是管道的最佳输入/输出

tar 可以输出到 stdout（默认）或从 stdin 读取，这让它成为管道的一员：

```bash
# 远程复制：tar + ssh——不用 scp，直接流式传输
tar -czf - dir/ | ssh user@host 'tar -xzf - -C /target'

# 跨服务器复制并排除文件
tar -czf - --exclude='*.log' dir/ | ssh user@host 'tar -xzf - -C /backup'
```

> 💡 这里的 `-f -` 表示"归档文件是 stdin/stdout"。tar 写到 stdout 就是字节流，可以被管道传给任何东西——ssh、netcat、或者另一个 tar。**这比先 scp 再解压快，因为省了一次磁盘 IO，而且是边压缩边传输的流式处理。**

## 六、真实排障全流程复盘

> 场景：收到一个 `backup-2024.tar.gz`，想安全地解压到 `/opt/restore`。

**第一步：查看内容——里面有什么？**
```bash
tar -tzf backup-2024.tar.gz
```

**第二步：确认路径——会解压到哪里？**
```bash
tar -tzf backup-2024.tar.gz | head -20
```
看文件路径是不是相对路径（`./data/...`），如果是绝对路径（`/etc/...`），解压会覆盖系统文件！

**第三步：解压到独立目录**
```bash
mkdir -p /opt/restore
tar -xzf backup-2024.tar.gz -C /opt/restore
```

> 整个过程依赖 `-t`（安全预览）→ `-C`（指定目录）→ `-x`（解压），没有一步是盲操作。

## 七、踩坑清单

- **坑一：`-f` 不紧跟文件名** → `-cfv archive.tar` 是错的，`-cvf archive.tar` 才是对的。`-f` 吃紧后面的词。
- **坑二：解压前不 `-t` 预览** → 可能覆盖现有文件、解压到奇怪路径。永远先 `-t`。
- **坑三：`--exclude` 的模式匹配规则和直觉不同** → 它匹配路径中任意部分，不是完整路径。`--exclude='*.log'` 会影响所有子目录。
- **坑四：创建时用了绝对路径** → `tar -cf /backup.tar /etc/nginx` 会把 `/etc/nginx` 存成绝对路径，解压时直接覆盖系统文件。用 `-C` 切换目录：`tar -cf backup.tar -C /etc nginx`。
- **坑五：混淆了压缩格式的字母** → `-z`=gzip, `-j`=bzip2, `-J`=xz。小写 z 是大写 J 的单胞胎哥哥——记法：g**z**ip, b**j**p2, **J** 是大写 = 最厉害的压缩。

## 八、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 打包目录、解压归档 | tar | tar 的标准领域 |
| 只压缩单个文件 | `gzip` / `bzip2` / `xz` | tar 去掉了归档层，更轻量 |
| 增量备份、同步目录 | `rsync` | rsync 只传差异，不是全量打包 |
| 查看 zip 文件 | `unzip -l` | tar 不支持 zip 创建，但 BSD tar 可以解压 zip |
| 加密归档 | `gpg` + `tar` | tar 本身不加密，管道给 gpg |

## 九、换个命令你会了吗？

tar 属于**骨架模式 B**：`模式 + 对象`。同一模式的命令还有：

- **grep**：`grep 选项 模式 文件`——和 `tar 动作 选项 文件` 同构
- **rsync**：`rsync 选项 源 目标`——多了方向维度，但句型一致

学完 tar，你会发现很多"模式 + 对象"的命令都是同一套思维方式：先选动作，再指定参数，最后给操作对象。

---

> **核心观点：** 学 tar 不是为了背 `-xzf` 这个"咒语"，而是理解它的 **4 个能力轴**（动作、压缩、输出、过滤）和**每个字母回答什么问题**。一旦理解 `-x`=解压、`-z`=gzip、`-f`=文件名，`tar -xjf`(解压 bzip2) 和 `tar -cJf`(创建 xz) 都可以自己推导出来。
>
> 你平时用 tar，每次是不是都要查一下那个字母组合？
