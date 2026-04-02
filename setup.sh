#!/usr/bin/env bash
# setup.sh — First-time setup for sysadmin-agent on a new machine.
#
# Uses HTTPS + fine-grained PAT (no SSH keys needed on headless machines).
#
# Quickstart:
#   git clone https://github.com/harper04/agent-sysadmin.git ~/sysadmin-agent
#   cd ~/sysadmin-agent
#   ./setup.sh \
#     --origin https://github.com/harper04/sysadmin-rpi5-dad.git \
#     --token github_pat_XXXX
#
# What this does:
#   1. Renames clone remote: origin → upstream (template stays reachable)
#   2. Sets machine repo as new origin
#   3. Stores token in local/.env (gitignored, never committed)
#   4. Configures per-repo git credential helper (reads token from local/.env)
#   5. Seeds local/ from templates/local/ with machine identity
#
# Options:
#   --origin <url>            Machine-specific repo URL (HTTPS)
#   --token <pat>             GitHub fine-grained PAT (stored in local/.env only)
#   --telegram-token <token>  Telegram bot token (from @BotFather)
#   --name <hostname>         Override auto-detected hostname
#   --start                   Enable and start systemd service after setup
#   --force                   Re-seed local/ from templates even if it exists

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ORIGIN_URL=""
GITHUB_TOKEN=""
HOSTNAME_OVERRIDE=""
TELEGRAM_TOKEN=""
FORCE=false
START=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --origin)          ORIGIN_URL="$2"; shift 2 ;;
    --token)           GITHUB_TOKEN="$2"; shift 2 ;;
    --name)            HOSTNAME_OVERRIDE="$2"; shift 2 ;;
    --telegram-token)  TELEGRAM_TOKEN="$2"; shift 2 ;;
    --start)           START=true; shift ;;
    --force)           FORCE=true; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: ./setup.sh --origin <machine-repo-url> --token <github-pat> [options]

Options:
  --origin <url>            Machine repo URL (HTTPS, required on first run)
  --token <pat>             GitHub fine-grained PAT (stored in local/.env)
  --telegram-token <token>  Telegram bot token (from @BotFather)
  --name <hostname>         Override auto-detected hostname
  --start                   Enable and start systemd service after setup
  --force                   Re-seed local/ even if it exists

Example:
  git clone https://github.com/harper04/agent-sysadmin.git ~/sysadmin-agent
  cd ~/sysadmin-agent
  ./setup.sh \
    --origin https://github.com/harper04/sysadmin-rpi5-dad.git \
    --token github_pat_XXXXXXXXXXXX

Fine-grained PAT setup:
  https://github.com/settings/personal-access-tokens/new
  → Only select repositories: agent-sysadmin + sysadmin-<machine>
  → Permissions: Contents (Read and write)
EOF
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

MISSING=false
for cmd in git jq curl unzip; do
  if command -v "$cmd" &>/dev/null; then
    echo "  ✅ $cmd"
  else
    echo "  ❌ $cmd not found"
    MISSING=true
  fi
done

if [ "$MISSING" = true ]; then
  echo ""
  echo "Install missing prerequisites:"
  echo "  apt install -y jq curl git unzip"
  exit 1
fi

# --- Install GitHub CLI (gh) ---
echo ""
echo "Checking GitHub CLI..."

if command -v gh &>/dev/null; then
  echo "  ✅ gh $(gh --version | head -1 | awk '{print $4}')"
else
  echo "  ℹ️  gh not found — installing GitHub CLI..."
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt update -qq && sudo apt install -y gh
  if command -v gh &>/dev/null; then
    echo "  ✅ gh $(gh --version | head -1 | awk '{print $4}') installed"
  else
    echo "  ⚠️  gh install failed — GitHub PR creation will not work"
  fi
fi

# --- Install bun (required for Telegram channel MCP plugin) ---
echo ""
echo "Checking bun runtime..."

