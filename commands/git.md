# 为什么 git 很强，但大多数人只用 add/commit/push？

> Git 是版本控制的事实标准。但大多数人只记住了三条命令：`git add .`、`git commit -m 'fix'`、`git push`。出了问题就删仓库重新 clone。其实 Git 是一个内容寻址的文件系统——理解了它的四个区域和指针模型，你就再也不会"先删了重来"。

## 一、你会遇到的场景

某天你改了一半代码，突然被叫去修一个紧急 bug。你不想提交当前的半成品，也不想丢掉这些改动。

新手的做法：`cp -r project project-backup`，手动备份一堆文件夹。

Git 的做法：

```bash
git stash                    # 暂存当前改动，工作区回到干净状态
# ... 切分支修 bug，提交 ...
git stash pop                # 恢复之前的半成品
```

几秒完成，不需要任何手动备份。

**这就是 Git 的核心价值：分布式版本控制——跟踪文件变更历史、支持分支协作、在任何时候可以回到任意历史状态。**

## 二、对象模型——Git 的四个区域

理解这四个区域是理解 Git 的关键：

```
工作目录 (Working Directory)        ← 你正在编辑的文件
    │  git add
    ↓
暂存区 (Staging Area / Index)      ← 下次 commit 会包含的内容
    │  git commit
    ↓
本地仓库 (Local Repository)        ← .git 目录里的完整历史
    │  git push / git fetch
    ↓
远程仓库 (Remote Repository)       ← GitHub / GitLab / 服务器
```

除了四个区域，还有两个关键概念：

```
commit  → SHA-1 哈希值（如 a1b2c3d...）——唯一标识一个快照
branch  → 指向某个 commit 的指针（会移动）
HEAD    → 指向当前分支的指针（你在哪）
tag     → 指向某个 commit 的固定指针（不会移动，用于发布版本）
```

> 💡 **理解了区域模型 + 指针模型，Git 命令就不再是咒语。** `git add` = 工作区→暂存区；`git commit` = 暂存区→本地仓库；`git push` = 本地仓库→远程仓库。每个命令都在移动数据或移动指针。

## 三、核心能力逐轴拆解

Git 的能力沿 5 个轴展开。

| 能力轴 | 问题 | 核心命令 |
|--------|------|---------|
| 快照轴 | 怎么保存/撤销改动？ | `add`、`commit`、`reset`、`stash`、`checkout --` |
| 分支轴 | 怎么并行开发？ | `branch`、`checkout`/`switch`、`merge`、`rebase` |
| 历史轴 | 怎么看发生了什么？ | `log`、`diff`、`show`、`blame` |
| 协作轴 | 怎么和他人同步？ | `push`、`pull`/`fetch`、`remote` |
| 撤销轴 | 怎么"撤回"？ | `reset`、`revert`、`reflog` |

---

### 轴 1：快照轴——"怎么保存当前状态？"

```bash
# 查看哪些文件改了
git status
git diff

# 把改动加入暂存区
git add file.txt
git add -p              # 交互式选择——只暂存部分改动（推荐！）

# 提交
git commit -m "fix: handle edge case in parser"
git commit --amend      # 修改上一次提交（修改 commit message 或补充遗漏的文件）

# 暂存当前改动（不提交，切分支干活）
git stash
git stash pop
git stash list

# 丢弃工作区的改动（⚠️ 不可恢复）
git checkout -- file.txt
# 新版本用：
git restore file.txt
```

> 💡 `git add -p`（patch mode）是被严重低估的功能——它让你选择性地暂存文件里的部分改动，而不是整个文件。一个文件改了两处但只想提交一处？`git add -p`。

---

### 轴 2：分支轴——"怎么并行开发？"

```bash
# 查看分支
git branch              # 本地分支
git branch -a           # 含远程分支

# 创建并切换到新分支
git switch -c feature-x    # 新版语法（推荐）
git checkout -b feature-x  # 旧版语法

# 合并
git switch main
git merge feature-x        # 把 feature-x 合入 main

# Rebase：把当前分支的提交"搬家"到目标分支的最新 commit 之后
git rebase main           # （在 feature 分支上执行）历史更线性

# 删除分支
git branch -d feature-x
```

---

### 轴 3：历史轴——"怎么查发生了什么？"

