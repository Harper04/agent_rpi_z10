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

# Load environment (.env for Telegram tokens, GitHub PAT, etc.)
safe_source

# ── Resolve claude binary ────────────────────────────────────────────────────
# Cron runs with a minimal PATH that doesn't include user-local installs.
# Claude Code is typically installed to ~/.local/bin (native installer) or
# ~/.npm-global/bin (npm). We also need CLAUDE_CODE_OAUTH_TOKEN from ~/.bashrc.
CRON_USER_HOME=$(eval echo "~$(whoami)")

# Expand PATH for common install locations
for p in "$CRON_USER_HOME/.local/bin" "$CRON_USER_HOME/.npm-global/bin" "/usr/local/bin"; do
  [[ -d "$p" ]] && [[ ":$PATH:" != *":$p:"* ]] && export PATH="$p:$PATH"
done

# Source CLAUDE_CODE_OAUTH_TOKEN if not already set (lives in ~/.bashrc)
if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
  # Extract just the token export line — don't source the whole .bashrc
  token_line=$(grep -m1 '^export CLAUDE_CODE_OAUTH_TOKEN=' "$CRON_USER_HOME/.bashrc" 2>/dev/null || true)
  [[ -n "$token_line" ]] && eval "$token_line"
fi

# Verify claude is reachable
if ! command -v claude &>/dev/null; then
  echo "ERROR: claude binary not found in PATH=$PATH" >&2
  telegram_send "❌ *Cron task failed*
Host: \`${HOSTNAME_SHORT}\`
Task: \`$TASK\`
Error: \`claude\` not found in PATH"
  exit 1
fi

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
