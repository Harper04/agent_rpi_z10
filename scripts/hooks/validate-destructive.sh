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

# --- Safe-command whitelist (arguments are data, not executable) ---
SAFE_PREFIXES="^(sudo )?(git (commit|log|show|tag|stash|blame|diff|shortlog|describe|notes|archive)|echo |printf |cat |head |tail |less |more |wc |grep |rg |ag |find |man |which |type |file |stat )"

# --- Destructive patterns: Tier A (must appear as leading command) ---
CMD_POSITION_PATTERNS="^(sudo )?(shutdown|reboot|tailscale down)"

# --- Destructive patterns: Tier B (specific enough to match anywhere) ---
ANYWHERE_PATTERNS="rm -rf /($|[*]|var|etc|home|usr)"
ANYWHERE_PATTERNS+="|mkfs\."
ANYWHERE_PATTERNS+="|fdisk "
ANYWHERE_PATTERNS+="|dd if="
ANYWHERE_PATTERNS+="|iptables -(F|X)"
ANYWHERE_PATTERNS+="|ufw disable"
ANYWHERE_PATTERNS+="|systemctl (stop sshd|stop tailscaled|disable|mask)"
ANYWHERE_PATTERNS+="|apt (remove|purge|autoremove)"
ANYWHERE_PATTERNS+="|virsh (destroy|undefine)"
ANYWHERE_PATTERNS+="|docker system prune -a"
ANYWHERE_PATTERNS+="|docker volume rm"
ANYWHERE_PATTERNS+="|kubectl delete namespace"
ANYWHERE_PATTERNS+="|btrfs subvolume delete"
ANYWHERE_PATTERNS+="|chmod 777"
ANYWHERE_PATTERNS+="|crontab -r"

# Split command on chain/pipe operators, check each segment
SEGMENTS=$(echo "$COMMAND" | sed 's/ *&& */\n/g; s/ *|| */\n/g; s/ *; */\n/g; s/ *| */\n/g')

while IFS= read -r SEGMENT; do
  SEGMENT=$(echo "$SEGMENT" | sed 's/^[[:space:]]*//')
  [ -z "$SEGMENT" ] && continue

  # Safe commands: arguments are data, skip checks
  if echo "$SEGMENT" | grep -qEi "$SAFE_PREFIXES"; then
    continue
  fi

  # Tier A: command-position patterns
  if echo "$SEGMENT" | grep -qEi "$CMD_POSITION_PATTERNS"; then
    echo "🚫 BLOCKED: Destructive command detected: '$SEGMENT'. This requires explicit operator confirmation. Please ask the operator before proceeding." >&2
    exit 2
  fi

  # Tier B: specific patterns anywhere in segment
  if echo "$SEGMENT" | grep -qEi "$ANYWHERE_PATTERNS"; then
    echo "🚫 BLOCKED: Destructive command detected: '$SEGMENT'. This requires explicit operator confirmation. Please ask the operator before proceeding." >&2
    exit 2
  fi
done <<< "$SEGMENTS"

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
