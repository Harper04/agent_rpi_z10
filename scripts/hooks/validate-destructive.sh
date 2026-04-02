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

# --- git push upstream branch: scan diff for credentials ---
if echo "$COMMAND" | grep -qE "git push upstream "; then
  BRANCH=$(echo "$COMMAND" | grep -oP '(?<=git push upstream )\S+')

  # Block pushes to main/master (belt-and-suspenders — also in deny list)
  if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
    echo "🚫 BLOCKED: Direct push to upstream/${BRANCH} is not allowed. Use a feature branch." >&2
    exit 2
  fi

  # Scan the diff about to be pushed for actual credential values.
  # Matches token/key formats, not variable references like ${VARNAME}.
  DIFF=$(git diff "upstream/main...${BRANCH}" 2>/dev/null || true)
  CRED_PATTERN='(sk-ant-[A-Za-z0-9_-]{20,}|gh[ps]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|[0-9]{8,10}:[A-Za-z0-9_-]{35}|(password|secret|api_key|token)\s*=\s*[^${\s#"'"'"'][^\s]+)'
  HITS=$(echo "$DIFF" | grep -Pn "^\+.*${CRED_PATTERN}" 2>/dev/null || true)

  if [ -n "$HITS" ]; then
    echo "🚫 BLOCKED: Possible credentials found in diff for upstream/${BRANCH}:" >&2
    echo "$HITS" | head -10 >&2
    echo "Review the above lines and remove secrets before pushing." >&2
    exit 2
  fi
fi

exit 0
