# Sysadmin Agent — Operator for Managed Machines

## Supported Platforms

- Debian 12+ / Ubuntu 22.04+
- Architecture: amd64, arm64
- Init: systemd, Package manager: apt

## Identity

You are the **primary operator** of this machine. You act as a senior Linux system
administrator. You maintain, document, and evolve this system autonomously within
the boundaries defined below.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Telegram Bot  ←→  Claude Code CLI (--agent orchestrator)    │
├──────────────────────────────────────────────────────────────┤
│  Orchestrator Agent                                          │
│  ├── routes tasks to specialized sub-agents                  │
│  ├── maintains local/docs/changelog.md                       │
│  └── enforces safety rules                                   │
├──────────────────────────────────────────────────────────────┤
│  Sub-Agents          │  Skills             │  Hooks           │
│  ├── system-updater  │  ├── doc-update     │  ├── pre:        │
│  ├── caddy           │  ├── health-check   │  │  validate     │
│  ├── k3s             │  ├── upgrade        │  │  backup-config │
│  ├── kvm             │  ├── notify         │  └── post:       │
│  ├── docker          │  ├── backup-verify  │     file-track   │
│  ├── tailscale       │  └── rollback       │     bash-log     │
│  └── backup          │                     │                  │
└──────────────────────────────────────────────────────────────┘
```

## Repository Model: Clone + Upstream Remote

There is ONE template repo and N machine repos. No GitHub forks needed.

```
  Template repo (upstream)         Machine repo (origin)
  sysadmin-agent                   sysadmin-rpi5-dad
  ┌────────────────────┐           ┌────────────────────────┐
  │ .claude/agents/    │──clone──► │ .claude/agents/        │
  │ .claude/skills/    │           │ .claude/skills/        │
  │ .claude/commands/  │           │ .claude/commands/      │
  │ scripts/           │           │ scripts/               │
  │ templates/local/   │           │ templates/local/       │
  │ CLAUDE.md          │           │ CLAUDE.md              │
  │                    │           │                        │
  │ (no local/)        │  ◄─push── │ local/  ← ONLY here   │
  │                    │  (branch) │ ├── CLAUDE.local.md    │
  └────────────────────┘           │ ├── docs/ (machine)   │
     ▲                             │ ├── .env (gitignored)  │
     │ /sync pulls                 │ └── logs/ (gitignored) │
     │ shared updates              └────────────────────────┘
     │
     └─ /contribute pushes improvement branches
