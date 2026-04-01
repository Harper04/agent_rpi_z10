#!/usr/bin/env bash
# Post-ToolUse hook for Bash: Logs executed commands to a session log.
# This creates an audit trail that the doc-update skill uses.
#
# Receives JSON on stdin with tool_input.command and tool_output

set -euo pipefail

INPUT=$(cat)

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/../lib/common.sh" && common_init "$0"

read -r COMMAND EXIT_CODE < <(jq -r '[.tool_input.command // "", .tool_output.exit_code // "unknown"] | @tsv' <<< "$INPUT")

if [ -z "$COMMAND" ]; then
  exit 0
fi

LOG_FILE="$LOG_DIR/session-log.jsonl"

# Append structured log entry
jq -nc \
  --arg ts "$(date -Is)" \
  --arg cmd "$COMMAND" \
  --arg exit "$EXIT_CODE" \
  --arg host "$(hostname)" \
  '{timestamp: $ts, hostname: $host, command: $cmd, exit_code: $exit}' \
  >> "$LOG_FILE"

# Keep session log from growing unbounded (last 500 entries)
if [ "$(wc -l < "$LOG_FILE")" -gt 500 ]; then
  tail -300 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

exit 0
