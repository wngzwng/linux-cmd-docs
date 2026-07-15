#!/usr/bin/env bash
# ============================================================
# joblog2html.sh —— 将 parallel --joblog 输出转为 H5 可视化报告
# ============================================================
# 用法:
#   parallel --joblog joblog.tsv 'cmd {}' ::: inputs
#   ./joblog2html.sh joblog.tsv > report.html
#   ./joblog2html.sh -o report.html joblog.tsv
#
# 依赖: awk (任何 POSIX awk 均可), Chart.js (CDN 加载)
# ============================================================
set -euo pipefail

# ─── 帮助 ─────────────────────────────────────────────────
usage() {
    cat <<'EOF'
用法: joblog2html.sh [选项] <joblog.tsv>

将 parallel --joblog 输出的 TSV 文件转为交互式 H5 报告（含 Chart.js 图表）。
报告输出到 stdout，可用 -o 写入文件。

选项:
  -o <path>     输出到文件而非 stdout
  -t <title>    报告标题（默认: "Parallel 任务执行报告"）
  -h, --help    显示此帮助

示例:
  parallel --joblog job.log 'ffmpeg -i {} {.}.mp4' ::: *.mov
  ./joblog2html.sh -t "视频转码报告" job.log > report.html

  # 跑完直接生成并打开
  ./joblog2html.sh job.log -o /tmp/report.html && open /tmp/report.html
EOF
    exit 0
}

# ─── 参数解析 ─────────────────────────────────────────────
OUTPUT=""
TITLE="Parallel 任务执行报告"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) OUTPUT="$2"; shift 2 ;;
        -t) TITLE="$2"; shift 2 ;;
        -h|--help) usage ;;
        --) shift; break ;;
        -*) echo "未知选项: $1" >&2; exit 1 ;;
        *)  JOBLOG="$1"; shift ;;   # 位置参数：记录后继续解析后续选项
    esac
done

if [[ -z "${JOBLOG:-}" ]]; then
    echo "错误: 请指定 joblog 文件路径" >&2
    usage
fi
if [[ ! -f "$JOBLOG" ]]; then
    echo "错误: 文件不存在 —— $JOBLOG" >&2
    exit 1
fi

# ─── 判断执行路径以支持符号链接 ───────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── 数据提取（全部由 awk 完成，一次遍历） ────────────────
# awk 输出三块，用标记行分隔:
#   ===STATS===    → 汇总统计（total ok fail sum_t max_t avg_t）
#   ===RUNTIMES=== → 成功任务耗时数组（JSON）
#   ===FAILS===    → 失败任务数组（JSON，每个 {seq,exit,cmd}）
#   ===TOP5===     → 最慢 5 个任务（JSON）

