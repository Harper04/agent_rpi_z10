#!/usr/bin/env bash
# Pre-ToolUse hook: Blocks dangerous bash commands.
# Exit code 0 = allow, Exit code 2 = block (message fed back to Claude)
#
# Receives JSON on stdin with tool_input.command

set -euo pipefail

INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")

if [ -z "$COMMAND" ]; then
  exit 0
fi

# --- Destructive command patterns (single combined regex) ---
BLOCKED_REGEX="rm -rf /($|[*]|var|etc|home|usr)"
BLOCKED_REGEX+="|mkfs\."
BLOCKED_REGEX+="|fdisk "
BLOCKED_REGEX+="|dd if="
BLOCKED_REGEX+="|shutdown|reboot"
BLOCKED_REGEX+="|tailscale down"
BLOCKED_REGEX+="|iptables -(F|X)"
BLOCKED_REGEX+="|ufw disable"
BLOCKED_REGEX+="|systemctl (stop sshd|stop tailscaled|disable|mask)"
BLOCKED_REGEX+="|apt (remove|purge|autoremove)"
BLOCKED_REGEX+="|virsh (destroy|undefine)"
BLOCKED_REGEX+="|docker system prune -a"
BLOCKED_REGEX+="|docker volume rm"
BLOCKED_REGEX+="|kubectl delete namespace"
BLOCKED_REGEX+="|btrfs subvolume delete"
BLOCKED_REGEX+="|chmod 777"
BLOCKED_REGEX+="|crontab -r"

if grep -qEi "$BLOCKED_REGEX" <<< "$COMMAND"; then
  echo "🚫 BLOCKED: Destructive command detected: '$COMMAND'. This requires explicit operator confirmation. Please ask the operator before proceeding." >&2
  exit 2
fi

exit 0
