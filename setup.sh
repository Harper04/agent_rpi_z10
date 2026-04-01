#!/usr/bin/env bash
# setup.sh — First-time setup for sysadmin-agent on a new machine.
#
# Workflow (no GitHub fork required):
#
#   1. You have ONE template repo:  github.com/you/sysadmin-agent
#   2. Per machine, create an EMPTY repo: github.com/you/sysadmin-rpi5-dad
#   3. On the machine:
#        git clone github.com/you/sysadmin-agent ~/sysadmin-agent
#        cd ~/sysadmin-agent
#        ./setup.sh --origin git@github.com:you/sysadmin-rpi5-dad.git
#
#   This renames the clone's default remote to 'upstream' and adds
#   your machine-specific repo as 'origin'. From then on:
#     - git push              → pushes to origin (machine repo, includes local/)
#     - /sync                 → pulls shared updates from upstream
#     - /contribute           → proposes changes back to upstream
#
# Options:
#   --origin <url>    Machine-specific repo (required on first run)
#   --name <hostname> Override auto-detected hostname
#   --force           Re-seed local/ from templates even if it exists

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ORIGIN_URL=""
HOSTNAME_OVERRIDE=""
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --origin)  ORIGIN_URL="$2"; shift 2 ;;
    --name)    HOSTNAME_OVERRIDE="$2"; shift 2 ;;
    --force)   FORCE=true; shift ;;
    -h|--help)
      echo "Usage: $0 --origin <machine-repo-url> [--name <hostname>] [--force]"
      echo ""
      echo "Example:"
      echo "  git clone git@github.com:you/sysadmin-agent.git ~/sysadmin-agent"
      echo "  cd ~/sysadmin-agent"
      echo "  ./setup.sh --origin git@github.com:you/sysadmin-rpi5-dad.git"
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (use --help)"; exit 1 ;;
  esac
done

echo "🤖 Sysadmin Agent — First-Time Setup"
echo "======================================"

# --- Check prerequisites ---
echo ""
echo "Checking prerequisites..."

check_cmd() {
  if command -v "$1" &>/dev/null; then
    echo "  ✅ $1"
  else
    echo "  ❌ $1 not found"
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
  echo "Install missing prerequisites:"
  echo "  apt install -y jq curl git"
  echo "  npm install -g @anthropic-ai/claude-code"
  exit 1
fi

# --- Configure git remotes ---
#
# After cloning the template, 'origin' points to the template repo.
# We rename that to 'upstream' and set the machine repo as 'origin'.

echo ""
echo "Configuring git remotes..."

if [ ! -d .git ]; then
  echo "  ❌ Not a git repository. Clone the template first:"
  echo "     git clone <template-repo-url> ~/sysadmin-agent"
  exit 1
fi

# Detect: is this a fresh clone of the template? (origin still points to template)
CURRENT_ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")

if [ -n "$ORIGIN_URL" ]; then
  # Rename current origin → upstream (if it exists and isn't already the machine repo)
  if [ -n "$CURRENT_ORIGIN" ] && [ "$CURRENT_ORIGIN" != "$ORIGIN_URL" ]; then
    if git remote get-url upstream &>/dev/null; then
      echo "  ℹ️  upstream already set: $(git remote get-url upstream)"
    else
      git remote rename origin upstream
      echo "  ✅ Renamed origin → upstream: $CURRENT_ORIGIN"
    fi
  fi

  # Set origin to machine-specific repo
  if git remote get-url origin &>/dev/null; then
    git remote set-url origin "$ORIGIN_URL"
  else
    git remote add origin "$ORIGIN_URL"
  fi
  echo "  ✅ origin set to: $ORIGIN_URL"
else
  # No --origin given: check if remotes are already configured
  if ! git remote get-url upstream &>/dev/null; then
    echo "  ⚠️  No upstream remote and no --origin given."
    echo "     On first run, provide: ./setup.sh --origin <machine-repo-url>"
    echo "     This will rename the template remote to 'upstream' automatically."
  fi
fi

echo ""
echo "  Remotes:"
git remote -v | sed 's/^/    /'

# --- Seed local/ from templates ---
echo ""
echo "Seeding local/ from templates/local/..."

if [ ! -f local/CLAUDE.local.md ] || $FORCE; then
  mkdir -p local
  cp -r templates/local/* local/ 2>/dev/null || true
  echo "  ✅ local/ seeded from templates/local/"
else
  echo "  ℹ️  local/ already exists (use --force to re-seed)"
fi

mkdir -p local/docs/system local/docs/apps local/docs/runbooks local/agents local/logs

# --- Fill machine identity ---
echo ""
echo "Populating machine identity..."

HOST="${HOSTNAME_OVERRIDE:-$(hostname -f 2>/dev/null || hostname)}"
ARCH=$(uname -m)
KERNEL=$(uname -r)
OS=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -o)
PRIMARY_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
TS_IP=$(tailscale ip -4 2>/dev/null || echo "not configured")
SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
ORIGIN_DISPLAY=$(git remote get-url origin 2>/dev/null || echo "not set")
UPSTREAM_DISPLAY=$(git remote get-url upstream 2>/dev/null || echo "not set")

echo "  Hostname:     $HOST"
echo "  Arch:         $ARCH"
echo "  OS:           $OS"
echo "  Primary IP:   $PRIMARY_IP"
echo "  Tailscale:    $TS_IP"

LOCAL_MD="local/CLAUDE.local.md"
if [ -f "$LOCAL_MD" ]; then
  sed -i "s/# Machine: TODO-HOSTNAME/# Machine: $HOST/" "$LOCAL_MD"
  sed -i "s/| Hostname         | \`TODO\`/| Hostname         | \`$HOST\`/" "$LOCAL_MD"
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
  cp .env.example local/.env
  echo "  ⚠️  Created local/.env — edit with Telegram credentials:"
  echo "     nano local/.env"
fi

# --- Make scripts executable ---
find scripts/ -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
chmod +x setup.sh

# --- Initial commit & push ---
git add -A
git commit -m "chore: initialize sysadmin-agent for $HOST" 2>/dev/null || true

echo ""
echo "======================================"
echo "✅ Setup complete for $HOST!"
echo ""
echo "Next steps:"
echo "  1. nano local/.env                   # Telegram credentials"
echo "  2. git push -u origin main           # Push to machine repo"
echo "  3. claude --agent orchestrator       # Start agent"
echo "     > /inventory                       # First system scan"
echo ""
echo "Optional:"
echo "  4. sudo cp scripts/telegram-bot/sysadmin-agent-telegram.service /etc/systemd/system/"
echo "     sudo systemctl enable --now sysadmin-agent-telegram"
echo "  5. crontab scripts/cron/crontab.example"
echo ""
