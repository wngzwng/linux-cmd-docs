# cd：不只是"进目录"——`cd -` 和 `cd ~` 才是日常主力

> `cd` 只有三个字母。但它的机制——工作目录、相对路径、`cd -`、`CDPATH`——藏着很多新人不知道的秘密。这个命令不需要学，只需要纠正三个认知盲区。

## 一、语法骨架

```
cd  [目录]
    ──┬──
     去哪？不写 = 回家目录（$HOME）
```

cd 是 shell 内建命令（不是外部程序），因为它必须改变当前 shell 的工作目录——外部程序做不到这一点。这解释了为什么 `cd /tmp` 不能在 shell 脚本里影响父 shell 的目录。

## 二、核心用法——5 个场景覆盖全部

### 场景 1：回家

```bash
cd              # 回到 $HOME
cd ~            # 等价
cd ~username    # 去 username 的家目录
```

### 场景 2：回到上次的目录

```bash
cd -            # 在最近两个目录之间切换
```

> 💡 `cd -` 是最被低估的技巧——你频繁在两个目录之间来回时，不需要重新敲完整路径。它内部用了 `$OLDPWD` 环境变量。

### 场景 3：各种路径写法

```bash
cd /var/log           # 绝对路径
cd ../../src          # 相对路径：往上两级再进 src
cd ./config           # 当前目录下的 config（./ 可以省略）
cd -P /symlink/dir    # 不跟随符号链接（进入物理路径）
```

### 场景 4：CDPATH——你不需要切到目录才能用它的命令

```bash
# 在 ~/.bashrc 里设置：
export CDPATH=.:~/projects:~/work

# 之后在任何目录下，直接 cd 到 projects 的子目录
cd myproject    # 如果 ./myproject 不存在，会尝试 ~/projects/myproject
```

> ⚠️ CDPATH 很方便，但它的行为容易误解——`cd myproject` 会先在当前目录找 `myproject`（因为 CDPATH 里的 `.`），找不到才去其他路径找。而且成功后 shell 会打印实际进入的目录路径。

### 场景 5：pushd / popd——当 cd - 不够用

```bash
pushd /var/log    # 记录当前位置，然后去 /var/log
pushd /etc        # 再记录，再去 /etc
dirs -v           # 查看目录栈
popd              # 回到上一个 pushd 的位置
popd              # 再弹一个
```

> 💡 需要在三个以上目录间跳转时，pushd/popd 比 cd 来回敲高效得多。它是内置的"面包屑导航"。

## 三、踩坑清单

- **坑一：`cd` 在脚本里改了目录不影响父 shell** → 这是 shell 的设计机制——每个脚本在子进程中运行。要在当前 shell 改目录，用 `source script.sh` 或 `. script.sh`（或者在函数里用 cd）。
- **坑二：`cd /some/path` 不检查是否成功** → 脚本里永远 `cd /some/path || exit 1`，否则后续命令可能在你没预料到的目录下执行（生产事故的常见源头）。
- **坑三：`cd -` 在不同 shell 间不共享** → 每次新开终端，`cd -` 的历史是独立的。它依赖当前 shell 的 `$OLDPWD`。
- **坑四：CDPATH 让 `cd` 的输出变多** → CDPATH 命中时 shell 会打印实际路径。如果你在脚本里用 cd 且输出被重定向，这多出来的一行可能干扰解析。脚本里用 `cd /absolute/path` 不用 CDPATH。

## 四、换个命令你会了吗？

cd 是基础的"状态切换"命令——改变当前工作目录。同一类 shell 内建命令还有 **pushd/popd**（目录栈）、**dirs**（查看目录栈），它们共享同一个"工作目录上下文"的概念。

---

> **核心观点：** `cd` 不需要"学"——它只有三个字母。需要理解的是三个概念：**路径写法**（绝对/相对/~）、**shell 子进程机制**（脚本里 cd 不影响父进程）、**cd - 和 pushd 的导航模型**。这三个概念懂了，cd 就不会再踩坑。
