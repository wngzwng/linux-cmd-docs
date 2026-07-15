
# brew：macOS 上"缺失的包管理器"——没装它之前 macOS 的命令行只算半成品

macOS 自带了很多 Unix 命令（BSD 版本），但你很快就会发现两件事：

1. 很多 Linux 上常用的命令 macOS 没有（`wget`、`tree`、`htop`……）
2. macOS 自带的版本和 Linux 行为不一致（`sed -i` 需要空参数，`date -d` 不存在……）

Homebrew 解决的就是这两个问题。它给 macOS 装上 Linux 世界里习以为常的工具，还能装 GNU 版的命令来替代 BSD 版。

---

## 场景引入：在 macOS 上用 Linux 脚本，各种报错

你从 Linux 服务器上拿了一个备份脚本在 Mac 上跑：

```bash
#!/bin/bash
sed -i 's/localhost/prod.example.com/g' config.yml
# macOS 报错：sed: 1: "config.yml": extra characters at the end of l command
```

原因：macOS 的 BSD sed 要求 `-i` 后面必须跟备份后缀名。修法：

```bash
# 装 GNU 版 sed
brew install gnu-sed
# 然后用 gsed 代替 sed
gsed -i 's/localhost/prod.example.com/g' config.yml
```

Homebrew 不只是装新软件——它还能给你熟悉的 Linux 行为。

---

## 核心概念：brew = macOS 的 apt

Homebrew 是 macOS 上事实上的包管理器。它的设计哲学：

- **公式（formula）**：编译安装的包（`brew install` 默认）
- **桶（cask）**：预编译的 GUI 应用（`brew install --cask`）
- **Coreutils**：GNU 版的 Linux 核心命令合集

---

## 核心命令速查

### 日常高频

```bash
brew install wget               # 安装公式
brew install --cask firefox     # 安装 GUI 应用
brew uninstall wget             # 卸载
brew update                     # 更新 Homebrew 自身
brew upgrade                    # 升级所有已装包
brew upgrade wget               # 升级指定包
brew list                       # 查看已装包
brew info wget                  # 查看包信息
brew search keyword             # 搜索包
```

### 服务管理

```bash
brew services start nginx       # 启动并设为开机自启
brew services stop nginx        # 停止
brew services restart nginx     # 重启
brew services list              # 查看所有服务状态
```

### 系统诊断

```bash
brew doctor                     # 检查 Homebrew 环境问题
brew cleanup                    # 清理旧版本和缓存
brew autoremove                 # 删除不再需要的依赖
```

---

## 场景驱动

### 1. 给 macOS 安装 Linux 基础工具

```bash
# 一键补全 macOS 缺失的常用命令
brew install wget tree htop watch
```

### 2. 安装 GNU 版命令（替代 BSD 版）

```bash
brew install coreutils          # ls → gls, cp → gcp 等
brew install gnu-sed            # sed → gsed
brew install grep               # grep → ggrep (--color=auto 默认开启)
brew install gawk               # awk → gawk

# 如果想把 GNU 版本当默认用：
# 在 ~/.bashrc 或 ~/.zshrc 里
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
```

### 3. 用 brew 管理开发环境

```bash
brew install node               # Node.js
brew install python             # Python
brew install go                 # Go
brew install rust               # Rust
# 版本管理更方便——不需要去各语言官网下载安装包
```

---

## 新手踩坑总结

- **坑一：brew 不是 macOS 自带的。** 需要先安装：[brew.sh](https://brew.sh)。
- **坑二：Intel Mac vs Apple Silicon 安装路径不同。** Intel: `/usr/local/`，Apple Silicon: `/opt/homebrew/`。官方安装脚本自动识别。
- **坑三：`brew install` 和 `brew install --cask` 的区别。** CLI 工具用前者，GUI 应用用后者。
- **坑四：装了 coreutils 但命令还是原来的。** GNU 版默认带 `g` 前缀（如 `gls`），需要手动改 PATH。

---

## 最后

Homebrew 是 macOS 变成"类 Linux 开发环境"的关键一步。如果你在 Mac 上做开发或者运维，装完系统第一件事就应该是装 brew——然后你才有了命令行世界的完整图景。
