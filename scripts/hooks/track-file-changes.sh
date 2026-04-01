#!/usr/bin/env bash
# Post-ToolUse hook for Write/Edit: Tracks which system files were modified.
# Maintains a list of changed files so the doc-update skill knows what to document.
#
# Receives JSON on stdin with tool_input (containing file path)

set -euo pipefail

INPUT=$(cat)

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/../lib/common.sh" && common_init "$0"

FILE_PATH=$(jq -r '.tool_input.path // .tool_input.file_path // empty' <<< "$INPUT")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

TRACKER="$LOG_DIR/changed-files.log"

# Only track files outside the docs/ directory (those are documentation itself)
if [[ "$FILE_PATH" != */docs/* ]]; then
  echo "$(date -Is) $FILE_PATH" >> "$TRACKER"
fi

# Keep last 100 entries (no sort — preserve chronological order)
if [ -f "$TRACKER" ] && [ "$(wc -l < "$TRACKER")" -gt 150 ]; then
  tail -100 "$TRACKER" > "$TRACKER.tmp" && mv "$TRACKER.tmp" "$TRACKER"
fi

exit 0
