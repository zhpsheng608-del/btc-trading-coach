#!/bin/bash
#
# fetch-btc-data.sh
# Fetch BTC market data from public APIs (no API key required)
# Outputs JSON to stdout
#

set -euo pipefail

OUTPUT="${1:-}"
_exit() { local rc=$?; [ -n "$OUTPUT" ] && mv /tmp/btc-data-$$.json "$OUTPUT" 2>/dev/null || true; exit $rc; }
trap _exit EXIT

# --- Binance Public API ---
BINANCE="https://api.binance.com/api/v3"
BINANCE_FUTURES="https://fapi.binance.com/futures/data"

echo "{\"fetched_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" > /tmp/btc-data-$$.json

# 1. Current price & 24hr stats
PRICE_DATA=$(curl -sf "$BINANCE/ticker/24hr?symbol=BTCUSDT" 2>/dev/null || echo "{}")
echo "," >> /tmp/btc-data-$$.json
echo "\"price_24hr\": $PRICE_DATA" >> /tmp/btc-data-$$.json

# 2. Daily klines (last 90 days for 3-day / daily / 4h analysis)
KLINES=$(curl -sf "$BINANCE/klines?symbol=BTCUSDT&interval=1d&limit=90" 2>/dev/null || echo "[]")
echo "," >> /tmp/btc-data-$$.json
echo "\"daily_klines_90d\": $KLINES" >> /tmp/btc-data-$$.json

# 3. 4-hour klines (last 30)
KLINE_4H=$(curl -sf "$BINANCE/klines?symbol=BTCUSDT&interval=4h&limit=30" 2>/dev/null || echo "[]")
echo "," >> /tmp/btc-data-$$.json
echo "\"kline_4h_30\": $KLINE_4H" >> /tmp/btc-data-$$.json

# 4. Funding rate
FUNDING=$(curl -sf "$BINANCE_FUTURES/fundingRate?symbol=BTCUSDT&limit=24" 2>/dev/null || echo "[]")
echo "," >> /tmp/btc-data-$$.json
echo "\"funding_rate\": $FUNDING" >> /tmp/btc-data-$$.json

# 5. Fear & Greed Index
FNG=$(curl -sf "https://api.alternative.me/fng/?limit=7" 2>/dev/null || echo "{}")
echo "," >> /tmp/btc-data-$$.json
echo "\"fear_greed_index\": $FNG" >> /tmp/btc-data-$$.json

# 6. CoinGecko BTC data
CG=$(curl -sf "https://api.coingecko.com/api/v3/coins/bitcoin?localization=false&tickers=false&community_data=false&developer_data=false" 2>/dev/null || echo "{}")
echo "," >> /tmp/btc-data-$$.json
echo "\"coingecko_data\": $CG" >> /tmp/btc-data-$$.json

# Close JSON
echo "}" >> /tmp/btc-data-$$.json

# Validate JSON
python3 -m json.tool /tmp/btc-data-$$.json > /dev/null 2>&1 || {
  echo "ERROR: Invalid JSON generated" >&2
  exit 1
}

[ -n "$OUTPUT" ] && cp /tmp/btc-data-$$.json "$OUTPUT"
cat /tmp/btc-data-$$.json
