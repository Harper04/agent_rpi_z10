#!/usr/bin/env bash
# Pre-ToolUse hook for Write/Edit: Backs up system config files before modification.
# Enforces CLAUDE.md Rule 5: "Before modifying a config file, copy it to
# <filename>.bak.<ISO-date> in the same directory."
#
# Only triggers for files OUTSIDE the repository (system config files).
# Receives JSON on stdin with tool_input containing the target file path.

set -euo pipefail

INPUT=$(cat)

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/../lib/common.sh" && common_init "$0"

FILE_PATH=$(jq -r '.tool_input.path // .tool_input.file_path // empty' <<< "$INPUT")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only back up files outside the repo (system config files)
case "$FILE_PATH" in
  "$REPO_ROOT"/*) exit 0 ;;  # Inside repo — skip
esac

# Only back up if the file already exists (new files don't need backup)
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Create backup
BACKUP="${FILE_PATH}.bak.$(date -I)"
if [ ! -f "$BACKUP" ]; then
  cp -p "$FILE_PATH" "$BACKUP" 2>/dev/null || true
fi

# Log the backup (only if we actually created one)
if [ -f "$BACKUP" ]; then
  echo "$(date -Is) $FILE_PATH -> $BACKUP" >> "$LOG_DIR/config-backups.log"
fi

exit 0
