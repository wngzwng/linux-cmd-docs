
# zip / unzip：Linux 管理员不想用，但同事非要发 .zip 文件给你

在 Linux 世界，压缩的标准是 tar.gz。但现实是：非技术同事用的都是 Windows/macOS，他们只会右键 → 压缩为 .zip。如果你的工作流需要和"外面的世界"打交道，zip/unzip 是你绕不过去的。

好消息：它比 tar 简单得多。坏消息：它有个 Linux 文件权限的坑。

---

## 场景引入：同事发来的 .zip 在服务器上解压后权限全是乱的

你从同事那里收到 `project.zip`，用 `unzip` 解压到服务器上准备部署：

```bash
unzip project.zip -d /var/www/
# 解压完成，但所有文件权限全是乱的
# 可执行脚本没了 x 权限，目录权限也不对
```

问题在于：**.zip 格式不完整保留 Linux 文件权限。** 它最初是为 Windows/DOS 设计的，只管文件内容，不管 `chmod` 那套东西。解压后你需要手动修复权限。

---

## 核心概念：zip 是跨平台格式，不是 Linux 原生

| 特性 | tar.gz | zip |
|------|--------|-----|
| Linux 权限 | ✅ 完整保留 | ❌ 部分保留 |
| 压缩率 | 中 | 中 |
| Windows 原生支持 | ❌ | ✅ |
| macOS 原生支持 | ❌ | ✅ |
| 可单独提取某个文件 | ❌ 需全部解压 | ✅ |

> 💡 经验法则：**内部流转用 tar.gz，需要发给非技术同事用 zip。**

---

## 核心参数

### zip：压缩

```bash
zip archive.zip file1 file2           # 压缩多个文件
zip -r archive.zip dir/               # 递归压缩目录（⚠️ 必须加 -r！）
zip -r archive.zip dir/ -x "*.log"    # 排除 .log 文件
zip -r -9 archive.zip dir/            # 最高压缩率（0-9，默认 6）
zip -e archive.zip file.txt           # 加密压缩（会提示输密码）
zip -r archive.zip dir/ --symlinks    # 保留软链接（默认会追随链接）
```

### unzip：解压

```bash
unzip archive.zip                     # 解压到当前目录
unzip archive.zip -d /target/path/    # 解压到指定目录
unzip -l archive.zip                  # 只看内容，不解压（重要！）
unzip -o archive.zip                  # 覆盖已存在的文件（不提示）
unzip -n archive.zip                  # 不覆盖已存在的文件
```

---

## 场景驱动

### 1. 发给 Windows/Mac 同事

```bash
# 把项目打包成 zip
zip -r project.zip project/ -x "*.log" "node_modules/*" ".git/*"
# 同事在 Windows 上右键解压就能用
```

### 2. 接收外部文件：解压前先预览

```bash
# 先看看里面有什么（不解压）——安全习惯
unzip -l received.zip
# 确认没有奇怪的路径、没有不该有的文件
# 再解压
unzip received.zip -d /tmp/incoming/
```

> ⚠️ **安全警告：不要直接 `unzip` 到重要目录！** 先 `unzip -l` 检查内容，确认没有 `../../etc/passwd` 之类的路径穿越攻击。

### 3. 批量压缩多个独立文件

```bash
# 把多个日志文件分别压缩成 .zip
for f in *.log; do
  zip "${f%.log}.zip" "$f"
done
```

### 4. 解压并修复权限

```bash
unzip web-project.zip -d /var/www/
# zip 不保留 Linux 权限，手动修复
find /var/www/ -type d -exec chmod 755 {} \;
find /var/www/ -type f -exec chmod 644 {} \;
```

---

## 新手踩坑总结

- **坑一：`zip dir/` 不递归。** 必须加 `-r`！这和 `tar` 不用加的行为不一样。
- **坑二：直接解压到系统目录。** 先 `unzip -l` 看内容，规避路径穿越攻击。
- **坑三：zip 不完整保留 Linux 权限。** 解压后需要手动 `chmod`。
- **坑四：zip 压缩中文文件名可能乱码。** zip 格式的老问题是编码处理不一致——跨平台尤其是 Windows ↔ Linux 之间。

---

## 什么时候换工具

| 需求 | zip 行不行 | 替代方案 |
|------|----------|---------|
| 发给 Windows/Mac 用户 | ✅ 首选 | — |
| Linux 内部备份 | 不推荐 | `tar -czf` |
| 需要完整保留权限 | 不行 | `tar -czf` 或 `tar -cJf` |
| 加密压缩 | 行（`-e`） | `gpg` 更安全 |

---

## 最后

zip 不是 Linux 的原生格式，但它是"和外面的世界交流"的通用语言。你不必喜欢它，但你需要会用它。记住两条：压缩目录加 `-r`，解压之前先 `-l`。
