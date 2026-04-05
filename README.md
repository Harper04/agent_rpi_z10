# Sysadmin Agent

An autonomous Linux system operator powered by [Claude Code](https://docs.anthropic.com/claude-code). Manages servers via Telegram or CLI — handles upgrades, reverse proxy, DNS, containers, VMs, backups, and documentation automatically.

One template repo, N machines. Each machine gets its own repo cloned from the template, with shared agents/skills synced via git.

## How it works

```
You (Telegram / CLI)
        |
  +-----v------------------------------------------+
  |  Orchestrator Agent                             |
  |  Routes tasks to specialized sub-agents         |
  +-------------------------------------------------+
  |  Sub-Agents        Skills          Hooks        |
  |  system-updater    app-install     pre: validate|
  |  caddy             health-check   pre: backup   |
  |  docker            dns-record     post: track   |
  |  k3s               caddy-onboard  post: log     |
  |  kvm               doc-update                   |
  |  tailscale         rollback                     |
  |  backup            notify                       |
  +-------------------------------------------------+
```

The orchestrator receives tasks via Telegram or CLI, delegates to the right sub-agent, verifies the result, documents everything, and reports back.

## Supported platforms

- Debian 12+ / Ubuntu 22.04+
- amd64, arm64
- systemd, apt

## Quick start

### Prerequisites

- A Linux server (Debian/Ubuntu)
- [Claude Code](https://docs.anthropic.com/claude-code) installed
- A GitHub account with two repos: one for the template, one for this machine

### 1. Create a GitHub PAT

Go to [github.com/settings/personal-access-tokens/new](https://github.com/settings/personal-access-tokens/new):

- **Name:** your machine hostname
- **Expiration:** 90 days (use `/rotate-token` to renew)
- **Repository access:** select the template repo + your machine repo
- **Permissions:** Contents: Read and write

### 2. Create an empty machine repo on GitHub

Create `sysadmin-<hostname>` — completely empty (no README, no .gitignore).

### 3. Clone and setup

```bash
git clone https://github.com/you/sysadmin-agent.git ~/sysadmin-agent
cd ~/sysadmin-agent

./setup.sh \
  --origin https://github.com/you/sysadmin-<hostname>.git \
  --token github_pat_XXXX

git push -u origin main
source ~/.bashrc
```

`setup.sh` will:
- Rename the clone remote to `upstream`, set your machine repo as `origin`
- Store the token in `local/.env` (gitignored)
- Configure a per-repo git credential helper
- Seed `local/` from `templates/local/` with your machine's identity
- Install `bun` (runtime for the Telegram plugin)
- Install the Claude Code Telegram plugin

### 4. Set up Telegram

Create a bot via [@BotFather](https://t.me/BotFather) on Telegram, then:

```bash
claude
# In the session:
/telegram:configure <bot-token>
```

Start the agent with Telegram connected:

```bash
claude --channels plugin:telegram@claude-plugins-official --agent orchestrator
```

Send the bot a DM, then pair with the code it returns:

```
/telegram:access pair <code>
/telegram:access policy allowlist
```

### 5. Run as a service

```bash
./setup.sh --start
# or manually:
sudo systemctl enable --now sysadmin-agent
```

The systemd service runs the agent in a tmux session with automatic restart and crash alerting.

## Usage

### Via Telegram

Send natural language messages to your bot:

```
"Run a security update"
"What services are failing?"
"Add a reverse proxy for grafana on port 3000"
"Show disk usage"
```

### Via CLI

```bash
claude --agent orchestrator                              # interactive
claude --agent orchestrator -p "show failed services"    # one-shot
claude --agent caddy -p "add upstream for grafana"       # direct sub-agent
```

### Commands

| Command         | Description                              |
|-----------------|------------------------------------------|
| `/status`       | Quick system overview                    |
| `/health`       | Health check with issue flagging         |
| `/upgrade`      | System upgrade with safety checks        |
| `/install`      | Interactive app installation             |
| `/dns`          | Manage Route53 DNS records               |
| `/inventory`    | Full system inventory scan               |
| `/sync`         | Pull updates from the template repo      |
| `/contribute`   | Propose improvements back to template    |
| `/rotate-token` | Renew the GitHub PAT                     |

## Repository model

```
Template repo (upstream)              Machine repo (origin)
sysadmin-agent                        sysadmin-mini-core
+----------------------+              +--------------------------+
| .claude/agents/      |---clone--->  | .claude/agents/          |
| .claude/skills/      |              | .claude/skills/          |
| .claude/commands/    |              | .claude/commands/        |
| scripts/             |              | scripts/                 |
| docs/recipes/        |              | docs/recipes/            |
| docs/examples/       |              | docs/examples/           |
| templates/local/     |              | templates/local/         |
| CLAUDE.md            |              | CLAUDE.md                |
|                      |              |                          |
| (no local/)          |  <-- /sync   | local/  <-- ONLY here    |
|                      |              | +-- CLAUDE.local.md      |
|                      |  /contribute | +-- docs/                |
|                      |  ----------> | +-- dns/                 |
+----------------------+              | +-- dashboard/           |
                                      | +-- .env (gitignored)   |
                                      +--------------------------+
```

### 3-tier content model

| Tier | Directory | Where | Purpose |
|------|-----------|-------|---------|
| 1 | `templates/local/` | Template repo | Seed files with placeholders. Copied to `local/` by `setup.sh`. Bug fixes synced via `/sync`. |
| 2 | `docs/examples/` | Template repo | Sanitized real-world docs from actual machines. Reference only. |
| 3 | `local/` | Machine repo only | Live configs, real hostnames/IPs. Never in the template. |

### Keeping machines in sync

```bash
/sync              # Pull shared updates from template into machine repo
/contribute        # Push universal improvements from machine back to template
```

## Agents

| Agent | Purpose | Key capabilities |
|-------|---------|-----------------|
| **orchestrator** | Central router | Task routing, health checks, documentation, Telegram replies |
| **system-updater** | OS updates | Security patches, full upgrades, kernel management, reboot scheduling |
| **caddy** | Reverse proxy | Site management, TLS certs, auth portal, user management |
| **docker** | Containers | Docker/Compose lifecycle, image updates, volume management |
| **k3s** | Kubernetes | Deployments, manifests, troubleshooting |
| **kvm** | Virtual machines | Creation, snapshots, networking, resource allocation |
| **tailscale** | Mesh VPN | Node management, ACLs, exit nodes, subnet routing |
| **backup** | Backups | btrfs snapshots, rsync, verification, restore |

Sub-agents can be overridden per machine by placing a file in `local/agents/`.

## App recipes

Ready-to-use installation recipes in `docs/recipes/`:

| Recipe | Description |
|--------|-------------|
| `caddy.md` | Reverse proxy with auth portal |
| `adguard-home.md` | DNS server via Podman Quadlet |
| `cockpit.md` | Web-based system admin behind Caddy auth |
| `dashboard.md` | System dashboard (Bun + Alpine.js) |
| `route53-dns.md` | File-based AWS Route53 DNS management |
| `home-assistant.md` | Home Assistant OS in a KVM VM |
| `unifi-os-server.md` | UniFi OS via Podman |
| `zerotier.md` | ZeroTier mesh VPN |
| `gitea.md` | Self-hosted Git server |

Use `/install <app>` to run a recipe interactively.

## Scheduled tasks

| Schedule | Task | Agent |
|----------|------|-------|
| Daily 02:00 | btrfs snapshot + prune | backup |
| Daily 03:00 | Security update check | system-updater |
| Weekly Sun 04:00 | Full system upgrade | system-updater |
| Daily 06:00 | Health check | orchestrator |
| Weekly Mon 05:00 | Backup verification | backup |
| Monthly 1st 05:30 | Full inventory refresh | orchestrator |

Cron tasks run via `scripts/cron/cron-runner.sh` which invokes the orchestrator in headless mode.

## Directory structure

```
.
+-- CLAUDE.md                  # Agent system prompt and rules
+-- README.md                  # This file
+-- setup.sh                   # Machine onboarding script
+-- .gitignore
+-- .env.example               # Template for local/.env
|
+-- .claude/
|   +-- agents/                # Sub-agent definitions
|   +-- skills/                # Reusable task templates
|   +-- commands/              # Slash command definitions
|   +-- settings.json          # Permissions and hooks
|
+-- scripts/
|   +-- agent/                 # Agent lifecycle (start, run, systemd)
|   +-- caddy/                 # Caddy helper scripts
|   +-- cron/                  # Scheduled task runner
|   +-- dns/                   # Route53 sync and dynamic DNS
|   +-- git/                   # Upstream sync and contribute
|   +-- hooks/                 # Pre/post tool-use hooks
|   +-- lib/                   # Shared shell library
|
+-- docs/
|   +-- conventions.md         # Cross-agent rules
|   +-- recipes/               # App installation recipes
|   +-- examples/apps/         # Sanitized reference docs (Tier 2)
|   +-- apps/_template.md      # Template for app documentation
|   +-- runbooks/_template.md  # Template for runbooks
|
+-- templates/
|   +-- local/                 # Seed files for new machines (Tier 1)
|
+-- local/                     # Machine-specific (not in template, Tier 3)
    +-- CLAUDE.local.md        # Machine identity and overrides
    +-- .env                   # Secrets (gitignored)
    +-- agents/                # Local agent overrides
    +-- dashboard/             # System dashboard source
    +-- dns/                   # DNS records and config
    +-- docs/                  # Machine documentation
    |   +-- apps/              # Per-app docs
    |   +-- system/            # System state docs
    |   +-- changelog.md       # Append-only change log
    |   +-- conventions.md     # Machine-specific conventions
    +-- logs/                  # Runtime logs (gitignored)
    +-- systemd/               # Machine-specific service units
```

## Safety rules

1. **Document everything** — every change is logged in `local/docs/changelog.md`
2. **Git commit after every logical unit** — conventional commits
3. **No destructive commands without confirmation** — unless in unattended mode
4. **Dry-run first** — for upgrades, config changes, and service restarts
5. **Rollback plan** — configs backed up to `<file>.bak.<date>` before modification
6. **Shared improvements** — universal fixes contributed upstream via `/contribute`

## Token security

| Location | Token present? |
|----------|---------------|
| `local/.env` | Yes (gitignored) |
| Git remote URLs | Never |
| Global `~/.gitconfig` | Never |
| `git remote -v` output | Never |
| Git commit history | Never |

## License

MIT