if command -v bun &>/dev/null || [ -x "$HOME/.bun/bin/bun" ]; then
  BUN_VER=$(${BUN_INSTALL:-$HOME/.bun}/bin/bun --version 2>/dev/null || bun --version)
  echo "  ✅ bun $BUN_VER"
else
  echo "  ℹ️  bun not found — installing (required for Telegram channel MCP)..."
  curl -fsSL https://bun.sh/install | bash 2>&1 | tail -3
  # Add to PATH for the rest of this script
  export PATH="$HOME/.bun/bin:$PATH"
  if command -v bun &>/dev/null; then
    echo "  ✅ bun $(bun --version) installed"
    echo "  ℹ️  Run: source ~/.bashrc   (or open a new shell) to get bun in PATH"
  else
    echo "  ❌ bun install failed — Telegram channel MCP will not start"
  fi
fi

# claude is optional at setup time (might install later)
if command -v claude &>/dev/null; then
  echo "  ✅ claude"
else
  echo "  ⚠️  claude not found (install before using agents)"
fi

# --- Claude Code onboarding (OAuth token + .claude.json) ---
echo ""
echo "Configuring Claude Code onboarding..."

CLAUDE_JSON="$HOME/.claude.json"

# Ensure hasCompletedOnboarding is set in ~/.claude.json
if [ -f "$CLAUDE_JSON" ]; then
  if jq -e '.hasCompletedOnboarding' "$CLAUDE_JSON" &>/dev/null; then
    echo "  ℹ️  ~/.claude.json already has hasCompletedOnboarding"
  else
    jq '. + {"hasCompletedOnboarding": true}' "$CLAUDE_JSON" > "${CLAUDE_JSON}.tmp" && mv "${CLAUDE_JSON}.tmp" "$CLAUDE_JSON"
    echo "  ✅ Added hasCompletedOnboarding: true to ~/.claude.json"
  fi
else
  echo '{"hasCompletedOnboarding": true}' > "$CLAUDE_JSON"
  echo "  ✅ Created ~/.claude.json with hasCompletedOnboarding: true"
fi

# Prompt for Claude Code OAuth token if not already in .bashrc
if grep -q "CLAUDE_CODE_OAUTH_TOKEN" "$HOME/.bashrc" 2>/dev/null; then
  echo "  ℹ️  CLAUDE_CODE_OAUTH_TOKEN already in ~/.bashrc"
else
  echo ""
  echo "  Claude Code requires an OAuth token for headless operation."
  echo "  On another machine with a browser, run:  claude setup-token"
  echo "  Then paste the token here (or press Enter to skip for now):"
  read -r -p "  CLAUDE_CODE_OAUTH_TOKEN= " CLAUDE_OAUTH_TOKEN
  if [ -n "$CLAUDE_OAUTH_TOKEN" ]; then
    echo "" >> "$HOME/.bashrc"
    echo "# Claude Code OAuth token (headless auth)" >> "$HOME/.bashrc"
    echo "export CLAUDE_CODE_OAUTH_TOKEN=\"$CLAUDE_OAUTH_TOKEN\"" >> "$HOME/.bashrc"
    export CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_OAUTH_TOKEN"
    echo "  ✅ CLAUDE_CODE_OAUTH_TOKEN added to ~/.bashrc and exported"
  else
    echo "  ⚠️  Skipped — add manually later:"
    echo "     echo 'export CLAUDE_CODE_OAUTH_TOKEN=<token>' >> ~/.bashrc && source ~/.bashrc"
  fi
fi

# --- Ensure git repo ---
if [ ! -d .git ]; then
  echo "  ❌ Not a git repository. Clone the template first:"
  echo "     git clone https://github.com/harper04/agent-sysadmin.git ~/sysadmin-agent"
  exit 1
fi

# --- Seed local/ from templates (before writing token) ---
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

