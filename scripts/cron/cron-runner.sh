#!/usr/bin/env bash
# cron-runner.sh — Runs a Claude Code command on schedule and logs output.
#
# Usage in crontab:
#   0 3 * * *  /home/tom/sysadmin-agent/scripts/cron/cron-runner.sh "system-upgrade --security-only --unattended"
#   0 6 * * *  /home/tom/sysadmin-agent/scripts/cron/cron-runner.sh "health-check"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/local/.env"
LOG_DIR="$REPO_ROOT/local/logs"
TASK="$*"

# Load environment
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

mkdir -p "$LOG_DIR"

TIMESTAMP=$(date -Is)
LOG_FILE="$LOG_DIR/cron-$(date +%Y%m%d-%H%M%S).log"

echo "[$TIMESTAMP] Running scheduled task: $TASK" | tee "$LOG_FILE"

cd "$REPO_ROOT"
OUTPUT=$(claude --agent orchestrator -p "/$(echo "$TASK")" --output-format text 2>&1) || true
echo "$OUTPUT" >> "$LOG_FILE"

# Notify via Telegram if configured
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  SUMMARY="${OUTPUT:0:3900}"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d parse_mode="Markdown" \
    -d text="🕐 *Scheduled Task Complete*
Host: \`$(hostname)\`
Task: \`$TASK\`
\`\`\`
$SUMMARY
\`\`\`" > /dev/null 2>&1 || true
fi

# Rotate logs: keep last 30 days
find "$LOG_DIR" -name "cron-*.log" -mtime +30 -delete 2>/dev/null || true

echo "[$TIMESTAMP] Task complete. Log: $LOG_FILE"
