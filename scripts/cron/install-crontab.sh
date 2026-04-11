#!/usr/bin/env bash
# install-crontab.sh — Atomically install the managed crontab from source of truth.
#
# Usage:
#   ./scripts/cron/install-crontab.sh              # install
#   ./scripts/cron/install-crontab.sh --diff        # show diff without applying
#   ./scripts/cron/install-crontab.sh --check       # exit 0 if in sync, 1 if drifted

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANAGED_FILE="$REPO_ROOT/scripts/cron/crontab.managed"

if [[ ! -f "$MANAGED_FILE" ]]; then
  echo "❌ Source of truth not found: $MANAGED_FILE"
  exit 1
fi

CURRENT=$(crontab -l 2>/dev/null || true)
DESIRED=$(cat "$MANAGED_FILE")

case "${1:-install}" in
  --diff)
    diff <(echo "$CURRENT") <(echo "$DESIRED") || true
    ;;
  --check)
    if diff -q <(echo "$CURRENT") <(echo "$DESIRED") >/dev/null 2>&1; then
      echo "✅ Crontab is in sync with $MANAGED_FILE"
      exit 0
    else
      echo "⚠️  Crontab has drifted from $MANAGED_FILE"
      diff <(echo "$CURRENT") <(echo "$DESIRED") || true
      exit 1
    fi
    ;;
  install|"")
    echo "$DESIRED" | crontab -
    echo "✅ Crontab installed from $MANAGED_FILE"
    ;;
  *)
    echo "Usage: $0 [--diff|--check|install]"
    exit 1
    ;;
esac