# --- Store token in local/.env ---
if [ -n "$GITHUB_TOKEN" ]; then
  echo ""
  echo "Storing credentials in local/.env..."

  if [ -f local/.env ]; then
    # Update existing token
    if grep -q "^GITHUB_TOKEN=" local/.env; then
      sed -i "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=$GITHUB_TOKEN|" local/.env
    else
      echo "GITHUB_TOKEN=$GITHUB_TOKEN" >> local/.env
    fi
  else
    cp .env.example local/.env
    sed -i "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=$GITHUB_TOKEN|" local/.env
  fi

  echo "  ✅ Token stored in local/.env (gitignored)"

  # Clear token from shell history (best effort)
  unset HISTFILE 2>/dev/null || true
fi

# --- Store Telegram token ---
if [ -n "$TELEGRAM_TOKEN" ]; then
  echo ""
  echo "Storing Telegram bot token..."

  # Write to local/.env
  if [ -f local/.env ]; then
    if grep -q "^TELEGRAM_BOT_TOKEN=" local/.env; then
      sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN|" local/.env
    else
      echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN" >> local/.env
    fi
  fi

  # Sync to ~/.claude/channels/telegram/.env (where the MCP plugin reads it)
  TELE_ENV="${HOME}/.claude/channels/telegram/.env"
  mkdir -p "$(dirname "$TELE_ENV")"
  if grep -q "TELEGRAM_BOT_TOKEN=" "$TELE_ENV" 2>/dev/null; then
    sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN|" "$TELE_ENV"
  else
    printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_TOKEN" >> "$TELE_ENV"
  fi
  chmod 600 "$TELE_ENV"

  echo "  ✅ Telegram token stored in local/.env and ~/.claude/channels/telegram/.env"
fi

# --- Configure git credential helper ---
echo ""
echo "Configuring git credential helper..."

CRED_HELPER="$(pwd)/scripts/git/git-credential-local-env.sh"
chmod +x "$CRED_HELPER"

# Set as LOCAL (per-repo) credential helper — never touches global git config
git config --local credential.helper "$CRED_HELPER"
# Disable other credential helpers for this repo to avoid token prompts
git config --local credential.useHttpPath true

echo "  ✅ Per-repo credential helper configured"
echo "  ℹ️  Token is read from local/.env at git-push/pull time"
echo "  ℹ️  No token in URLs, no token in global git config"

# --- Verify token works (if token was provided) ---
if [ -n "$GITHUB_TOKEN" ]; then
  echo ""
  echo "Verifying GitHub access..."
  GH_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    "https://api.github.com/user" 2>/dev/null || echo -e "\n000")
  HTTP_CODE=$(tail -1 <<< "$GH_RESPONSE")
  GH_BODY=$(head -n -1 <<< "$GH_RESPONSE")

  if [ "$HTTP_CODE" = "200" ]; then
    GH_USER=$(jq -r '.login // "unknown"' <<< "$GH_BODY")
    echo "  ✅ Token valid — authenticated as: $GH_USER"

    # Authenticate gh CLI with the same token
    if command -v gh &>/dev/null; then
      echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null \
        && echo "  ✅ gh CLI authenticated as: $GH_USER" \
        || echo "  ⚠️  gh auth failed — authenticate manually: gh auth login"
    fi
  elif [ "$HTTP_CODE" = "401" ]; then
    echo "  ❌ Token invalid (HTTP 401). Check your PAT."
    echo "     Create a new one: https://github.com/settings/personal-access-tokens/new"
  else
    echo "  ⚠️  Could not verify token (HTTP $HTTP_CODE). Continuing anyway."
  fi
fi

# --- Configure git remotes ---
echo ""
echo "Configuring git remotes..."

CURRENT_ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")

