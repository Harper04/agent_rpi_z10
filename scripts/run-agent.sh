#!/usr/bin/env bash
# run-agent.sh — Claude restart loop (runs inside tmux window)
# Loaded from scripts/start-agent.sh via tmux send-keys.

set -uo pipefail

REPO="/home/tomjaster/sysadmin-agent"
cd "$REPO"

# Load secrets into environment
if [[ -f local/.env ]]; then
    set -a
    # shellcheck source=/dev/null
    source local/.env
    set +a
fi

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

stamp() { date '+%Y-%m-%d %H:%M:%S'; }

echo -e "${GREEN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║      Sysadmin Claude Agent               ║${RESET}"
echo -e "${GREEN}║      ziegeleiweg-pi                      ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${RESET}"
echo ""

ATTEMPT=0
while true; do
    ATTEMPT=$((ATTEMPT + 1))
    echo -e "${GREEN}[$(stamp)] Starting claude (attempt #${ATTEMPT})...${RESET}"
    claude --dangerously-skip-permissions || true
    EXIT_CODE=$?
    echo -e "${YELLOW}[$(stamp)] Claude exited (code: ${EXIT_CODE}). Restarting in 5s...${RESET}"
    echo ""
    sleep 5
done
