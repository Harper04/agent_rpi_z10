#!/usr/bin/env bash
# cron-runner.sh — Runs a task via the orchestrator agent on schedule and logs output.
#
# Usage in crontab:
#   0 3 * * *  /path/to/sysadmin-agent/scripts/cron/cron-runner.sh "upgrade --security-only --unattended"
#   0 6 * * *  /path/to/sysadmin-agent/scripts/cron/cron-runner.sh "health"

set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/../lib/common.sh" && common_init "$0"

TASK="$*"

# Load environment
safe_source

TIMESTAMP=$(date -Is)
LOG_FILE="$LOG_DIR/cron-$(date +%Y%m%d-%H%M%S).log"

echo "[$TIMESTAMP] Running scheduled task: $TASK" | tee "$LOG_FILE"

cd "$REPO_ROOT"
OUTPUT=$(claude --agent orchestrator -p "$TASK" --output-format text 2>&1) || true
echo "$OUTPUT" >> "$LOG_FILE"

# Notify via Telegram if configured
telegram_send "🕐 *Scheduled Task Complete*
Host: \`${HOSTNAME_SHORT}\`
Task: \`$TASK\`
\`\`\`
${OUTPUT:0:3900}
\`\`\`"

# Rotate logs: keep last 30 days
find "$LOG_DIR" -name "cron-*.log" -mtime +30 -delete 2>/dev/null || true

echo "[$TIMESTAMP] Task complete. Log: $LOG_FILE"
