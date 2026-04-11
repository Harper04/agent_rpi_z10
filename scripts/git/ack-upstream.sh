#!/usr/bin/env bash
# ack-upstream.sh — Acknowledge an upstream commit as reviewed & intentionally skipped.
#
# Appends the hash + reason to local/.sync-ack so sync-upstream.sh
# stops reporting it as an unreviewed pending change.
#
# Usage:
#   ./scripts/git/ack-upstream.sh <hash> "reason"
#
# Example:
#   ./scripts/git/ack-upstream.sh ef97c21 "safe equivalent applied locally in 07d004d"

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

ACK_FILE="local/.sync-ack"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <hash> \"reason\""
  echo ""
  echo "  <hash>    Short or full upstream commit hash to acknowledge"
  echo "  <reason>  Why this commit is intentionally not applied"
  echo ""
  echo "Example:"
  echo "  $0 ef97c21 \"safe equivalent applied locally in 07d004d\""
  exit 1
fi

HASH="$1"
REASON="$2"
TODAY="$(date -I)"

# Verify the hash exists in upstream
if ! git cat-file -e "${HASH}^{commit}" 2>/dev/null; then
  echo "⚠️  Hash '$HASH' not found in repo. Fetching upstream..."
  git fetch upstream 2>/dev/null || true
  if ! git cat-file -e "${HASH}^{commit}" 2>/dev/null; then
    echo "❌ Hash '$HASH' still not found after fetch. Check the hash and try again."
    exit 1
  fi
fi

# Normalize to short hash (7 chars)
SHORT_HASH="$(git rev-parse --short=7 "$HASH")"

# Check for duplicate
if grep -q "^${SHORT_HASH}" "$ACK_FILE" 2>/dev/null; then
  echo "ℹ️  $SHORT_HASH is already acknowledged in $ACK_FILE"
  grep "^${SHORT_HASH}" "$ACK_FILE"
  exit 0
fi

# Show what we're acknowledging
COMMIT_MSG="$(git log --oneline -1 "$HASH" 2>/dev/null || echo "(commit message unavailable)")"
echo "📝 Acknowledging: $COMMIT_MSG"
echo "   Reason: $REASON"

# Append to ack file
echo "${SHORT_HASH}  # ${TODAY} — ${REASON}" >> "$ACK_FILE"

echo "✅ Added to $ACK_FILE"

# Commit the ack file
if git diff --quiet "$ACK_FILE"; then
  echo "ℹ️  No changes to commit (already staged or identical)."
else
  git add "$ACK_FILE"
  git commit -m "chore(sync): ack upstream $SHORT_HASH — $REASON"
  echo "✅ Committed."
fi
