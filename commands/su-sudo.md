# su + sudo：切换身份的正确姿势

> `su` 和 `sudo` 都是切换用户身份的命令，但它们的机制完全不同。大多数人的困惑在于：什么时候用 `su`，什么时候用 `sudo`？`sudo su -` 又是什么意思？

## su：切换用户（Substitute User）

```bash
su              # 切换到 root（保持当前环境变量和目录）
su -            # 切换到 root（模拟完整登录——加载 root 的环境变量、HOME、SHELL）
su - username   # 切换到 username（完整登录）
su username     # 切换到 username（仅切换用户，保持当前环境）
```

> ⚠️ **`su` 和 `su -` 的区别是新人最常踩的坑。** 不带 `-` 时，你保留了当前用户的 PATH——`/usr/local/bin` 可能不在 root 的 PATH 里，命令找不到。带 `-` 时相当于用目标用户重新登录，环境是干净的。**日常用 `su -`。**

## sudo：以另一个用户身份执行命令（SuperUser Do）

```bash
sudo command            # 以 root 身份执行一个命令
sudo -u username cmd    # 以 username 身份执行
sudo -i                 # 启动一个 root 登录 shell（等同于 su -）
sudo -s                 # 启动一个 root shell（不加载环境，等同于 su）
sudo -l                 # 列出当前用户可以执行哪些 sudo 命令
sudo !!                 # 以 sudo 重新执行上一条命令（最常用的 sudo 技巧）
```

## su vs sudo：一张表说清

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 执行一条特权命令 | `sudo cmd` | 不需要知道 root 密码，只用自己的密码 |
| 切换到 root 做很多事情 | `sudo -i` | 等同于 `su -`，但用自己的密码 + 有审计日志 |
| 切换到其他用户 | `sudo -u user cmd` | su 需要知道目标用户密码，sudo 不需要 |
| root 被禁用的系统（Ubuntu） | sudo | Ubuntu 默认没有 root 密码，只能用 sudo |
| 老系统/无 sudo 的容器 | `su -` | sudo 可能不存在 |

## 核心原理

```
su    → 需要目标用户的密码（su root 需要 root 密码）
sudo  → 用自己的密码（或免密码），通过 /etc/sudoers 控制权限
       每次 sudo 执行都记录在 /var/log/auth.log 里（审计！）
```

## 踩坑清单

- **坑一：`sudo su` 是多此一举** → `sudo su -` = `sudo -i`。后者更简洁、更快、日志更清晰。
- **坑二：`su` 需要知道 root 密码** → 共享 root 密码是安全大忌。团队里用 sudo + sudoers 配置权限（按人限命令），不要共享 root 密码。
- **坑三：脚本里用 `sudo`，密码提示可能卡住** → CI/CD 里配置 `NOPASSWD` 或确保交互式终端存在。
- **坑四：`visudo` 编辑 `/etc/sudoers`，不要直接 `vim`** → `visudo` 会在保存前检查语法错误——一个语法错误可能让 sudo 完全失效。

---

> **核心观点：** `su` 是"成为另一个人"，`sudo` 是"以另一个人的身份做一件事"。现代 Linux 推荐 sudo：审计日志 + 细粒度权限 + 不需要共享 root 密码。
