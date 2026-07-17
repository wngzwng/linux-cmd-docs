---
name: deep-dive-cmd
description: 为 git、docker、tmux、systemctl 等复杂命令撰写深度分析，沿「内部模型→行为机制→高级模式」三层递进，区别于基础教程的 What/How，侧重 Why/What If
---

# deep-dive：复杂命令深度剖析写作框架

## 定位

为 git、docker、tmux、systemctl、nvim、ssh 等「复杂命令」撰写深度分析文档，区别于 `commands/` 的基础教程。

| | commands/ | deep-dive/ |
|---|---|---|
| 目标 | 让你**用对**这个命令 | 让你**理解**这个命令 |
| 核心问题 | What & How | Why & What If |
| 读者已会 | 基本用法 | 日常操作 |

---

## 写入路径

文档放入 `deep-dive/` 目录。每个命令一个 `.md` 文件，文件名即命令名（如 `git.md`、`docker.md`）。

---

## 展开框架：三层递进

沿着「内部模型 → 行为机制 → 高级模式」逐层推进：

### 第一层：内部模型（Internal Model）

回答「这个工具的世界是什么样的」——画出对象模型和架构图。

- 用概念图（ASCII art 或对象关系图）呈现核心架构
- 让读者建立心智模型，后续所有行为都能从模型推导
- 例子：
  - git：四个区域（working tree / index / local repo / remote）+ 四种对象（blob / tree / commit / tag）
  - docker：OCI 运行时栈（CLI → daemon → containerd → runc）+ 镜像层模型
  - tmux：client-server 分离架构 + session/window/pane 三层嵌套
  - systemctl：unit 文件体系 + 依赖拓扑 + cgroups

### 第二层：行为机制（Behavioral Mechanics）

回答「当你做 X 时，背后到底发生了什么」——选取最核心的 2-3 个生命周期逐步追踪。

- 用「追踪式叙事」：一个操作从输入到完成，每一步发生了什么
- 每一步标注关键概念
- 例子：
  - docker run 全生命周期：CLI → REST API → pull 镜像层 → 创建容器（CoW + namespace + cgroups）→ 启动 → stop 信号链
  - git commit：hash 计算 → blob 写入 → tree 更新 → commit 对象创建 → HEAD 移动
  - systemctl start nginx：读 unit → 解析依赖 → 启动 → cgroup 监控

### 第三层：高级模式（Advanced Patterns）

前两层建立后，高级用法不再是「背参数」而是「推理出来的」。

- 展示 3-5 个真实高级场景
- 每个场景先从「第一层模型」推导出思路，再给命令
- 例子：
  - git reflog 不是魔法——HEAD 移动日志
  - 多阶段构建的本质——只拷贝产物，丢弃中间层
  - drop-in override.conf 比直接改 service 文件好在哪

---

## 叙事风格约束

1. **开场**：一个「你自以为理解但其实没有」的顿悟时刻，而非单纯的场景引入
2. **比喻有深度**：不只说「X 是瑞士军刀」，要说「git 是一个内容寻址的文件系统」这种揭示本质的表述
3. **图表优先**：架构图 / 对象关系图 / 生命周期序列图，ASCII art 或文字描述的图均可
4. **代码示例带原理注释**：每条命令后面解释它在模型中做了什么，而非只给输出
5. **结尾**：「你现在理解了原理，可以自己推理出新用法」，而非「记住这几个参数」
6. **长度不限**：按需要展开，可以分章节、可以有二级/三级标题

---

## 输出前自检

- [ ] 读完第一层后，读者能否画出这个工具的核心架构图？
- [ ] 读完第二层后，读者能否解释一个核心操作的全流程？
- [ ] 读完第三层后，读者能否推理出他们没见过的用法？
- [ ] 全程有没有单纯罗列参数表？（有就删）
- [ ] 比喻是否揭示本质而非仅仅类比表象？
