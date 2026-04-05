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

# --- BLOCK (exit 2): Catastrophic / irreversible commands ---
# These are never safe to run unattended, even if the operator asked.
BLOCK_PATTERNS="rm -rf /($|[*]|var|etc|home|usr)"
BLOCK_PATTERNS+="|mkfs\."
BLOCK_PATTERNS+="|fdisk "
BLOCK_PATTERNS+="|dd if="
BLOCK_PATTERNS+="|iptables -(F|X)"
BLOCK_PATTERNS+="|chmod 777"
BLOCK_PATTERNS+="|crontab -r"
BLOCK_PATTERNS+="|virsh undefine"
BLOCK_PATTERNS+="|docker system prune -a"
BLOCK_PATTERNS+="|kubectl delete namespace"
BLOCK_PATTERNS+="|systemctl (stop sshd|stop tailscaled|mask)"
BLOCK_PATTERNS+="|tailscale down"

# --- WARN (log + allow): Operational commands ---
# The agent legitimately needs these when the operator requests them.
# Log to stderr so the agent sees the warning, but don't block.
WARN_PATTERNS="^(sudo )?(shutdown|reboot)"
WARN_ANYWHERE="virsh destroy"
WARN_ANYWHERE+="|systemctl (disable|stop)"
WARN_ANYWHERE+="|apt (remove|purge|autoremove)"
WARN_ANYWHERE+="|docker volume rm"
WARN_ANYWHERE+="|btrfs subvolume delete"
WARN_ANYWHERE+="|ufw disable"

# Split command on chain/pipe operators, check each segment
SEGMENTS=$(echo "$COMMAND" | sed 's/ *&& */\n/g; s/ *|| */\n/g; s/ *; */\n/g; s/ *| */\n/g')

while IFS= read -r SEGMENT; do
  SEGMENT=$(echo "$SEGMENT" | sed 's/^[[:space:]]*//')
  [ -z "$SEGMENT" ] && continue

  # Safe commands: arguments are data, skip checks
  if echo "$SEGMENT" | grep -qEi "$SAFE_PREFIXES"; then
    continue
  fi

  # BLOCK tier: hard stop
  if echo "$SEGMENT" | grep -qEi "$BLOCK_PATTERNS"; then
    echo "🚫 BLOCKED: Dangerous command detected: '$SEGMENT'. This is blocked even with operator confirmation." >&2
    exit 2
  fi

  # WARN tier: log but allow
  if echo "$SEGMENT" | grep -qEi "$WARN_PATTERNS"; then
    echo "⚠️  Operational command: '$SEGMENT' — proceeding (operator-initiated)." >&2
    continue
  fi
  if echo "$SEGMENT" | grep -qEi "$WARN_ANYWHERE"; then
    echo "⚠️  Operational command: '$SEGMENT' — proceeding (operator-initiated)." >&2
    continue
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
