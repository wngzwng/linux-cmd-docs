# git：一个内容寻址的文件系统，假装自己是版本控制工具

你每天都在 `git add`、`git commit`、`git push`。但如果问你：「`git commit` 时究竟发生了什么？`.git` 目录里存了什么？为什么切分支只要一瞬间？」——你能说清楚吗？

git 的「表面身份」是版本控制系统。但它的**本质是一个内容寻址的文件系统**——一个 key-value 数据库，key 是内容的 SHA-1 哈希，value 是压缩后的内容。版本控制（branch、tag、log、diff）只是在这个文件系统上的一层 UI。

理解了这一点，你就不再需要「背 git 命令」。

---

## 第一层：内部模型

### 1.1 四个区域

git 的世界有四个区域，每个 `git` 命令本质上是**在四个区域之间搬运内容**：

```
工作目录（Working Directory）          ← 你正在编辑的文件，看得见摸得着
    │  git add
    ↓
暂存区（Staging Area / Index）        ← 下次 commit 的「购物车」
    │  git commit
    ↓
本地仓库（Local Repository）          ← .git/ 目录，完整的版本历史
    │  git push / git fetch
    ↓
远程仓库（Remote Repository）         ← GitHub / GitLab / 服务器
```

> 💡 **理解了这个图，所有 git 命令就自然归位了：**
> - `git add` = working directory → index
> - `git commit` = index → local repo
> - `git push` = local repo → remote
> - `git fetch` = remote → local repo（只更新远程跟踪分支，不碰你的代码）
> - `git pull` = fetch + merge（两步合一步）
> - `git checkout` = local repo → working directory（从历史里还原文件）
> - `git reset` = 移动当前分支指针（可以在不同区域之间穿梭）
> - `git stash` = working directory + index → 一个临时 commit（存放在 stash 栈里）

任何一个 git 命令，你都能在这张图上找到它搬运的起点和终点。

### 1.2 四种对象

本地仓库（`.git/` 目录）里存的不是「文件差异」，而是四种不可变对象：

```
commit 对象                           ← 一次提交的快照
  ├─ tree: 指向本次提交的目录结构（一个 tree 对象）
  ├─ parent: 指向上一个 commit（形成链表）
  ├─ author / committer / message
  └─ 自身的 SHA-1 哈希就是「commit ID」

tree 对象                             ← 一个目录的快照
  ├─ blob  abc123  index.html         ← 「文件名 + 模式 + 指向 blob 的 hash」
  ├─ tree  def456  src/               ← 子目录指向另一个 tree 对象
  └─ blob  ghi789  style.css

blob 对象                             ← 一个文件的内容（不含文件名！）
  └─ 压缩后的文件内容，key = SHA-1(内容)

tag 对象                              ← 一个不可移动的标签
  ├─ object: 指向某个 commit
  ├─ type: "commit"
  └─ tag / tagger / message
```

> 💡 **关键洞察：blob 对象只存文件内容，不存文件名。** 文件名存储在 tree 对象中。这意味着：两个内容完全相同的文件（即使文件名不同）在 git 里共享同一个 blob——`git` 天然去重。这也是为什么你 `cp` 一个大文件再 `git add`，仓库体积不会翻倍。

### 1.3 HEAD 与分支：不过是指针

这是 git 里最核心也最容易被误解的概念：

```
HEAD  →  一个特殊的符号指针
           ├─ 正常状态：HEAD → refs/heads/main → commit C
           │   你在 main 分支上，HEAD 指向 main，main 指向 C
           │
           └─ 分离状态（detached HEAD）：HEAD → commit B
                HEAD 直接指向某个 commit，没有分支保护你
                此时做 commit 会丢失（除非你新建一个分支）

分支   →  只是指向某个 commit 的指针（refs/heads/xxx）
           git commit 时，当前分支指针自动向前移动一步
           所以「切分支」 = 移动 HEAD 指向 + 更新工作目录
           这只是一个指针赋值——这就是为什么它飞快

标签   →  和分支一样是指针，但**不会自动移动**
           创建时指向某个 commit，永远钉在那里
```

```
正常状态：                         分离 HEAD 状态：
                                   HEAD
HEAD                                │
  │                                 ▼
  ▼                              commit B
 main                               │
  │                                 ▼
  ▼                              commit A
commit C
  │
  ▼
commit B
```

> 💡 **git 没有「当前版本号」这个概念。** 它只有一个指针体系：HEAD → 分支 → commit。你看到的每一个版本，都是沿着 commit 链表（parent 指针）回溯出来的。所谓「切到三天前的版本」= 让 HEAD 指向三天前的那个 commit 对象。

---

## 第二层：行为机制

### 2.1 git commit 的全过程

当你敲下 `git commit -m "fix bug"`，git 内部发生了什么？

```
Step 1：计算每个暂存文件的 SHA-1
  → 对每个 git add 过的文件内容做 SHA-1("blob " + size + "\0" + content)
  → 如果 .git/objects/ 里已经有这个 blob（内容没变），直接复用它的 hash

Step 2：构建 tree 对象
  → 根据暂存区的目录结构，构建一个 tree（包含文件名→blob hash 的映射）
  → 子目录递归构建子 tree
  → tree 对象也有 SHA-1，写入 .git/objects/

Step 3：构建 commit 对象
  → 内容 = tree hash + parent commit hash + author + committer + message
  → 计算 SHA-1，写入 .git/objects/

Step 4：移动指针
  → HEAD → 当前分支 → 新 commit
  → 同时更新 .git/refs/heads/main 文件，写入新 commit hash
```