if [ -n "$ORIGIN_URL" ]; then
  # Rename current origin → upstream (template)
  if [ -n "$CURRENT_ORIGIN" ] && [ "$CURRENT_ORIGIN" != "$ORIGIN_URL" ]; then
    if git remote get-url upstream &>/dev/null; then
      echo "  ℹ️  upstream already set: $(git remote get-url upstream)"
    else
      git remote rename origin upstream
      echo "  ✅ Renamed origin → upstream (template): $CURRENT_ORIGIN"
    fi
  fi

  # Set machine repo as origin
  if git remote get-url origin &>/dev/null; then
    git remote set-url origin "$ORIGIN_URL"
  else
    git remote add origin "$ORIGIN_URL"
  fi
  echo "  ✅ origin (machine): $ORIGIN_URL"
else
  if ! git remote get-url upstream &>/dev/null; then
    echo "  ⚠️  No --origin given. On first run, provide:"
    echo "     ./setup.sh --origin https://github.com/harper04/sysadmin-<machine>.git --token <pat>"
  fi
fi

echo ""
echo "  Remotes:"
git remote -v | sed 's/^/    /'

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
  sed -i \
    -e "s/# Machine: TODO-HOSTNAME/# Machine: $HOST/" \
    -e "s/| Hostname         | \`TODO\`/| Hostname         | \`$HOST\`/" \
    -e "s/| OS               | Ubuntu Server 24.04 LTS/| OS               | $OS/" \
    -e "s/| Architecture     | \`TODO\` (aarch64 \/ x86_64)/| Architecture     | \`$ARCH\`/" \
    -e "s/| Primary IP       | \`TODO\`/| Primary IP       | \`$PRIMARY_IP\`/" \
    -e "s/| Tailscale IP     | \`TODO\`/| Tailscale IP     | \`$TS_IP\`/" \
    -e "s/| SSH Port         | \`TODO\`/| SSH Port         | \`$SSH_PORT\`/" \
    -e "s#| Git origin       | \`TODO\`#| Git origin       | \`$ORIGIN_DISPLAY\`#" \
    -e "s#| Git upstream     | \`TODO\`#| Git upstream     | \`$UPSTREAM_DISPLAY\`#" \
    "$LOCAL_MD"
  echo "  ✅ local/CLAUDE.local.md populated"
fi

# --- Ensure local/.env has all fields ---
if [ -f local/.env ]; then
  # Add missing fields from template
  for key in TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID POLL_INTERVAL; do
    if ! grep -q "^${key}=" local/.env; then
      grep "^${key}=" .env.example >> local/.env 2>/dev/null || true
    fi
  done
fi

# --- Make scripts executable ---
find scripts/ -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
chmod +x setup.sh

# --- Install Claude Code Telegram plugin ---
if command -v claude &>/dev/null; then
  echo ""
  echo "Installing Claude Code Telegram plugin..."
  if claude plugin install telegram@claude-plugins-official --yes 2>/dev/null; then
    echo "  ✅ Telegram plugin installed"
  else
    echo "  ⚠️  Plugin install failed or already installed — skipping"
    echo "     Manual: claude plugin install telegram@claude-plugins-official"
  fi
else
  echo ""
  echo "  ⚠️  claude not installed — skipping Telegram plugin install"
  echo "     After installing Claude Code, run:"
  echo "     claude plugin install telegram@claude-plugins-official"
fi

# --- Install cron jobs ---
echo ""
echo "Installing cron jobs..."

CRONTAB_EXAMPLE="scripts/cron/crontab.example"
REPO_PATH="$(pwd)"

