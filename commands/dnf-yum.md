
# dnf / yum：Fedora/RHEL/CentOS 上的包管理——以及 yum 为什么该退休了

如果你用的是 Fedora、RHEL、CentOS、Rocky Linux、AlmaLinux——你用的包管理器叫 `dnf`（或它的前身 `yum`）。

`yum` 在 RHEL 7 / CentOS 7 及之前是标准，但它的依赖解析慢、代码老旧。从 RHEL 8 / CentOS 8 开始，`dnf` 取代了 `yum`。两者的命令几乎一模一样——你甚至可以在新系统上打 `yum`，它会被自动重定向到 `dnf`。

---

## 核心概念：dnf = 新一代 yum

| | yum | dnf |
|---|---|---|
| 出现时间 | 2003 | 2015 |
| 依赖解析 | 较慢（Python 2） | 更快（Python 3 + libsolv） |
| 语法兼容 | — | 和 yum 几乎一致 |
| 状态 | RHEL 7 及之前的默认 | RHEL 8+ 的默认 |

> 💡 如果你还在用 `yum`，现在是迁移到 `dnf` 的时机——语法几乎不变，但更快更可靠。

---

## 核心命令速查

```bash
# 更新
sudo dnf update                         # 升级所有包
sudo dnf check-update                   # 列出可升级包（不执行升级）

# 安装
sudo dnf install nginx                  # 安装
sudo dnf install nginx-1.20.1           # 安装指定版本

# 卸载
sudo dnf remove nginx                   # 卸载
sudo dnf autoremove                     # 删除孤儿依赖

# 搜索
dnf search keyword                      # 搜索包
dnf info nginx                          # 包详情
dnf list installed                      # 已装包
dnf list available                      # 可用包

# 仓库
dnf repolist                            # 查看启用的仓库
dnf repolist all                        # 查看所有仓库（含禁用的）

# 历史（dnf 的杀手特性）
dnf history                             # 查看安装/卸载历史
dnf history undo 42                     # 回退第 42 次操作
dnf history info 42                     # 看第 42 次操作的详情
```

---

## 场景驱动

### 1. 装包装坏了：回退

```bash
# 某人装了一堆包，系统出了问题
dnf history
# ID | Command line             | Date and time    | Action
# 42 | install some-bad-pkg     | 2025-07-13 14:30 | Install

# 回退到装之前的干净状态
sudo dnf history undo 42
```

> 💡 **`dnf history` 是 dnf 最被低估的功能——它记录了每一次安装/升级/卸载操作，而且可以回退。** yum 也有 `yum history`，但 dnf 的更好用。

### 2. 查某个文件是哪个包装的

```bash
# 想知道 /etc/nginx/nginx.conf 属于哪个包
rpm -qf /etc/nginx/nginx.conf
# nginx-1.20.1-1.el8.x86_64

# 看一个包装了哪些文件
rpm -ql nginx
```

### 3. 启用 EPEL 仓库（获取更多包）

```bash
# RHEL/CentOS 的默认仓库包不多，EPEL 是必需品
sudo dnf install epel-release
# 此后可用包数量大幅增加
```

### 4. 仅下载不安装

```bash
# 下载 .rpm 文件到本地（离线安装用）
dnf download nginx --destdir=/tmp/rpms/
# 下载并包含所有依赖
dnf download nginx --resolve --destdir=/tmp/rpms/
```

---

## 新手踩坑总结

- **坑一：在新系统上坚持用 `yum`。** RHEL 8+ 已经替换为 dnf。`yum` 只是别名，底层调的还是 dnf。
- **坑二：`dnf update` 和 `dnf upgrade` 几乎一样。** dnf 把两者合并了（yum 时代有细微差异）。
- **坑三：只装包不更新索引。** dnf 自动处理缓存更新，但偶尔需要手动 `dnf makecache`。
- **坑四：不知道 `dnf history undo`。** 装错了包不是只能手动卸载——dnf 可以精确回退到安装之前的状态。

---

## apt vs dnf 命令对照（从 Ubuntu 转过来的速查）

| 操作 | apt (Debian/Ubuntu) | dnf (RHEL/Fedora) |
|------|---------------------|-------------------|
| 更新索引 | `apt update` | `dnf check-update`（或自动） |
| 升级所有包 | `apt upgrade` | `dnf update` / `dnf upgrade` |
| 安装 | `apt install <pkg>` | `dnf install <pkg>` |
| 卸载 | `apt remove <pkg>` | `dnf remove <pkg>` |
| 搜索 | `apt search <kw>` | `dnf search <kw>` |
| 清理 | `apt autoremove` | `dnf autoremove` |
| 历史回退 | ❌ | ✅ `dnf history undo` |

---

## 最后

dnf 是 Red Hat 系的现代包管理器——更快、更聪明、自带操作回退。如果你还习惯性地敲 `yum`，不妨试试 `dnf`——命令不变，体验更好。
