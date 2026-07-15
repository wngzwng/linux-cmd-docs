# 为什么 git 很强，但大多数人只用 add/commit/push？

> Git 是版本控制的事实标准。但大多数人只记住了三条命令：`git add .`、`git commit -m 'fix'`、`git push`。出了问题就删仓库重新 clone。其实 Git 是一个内容寻址的文件系统——理解了它的四个区域和指针模型，你就再也不会"先删了重来"。

## 一、从一个场景说起

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

除了四个区域，还需要理解一套**指针体系**——指针才是 Git 的导航系统，理解了指针的移动规则，Git 命令就不再是咒语。

### 2.1 指针类型一览

```
指针类型          标识方式                    移动规则
───────────────────────────────────────────────────────────
HEAD              特殊的符号指针              指向"当前分支"时：跟随 checkout/switch 移动
                  指向分支时：refs/heads/xxx   直接指向 commit 时：分离状态（见 2.3）

分支指针           refs/heads/main            git commit 时自动前进到新 commit
                  refs/heads/feature          始终指向该分支的最新 commit

远程跟踪分支        refs/remotes/origin/main    git fetch / git push 时更新
                                              ⚠️ 不能手动移动（由远程状态决定）

标签指针           refs/tags/v1.0             创建时固定，不随 commit 移动
                                              （类似图钉，不是滑动指针）

暂存区（严格说不是指针）  .git/index            记录"下一个 commit 要包含什么"
                                              是内容快照，不是指针
```

### 2.2 HEAD 与分支指针：正常 vs 分离

**正常状态（HEAD 指向分支）：**

```
HEAD ──→ main ──→ commit C       ← "你在 main 分支上，main 指向 C"

git commit 之后：

HEAD ──→ main ──→ commit D       ← main 自动向前移动了一步
                    ↑
                 commit C         ← C 变成 D 的 parent
```

**分离 HEAD 状态（HEAD 直接指向 commit）：**

```
HEAD ──→ commit B                 ← "你直接站在 B 上，没有分支保护你"
            ↑
main ──→ commit C                 ← main 还在 C，跟你没关系了

在分离 HEAD 下做 git commit 之后：

HEAD ──→ commit D                 ← HEAD 前进了
            ↑
       commit B                   ← B 变成 D 的 parent

main ──→ commit C                 ← main 纹丝不动！D 没有分支指向它！
```

> 💡 **"分离"的本质：HEAD 脱离了分支的"轨道"，自己直接指向了一个裸 commit。** 正常状态下 HEAD 坐在分支这辆车上，车往前开你就跟着走；分离状态下你自己站在铁轨上，车开走了你还在原地。

### 2.3 分离 HEAD（Detached HEAD）详解

**什么情况下会进入分离 HEAD：**

```bash
git checkout a1b2c3d        # 直接 checkout 一个 commit ID
git checkout v1.0            # checkout 一个 tag
git checkout origin/main     # checkout 远程跟踪分支（不创建本地分支）
```

共同点：让 HEAD 指向了一个 commit，而不是一个本地分支名。

**危险在哪：**

```
正常状态:
  git commit → 分支指针自动前进 → commit 挂在分支链条上 → 安全

分离 HEAD 状态:
  git commit → HEAD 自己前进 → 没有分支指针指向这个新 commit
  → 一旦 git switch main → HEAD 跳到 main 上
  → 刚才的 commit 变成了没有指针指向的"孤儿"
  → git GC 运行时会清理掉
  → 看起来像"代码丢了"
```

**正确用法：临时看看，别在上面工作：**

```bash
# ✅ 正确：临时看一眼某个历史版本
git checkout a1b2c3d          # 进入分离 HEAD
# 看看代码，运行测试……
git switch main               # 回到正常状态

# ✅ 正确：从历史版本开始修 bug，立即创建分支
git checkout a1b2c3d          # 进入分离 HEAD
git switch -c hotfix-from-old  # 立刻创建分支保护它！
# 现在 HEAD → hotfix-from-old → a1b2c3d，安全了

# ❌ 错误：在分离 HEAD 下工作很久然后切换走
git checkout a1b2c3d
# ……写了三天代码，做了 10 个 commit ……
git switch main               # 10 个 commit 全成了孤儿！
```

**如果不小心丢了分离 HEAD 上的 commit：**

```bash
# git reflog 记录了 HEAD 的所有移动历史（包括"丢掉的"commit）
git reflog
# 输出类似：
# a1b2c3d HEAD@{0}: checkout: moving from a1b2c3d to main
# d4e5f6g HEAD@{1}: commit: 最后一天的工作     ← 丢掉的 commit！

# 找回最后一个"丢失的" commit：
git checkout d4e5f6g          # 回到那个 commit
git switch -c rescued-work    # 立即创建分支保护！
```