if [ -f "$CRONTAB_EXAMPLE" ]; then
  # Build the new entries with correct repo path substituted
  NEW_ENTRIES=$(sed "s|%REPO_PATH%|${REPO_PATH}|g" "$CRONTAB_EXAMPLE")

  # Get existing crontab (empty string if none)
  EXISTING=$(crontab -l 2>/dev/null || true)

  # Merge: append only entries whose script path isn't already in the crontab
  ADDED=0
  MERGED="$EXISTING"
  while IFS= read -r line; do
    # Skip blank lines and comment lines for dedup check
    [[ -z "$line" || "$line" =~ ^# || "$line" =~ ^SHELL= || "$line" =~ ^PATH= ]] && continue
    # Extract the script path from the cron line (last whitespace-separated token)
    script_path=$(echo "$line" | awk '{print $NF}')
    if [[ "$EXISTING" == *"$script_path"* ]]; then
      echo "  ℹ️  Already installed: $script_path"
    else
      if [ $ADDED -eq 0 ] && [ -n "$MERGED" ]; then
        MERGED="${MERGED}"$'\n'
      fi
      MERGED="${MERGED}${line}"$'\n'
      ADDED=$((ADDED + 1))
      echo "  ✅ Added: $script_path"
    fi
  done <<< "$NEW_ENTRIES"

  if [ $ADDED -gt 0 ]; then
    echo "$MERGED" | crontab -
    echo "  ✅ Crontab updated ($ADDED new job(s) added)"
  else
    echo "  ℹ️  All cron jobs already installed"
  fi
else
  echo "  ⚠️  $CRONTAB_EXAMPLE not found — skipping"
fi

# --- Install systemd service ---
echo ""
echo "Installing systemd service..."

SERVICE_TEMPLATE="scripts/agent/sysadmin-agent.service"
SERVICE_TARGET="/etc/systemd/system/sysadmin-agent.service"

if [ -f "$SERVICE_TEMPLATE" ]; then
  sed -e "s|%USER%|$USER|g" \
      -e "s|%REPO_PATH%|${REPO_PATH}|g" \
      -e "s|%HOME%|$HOME|g" \
      -e "s|%HOSTNAME%|$HOST|g" \
      "$SERVICE_TEMPLATE" > /tmp/sysadmin-agent.service

  if sudo -n true 2>/dev/null; then
    sudo cp /tmp/sysadmin-agent.service "$SERVICE_TARGET"
    sudo systemctl daemon-reload
    sudo systemctl enable sysadmin-agent
    loginctl enable-linger "$USER" 2>/dev/null || true
    echo "  ✅ systemd service installed and enabled"
    if [ "$START" = true ]; then
      sudo systemctl start sysadmin-agent
      echo "  ✅ sysadmin-agent started"
    fi
  else
    echo "  ⚠️  No passwordless sudo — install manually:"
    echo "     sudo cp /tmp/sysadmin-agent.service $SERVICE_TARGET"
    echo "     sudo systemctl daemon-reload && sudo systemctl enable --now sysadmin-agent"
    echo "     loginctl enable-linger $USER"
  fi
  rm -f /tmp/sysadmin-agent.service
else
  echo "  ⚠️  $SERVICE_TEMPLATE not found — skipping"
fi

# --- Initial commit ---
git add -A
git commit -m "chore: initialize sysadmin-agent for $HOST" 2>/dev/null || true

echo ""
echo "======================================"
echo "✅ Setup complete for $HOST!"
echo ""
echo "Next steps:"
echo "  1. git push -u origin main                                    # Push to machine repo"
echo "  2. source ~/.bashrc                                           # Reload PATH + Claude OAuth token"
if [ "$START" = true ]; then
echo "  3. Agent is running! Pair Telegram:"
else
echo "  3. Start the agent:"
echo "     sudo systemctl start sysadmin-agent"
echo "  4. Pair Telegram:"
fi
echo "     - DM the bot on Telegram → get pairing code"
echo "     - tmux attach -t sysadmin-agent"
echo "     > /telegram:access pair <code>                             # Link your Telegram ID"
echo "     > /telegram:access policy allowlist                        # Lock down access"
echo "     > /inventory                                               # First system scan"
echo ""
echo "Service management:"
echo "  - Status:  systemctl status sysadmin-agent"
echo "  - Logs:    journalctl -u sysadmin-agent -f"
echo "  - Attach:  tmux attach -t sysadmin-agent"
echo ""
echo "Token management:"
echo "  - GitHub token: local/.env (never committed, never in URLs)"
echo "  - Rotate: update GITHUB_TOKEN in local/.env"
echo ""
