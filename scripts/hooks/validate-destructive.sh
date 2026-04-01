#!/usr/bin/env bash
# Pre-ToolUse hook: Blocks dangerous bash commands.
# Exit code 0 = allow, Exit code 2 = block (message fed back to Claude)
#
# Receives JSON on stdin with tool_input.command

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# --- Destructive command patterns ---
BLOCKED_PATTERNS=(
  # Filesystem destruction
  "rm -rf /"
  "rm -rf /\*"
  "rm -rf /var"
  "rm -rf /etc"
  "rm -rf /home"
  "rm -rf /usr"
  "mkfs\."
  "fdisk "
  "dd if="
  # System control
  "shutdown"
  "reboot"
  # Network / access lockout
  "tailscale down"
  "iptables -F"
  "iptables -X"
  "ufw disable"
  "systemctl stop sshd"
  "systemctl stop tailscaled"
  "systemctl disable"
  "systemctl mask"
  # Package management
  "apt remove"
  "apt purge"
  "apt autoremove"
  # Virtualisation
  "virsh destroy"
  "virsh undefine"
  # Containers
  "docker system prune -a"
  "docker volume rm"
  "kubectl delete namespace"
  # Storage
  "btrfs subvolume delete"
  # Dangerous permission / cron changes
  "chmod 777"
  "crontab -r"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qEi "$pattern"; then
    echo "🚫 BLOCKED: Destructive command detected: '$COMMAND'. This requires explicit operator confirmation. Please ask the operator before proceeding." >&2
    exit 2
  fi
done

exit 0
