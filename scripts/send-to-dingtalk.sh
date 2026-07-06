#!/bin/bash
#
# send-to-dingtalk.sh
# Send a Markdown report to DingTalk group via webhook robot
#
# Usage: ./send-to-dingtalk.sh <markdown_file> [title]
#
# Environment:
#   DINGTALK_WEBHOOK_URL (required) - DingTalk bot webhook URL
#   DINGTALK_SECRET       (optional) - HMAC-SHA256 secret for signed webhooks
#

set -euo pipefail

MARKDOWN_FILE="${1:?Usage: $0 <markdown_file> [title]}"
TITLE="${2:-BTC 交易分析报告}"

if [ ! -f "$MARKDOWN_FILE" ]; then
  echo "ERROR: File not found: $MARKDOWN_FILE" >&2
  exit 1
fi

: "${DINGTALK_WEBHOOK_URL:?DINGTALK_WEBHOOK_URL is required}"

# Use Python to handle all the logic (signing, sending, error checking)
python3 -c "
import sys, json, time, hmac, hashlib, base64, urllib.request, urllib.parse, os

# Read the markdown file
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    lines = f.read()
    if len(lines) > 19000:
        lines = lines[:19000] + '\n\n...（报告过长，已截断）'

# Get webhook URL and secret
webhook_url = os.environ.get('DINGTALK_WEBHOOK_URL', '')
secret = os.environ.get('DINGTALK_SECRET', '')
title = sys.argv[2] if len(sys.argv) > 2 else 'BTC 交易分析报告'

# Build the payload
payload = {
    'msgtype': 'markdown',
    'markdown': {
        'title': title,
        'text': lines
    }
}

# Build final URL
if secret:
    timestamp = str(round(time.time() * 1000))
    string_to_sign = timestamp + '\n' + secret
    signature = hmac.new(secret.encode('utf-8'), string_to_sign.encode('utf-8'), digestmod=hashlib.sha256).digest()
    sign = base64.b64encode(signature).decode('utf-8')
    url = webhook_url + '&timestamp=' + timestamp + '&sign=' + urllib.parse.quote(sign, safe='')
else:
    url = webhook_url

# Send request
data = json.dumps(payload, ensure_ascii=False).encode('utf-8')
req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json; charset=utf-8'})
response = urllib.request.urlopen(req)
result = json.loads(response.read().decode('utf-8'))
if result.get('errcode') == 0:
    print('SUCCESS: Report sent to DingTalk ({0} chars).'.format(len(lines)))
    sys.exit(0)
else:
    print('ERROR: ' + result.get('errmsg', 'unknown'), file=sys.stderr)
    sys.exit(1)
" "$MARKDOWN_FILE" "$TITLE"