```bash
# 查看提交历史
git log --oneline --graph --all    # 树形图
git log -p                          # 每次提交的详细 diff
git log --author="Alice"            # 只看某人的提交
git log --since="2 weeks ago"

# 查看某个 commit 的详情
git show a1b2c3d

# 查看谁最后改了某一行
git blame file.txt

# 看某次提交改了什么
git diff a1b2c3d..d4e5f6g
```

---

### 轴 4：协作轴——"怎么和别人同步？"

```bash
# 拉取远程更新（不合并）
git fetch

# 拉取并合并
git pull

# 推送
git push origin main

# 查看远程仓库
git remote -v

# 添加远程仓库
git remote add upstream https://github.com/original/repo.git
```

> 💡 **先 `fetch` 再 `merge`，不要直接 `pull`。** `git pull` = `git fetch` + `git merge`。直接 pull 可能在你不注意的时候产生合并冲突。`fetch` 让你先看看远程有什么变化，再决定怎么处理。

---

### 轴 5：撤销轴——"我搞砸了，怎么回去？"

```bash
# 撤销工作区改动（还没 add 的文件）
git restore file.txt

# 撤销暂存区（已经 add 但还没 commit）
git restore --staged file.txt

# 撤销最近一次 commit（保留改动在工作区）
git reset --soft HEAD~1

# 撤销最近一次 commit（丢弃改动——⚠️ 不可恢复）
git reset --hard HEAD~1

# 创建一个反向 commit 来"撤销"（安全——历史可追溯）
git revert a1b2c3d

# 终极救命：reflog——就算 reset --hard 了也能找回来
git reflog
git reset --hard HEAD@{2}   # 回到 2 次操作前的状态
```

> 💡 **`git reflog` 是 Git 的时光机。** 即使你用 `reset --hard` 或 `rebase` 操作了，reflog 会保留 90 天以内的所有 HEAD 移动记录。只要你还在同一个仓库里，没有什么是真正丢失的。

---

## 四、实用组合速查

```bash
# 修改最后一次 commit 的信息
git commit --amend -m "new message"

# 把某次 commit 从一个分支搬到另一个
git cherry-pick a1b2c3d

# 看看还没 push 的 commit
git log origin/main..HEAD

# 撤回最近一次 push（⚠️ 如果有人已经 pull 了别这么做）
git reset --hard HEAD~1 && git push --force

# 忽略已跟踪文件的本地修改
git update-index --assume-unchanged config/database.yml
```

---

## 五、踩坑清单

- **坑一：`git push -f` 覆盖了别人的工作** → force push 会重写远程历史。如果有人基于你 force push 之前的 commit 做了工作，他们的提交会变成孤儿。**永远不要 force push 共享分支（main/master）。**
- **坑二：`git reset --hard` 丢了未提交的改动** → `--hard` 不可恢复（除非在 reflog 的窗口内且数据还在）。不确定时先用 `git stash` 保存。
- **坑三：merge conflict 时直接 `git add . && git commit`** → 可能把冲突标记（`<<<<<<<`）也提交进去。解决每个冲突后单独测试。
- **坑四：`git pull` 在错误的分支上执行** → 把本不该合并的分支合进了 main。养成 `git fetch` + `git merge` 的两步习惯。
- **坑五：大文件（>100MB）提交后永久留在 Git 历史里** → 即使 `git rm` 后 commit，`.git` 目录仍然包含那个文件。用 `git filter-branch` 或 `BFG Repo-Cleaner` 清理。

## 六、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 代码版本控制 | Git | 标准方案 |
| 大文件/二进制文件版本控制 | `git-lfs` | Git 本身不擅长大文件（每次 clone 下载全部历史） |
| 交互式 commit 管理 | `lazygit` / `tig` | TUI 工具，比命令行更直观 |
| 图形化 diff/merge | `vscode` / `meld` / `p4merge` | 冲突解决可视化 |

---

> **核心观点：** 学 Git 不是为了记住 `add/commit/push` 三个命令——而是理解它的 **四个区域**（工作区→暂存区→本地仓库→远程仓库）和 **指针模型**（commit/branch/HEAD）。`git reflog` 是你的时光机——只要还在同一个仓库里，没有什么是真正丢失的。**你不需要"删了重来"，你只是还没找到回去的路。**
