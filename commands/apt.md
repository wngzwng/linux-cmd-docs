
# apt：Debian/Ubuntu 包管理——`purge` vs `remove`、`autoremove` 清理依赖

`apt install` 和 `apt update` 已经刻在了每个 Ubuntu 用户的肌肉记忆里。但 apt 身上还有几个你每天都能用到但可能不知道的能力——比如 `apt list --upgradable`、`apt purge`、`apt autoremove`。

这篇文章不讲基础用法，只讲那些能让你更高效、更安全地管理包的技巧。

---

## 核心概念：apt vs apt-get vs dpkg

| 命令 | 层级 | 用途 |
|------|------|------|
| `apt` | 高层（推荐） | 日常使用，输出友好，有进度条 |
| `apt-get` | 底层 | 脚本中使用，行为稳定不轻易变 |
| `dpkg` | 最底层 | 直接操作 .deb 包 |

> 💡 2014 年后，日常使用优先用 `apt` 而不是 `apt-get`。`apt` 提供了进度条、颜色、更友好的输出。但写脚本时仍用 `apt-get`——它的行为更可预测。

---

## 核心命令速查

### 安装与更新

```bash
sudo apt update                          # 更新本地包索引（必须！）
sudo apt upgrade                         # 升级所有已装包
sudo apt full-upgrade                    # 更彻底的升级（可删除冲突包）
sudo apt install nginx                   # 安装
sudo apt install nginx=1.18.0-0ubuntu1   # 安装指定版本
```

### 卸载

```bash
sudo apt remove nginx                    # 卸载（保留配置文件）
sudo apt purge nginx                     # 彻底卸载（含配置文件）
sudo apt autoremove                      # 删除不再需要的依赖
```

### 搜索与信息

```bash
apt search keyword                       # 搜索包
apt show nginx                           # 查看包详细信息
apt list --installed                     # 列出已装包
apt list --upgradable                    # 列出可升级的包
apt policy nginx                         # 查看已装版本和可用版本
```

---

## 场景驱动

### 1. 安全升级：先看要升什么

```bash
# 第一步：看看有哪些可升级的
apt list --upgradable

# 第二步：看一个关键包的升级详情
apt changelog openssl   # 看变更日志
apt show openssl        # 看版本号

# 第三步：升级（可以只升指定包）
sudo apt install --only-upgrade openssl
```

### 2. 彻底清理软件

```bash
# 不只用 remove，而是三步彻底清理
sudo apt purge nginx           # 卸载 + 删除配置
sudo apt autoremove            # 删依赖
sudo apt autoclean             # 清理下载的 .deb 缓存
```

### 3. 装包失败：修复依赖

```bash
# 依赖关系出问题时的救命命令
sudo apt --fix-broken install
# 它会尝试自动修复依赖问题
```

### 4. 查找某个文件属于哪个包

```bash
# 需要知道 /etc/nginx/nginx.conf 是谁装的
dpkg -S /etc/nginx/nginx.conf
# nginx-common: /etc/nginx/nginx.conf

# 或者反过来：看一个包装了哪些文件
dpkg -L nginx
```

---

## 新手踩坑总结

- **坑一：`apt update` 忘记 sudo。** 更新索引需要 root 权限，但忘了也不会有明显报错。
- **坑二：`apt autoremove` 可能删掉你还在用的包。** 有些包被标记为"自动安装的依赖"，但你可能手动在用它。检查列出的包再确认。
- **坑三：`apt remove` 不删配置文件。** 彻底清理用 `apt purge`。
- **坑四：混用 apt 和 apt-get。** 日常用 apt，脚本用 apt-get——避免混用导致行为不一致。
- **坑五：从不明 PPA 源装包。** PPA 是第三方源，安全无保证。只加你信任的源。

---

## 最后

apt 让你在 Debian/Ubuntu 系上管理软件像使用应用商店一样简单。但它的真正价值不在于"安装"，而在于"管理"——你知道自己装了哪些包、哪些可以升级、哪些可以清理。