> 💡 `git reflog` 是分离 HEAD 的安全网——它记录了 HEAD 在最近 90 天内的每一次移动。即使没有分支指针指向的 commit，只要 reflog 里还有记录，就能找回来。但它是救命稻草，不是日常工作流。

### 2.4 核心操作的指针移动可视化

**操作一：`git commit` → 分支指针前移**

```
提交前：HEAD → main → A → B → C
提交后：HEAD → main → A → B → C → D
                                       ↑ main 从 C 移到 D
```

**规则：** 基于 HEAD 指向的 commit 创建新 commit，然后把当前分支指针往前挪一步。HEAD 始终跟着分支走。

**操作二：`git switch <分支>` → HEAD 换轨**

```
切换前：
  HEAD → feature → A → B → F
  main  → A → B → C → D

git switch main 之后：
  feature → A → B → F          ← feature 留在原地
  HEAD → main → A → B → C → D  ← HEAD 换到了 main 这辆车上
```

**操作三：`git reset` → 强制移动分支指针**

```
reset 前：HEAD → main → A → B → C → D
git reset HEAD~1 之后：
         HEAD → main → A → B → C     ← main 倒退了一步
                            ↑
                            D         ← D 变成孤儿 commit
```

**三种 reset 模式：** `--soft` 只挪指针（暂存区和工作区不动）；`--mixed`（默认）挪指针 + 清暂存区；`--hard` 挪指针 + 清暂存区 + 覆盖工作区（⚠️ 不可逆）。

**操作四：`git merge` → 分支指针跳到合并结果**

```
merge 前：
  HEAD → main → A → B → C
  feature → A → B → F

git merge feature 之后：
  HEAD → main → A → B → C → M    ← M 是合并提交，有两个 parent
                    ↘       ↗
                      F           ← feature 还在 F，不动
```

**操作五：`git rebase` → 重写 commit 链条 + 移动分支指针**

```
rebase 前：
  HEAD → feature → A → B → F
  main  → A → B → C → D

git rebase main 之后：
  feature → A → B → C → D → F'   ← F 被"复制"一份，重新挂到 D 后面
            ↑
  原来的 F 变成孤儿，最终被 GC 回收
  main  → A → B → C → D          ← main 不动
  HEAD  → feature → ...          ← HEAD 跟着 feature 走
```

**规则：** rebase 不是"移动" commit，而是"重放"——把 feature 上独有的提交逐个复制，挂到目标分支顶端。原 commit 还在 `.git/` 里但无指针指向，最终被垃圾回收。

> 💡 **核心认知：Git 的"状态"不是单一快照，而是一个指针图。** `git add` = 工作区→暂存区；`git commit` = 暂存区→本地仓库 + 分支指针前移；`git push` = 本地仓库→远程仓库。Git 的几乎所有操作都是**指针操作**——对象一旦创建就不可变，变的只是哪些指针指向它。理解了这一点，"为什么 reset 之后还能找回"这类困惑自然消解。

### 2.5 commit 的内部结构：为什么 git 这么"反直觉"

指针体系解释了"数据怎么流动"，但还没解释 git 最底层的存储方式——**内容寻址**。每个 commit 的内部结构是这样的：

```
commit（一次提交）
  ├── tree（一个目录快照）
  │     ├── blob（文件内容）── 按内容哈希寻址
  │     └── tree（子目录）── 递归嵌套
  ├── parent（指向父 commit 的指针）
  ├── author / committer / message（元信息）
  └── 一个 SHA-1 哈希 ID 来标识整个 commit
```

**这解释了 git 最反直觉的三个行为：**

1. **为什么"删不掉"历史？** 每个 commit 的 ID 是内容的哈希。改内容 = 换 ID ≠ 修改旧 commit。旧 commit 仍然在 `.git/` 里，只是没有分支指向它了。这也就是为什么 `git reset --hard` 之后还能用 `reflog` 找回来——对象没删，只是指针挪了。

2. **为什么 `git diff` 能瞬间对比任意两个版本？** blob 是按内容哈希寻址的，相同内容 = 相同 blob = 不需要重新计算。git 只需要比较两个 commit 的 tree 对象，找到不同的 blob 然后对比内容。

3. **为什么分支切换这么快？** "分支"只是一个指向 commit 的指针（40 字节的文件），切换分支只是移动 HEAD 指针 + 更新工作区文件到目标 commit 的内容。没有"复制一份代码"的过程。

