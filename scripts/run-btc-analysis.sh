#!/bin/bash
#
# run-btc-analysis.sh
# Main orchestrator: fetch BTC data → run Codex analysis → send to DingTalk
#
# Usage:
#   ./run-btc-analysis.sh <report-type>
#
# Report types:
#   morning     - 09:00 Daily Morning Report
#   interval    - Every-2-hour interval update
#   weekly      - Sunday Weekly Summary
#
# Environment:
#   OPENAI_API_KEY         (required for codex exec in CI)
#   DINGTALK_WEBHOOK_URL   (required) - DingTalk bot webhook URL
#   DINGTALK_SECRET        (optional) - DingTalk webhook secret
#   CODEX_BIN              (optional) - Path to codex binary, defaults to "codex"
#   MODEL                  (optional) - Model name, defaults to "o3-mini"
#

set -euo pipefail

REPORT_TYPE="${1:?Usage: $0 <morning|interval|weekly>}"
CODEX_BIN="${CODEX_BIN:-codex}"
MODEL="${MODEL:-o3-mini}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORTS_DIR="$PROJECT_ROOT/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M)

# Validate report type
case "$REPORT_TYPE" in
  morning|interval|weekly) ;;
  *) echo "ERROR: Invalid report type: $REPORT_TYPE (must be: morning, interval, weekly)" >&2; exit 1 ;;
esac

mkdir -p "$REPORTS_DIR"

# ── Step 1: Fetch BTC data ──
echo "=== Step 1: Fetching BTC market data ===" >&2
BTC_DATA_FILE="/tmp/btc-data-$$.json"
"$PROJECT_ROOT/scripts/fetch-btc-data.sh" "$BTC_DATA_FILE"

# ── Step 2: Build the prompt ──
echo "=== Step 2: Building analysis prompt ===" >&2

# Read the system prompt template
PROMPT_FILE="$PROJECT_ROOT/prompts/${REPORT_TYPE}-report.md"
if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: Prompt template not found: $PROMPT_FILE" >&2
  exit 1
fi

SYSTEM_PROMPT=$(cat "$PROMPT_FILE")
BTC_DATA_JSON=$(cat "$BTC_DATA_FILE")

# Combine into full prompt
FULL_PROMPT=$(cat << PROMPT
${SYSTEM_PROMPT}

## BTC 实时市场数据

\`\`\`json
${BTC_DATA_JSON}
\`\`\`

请根据以上数据和你的交易教练角色，生成完整的报告。
请严格按照你的角色设定和报告格式输出，不要省略任何部分。
今天是 $(date '+%Y-%m-%d %A')，当前时间 $(date '+%H:%M') (Asia/Shanghai)。
PROMPT
)

# ── Step 3: Run Codex analysis ──
echo "=== Step 3: Running Codex analysis (model: $MODEL) ===" >&2
OUTPUT_FILE="$REPORTS_DIR/btc_${REPORT_TYPE}_${TIMESTAMP}.md"

echo "$FULL_PROMPT" | "$CODEX_BIN" exec \
  --dangerously-bypass-approvals-and-sandbox \
  --skip-git-repo-check \
  --ephemeral \
  -m "$MODEL" \
  -o "$OUTPUT_FILE" \
  -C "$PROJECT_ROOT" \
  -

if [ ! -f "$OUTPUT_FILE" ] || [ ! -s "$OUTPUT_FILE" ]; then
  echo "ERROR: Codex analysis produced no output" >&2
  exit 1
fi

echo "Report saved to: $OUTPUT_FILE" >&2

# ── Step 4: Send to DingTalk ──
echo "=== Step 4: Sending report to DingTalk ===" >&2

REPORT_TITLE=""
case "$REPORT_TYPE" in
  morning)  REPORT_TITLE="BTC 每日交易晨报 | $(date '+%Y-%m-%d')" ;;
  interval) REPORT_TITLE="BTC 行情更新 | $(date '+%Y-%m-%d %H:%M')" ;;
  weekly)   REPORT_TITLE="BTC 本周交易报告 | $(date '+%Y年第%V周')" ;;
esac

"$PROJECT_ROOT/scripts/send-to-dingtalk.sh" "$OUTPUT_FILE" "$REPORT_TITLE"

echo ""
echo "========================================" >&2
echo "✅ Complete: BTC ${REPORT_TYPE} report generated and sent." >&2
echo "   Report file: $OUTPUT_FILE" >&2
echo "========================================" >&2