DATA=$(awk -F'\t' -v q='"' '
BEGIN {
    total = 0; ok = 0; fail = 0
    sum_t = 0; max_t = 0; avg_t = 0
    runtime_count = 0
}
NR == 1 {
    # 校验表头——必须包含 Exitval
    if ($0 !~ /Exitval/) {
        print "错误: 文件第一行不包含 Exitval 列，这不是有效的 parallel --joblog 输出" > "/dev/stderr"
        exit 1
    }
    next
}
{
    total++
    runtime  = $4
    exitval  = $7
    cmd_raw  = $9
    # 命令可能跨列（如果没被正确引用），从第9列起拼回去
    if (NF > 9) {
        cmd_raw = $9
        for (i = 10; i <= NF; i++) cmd_raw = cmd_raw " " $i
    }

    # ── 转义给 JS 用的命令字符串 ──
    cmd_escaped = cmd_raw
    gsub(/\\/, "\\\\", cmd_escaped)   # \ → \\
    gsub(/"/,  "\\\"", cmd_escaped)   # " → \"
    gsub(/\t/, " ",    cmd_escaped)   # tab → 空格
    # 去掉不可打印控制字符（除了换行）
    gsub(/[\001-\010\013\014\016-\037]/, "", cmd_escaped)

    if (exitval == 0 || exitval == "0") {
        ok++
        if (runtime + 0 == runtime && runtime >= 0) {
            runtime_count++
            sum_t += runtime
            if (runtime > max_t) max_t = runtime
            # 收集前 60 个成功任务耗时用于柱状图
            if (runtime_count <= 60) {
                runtimes[runtime_count] = runtime
            }
            # 收集所有成功任务用于 Top 5 排序
            all_runtimes[ok] = runtime
            all_cmds[ok]     = cmd_escaped
        }
    } else {
        fail++
        # 收集失败任务（最多 200 条，避免 HTML 过大）
        if (fail <= 200) {
            fail_items[fail] = sprintf("{\"seq\":%d,\"exit\":%d,\"cmd\":%s%s%s}",
                                       $1, exitval, q, cmd_escaped, q)
        }
    }
}
END {
    if (total == 0) {
        print "警告: joblog 中没有数据行（只有表头或为空）" > "/dev/stderr"
        total = 0; ok = 0; fail = 0; sum_t = 0; max_t = 0
    }
    if (ok > 0 && runtime_count > 0) avg_t = sum_t / runtime_count

    # === 输出 STATS ===
    print "===STATS==="
    printf "%d %d %d %.3f %.3f %.3f\n", total, ok, fail, sum_t, max_t, avg_t

    # === 输出 RUNTIMES（前 60 个，JSON） ===
    print "===RUNTIMES==="
    printf "["
    first = 1
    for (i = 1; i <= runtime_count && i <= 60; i++) {
        if (!first) printf ","
        printf "%.3f", runtimes[i]
        first = 0
    }
    printf "]\n"

    # === 输出 FAILS（JSON） ===
    print "===FAILS==="
    if (fail == 0) {
        print "[]"
    } else {
        printf "["
        for (i = 1; i <= fail && i <= 200; i++) {
            if (i > 1) printf ","
            printf "%s", fail_items[i]
        }
        printf "]\n"
        if (fail > 200) {
            printf "// 注意: 共 %d 个失败任务，仅显示前 200 个\n", fail > "/dev/stderr"
        }
    }

    # === 输出 TOP5 最慢 ===
    print "===TOP5==="
    n = ok
    if (n == 0) {
        print "[]"
    } else {
        # 简单选择排序取 top 5（数据量不大，O(n*k) 足够）
        top_count = (n < 5) ? n : 5
        # 构建输出
        printf "["
        for (k = 1; k <= top_count; k++) {
            max_idx = 1
            max_val = all_runtimes[1]
            for (j = 2; j <= n; j++) {
                if (all_runtimes[j] > max_val) {
                    max_val = all_runtimes[j]
                    max_idx = j
                }
            }
            if (k > 1) printf ","
            printf "{\"cmd\":%s%s%s,\"time\":%.3f}", q, all_cmds[max_idx], q, max_val
            all_runtimes[max_idx] = -1  # 标记已选
        }
        printf "]\n"
    }
}
' "$JOBLOG")

# ─── 解析 awk 输出 ────────────────────────────────────────
parse_section() {
    echo "$DATA" | awk -v section="$1" '
        $0 == "===" section "===" { found = 1; next }
        /^===.*===$/               { found = 0; next }
        found                      { print }
    '
}

STATS=$(parse_section STATS)
RUNTIMES_JSON=$(parse_section RUNTIMES)
FAILS_JSON=$(parse_section FAILS)
TOP5_JSON=$(parse_section TOP5)

read -r TOTAL OK FAIL SUM_T MAX_T AVG_T <<< "$STATS"

# 成功率（避免除以零）
if [[ "$TOTAL" -gt 0 ]]; then
    RATE=$(awk "BEGIN {printf \"%.1f\", $OK * 100.0 / $TOTAL}")
else
    RATE="0.0"
fi

# 从 joblog 文件名提取时间
GEN_TIME=$(date '+%Y-%m-%d %H:%M:%S')
JOBLOG_NAME=$(basename "$JOBLOG")

# ─── 生成 HTML ────────────────────────────────────────────
generate_html() {
    cat <<HTML
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$TITLE</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"></script>
<style>
  *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
  body{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial,
                 "Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif;
    background: #f1f5f9;
    color: #1e293b;
    line-height: 1.6;
    padding: 24px;
  }
  .container{max-width:1200px;margin:0 auto}
  h1{font-size:1.75rem;font-weight:700;margin-bottom:4px}
  .meta{color:#64748b;font-size:0.875rem;margin-bottom:24px;display:flex;gap:16px;flex-wrap:wrap}
  .meta span{white-space:nowrap}
  .badge{display:inline-block;padding:2px 10px;border-radius:99px;font-size:0.8rem;font-weight:600}
  .badge-ok{background:#dcfce7;color:#166534}
  .badge-warn{background:#fef3c7;color:#92400e}
  .badge-err{background:#fee2e2;color:#991b1b}

  /* ── 摘要卡片 ── */
  .cards{
    display:grid;
    grid-template-columns:repeat(auto-fit,minmax(150px,1fr));
    gap:16px;
    margin-bottom:24px;
  }
  .card{
    background:#fff;
    border-radius:14px;
    padding:20px 24px;
    box-shadow:0 1px 3px rgba(0,0,0,.06),0 1px 2px rgba(0,0,0,.04);
    transition:box-shadow .2s;
  }
  .card:hover{box-shadow:0 4px 12px rgba(0,0,0,.1)}
  .card .num{font-size:2rem;font-weight:800;line-height:1.2;margin-bottom:4px}
  .card .label{font-size:0.85rem;color:#64748b}
  .card.ok .num{color:#16a34a}
  .card.fail .num{color:#dc2626}
  .card.rate .num{color:#2563eb}
  .card.time .num{color:#7c3aed}

  /* ── 图表区 ── */
  .charts{
    display:grid;
    grid-template-columns:1fr 1fr;
    gap:16px;
    margin-bottom:24px;
  }
  .chart-box{
    background:#fff;
    border-radius:14px;
    padding:20px;
    box-shadow:0 1px 3px rgba(0,0,0,.06);
  }
  .chart-box h3{font-size:0.95rem;font-weight:600;color:#475569;margin-bottom:12px}

  /* ── 失败表格 ── */
  .section-box{
    background:#fff;
    border-radius:14px;
    padding:20px;
    box-shadow:0 1px 3px rgba(0,0,0,.06);
    margin-bottom:24px;
  }
  .section-box h3{font-size:0.95rem;font-weight:600;margin-bottom:12px}
  .section-box h3.err{color:#dc2626}
  .section-box h3.warn{color:#d97706}
  .all-ok{color:#16a34a;font-weight:600;font-size:1.05rem;padding:12px 0}

  table{width:100%;border-collapse:collapse}
  th,td{padding:10px 14px;text-align:left;border-bottom:1px solid #f1f5f9;font-size:0.875rem}
  th{color:#94a3b8;font-weight:600;font-size:0.8rem;text-transform:uppercase;letter-spacing:.5px}
  tr:hover td{background:#f8fafc}
  tr.fail-row td{color:#dc2626}
  code{
    background:#f1f5f9;
    padding:2px 8px;
    border-radius:5px;
    font-size:0.82rem;
    word-break:break-all;
    font-family: "SF Mono", "Fira Code", "Cascadia Code", Consolas, monospace;
  }

  .footer{
    text-align:center;
    color:#94a3b8;
    font-size:0.78rem;
    margin-top:32px;
    padding-top:16px;
    border-top:1px solid #e2e8f0;
  }

  @media(max-width:768px){
    .charts{grid-template-columns:1fr}
    .cards{grid-template-columns:repeat(2,1fr)}
    body{padding:12px}
    .card{padding:14px 16px}
    .card .num{font-size:1.5rem}
  }
</style>
</head>
<body>
<div class="container">

<h1>🧵 $TITLE</h1>
<div class="meta">
  <span>📅 $GEN_TIME</span>
  <span>📄 $JOBLOG_NAME</span>
  <span class="badge badge-ok">$OK 成功</span>
  $( [[ "$FAIL" -gt 0 ]] && echo "<span class=\"badge badge-err\">$FAIL 失败</span>" || echo "<span class=\"badge badge-ok\">✓ 零失败</span>" )
  $( [[ "$TOTAL" -gt 0 && "$FAIL" -gt 0 ]] && echo "<span class=\"badge badge-warn\">成功率 $RATE%</span>" || true )
</div>

<!-- ═════════ 摘要卡片 ═════════ -->
<div class="cards">
  <div class="card">
    <div class="num">$TOTAL</div>
    <div class="label">📋 总任务数</div>
  </div>
  <div class="card ok">
    <div class="num">$OK</div>
    <div class="label">✅ 成功</div>
  </div>
  <div class="card fail">
    <div class="num">$FAIL</div>
    <div class="label">❌ 失败</div>
  </div>
  <div class="card rate">
    <div class="num">${RATE}%</div>
    <div class="label">📊 成功率</div>
  </div>
  <div class="card time">
    <div class="num">${SUM_T}s</div>
    <div class="label">⏱ CPU 总耗时</div>
  </div>
  <div class="card time">
    <div class="num">${MAX_T}s</div>
    <div class="label">🐢 最慢任务</div>
  </div>
</div>

<!-- ═════════ 图表 ═════════ -->
<div class="charts">
  <div class="chart-box">
    <h3>📊 成功任务耗时分布（前 60 个）</h3>
    <canvas id="barChart"></canvas>
  </div>
  <div class="chart-box">
    <h3>🥧 成功 / 失败 比例</h3>
    <canvas id="pieChart"></canvas>
  </div>
</div>

<!-- ═════════ Top 5 最慢任务 ═════════ -->
<div class="section-box">
  <h3 class="warn">🐢 最慢的 5 个任务</h3>
  <div id="top5List"></div>
</div>

<!-- ═════════ 失败任务 ═════════ -->
<div class="section-box">
  <h3 class="err">❌ 失败任务明细</h3>
  <div id="failList"></div>
</div>

<div class="footer">
  Generated by <code>parallel --joblog</code> → <code>joblog2html.sh</code> ·
  <span id="genTime"></span>
</div>

</div><!-- /.container -->

<script>
// ═══════════ 从 awk 注入的数据 ═══════════
const STATS = {
  total: $TOTAL,
  ok:    $OK,
  fail:  $FAIL,
  sumT:  $SUM_T,
  maxT:  $MAX_T,
  avgT:  $AVG_T
};
const RUNTIMES = $RUNTIMES_JSON;
const FAILS    = $FAILS_JSON;
const TOP5     = $TOP5_JSON;

// 页脚时间
document.getElementById('genTime').textContent = new Date().toLocaleString('zh-CN');

// ── 耗时条形图 ──
(function(){
  const ctx = document.getElementById('barChart');
  if (!ctx) return;

  if (RUNTIMES.length === 0) {
    ctx.parentElement.innerHTML = '<p style="color:#94a3b8;text-align:center;padding:2em">暂无成功任务数据</p>';
    return;
  }

  const labels  = RUNTIMES.map((_, i) => '#' + (i + 1));
  const avgLine = STATS.avgT;
  const colors  = RUNTIMES.map(v =>
    v > avgLine * 2 ? 'rgba(239,68,68,0.75)' :    // 超出均值 2 倍 → 红色警告
    v > avgLine     ? 'rgba(251,191,36,0.75)' :    // 超出均值 → 黄色提醒
                      'rgba(34,197,94,0.7)'        // 正常 → 绿色
  );

  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: [{
        label: '耗时（秒）',
        data: RUNTIMES,
        backgroundColor: colors,
        borderColor: colors.map(c => c.replace('0.7','1').replace('0.75','1')),
        borderWidth: 1,
        borderRadius: 3,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: ctx => ctx.raw.toFixed(2) + 's' +
              (ctx.raw > avgLine * 2 ? ' ⚠️ 严重偏离均值' :
               ctx.raw > avgLine     ? ' ⚡ 超出均值' : '')
          }
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          title: { display: true, text: '秒', color: '#94a3b8' },
          grid: { color: '#f1f5f9' }
        },
        x: {
          ticks: { maxTicksLimit: 20, font: { size: 10 } },
          grid: { display: false }
        }
      }
    }
  });
})();

// ── 饼图 ──
(function(){
  const ctx = document.getElementById('pieChart');
  if (!ctx) return;
  new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: ['成功', '失败'],
      datasets: [{
        data: [STATS.ok, STATS.fail],
        backgroundColor: ['#22c55e','#ef4444'],
        borderColor: '#fff',
        borderWidth: 2,
        hoverBorderWidth: 3,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      cutout: '60%',
      plugins: {
        legend: {
          position: 'bottom',
          labels: { padding: 20, usePointStyle: true, pointStyleWidth: 10 }
        }
      }
    }
  });
})();

// ── Top 5 最慢任务 ──
(function(){
  const div = document.getElementById('top5List');
  if (TOP5.length === 0) {
    div.innerHTML = '<p class="all-ok">暂无数据</p>';
    return;
  }
  let html = '<table><tr><th>#</th><th>耗时</th><th>命令</th></tr>';
  TOP5.forEach((item, i) => {
    const warnClass = i === 0 ? 'fail-row' : '';
    html += '<tr class="' + warnClass + '">' +
            '<td>' + (i+1) + '</td>' +
            '<td><strong>' + item.time.toFixed(2) + 's</strong></td>' +
            '<td><code>' + escapeHTML(item.cmd) + '</code></td>' +
            '</tr>';
  });
  html += '</table>';
  div.innerHTML = html;
})();

// ── 失败任务列表 ──
(function(){
  const div = document.getElementById('failList');
  if (!FAILS || FAILS.length === 0) {
    div.innerHTML = '<p class="all-ok">🎉 全部成功，没有失败任务！</p>';
    return;
  }
  let html = '<table><tr><th>Seq</th><th>Exit Code</th><th>Command</th></tr>';
  FAILS.forEach(f => {
    html += '<tr class="fail-row">' +
            '<td>' + f.seq + '</td>' +
            '<td><strong>' + f.exit + '</strong></td>' +
            '<td><code>' + escapeHTML(f.cmd) + '</code></td>' +
            '</tr>';
  });
  html += '</table>';
  div.innerHTML = html;
})();

// ── 辅助函数：安全转义 HTML ──
function escapeHTML(str) {
  const el = document.createElement('span');
  el.textContent = str;
  return el.innerHTML;
}
</script>
</body>
</html>
HTML
}

# ─── 输出 ─────────────────────────────────────────────────
if [[ -n "$OUTPUT" ]]; then
    generate_html > "$OUTPUT"
    echo "✅ 报告已生成: $OUTPUT" >&2
    echo "   总任务: $TOTAL | 成功: $OK | 失败: $FAIL | 成功率: ${RATE}%" >&2
else
    generate_html
fi
