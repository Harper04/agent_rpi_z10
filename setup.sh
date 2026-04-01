#!/usr/bin/env bash
# setup.sh — First-time setup for sysadmin-agent on a new machine.
#
# This script:
# 1. Checks prerequisites
# 2. Populates local/CLAUDE.local.md with machine identity
# 3. Sets up git remotes (upstream template + machine origin)
# 4. Creates local/.env from template
# 5. Runs initial git commit
#
# Usage:
#   ./setup.sh
#   ./setup.sh --upstream <template-repo-url> --origin <machine-repo-url>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

UPSTREAM_URL=""
ORIGIN_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upstream) UPSTREAM_URL="$2"; shift 2 ;;
    --origin)   ORIGIN_URL="$2"; shift 2 ;;
    *)          echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🤖 Sysadmin Agent — First-Time Setup"
echo "======================================"

# --- Check prerequisites ---
echo ""
echo "Checking prerequisites..."

check_cmd() {
  if command -v "$1" &>/dev/null; then
    echo "  ✅ $1 found: $(command -v "$1")"
  else
    echo "  ❌ $1 not found — please install it"
    MISSING=true
  fi
}

MISSING=false
check_cmd git
check_cmd jq
check_cmd claude
check_cmd curl

if [ "$MISSING" = true ]; then
  echo ""
  echo "Install missing prerequisites and re-run this script."
  echo "  apt install -y jq curl git"
  echo "  npm install -g @anthropic-ai/claude-code"
  exit 1
fi

# --- Git init & remotes ---
echo ""
echo "Setting up git..."

if [ ! -d .git ]; then
  git init
fi

if [ -n "$UPSTREAM_URL" ]; then
  if git remote get-url upstream &>/dev/null; then
    git remote set-url upstream "$UPSTREAM_URL"
  else
    git remote add upstream "$UPSTREAM_URL"
  fi
  echo "  ✅ upstream remote: $UPSTREAM_URL"
fi

if [ -n "$ORIGIN_URL" ]; then
  if git remote get-url origin &>/dev/null; then
    git remote set-url origin "$ORIGIN_URL"
  else
    git remote add origin "$ORIGIN_URL"
  fi
  echo "  ✅ origin remote: $ORIGIN_URL"
fi

echo "  Current remotes:"
git remote -v | sed 's/^/    /'

# --- Seed local/ from templates ---
echo ""
echo "Seeding local/ from templates/local/..."

if [ ! -f local/CLAUDE.local.md ]; then
  # First run: copy entire template tree into local/
  cp -rn templates/local/* local/ 2>/dev/null || true
  cp -rn templates/local/.* local/ 2>/dev/null || true
  echo "  ✅ local/ seeded from templates/local/"
else
  echo "  ℹ️  local/ already exists — skipping seed (run with --force to re-seed)"
fi

# Ensure directories exist even if template was incomplete
mkdir -p local/docs/system local/docs/apps local/docs/runbooks local/agents local/logs

# --- Fill machine identity ---
echo ""
echo "Populating machine identity..."

HOSTNAME=$(hostname -f 2>/dev/null || hostname)
ARCH=$(uname -m)
KERNEL=$(uname -r)
OS=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -o)
PRIMARY_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
TS_IP=$(tailscale ip -4 2>/dev/null || echo "not configured")
SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
ORIGIN_DISPLAY=$(git remote get-url origin 2>/dev/null || echo "not set")
UPSTREAM_DISPLAY=$(git remote get-url upstream 2>/dev/null || echo "not set")

echo "  Hostname:     $HOSTNAME"
echo "  Arch:         $ARCH"
echo "  OS:           $OS"
echo "  Kernel:       $KERNEL"
echo "  Primary IP:   $PRIMARY_IP"
echo "  Tailscale:    $TS_IP"
echo "  SSH Port:     $SSH_PORT"

# Update local/CLAUDE.local.md
LOCAL_MD="local/CLAUDE.local.md"
if [ -f "$LOCAL_MD" ]; then
  sed -i "s/# Machine: TODO-HOSTNAME/# Machine: $HOSTNAME/" "$LOCAL_MD"
  sed -i "s/| Hostname         | \`TODO\`/| Hostname         | \`$HOSTNAME\`/" "$LOCAL_MD"
  sed -i "s/| OS               | Ubuntu Server 24.04 LTS/| OS               | $OS/" "$LOCAL_MD"
  sed -i "s/| Architecture     | \`TODO\` (aarch64 \/ x86_64)/| Architecture     | \`$ARCH\`/" "$LOCAL_MD"
  sed -i "s/| Primary IP       | \`TODO\`/| Primary IP       | \`$PRIMARY_IP\`/" "$LOCAL_MD"
  sed -i "s/| Tailscale IP     | \`TODO\`/| Tailscale IP     | \`$TS_IP\`/" "$LOCAL_MD"
  sed -i "s/| SSH Port         | \`TODO\`/| SSH Port         | \`$SSH_PORT\`/" "$LOCAL_MD"
  sed -i "s|| Git origin       | \`TODO\`|| Git origin       | \`$ORIGIN_DISPLAY\`|" "$LOCAL_MD"
  sed -i "s|| Git upstream     | \`TODO\`|| Git upstream     | \`$UPSTREAM_DISPLAY\`|" "$LOCAL_MD"
  echo "  ✅ local/CLAUDE.local.md populated"
fi

# --- Environment file ---
if [ ! -f local/.env ]; then
  echo ""
  echo "Creating local/.env from template..."
  cp .env.example local/.env
  echo "  ⚠️  Edit local/.env with your Telegram bot token and chat ID:"
  echo "     nano local/.env"
fi

# --- Make scripts executable ---
chmod +x scripts/hooks/*.sh scripts/telegram-bot/telegram-dispatch.sh scripts/cron/cron-runner.sh scripts/git/*.sh 2>/dev/null || true

# --- Initial commit ---
git add -A
git commit -m "chore: setup sysadmin-agent for $HOSTNAME" 2>/dev/null || true

echo ""
echo "======================================"
echo "✅ Setup complete for $HOSTNAME!"
echo ""
echo "Next steps:"
echo "  1. Edit local/.env with Telegram credentials"
echo "  2. Run: claude --agent orchestrator"
echo "  3. In the session, type: /inventory"
echo "  4. Start Telegram bot:"
echo "     sudo cp scripts/telegram-bot/sysadmin-agent-telegram.service /etc/systemd/system/"
echo "     sudo systemctl enable --now sysadmin-agent-telegram"
echo "  5. Set up cron: crontab scripts/cron/crontab.example"
echo ""
echo "Git workflow:"
echo "  - Your changes commit to 'origin' (this machine's fork)"
echo "  - Shared improvements: /contribute → pushes branch to 'upstream'"
echo "  - Pull shared updates:  /sync → merges from upstream/main"
echo ""
