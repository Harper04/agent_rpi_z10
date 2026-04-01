#!/usr/bin/env bash
# Post-ToolUse hook for Write/Edit: Tracks which system files were modified.
# Maintains a list of changed files so the doc-update skill knows what to document.
#
# Receives JSON on stdin with tool_input (containing file path)

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // .tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TRACKER="$REPO_ROOT/local/logs/changed-files.log"

mkdir -p "$(dirname "$TRACKER")"

# Only track files outside the docs/ directory (those are documentation itself)
if [[ "$FILE_PATH" != */docs/* ]]; then
  echo "$(date -Is) $FILE_PATH" >> "$TRACKER"
fi

# Deduplicate and keep last 100 entries
if [ -f "$TRACKER" ] && [ "$(wc -l < "$TRACKER")" -gt 100 ]; then
  sort -u "$TRACKER" | tail -100 > "$TRACKER.tmp" && mv "$TRACKER.tmp" "$TRACKER"
fi

exit 0
