#!/usr/bin/env bash
# telegram-dispatch.sh — Polls Telegram for messages and dispatches to Claude Code
#
# Requirements:
#   - TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in local/.env
#   - claude CLI installed and authenticated
#   - jq installed
#
# Usage:
#   ./telegram-dispatch.sh              # Run in foreground (polling)
#   ./telegram-dispatch.sh --once       # Process one batch and exit (for cron)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/local/.env"
OFFSET_FILE="$REPO_ROOT/local/logs/telegram-offset"

# Load environment
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "❌ No local/.env found. Copy .env.example to local/.env and configure."
  exit 1
fi

: "${TELEGRAM_BOT_TOKEN:?Set TELEGRAM_BOT_TOKEN in local/.env}"
: "${TELEGRAM_CHAT_ID:?Set TELEGRAM_CHAT_ID in local/.env}"

POLL_INTERVAL="${POLL_INTERVAL:-5}"
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

mkdir -p "$(dirname "$OFFSET_FILE")"

# --- Functions ---

get_offset() {
  if [ -f "$OFFSET_FILE" ]; then
    cat "$OFFSET_FILE"
  else
    echo "0"
  fi
}

save_offset() {
  echo "$1" > "$OFFSET_FILE"
}

send_message() {
  local text="$1"
  text="${text:0:4000}"
  curl -s -X POST "$API/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d parse_mode="Markdown" \
    -d text="$text" > /dev/null 2>&1
}

process_message() {
  local text="$1"
  local from="$2"

  echo "[$(date -Is)] Received from $from: $text"
  send_message "⏳ Processing: \`${text:0:100}\`..."

  # Dispatch to Claude Code with orchestrator agent
  local output
  output=$(cd "$REPO_ROOT" && claude --agent orchestrator -p "$text" --output-format text 2>&1) || true

  if [ ${#output} -le 4000 ]; then
    send_message "✅ Done:
\`\`\`
${output:0:3900}
\`\`\`"
  else
    send_message "✅ Done (1/n):
\`\`\`
${output:0:3900}
\`\`\`"
    local offset=3900
    local part=2
    while [ $offset -lt ${#output} ]; do
      send_message "(${part}/n):
\`\`\`
${output:$offset:3900}
\`\`\`"
      offset=$((offset + 3900))
      part=$((part + 1))
      sleep 1
    done
  fi
}

poll() {
  local offset
  offset=$(get_offset)

  local response
  response=$(curl -s "$API/getUpdates?offset=$offset&timeout=30&allowed_updates=[\"message\"]")

  local count
  count=$(echo "$response" | jq '.result | length')

  if [ "$count" -gt 0 ]; then
    echo "$response" | jq -c '.result[]' | while read -r update; do
      local update_id chat_id text from_user

      update_id=$(echo "$update" | jq -r '.update_id')
      chat_id=$(echo "$update" | jq -r '.message.chat.id // empty')
      text=$(echo "$update" | jq -r '.message.text // empty')
      from_user=$(echo "$update" | jq -r '.message.from.username // .message.from.first_name // "unknown"')

      if [ "$chat_id" = "$TELEGRAM_CHAT_ID" ] && [ -n "$text" ]; then
        process_message "$text" "$from_user"
      else
        echo "[$(date -Is)] Ignored message from chat_id=$chat_id"
      fi

      save_offset "$((update_id + 1))"
    done
  fi
}

# --- Main ---

echo "[$(date -Is)] Telegram dispatcher starting"
echo "  Repo: $REPO_ROOT"
echo "  Chat ID: $TELEGRAM_CHAT_ID"
echo "  Mode: ${1:-polling}"

if [ "${1:-}" = "--once" ]; then
  poll
  echo "[$(date -Is)] Single poll complete"
  exit 0
fi

send_message "🤖 Sysadmin Agent online on \`$(hostname)\`"

while true; do
  poll
  sleep "$POLL_INTERVAL"
done
