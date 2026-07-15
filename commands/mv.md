
# mv：移动还是重命名？同一文件系统内它只改一个标签

mv 可能是 Linux 里"使用频率最高、理解深度最浅"的命令之一。你知道 `mv old new` 是重命名，`mv file /tmp/` 是移动。但如果问你："mv 移动文件时，文件的实际数据在磁盘上动了吗？"大部分人会愣住。

更致命的是，mv 和 cp 有一个关键区别大多数人没意识到：**mv 移动文件后，原路径的文件就不在了——没有"撤销"，没有回收站。** 一旦 mv 覆盖了一个同名文件，原文件就永远消失。

---

## 场景引入：那个让你心跳加速的瞬间

你正在整理项目文件：

```bash
mv config.yml config.yaml
```

回车之后你突然发现：当前目录下已经有一个 `config.yaml`——是上周备份的旧版本。现在它被你刚改完的 `config.yml` 无声无息地覆盖了。

你没看到任何提示。没有任何确认。文件系统只是照做了。

如果你敲的是：

```bash
mv -i config.yml config.yaml
# mv: overwrite 'config.yaml'? (y/n)
```

它会问你一下。那个弹窗就是你最后的后悔药。

---

## 核心概念：mv 只改目录条目，不搬数据

mv 的核心逻辑：**修改文件系统里一个文件名的指向**。它不复制数据块（除非跨文件系统）。

```
同一个文件系统内：
mv /data/a.txt /data/b.txt
→ 只是把目录条目从 "a.txt" 改成 "b.txt"
→ 数据块在原地，根本没动过
→ 所以 mv 一个 1GB 的文件只要一瞬间

跨文件系统：
mv /data/a.txt /mnt/usb/a.txt
→ 等价于 cp + rm
→ 数据被实际复制到新文件系统，然后原文件删除
→ 时间取决于文件大小
```

> 💡 这就是为什么 `mv` 同分区内移动大文件飞快，而 `cp` 永远要等——mv 只是改标签，cp 要真的抄一遍数据。

---

## 先排雷：mv 覆盖是无提示的

```bash
# 危险做法
mv new_config.yml /etc/myapp/config.yml
# 如果 /etc/myapp/config.yml 已存在，直接覆盖，无声无息

# 安全做法
mv -i new_config.yml /etc/myapp/config.yml
# 覆盖前提示确认

# 更安全的做法：绝不允许覆盖
mv -n new_config.yml /etc/myapp/config.yml
# 如果目标已存在，直接跳过（不覆盖）

# 备份式做法：覆盖前自动备份
mv -b new_config.yml /etc/myapp/config.yml
# 原有文件会被自动重命名为 config.yml~
```

> ⚠️ 建议：**把 `alias mv='mv -i'` 写进你的 `.bashrc`。** 半秒钟的确认能在你需要的时候救你一命。

---

## 核心能力逐层拆解

### 1. 重命名

```bash
mv old_name.txt new_name.txt       # 简单的重命名
mv old_name.txt ../new_name.txt    # 重命名并移动到上级目录
```

### 2. 移动

```bash
mv file.txt /tmp/                  # 移动单个文件
mv file1.txt file2.txt /tmp/       # 移动多个文件到同一个目标目录
mv *.log /var/log/archive/         # 移动所有 .log 文件
```

### 3. 移动整个目录

```bash
mv dir/ /tmp/                      # 移动目录——不需要 -r（和 cp 不一样！）
mv -v dir/ /tmp/                   # 显示过程
```

> ⚠️ 注意：mv 移动目录**不需要 `-r`**，这是和 `cp`、`rm` 最大的语法差异之一。`cp -r dir/ /tmp/` 但 `mv dir/ /tmp/`。

### 4. 安全选项

```bash
mv -i source dest     # 覆盖前询问（interactive）
mv -n source dest     # 不覆盖已存在的文件（no-clobber）
mv -b source dest     # 覆盖前备份原文件（backup）
mv -u source dest     # 仅当源文件比目标文件新，或目标不存在时才移动（update）
```

### 5. 显示过程 `-v`

```bash
mv -v *.txt /tmp/
# 输出：
# file1.txt -> /tmp/file1.txt
# file2.txt -> /tmp/file2.txt
```

在脚本里加 `-v`，让你看到 mv 实际做了什么——出了问题时能追溯。

---

## 场景驱动

### 1. 批量重命名：给文件加后缀

```bash
# 把所有 .txt 改成 .txt.bak
for f in *.txt; do
  mv "$f" "${f}.bak"
done
```

> ⚠️ 注意：`for f in *.txt` 中，如果文件名包含空格，不加双引号会出错。养成 `"$f"` 加引号的习惯。

### 2. 移动并保证不覆盖

```bash
# 把 .conf 文件移到 /etc，但不覆盖任何已存在的配置
mv -nv *.conf /etc/myapp/
# -n：目标已存在就跳过
# -v：告诉我哪个跳过了、哪个移动了
```

### 3. 只在源文件更新时才覆盖

```bash
# 把缓存目录里的文件同步到主目录，只覆盖旧的
mv -u /tmp/build/*.o ./obj/
# -u：如果目标比源更新，不覆盖
```

### 4. 安全替换关键配置文件

```bash
# 三步法：备份 → 移动 → 验证
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%Y%m%d)
mv -i nginx.conf.new /etc/nginx/nginx.conf
nginx -t             # 测试配置是否正确
```

---

## 新手踩坑总结

- **坑一：mv 覆盖不提示。** 没有任何 undo。养成 `-i` 或 alias 的习惯。
- **坑二：以为 mv 目录需要 `-r`。** 不需要。mv 直接移动目录，`cp` 和 `rm` 才需要 `-r`。
- **坑三：mv 跨文件系统就是 cp + rm。** 移动大文件到 U 盘会等很久——不是 mv 慢了，是它在复制数据。
- **坑四：`mv dir1 dir2` 的行为取决于 dir2 是否存在。** dir2 不存在 → dir1 重命名为 dir2。dir2 存在 → dir1 移入 dir2。搞混了会得到意料之外的目录结构。
- **坑五：文件名含空格时不用引号。** `mv $f /tmp/` 会把带空格的文件名拆成多个参数，结果完全不对。

---

## 什么时候换工具

| 需求 | mv 行不行 | 替代方案 |
|------|----------|---------|
| 移动/重命名文件 | 行 | — |
| 批量按规则重命名 | 不便 | `rename`（perl 版）或 `mmv` |
| 移动并保留原文件 | 行（配合 cp） | `cp` 然后删原文件 |
| 跨主机移动文件 | 不行 | `scp` 或 `rsync` |
| 安全替换（带备份） | 行（`-b`） | 手动 cp 备份更可控 |

---

## 最后

mv 是那种"简单到没人愿意读文档"的命令。但越简单的命令，犯错的代价越高——rm 删错了还能用数据恢复工具碰碰运气，mv 覆盖错了，原文件就没了。

`-i`、`-n`、`-b` 三个选项，选一个成为你的肌肉记忆。花半秒钟敲一个 `-i`，比花半天恢复数据划算得多。