> 💡 **记住这个等式：git 是一个内容寻址的文件系统，上面加了一层版本控制的 UI。** 底层是 key-value 存储（key=SHA-1 哈希，value=对象内容），上层是指针操作。理解了这一点，所有"魔法"都变成了"哦，原来就是在读写对象数据库 + 移动指针"。

### 2.6 语法骨架——git 的两层句型

git 的语法有两层：外层是路由句型，内层是每个子命令自己的句型。

**外层路由句型：**

```
git <子命令> [<选项>...] [<参数>...]
```

`git` 本身不干活，它只是一个路由器——把请求分发到对应的子命令。敲 `git` 不带参数时列出的那 20+ 个命令，就是它的路由表。

**内层：高频子命令的句型与骨架模式映射：**

| 子命令 | 句型 | 骨架模式 |
|--------|------|---------|
| `git status` | `命令` （无参数，纯查询） | D 类：查询+展示 |
| `git add` | `命令 [选项] <路径...>` | C 类：动作+目标 |
| `git commit` | `命令 [选项] [-m "消息"]` | C 类：动作+目标 |
| `git push` | `命令 [远程] [分支]` | C 类：动作+目标 |
| `git pull` | `命令 [远程] [分支]` | C 类：动作+目标 |
| `git branch` | `命令 [选项] [分支名]` | D/C 混合：查/建/删 |
| `git checkout` | `命令 [选项] <分支/commit/路径>` | C 类：动作+目标 |
| `git log` | `命令 [选项] [范围]` | D 类：查询+展示 |
| `git diff` | `命令 [选项] [版本1] [版本2] [路径]` | D 类：查询+展示 |
| `git merge` | `命令 [选项] <分支>` | C 类：动作+目标 |
| `git rebase` | `命令 [选项] <基底>` | C 类：动作+目标 |
| `git stash` | `命令 <动作> [选项]` | C 类：动作+目标 |

> 💡 **git 的句型特点：绝大多数子命令是 C 类（动作+目标）——你告诉 git "对谁做什么"。** 少数是 D 类（查询+展示）——`status`、`log`、`diff`、`show`。这个规律意味着：遇到不熟悉的 git 子命令时，先判断它是"做事"的还是"查看"的，句型就基本定了。

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

## 四、场景推演——从需求反推命令

上面的五个轴覆盖了 git 的"能力空间"。真正使用时，思考过程是从需求反推：**需求 → 确认命令 → 选能力轴 → 填骨架 → 敲命令**。下面四个场景演示这个完整流程。

### 场景一：只提交部分文件的改动

> 「我改了三个文件 file1、file2、file3，想把 file1 和 file2 提交了，file3 留着继续改。」

**推演过程：**

```
① 需求分析：要提交 → commit；但只提交两个文件 → add 时指定范围
② 选能力轴：add 的目标=加入暂存区，范围=指定文件；commit 的消息来源=-m
③ 填入骨架：git add <文件...> → git commit -m "..."
```

```bash
git add file1.go file2.go
git commit -m "fix: handle edge case in file1 and file2"

# 验证
git status   # file3.go 显示为 modified but not staged ✅
```

### 场景二：修改最近一次提交的信息

> 「提交完发现 commit message 写错了，想改。」

**推演过程：**

```
① 需求分析：修改最近一次提交 → --amend；只改消息不改内容
② 选能力轴：commit 的修改模式=--amend
③ 填入骨架：git commit --amend -m "..."
```

```bash
git commit --amend -m "正确的提交信息"
```

> ⚠️ **安全铁律：如果这次提交已经 push 到远程，不要 amend！** amend = 生成一个新 commit 替换旧的 → 旧 commit 变成孤儿 → 远程还有旧 commit → 下次 push 会冲突。如果已经 push 了且确认安全，用 `git push --force-with-lease`，并确保团队没有其他人基于旧 commit 工作。

### 场景三：放弃本地改动，回到远程最新状态

> 「我刚才改了一些东西，但现在不想要了，想回到和远程 main 分支完全一样的状态。」

**推演过程：**

```
① 需求分析：放弃本地所有改动，基准是远程 main
② 先 fetch 拿到远程最新 → 再用 reset 重置本地
③ 选能力轴：fetch 方向=下载，远程=origin；reset 模式=--hard
```

```bash
git fetch origin
git reset --hard origin/main

# 验证
git status   # "nothing to commit, working tree clean" ✅
```

> ⚠️ **`git reset --hard` 不可逆！** 执行前确认两件事：① `git status` 看看有哪些未保存的改动；② 有想保留的先用 `git stash` 暂存。

### 场景四：把 feature 分支的提交 rebase 到 main 最新代码之上

> 「我在 feature 分支上开发，main 往前走了，我想把我的提交放到 main 最新代码之上重放一遍，保持线性历史。」

