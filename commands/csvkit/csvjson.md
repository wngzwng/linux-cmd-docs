
# csvjson：CSV → JSON 转换——给 API 和后端程序用的桥梁

命令行里处理 CSV 用 csvkit，但传给 Web 前端或 API 时需要 JSON。`csvjson` 一行把 CSV 转成 JSON，支持多种输出格式。

---

## 场景引入

把 `users.csv` 转成 JSON 数组，给前端一个 API mock：

```bash
csvjson users.csv
```

输入：

```
id,name,city
1,张三,北京
2,李四,上海
```

输出：

```json
[
  {"id": "1", "name": "张三", "city": "北京"},
  {"id": "2", "name": "李四", "city": "上海"}
]
```

---

## 核心能力

### 默认：JSON 数组（每行一个对象）

```bash
csvjson data.csv
```

### 按主键嵌套（`-k`）——Keyed JSON

```bash
csvjson -k id users.csv
```

输出：

```json
{
  "1": {"id": "1", "name": "张三", "city": "北京"},
  "2": {"id": "2", "name": "李四", "city": "上海"}
}
```

### 压缩 JSON（`-c`）

```bash
csvjson -c data.csv     # 一行 JSON，无缩进无空格
```

### 指定数据类型（`--snifflimit 0` + `-t`）

```bash
csvjson -t data.csv     # 数字不转成字符串，保留原始类型
```

### 地理 JSON（`--lat` `--lon`）

```bash
csvjson --lat latitude --lon longitude --type Point locations.csv
```

---

## 管道中的经典用法

```bash
# 过滤 → 选列 → 排序 → 转 JSON
csvgrep -c status -m active users.csv \
  | csvcut -c id,name,email \
  | csvsort -c id \
  | csvjson > users.json

# 给 curl 用
curl -X POST https://api.example.com/upload \
  -H "Content-Type: application/json" \
  -d "$(csvjson data.csv -c)"
```

---

## ⚠️ 雷区

### 默认所有值都是字符串

```bash
csvjson data.csv
# "amount": "500" ← 这是字符串 "500"，不是数字 500

csvjson -t data.csv
# "amount": 500   ← 这是数字
```

### 大文件 JSON 体积膨胀

CSV 是紧凑的列式文本，JSON 是冗余的键值对。10MB 的 CSV 转出来可能是 40MB 的 JSON。`-c` 压缩能省一点，但结构冗余无解。