> 💡 **同一个文件内容 → 同一个 blob hash。** 这就是为什么 git 能高效存储大量版本——一个 100MB 的文件修改了 1KB，git 只存两个 blob：一个旧的、一个修改后的。不是存 diff，是存完整快照——但通过 hash 去重和 zlib 压缩，实际体积很小。

### 2.2 merge vs rebase：两种不同的历史哲学

**merge**：保留真实的历史拓扑。

```
     A---B---C  feature
    /         \
D---E---F---G---H  main (H 是 merge commit，有两个 parent：G 和 C)
```

- 创建新的 merge commit（H），它的 parent 有**两个**
- 优点：完整保留「什么时候分支、什么时候合并」的历史
- 缺点：历史图复杂，log 不够线性

**rebase**：重写历史，假装你一直在一个分支上开发。

```
变基前：                         变基后：
A---B---C  feature               D---E---F---A'---B'---C'  feature
       /                         （A' B' C' 是重新计算的 commit，
D---E---F  main                    内容相同但 parent 和 hash 不同）
```

- 把 feature 分支的 commit「摘下来」，重新「接」到 main 的最新 commit 后面
- 每个 commit 被重新计算（parent 变了 → hash 变了）
- 优点：历史线性，`git log` 干净
- **铁律：不要 rebase 已经 push 过的分支。** 因为你重写了历史——别人的仓库里还留着旧 commit，push 会冲突，force push 会让协作崩溃。

### 2.3 .git 目录结构

```
.git/
├── HEAD              ← "ref: refs/heads/main"（当前分支的指针文件）
├── config            ← 仓库级别的 git 配置
├── index             ← 暂存区（二进制文件，不是文本）
├── objects/          ← 所有对象（blob / tree / commit / tag）的存储
│   ├── ab/
│   │   └── c123...   ← 文件名 = hash 的前两个字符 / 剩余 38 个字符
│   └── pack/         ← 打包文件（大仓库会用 pack 压缩多个对象）
├── refs/
│   ├── heads/
│   │   └── main      ← 文件内容就是这个分支指向的 commit hash
│   ├── remotes/
│   │   └── origin/
│   │       └── main  ← 远程跟踪分支
│   └── tags/
│       └── v1.0      ← 标签指向的 commit hash
└── logs/
    └── HEAD          ← reflog：HEAD 的每一次移动记录
```

> 💡 你可以直接 `cat .git/HEAD`、`cat .git/refs/heads/main` 来看指针指向。git 没有魔法——它只是一堆文件，结构极其简单。

---

## 第三层：高级模式

理解了前两层，以下高级用法就不再是「背命令」，而是从内部模型推导出来的。

### 3.1 git reflog：时间的后悔药

你刚刚 `git reset --hard` 丢了一个 commit。git log 看不到了——因为那个 commit 没有被任何分支指向。但它还在 `.git/objects/` 里！

```
git reflog
# 显示 HEAD 的每一次移动记录（默认保留 90 天）：
# abc1234 HEAD@{0}: reset: moving to HEAD~1
# def5678 HEAD@{1}: commit: important work
# ...

git reset --hard HEAD@{1}
# 回到丢掉的 commit——因为 reflog 记住了 HEAD 曾经在那里
```

> reflog 不是魔法——它就是 `.git/logs/HEAD` 文件里的逐行记录。每次 HEAD 移动，git 就往这个文件追加一行。

### 3.2 交互式 rebase：重写提交历史

```bash
git rebase -i HEAD~4
# 打开编辑器，列出最近 4 个 commit
# pick abc1234 fix typo
# pick def5678 add feature
# pick ghi9012 wip
# pick jkl3456 fix bug
#
# 你可以：
# - 把 'pick' 改成 'squash'：将这个 commit 合并到上一个
# - 把 'pick' 改成 'reword'：只改 commit message
# - 把 'pick' 改成 'edit'：暂停 rebase，让你修改这个 commit 的内容
# - 删除一行：丢弃这个 commit
# - 调换行顺序：重新排列 commit
```

> 本质：交互式 rebase 是「重放 commit 序列」。git 把你要 rebase 的 commit 按顺序重新 apply 到新的 base 上，期间停下来让你做修改。每个 commit 的 hash 都会变（因为 parent 变了）——这就是为什么不能 rebase 已经 push 的分支。

### 3.3 git bisect：二分查找引入 bug 的 commit

```bash
git bisect start
git bisect bad HEAD         # 当前版本有 bug
git bisect good v1.0        # v1.0 没 bug
# git 自动切换到中间的 commit

# 测试这个版本有没有 bug → 有就 git bisect bad，没有就 git bisect good
# git 继续二分，直到定位到引入 bug 的那个 commit
```

> 本质：git 的 commit 历史是一个 DAG（有向无环图），bisect 在这个图上做二分查找。你用 `good` 和 `bad` 标签标记节点，git 优先选择能最快收敛的路径。

### 3.4 恢复误删的文件

```bash
# 你 git rm 了一个文件并提交了，但后来发现还需要它
# 原理：找到最后一次包含该文件的 commit，从它的 tree 里取回 blob

git log --all --full-history -- path/to/file
# 找到最后一次包含该文件的 commit hash

git checkout <commit-hash> -- path/to/file
# 从那个 commit 的 tree 里，把该文件恢复到工作目录
```

> 本质：文件虽然在最新 commit 里不存在了，但在历史 commit 的 tree 对象里还完好地保存着对应的 blob。git 没有「删除」——它只是不再引用那个 blob。

---

## 一句话

> git 不是版本控制工具。git 是一个内容寻址的文件系统，版本控制只是它上面的一层 UI。理解了 blob / tree / commit / tag 四种对象和 working tree / index / local repo / remote 四个区域，所有的 git 命令都是「在四个区域之间搬运内容」的不同组合——你不需要背命令，你需要看懂搬运的方向。