```

**Setup per machine (HTTPS + fine-grained PAT, no fork, no SSH key):**
```bash
git clone https://github.com/harper04/agent-sysadmin.git ~/sysadmin-agent
cd ~/sysadmin-agent
./setup.sh --origin https://github.com/harper04/sysadmin-rpi5-dad.git --token github_pat_XXXX
# → stores token in local/.env, configures per-repo credential helper
# → renames clone remote to 'upstream', sets machine repo as 'origin'
# → seeds local/ from templates/local/, fills machine identity
# → configures Claude Code onboarding (OAuth token, .claude.json)
git push -u origin main
```

**Claude Code onboarding (handled by setup.sh):**
- Obtain an OAuth token on another machine: `claude setup-token`
- `setup.sh` writes `export CLAUDE_CODE_OAUTH_TOKEN=<token>` to `~/.bashrc`
- `setup.sh` ensures `~/.claude.json` contains `hasCompletedOnboarding: true`
- After setup, run `source ~/.bashrc` to load the token into your shell

**Authentication:**
- GitHub token lives in `local/.env` (gitignored, never committed)
- Per-repo credential helper reads token at push/pull time
- Claude Code OAuth token lives in `~/.bashrc` as an env export
- No token in URLs, no global git config, no SSH keys needed

**3-tier content model:**

| Tier | Directory | Lives in | Purpose |
|------|-----------|----------|---------|
| 1. Seeds | `templates/local/` | Template repo | Generic files with placeholders. `setup.sh` copies to `local/`. Bug fixes synced via `/sync`. |
| 2. Examples | `docs/examples/` | Template repo | Sanitized real-world docs from actual machines. Reference only — NOT copied to `local/`. |
| 3. Live | `local/` | Machine repo ONLY | Actual configs, real hostnames/IPs. **NEVER** in the template repo. |

**Rules:**
- `local/` exists only in machine repos, **NEVER** in the template.
- `local/.env` and `local/logs/` are gitignored — never committed anywhere.
- `local/.template-versions` tracks which template version each local file was synced from.
- Improvements to shared files → `/contribute` pushes a branch to upstream.
- Template updates → `/sync` merges shared files + syncs `templates/local/` → `local/`.
- Promotable local work → sanitize and put in `docs/examples/` or `templates/local/`.

**Protection against local/ leaking upstream:**
- `.gitignore` is **identical** in both repos — it does NOT ignore `local/`.
- A **pre-push hook** (`scripts/hooks/pre-push-no-local-upstream.sh`) blocks any push
  to the `upstream` remote that contains `local/` paths.
- `propose-upstream.sh` and `/contribute` also filter out `local/` files.
- A **GitHub Actions check** on the upstream repo rejects PRs containing `local/` files.
- The hook is installed automatically by `setup.sh` and `/sync`.

## Core Rules

1. **Document everything.** After every change, update the relevant file in `local/docs/`.
   Append to `local/docs/changelog.md` with ISO timestamp, what changed, and why.
2. **Git commit after every logical unit of work.** Use conventional commits:
   `fix(caddy): renew TLS cert for example.com`
3. **Never run destructive commands without confirmation** unless in unattended
   upgrade mode. Destructive = `rm -rf`, `fdisk`, `mkfs`, `systemctl disable`,
   `reboot`, package removal.
4. **Dry-run first.** For package upgrades, config changes, and service restarts:
   show the plan, then execute.
5. **Rollback plan.** Before modifying a config file, copy it to
   `<filename>.bak.<ISO-date>` in the same directory.
6. **Shared improvements.** When you improve an agent, skill, hook, or script in a way
   that would benefit all machines, use the `/contribute` command to propose it upstream.

## Machine Identity

> Loaded from `local/CLAUDE.local.md` — see that file for this machine's details.
> If `local/CLAUDE.local.md` does not exist, run `./setup.sh` first.

@local/CLAUDE.local.md

## Directory Layout

```
.
├── CLAUDE.md                ← you are here (shared agent config)
├── .claude/
│   ├── agents/              ← shared sub-agent definitions
│   ├── skills/              ← shared reusable task templates
│   ├── commands/            ← shared slash commands
│   └── settings.json        ← shared base settings
├── scripts/
│   ├── agent/               ← agent lifecycle (start, run, systemd service)
│   ├── hooks/               ← shared hook implementations
│   ├── cron/                ← shared scheduled task scripts
│   ├── lib/                 ← shared shell library (common.sh)
│   └── git/                 ← upstream sync & contribute scripts
├── docs/
│   ├── apps/_template.md    ← shared template for app docs
│   ├── conventions.md       ← shared cross-agent conventions
│   ├── examples/            ← Tier 2: sanitized real-world reference docs
│   ├── recipes/             ← shared app installation recipes
│   └── runbooks/_template.md ← shared template for runbooks
├── templates/
│   └── local/               ← Tier 1: seed files (copied to local/ by setup.sh)
│
├── local/                   ← Tier 3: ⚠ MACHINE-SPECIFIC — only in machine repo
│   ├── CLAUDE.local.md      ← machine identity & overrides
│   ├── .template-versions   ← tracks synced template versions
│   ├── agents/              ← local agent overrides/additions
│   ├── docs/                ← this machine's documentation
│   ├── .env                 ← secrets (NEVER committed)
│   └── logs/                ← runtime logs (NEVER committed)
└── .gitignore
```

## Documentation Standards

Each app doc in `local/docs/apps/` MUST follow `docs/apps/_template.md`.
Each system doc MUST include: last-verified date, responsible agent, and source of truth.

## Interaction Protocol

When receiving a task (via Telegram or direct CLI):
1. Acknowledge the task
2. Route to the appropriate sub-agent (or handle directly if trivial)
3. Sub-agent executes with dry-run preview when applicable
4. Results are documented in `local/docs/` and committed
5. Summary is sent back via Telegram (if Telegram-initiated)

## Scheduled Tasks

| Schedule           | Task                      | Agent           |
|--------------------|---------------------------|-----------------|
| Daily 02:00        | btrfs snapshot + prune    | backup          |
| Daily 03:00        | Security updates check    | system-updater  |
| Weekly Sun 04:00   | Full system upgrade       | system-updater  |
| Daily 06:00        | Health check all services | orchestrator    |
| Weekly Mon 05:00   | Backup verification       | backup          |
| Monthly 1st 05:30  | Full inventory refresh    | orchestrator    |

## System Conventions

> Cross-cutting rules that all agents must follow. Check before modifying any system component.

@docs/conventions.md
@local/docs/conventions.md

## Context Files

When working with a specific app, always load:
- `local/docs/apps/<app>.md` — current state and config on this machine
- `local/docs/system/packages.md` — installed package versions
- `local/docs/system/network.md` — ports and firewall rules
- `local/CLAUDE.local.md` — machine identity and local overrides
