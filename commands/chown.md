
# chown："Permission denied" 的终极解法——但用错了比不用更危险

如果你部署了一个 Web 应用，访问时看到 "Permission denied"，八成是文件所有者不对。Nginx 用 `www-data` 用户运行，但你的文件所有者是 `root`——它读不了。

解决方案就一条：`chown`。但 chown 有两个极端：**不够用（忘加 -R）和用过头（给整个系统改了所有者）。** 这篇文章讲怎么在正确的范围内使用它。

---

## 场景引入：部署后网站 403

你把网站文件上传到 `/var/www/mysite/`，配置了 Nginx，访问却返回 403 Forbidden。

查日志：

```
nginx: [error] open() "/var/www/mysite/index.html" failed (13: Permission denied)
```

看一下文件权限：

```bash
ls -la /var/www/mysite/
# -rw------- 1 root root 1024 Jul 13 10:00 index.html
```

问题一目了然：文件所有者是 `root:root`，权限 `600`——只有 root 能读。Nginx 以 `www-data` 用户运行，根本没有读取权限。

```bash
# 修复：把所有者改为 www-data
chown www-data:www-data /var/www/mysite/index.html
```

---

## 核心概念：文件属于谁，谁说了算

chown 的核心逻辑：**修改文件的所有者（user）和所属组（group）。** 它是 Linux 权限体系的三根支柱之一（chmod、chown、chgrp）。

chown 的语法：

```bash
chown [用户] 文件               # 只改所有者
chown [用户]:[组] 文件          # 同时改所有者和组
chown :[组] 文件                # 只改组（等价于 chgrp）
```

> ⚠️ 注意：只有 root 能执行 chown。普通用户不能把文件"送给"别人（除非系统启用了 POSIX capabilities）。

---

## 先排雷：`chown -R` 的杀伤半径

```bash
# ⚠️ 极度危险：递归改整个根文件系统
chown -R user:group /

# ⚠️ 也很危险：递归改 /etc——系统可能无法启动
chown -R user:group /etc/
```

`chown -R` 会把目录下所有文件和子目录的所有者全部改掉——包括那些必须属于 root 的系统文件。

> 💡 **每次用 `chown -R` 之前，先确认你在哪个目录：`pwd`，再确认你要改的范围：`ls -la`。** 和在 `rm -rf` 前面的安全习惯一样。

---

## 核心能力逐层拆解

### 1. 改所有者

```bash
chown alice file.txt                     # 把 file.txt 的所有者改为 alice
chown alice file1.txt file2.txt          # 一次改多个文件
```

### 2. 同时改所有者和组

```bash
chown alice:developers file.txt          # 所有者为 alice，组为 developers
chown alice:alice file.txt               # 所有者和组都改为 alice（常见）
```

### 3. 只改组

```bash
chown :developers file.txt               # 只改所属组
# 等价于
chgrp developers file.txt
```

### 4. 递归修改 `-R`

```bash
chown -R www-data:www-data /var/www/mysite/
# 把目录及其所有内容的所有者都改为 www-data
```

> ⚠️ 注意符号链接：`chown -R` 默认**不穿越符号链接**（安全）。如果符号链接指向系统关键文件（如 `/etc/passwd`），不加处理不会误改。

### 5. 从参考文件复制所有权 `--reference`

```bash
chown --reference=template.txt target.txt
# target.txt 的所有者和组变得和 template.txt 一模一样
```

这在批量操作时非常有用——先手动设置好一个文件的权限，然后"复制"到其他文件。

---

## 场景驱动

### 1. 修复 Web 应用权限

```bash
# Web 应用标准权限设置
chown -R www-data:www-data /var/www/mysite/
find /var/www/mysite/ -type d -exec chmod 755 {} \;
find /var/www/mysite/ -type f -exec chmod 644 {} \;
# 目录 755，文件 644，所有者 www-data——标准姿势
```

### 2. 用户搬家：把文件从 alice 移交给 bob

```bash
# alice 离职，bob 接手她的项目文件
chown -R bob:developers /home/alice/projects/
# 但注意 alice 的私有文件（如 .ssh）不要动！
```

### 3. 外接硬盘/移动存储的所有权

```bash
# U 盘挂载后文件可能全是 root，普通用户写不进去
chown -R $USER:$USER /media/usb-drive/
# $USER 是当前登录用户的用户名
```

### 4. 批量修复文件组

```bash
# 把某个目录下所有文件改到 shared 组，以便团队协作
chown -R :shared /opt/team-project/
find /opt/team-project/ -type d -exec chmod 2770 {} \;
# 2770 = setgid + rwxrwx---，新建文件自动继承 shared 组
```

---

## 新手踩坑总结

- **坑一：用 `chown -R` 时不确认路径。** 和 `rm -rf` 一样，先 `pwd && ls -la` 再执行。
- **坑二：只改了文件没改目录。** 文件所有者对了但父目录不可访问，还是 Permission denied。目录需要 `x` 权限才能进入。
- **坑三：普通用户执行 chown 失败。** 只有 root 能改所有者，这是安全设计。需要改权限找管理员。
- **坑四：改了 `/etc` 或 `/usr` 下的系统文件所有者。** 很多系统工具要求特定文件属于 root，改了可能导致系统异常。
- **坑五：以为改了所有者就能访问。** 改了所有者但权限还是 000，一样读不了。权限 = 所有者 + 权限位。

---

## chown / chmod / chgrp 三者关系

| 命令 | 改什么 | 谁可以执行 |
|------|--------|-----------|
| `chown` | 文件所有者（和组） | 仅 root |
| `chgrp` | 文件所属组 | 文件所有者（限于自己所在的组） |
| `chmod` | 文件的读/写/执行权限 | 文件所有者 + root |

---

## 最后

chown 是 Linux 权限系统里"最有力也最危险"的一环。chmod 改错了还能改回来，chown 改错了一般也能改回来——但如果你 `chown -R` 了整个 `/etc`，改回来的过程会非常痛苦（你甚至不一定记得每个文件原来的所有者是谁）。

用 chown 的原则只有一个：**精确到文件或目录，不滥用 `-R`，用之前先 `ls -la`。**
