#!/usr/bin/env bash
# run-agent.sh — Claude restart loop (runs inside tmux window)
# Loaded from scripts/start-agent.sh via tmux send-keys.

set -uo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh" && common_init "$0"
cd "$REPO_ROOT"

# Load secrets into environment
safe_source

# ── Single-instance lock ──────────────────────────────────────────────────────
PIDFILE="${LOG_DIR}/run-agent.pid"

if [[ -f "$PIDFILE" ]]; then
    old_pid=$(<"$PIDFILE")
    if kill -0 "$old_pid" 2>/dev/null; then
        echo "[$(stamp)] Another run-agent.sh is already running (PID $old_pid). Exiting."
        exit 1
    fi
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

# ── Ensure Telegram plugin can read its token ─────────────────────────────────
# Plugin-spawned MCP servers don't inherit the parent env block, so the plugin
# reads its token from ~/.claude/channels/telegram/.env. Sync it from local/.env
# if missing so the plugin always starts correctly.
TELE_ENV="${HOME}/.claude/channels/telegram/.env"
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    mkdir -p "$(dirname "$TELE_ENV")"
    if ! grep -q "TELEGRAM_BOT_TOKEN=" "$TELE_ENV" 2>/dev/null; then
        printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_BOT_TOKEN" >> "$TELE_ENV"
        chmod 600 "$TELE_ENV"
    fi
fi

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

# ── Log rotation ──────────────────────────────────────────────────────────────
LOG_FILE="$LOG_DIR/agent.log"
MAX_LOG_BYTES=1048576  # 1 MB
MAX_LOG_ROTATIONS=3

mkdir -p "$LOG_DIR"

rotate_log() {
    [[ -f "$LOG_FILE" ]] || return
    local size
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
    if (( size >= MAX_LOG_BYTES )); then
        for i in $(seq $((MAX_LOG_ROTATIONS - 1)) -1 1); do
            [[ -f "${LOG_FILE}.${i}" ]] && mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i+1))"
        done
        mv "$LOG_FILE" "${LOG_FILE}.1"
    fi
}

log() {
    local msg="$1"
    echo -e "$msg"
    echo "[$(stamp)] $msg" >> "$LOG_FILE"
}

CRASH_ALERT_THRESHOLD=3

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${GREEN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║      Sysadmin Claude Agent               ║${RESET}"
echo -e "${GREEN}║      ${HOSTNAME_SHORT}$(printf '%*s' $((30 - ${#HOSTNAME_SHORT})) '')║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${RESET}"
echo ""

# ── Backoff table: consecutive failures → sleep seconds ──────────────────────
# 0-1 failures: 5s, 2: 15s, 3+: 60s
backoff_sleep() {
    local fails=$1
    if   (( fails <= 1 )); then echo 5
    elif (( fails == 2 )); then echo 15
    else                        echo 60
    fi
}

# A run is considered "stable" if it lasted at least this many seconds
STABLE_UPTIME_SECS=30

ATTEMPT=0
CONSECUTIVE_FAILURES=0

# ── Startup notification ──────────────────────────────────────────────────────
telegram_send "🟢 *sysadmin-agent* started on \`${HOSTNAME_SHORT}\` ($(date '+%Y-%m-%d %H:%M UTC'))"

while true; do
    ATTEMPT=$((ATTEMPT + 1))
    rotate_log

    log "${GREEN}[$(stamp)] Starting claude (attempt #${ATTEMPT}, consecutive failures: ${CONSECUTIVE_FAILURES})...${RESET}"

    START_TS=$(date +%s)
    # Run claude against the tmux PTY so it detects an interactive terminal.
    # Wrapper log messages are written via log(); tmux pipe-pane (set up in
    # start-agent.sh) captures the full window output to the log file.
    claude --dangerously-skip-permissions || true
    EXIT_CODE=$?
    END_TS=$(date +%s)
    UPTIME=$(( END_TS - START_TS ))

    if (( UPTIME >= STABLE_UPTIME_SECS )); then
        # Ran long enough — treat as clean exit, reset failure count
        CONSECUTIVE_FAILURES=0
        log "${YELLOW}[$(stamp)] Claude exited after ${UPTIME}s (code: ${EXIT_CODE}). Restarting in 5s...${RESET}"
        sleep 5
    else
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        SLEEP=$(backoff_sleep "$CONSECUTIVE_FAILURES")
        log "${RED}[$(stamp)] Claude crashed after ${UPTIME}s (code: ${EXIT_CODE}). Failure #${CONSECUTIVE_FAILURES}. Restarting in ${SLEEP}s...${RESET}"

        if (( CONSECUTIVE_FAILURES == CRASH_ALERT_THRESHOLD )); then
            telegram_send "⚠️ *sysadmin-agent* on \`${HOSTNAME_SHORT}\` has crashed ${CONSECUTIVE_FAILURES} times in a row (last exit code: ${EXIT_CODE}). Check \`tmux attach -t sysadmin-agent\`."
        fi

        sleep "$SLEEP"
    fi

    echo ""
done
