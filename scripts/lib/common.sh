#!/usr/bin/env bash
# common.sh — Shared shell library for sysadmin-agent scripts.
# Source this file from any script: source "$(dirname "$0")/../lib/common.sh"
#
# Provides:
#   REPO_ROOT        — Absolute path to the repository root
#   ENV_FILE         — Path to local/.env
#   LOG_DIR          — Path to local/logs/
#   HOSTNAME_SHORT   — Short hostname of this machine
#   safe_source()    — Load .env without executing arbitrary code
#   stamp()          — ISO-ish timestamp for log lines
#   telegram_send()  — Send a Telegram message (silent no-op if unconfigured)
#   repo_root_from() — Derive REPO_ROOT from a script path

# ── Repo root detection ──────────────────────────────────────────────────────
# Called automatically when this file is sourced. Uses git if available,
# otherwise walks up from COMMON_SH_DIR (set by the sourcing script).
repo_root_from() {
  local script_path="$1"
  local dir
  dir="$(cd "$(dirname "$script_path")" && pwd)"
  # Walk up until we find CLAUDE.md (the repo marker)
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/CLAUDE.md" ]] && { echo "$dir"; return; }
    dir="$(dirname "$dir")"
  done
  # Fallback: git
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# The sourcing script should pass its own path:
#   source "$(dirname "$0")/../lib/common.sh" && common_init "$0"
# If not called, REPO_ROOT defaults to git or pwd.
common_init() {
  REPO_ROOT="$(repo_root_from "$1")"
  ENV_FILE="$REPO_ROOT/local/.env"
  LOG_DIR="$REPO_ROOT/local/logs"
  HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
  mkdir -p "$LOG_DIR"
}

# ── Safe .env loading ─────────────────────────────────────────────────────────
# Reads KEY=VALUE lines from a file without executing arbitrary shell code.
# Only exports lines matching ^[A-Z_][A-Z0-9_]*=
safe_source() {
  local env_file="${1:-$ENV_FILE}"
  [[ -f "$env_file" ]] || return 0
  while IFS='=' read -r key value; do
    # Strip inline comments and trailing whitespace
    value="${value%%#*}"
    value="${value%"${value##*[![:space:]]}"}"
    # Strip surrounding quotes
    if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    export "$key=$value"
  done < <(grep -E '^[A-Z_][A-Z0-9_]*=' "$env_file")
}

# ── Timestamp ─────────────────────────────────────────────────────────────────
stamp() { date '+%Y-%m-%d %H:%M:%S'; }

# ── Telegram ──────────────────────────────────────────────────────────────────
# Silent no-op if TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID are unset.
telegram_send() {
  local text="$1"
  [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]] && return 0
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d parse_mode="Markdown" \
    -d text="${text:0:4000}" >/dev/null 2>&1 || true
}
