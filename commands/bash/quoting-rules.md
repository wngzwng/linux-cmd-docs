# bash 引号规则——单引号、双引号、无引号，各发生什么？

> 引号不是"风格问题"——它们直接决定 bash 对你的字符串做几次处理。不加引号 = 变量展开 + 单词拆分 + 通配符展开（三次处理），双引号 = 只展开变量（一次处理），单引号 = 零处理。理解这个"次数模型"，引号就不需要猜了。

## 一、引号的本质——控制处理步骤

```
无引号：$var → 变量展开 → 单词拆分 → 通配符展开 → 结果字面量转义
双引号：$var → 变量展开 → 直接输出（保留了空格）
单引号：$var → 直接输出 $var（什么都没做）
```

```bash
var="hello   world"

echo $var        # hello world（拆分+压缩：多个空格变成单个）
echo "$var"      # hello   world（保留原样，多个空格还在）
echo '$var'      # $var（字面量，$ 没有展开）
```

## 二、单引号——"不许碰我的内容"

```bash
# 单引号内部一切都是字面量
echo '$USER $HOME $(date) *.txt \n \t'
# → $USER $HOME $(date) *.txt \n \t

# 一个例外：单引号里不能包含单引号
# echo 'it's'    # ❌ 语法错误
echo 'it'\''s'   # ✅ 拼接：'it' + 转义的单引号 + 's'
```

单引号的使用场景：

- awk/sed 程序（防止 `$1` 被 shell 展开）
- 固定字符串（不需要变量展开的场合）
- Here Document 的分隔符加引号（防止内部变量展开）

```bash
awk '{print $1}' data.txt             # $1 是 awk 的，不是 shell 的
sed 's/old/new/g' file.txt            # 同上
cat << 'EOF' > config.ini             # EOF 加引号 → 内部 $var 不展开
```

## 三、双引号——"展开变量，但别拆分"

```bash
# 双引号内展开变量和命令
echo "User: $USER, Home: $HOME"

# 双引号内展开命令替换
echo "Today is $(date)"

# 双引号内展开算术
echo "Result: $(( 2 + 3 ))"

# 双引号阻止单词拆分和通配符展开
var="a   b   *.txt"
echo "$var"         # → a   b   *.txt（保留空格，保留 *）

# 但双引号不阻止以下：
echo "Line 1\nLine 2"    # \n 不转义（bash 的 echo 默认不解释）
echo $'Line 1\nLine 2'   # $'...' ANSI-C quoting 才解释转义
```

### 双引号内需要转义的字符

```bash
echo "Cost: \$100"       # $ → 用 \$ 保留字面量
echo "He said \"hello\"" # " → 用 \" 保留字面量  
echo "Path: C:\\\\data"  # \ → 用 \\ 保留字面量（一个反斜杠不够）
echo "Command: \`date\`" # ` → 用 \` 保留字面量
```

## 四、无引号——"让 bash 自由处理"

```bash
# 无引号时发生：变量展开 → 单词拆分 → 通配符展开
var="*.txt a b"

echo $var
# 步骤 1：变量展开 → "*.txt a b"
# 步骤 2：单词拆分 → "*.txt" "a" "b"（三个词）
# 步骤 3：通配符展开 → "readme.txt" "a" "b"（*.txt 替换为实际文件名）
```

无引号只在两个场景有意义：
1. 你确实需要单词拆分（如遍历 flags）
2. 你确实需要通配符展开（如 `for f in *.log`）

其他所有场景——加双引号。

## 五、`$'...'` ANSI-C Quoting

```bash
# 解释 C 风格的转义序列（不受 echo -e / printf 的限制）
echo $'Line1\nLine2\tTabbed'
# → Line1
# → Line2    Tabbed

echo $'Hex: \x41'         # → Hex: A（\x41 = ASCII 'A'）
echo $'Unicode: \u263A'   # → Unicode: ☺
```

## 六、引号嵌套——实战模式

```bash
# 模式 1：外层单引号，内层双引号（awk/sed 程序里嵌变量展开）
awk "{print \$$col}" data.txt
# → awk 程序是 {print $3}（col=3 时）
# ⚠️ 这种写法需要精确控制转义，不建议

# 更好的做法：用 -v 传变量
awk -v col="$col" '{print $col}' data.txt

# 模式 2：双引号内部嵌套命令替换
echo "The date is $(date)"

# 模式 3：拼接不同类型的引号
echo 'Static text '"$variable"' more static text'
# → Static text value more static text
```

## 七、Here Document 的引号规则

```bash
# EOF 不加引号：内部变量和命令都会展开
cat << EOF
User: $USER
Date: $(date)
EOF

# EOF 加引号（'EOF' 或 "EOF"）：内部什么都不展开
cat << 'EOF'
User: $USER         # ← 字面量 $USER，不展开
EOF
```

## 八、踩坑清单

- **坑一：变量不加引号，包含空格时被拆成多个参数** → 99% 的场景用 `"$var"`。
- **坑二：单引号内想加单引号** → `'it'\''s'`（结束单引号 + 转义单引号 + 开始新单引号），或者用双引号：`"it's"`。
- **坑三：双引号内 `!` 在交互式 bash 里有历史展开** → `echo "Run!"` 可能触发 history expansion。用 `set +H` 关闭，或写成 `echo "Run"\!"`。
- **坑四：Here Document 分隔符忘了加引号** → `cat << EOF` 内部 `$VAR` 会被展开；`cat << 'EOF'` 不会。不想展开时加引号。
- **坑五：`$'...'` 和 `$"..."` 不是同一种东西** → `$'...'` 是 ANSI-C quoting（解释转义），`$"..."` 是 locale translation（极少用，几乎总是该避免）。

---

> **核心观点：** 引号规则不需要背——只需要记住一个模型：**bash 对字符串的处理有三步：变量展开 → 单词拆分 → 通配符展开。** 单引号跳过全部三步，双引号只做第一步，无引号三步全做。选哪种引号取决于你希望 bash 对你的字符串做几次处理。
