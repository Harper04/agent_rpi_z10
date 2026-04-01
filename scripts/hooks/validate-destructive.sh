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
  "rm -rf /"
  "rm -rf /*"
  "mkfs\."
  "fdisk "
  "dd if="
  "shutdown"
  "reboot"
  "tailscale down"
  "apt remove"
  "apt purge"
  "apt autoremove"
  "systemctl disable"
  "systemctl mask"
  "virsh destroy"
  "virsh undefine"
  "docker system prune -a"
  "docker volume rm"
  "kubectl delete namespace"
  "btrfs subvolume delete"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qEi "$pattern"; then
    echo "🚫 BLOCKED: Destructive command detected: '$COMMAND'. This requires explicit operator confirmation. Please ask the operator before proceeding." >&2
    exit 2
  fi
done

exit 0
