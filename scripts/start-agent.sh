#!/usr/bin/env bash
# start-agent.sh — systemd entrypoint for the Claude sysadmin agent
#
# Creates (and monitors) a tmux session named "sysadmin-agent".
# Designed for: Type=simple in systemd — this script never exits.
#
# Attach manually:   tmux attach -t sysadmin-agent
# Agent window:      window 0 "agent"   — claude restart loop
# Shell window:      window 1 "shell"   — spare interactive shell

set -uo pipefail

SESSION="sysadmin-agent"
REPO="/home/tomjaster/sysadmin-agent"

setup_session() {
    echo "[$(date -Is)] Creating tmux session '${SESSION}'..."

    # Fresh start
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    sleep 1

    # Create session with agent window (detached, sized for readability)
    tmux new-session -d -s "$SESSION" -n "agent" -x 200 -y 50

    # ── Status bar ────────────────────────────────────────────────
    tmux set-option -t "$SESSION" status on
    tmux set-option -t "$SESSION" status-interval 10
    tmux set-option -t "$SESSION" status-style        "bg=colour235,fg=colour250"
    tmux set-option -t "$SESSION" status-left         "#[bold,fg=colour46] sysadmin-agent #[fg=colour244] │ "
    tmux set-option -t "$SESSION" status-right        "#[fg=colour244]ziegeleiweg-pi │ #[fg=colour250]%H:%M "
    tmux set-option -t "$SESSION" window-status-current-style "fg=colour46,bold"
    tmux set-option -t "$SESSION" pane-border-style   "fg=colour238"
    tmux set-option -t "$SESSION" pane-active-border-style "fg=colour46"
    # ─────────────────────────────────────────────────────────────

    # Window 0: claude restart loop
    tmux send-keys -t "${SESSION}:agent" \
        "bash ${REPO}/scripts/run-agent.sh" Enter

    # Window 1: spare interactive shell
    tmux new-window -t "$SESSION" -n "shell"
    tmux send-keys -t "${SESSION}:shell" "cd ${REPO}" Enter

    # Focus agent window
    tmux select-window -t "${SESSION}:agent"

    echo "[$(date -Is)] Session ready. Attach with: tmux attach -t ${SESSION}"
}

# ── Main: create session, then watch it ──────────────────────────
setup_session

while true; do
    sleep 15
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        echo "[$(date -Is)] Session '${SESSION}' disappeared — recreating..."
        setup_session
    fi
done