**推演过程：**

```
① 需求分析：把 feature 的提交"搬"到 main 顶端 → rebase（不是 merge！）
② 选能力轴：rebase 的基底=main，冲突处理=手动解决后 --continue
③ 填入骨架：git rebase <基底>
```

```bash
git switch feature
git rebase main

# 如果有冲突：
# 1. 手动编辑冲突文件
# 2. git add <解决后的文件>
# 3. git rebase --continue

# 如果想放弃整个 rebase：
# git rebase --abort
```

> 💡 **rebase vs merge 的选择：** merge 保留真实的分叉历史（"这两个分支确实并行开发了"）；rebase 制造线性历史（"看起来像是一条直线开发下来的"）。没有绝对的好坏——公开分支用 merge 保留历史真相，个人分支用 rebase 保持整洁。

---

## 五、实用组合速查

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

## 六、踩坑清单

- **坑一：`git push -f` 覆盖了别人的工作** → force push 会重写远程历史。如果有人基于你 force push 之前的 commit 做了工作，他们的提交会变成孤儿。**永远不要 force push 共享分支（main/master）。**
- **坑二：`git reset --hard` 丢了未提交的改动** → `--hard` 不可恢复（除非在 reflog 的窗口内且数据还在）。不确定时先用 `git stash` 保存。
- **坑三：merge conflict 时直接 `git add . && git commit`** → 可能把冲突标记（`<<<<<<<`）也提交进去。解决每个冲突后单独测试。
- **坑四：`git pull` 在错误的分支上执行** → 把本不该合并的分支合进了 main。养成 `git fetch` + `git merge` 的两步习惯。
- **坑五：大文件（>100MB）提交后永久留在 Git 历史里** → 即使 `git rm` 后 commit，`.git` 目录仍然包含那个文件。用 `git filter-branch` 或 `BFG Repo-Cleaner` 清理。
- **坑六：`git commit` 忘了 `-m`，直接打开编辑器（新手一脸懵）** → 不带 `-m` 时 git 会打开默认编辑器（通常是 vim）让你写提交信息。如果不会用 vim：按 `i` 进入编辑模式，写完按 `Esc`，输入 `:wq` 回车。或者养成带 `-m` 的习惯。
- **坑七：`git push` 不带参数，不确定推到哪** → 第一次 push 时明确指定远程和分支：`git push -u origin main`。`-u`（set-upstream）会建立本地分支和远程分支的追踪关系，之后就可以直接用 `git push` 了。
- **坑八：`git pull` 冲突了想放弃，敲 `git pull --abort` 报错** → `pull` 不支持 `--abort`。因为 `pull` = `fetch` + `merge`，放弃合并应该用 `git merge --abort`（如果是 rebase 触发的冲突则用 `git rebase --abort`）。
- **坑九：`git checkout` 一个命令干太多事——切换分支、恢复文件、创建分支** → 一个命令承担了三种完全不同的操作，新手极容易搞混。Git 2.23+ 引入了更明确的子命令：`git switch` 管分支切换，`git restore` 管文件恢复，`git checkout` 逐步退居二线。
- **坑十：`git add .` 习惯性把所有改动都加进去** → 可能把不想提交的调试代码、临时文件也一并加入暂存区。先 `git status` 看一眼，再选择性 `git add <文件>`；或者用 `git add -p` 逐块确认。

## 七、什么时候该换工具

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 代码版本控制 | Git | 标准方案 |
| 大文件/二进制文件版本控制 | `git-lfs` | Git 本身不擅长大文件（每次 clone 下载全部历史） |
| 交互式 commit 管理 | `lazygit` / `tig` | TUI 工具，比命令行更直观 |
| 图形化 diff/merge | `vscode` / `meld` / `p4merge` | 冲突解决可视化 |

---

> 💡 **git 在五步模型中的特殊地位：** 常规命令（find/grep/ss）是"单一命令 + 参数"的**数据处理型**工具，一张能力轴表就能覆盖。git 是"命令路由器 + 20+ 子命令"的**状态管理型**工具——必须先理解对象模型（四空间 + 指针体系 + commit 内部结构），否则后面所有分析都是空中楼阁。git 给五步模型增加了一条前置规则：**对于有复杂对象层级的命令，在"功能认知"之前先画对象模型。**

> **核心观点：** 学 Git 不是为了记住 `add/commit/push` 三个命令——而是理解它的 **四个区域**（工作区→暂存区→本地仓库→远程仓库）和 **指针模型**（commit/branch/HEAD）。`git reflog` 是你的时光机——只要还在同一个仓库里，没有什么是真正丢失的。**你不需要"删了重来"，你只是还没找到回去的路。**
