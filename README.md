# 🤖 Sysadmin Agent

Claude Code als autonomer Linux-System-Operator — erreichbar via Telegram.

## Konzept

Ein **Template-Repo** mit Agenten, Skills, Hooks und Scripts. Jede Maschine
bekommt ein eigenes Repo per `git clone` + Umbenennung der Remotes.
Kein GitHub Fork nötig — funktioniert beliebig oft.

```
  sysadmin-agent (Template)
        │
        ├── clone → sysadmin-rpi5-dad     (origin)
        ├── clone → sysadmin-vps-hetzner  (origin)
        └── clone → sysadmin-office-srv   (origin)
              │
              └── local/  ← nur hier, nie im Template
                  ├── CLAUDE.local.md
                  ├── docs/ (Maschinendaten)
                  ├── .env  (Secrets, gitignored)
                  └── logs/ (gitignored)
```

Verbesserungen fließen per `/contribute` zurück ins Template und werden
per `/sync` auf alle Maschinen verteilt.

## Was ist shared, was ist lokal?

| Shared (Template + alle Maschinen)     | Lokal (nur Maschinen-Repo)      |
|----------------------------------------|---------------------------------|
| `.claude/agents/`, `skills/`, `commands/` | `local/CLAUDE.local.md`      |
| `scripts/`, `docs/*_template.md`       | `local/docs/**`                 |
| `CLAUDE.md`, `setup.sh`               | `local/agents/` (Overrides)     |
| `templates/local/` (Seed-Dateien)      | `local/.env`, `local/logs/`     |

## Setup

### 1. Template-Repo erstellen (einmalig)

```bash
# Dieses Repo auf GitHub/Gitea/Forgejo pushen
cd sysadmin-agent
git init && git add -A && git commit -m "initial template"
git remote add origin git@github.com:you/sysadmin-agent.git
git push -u origin main
```

### 2. Maschinen-Repo erstellen (pro Maschine)

Auf GitHub ein **leeres** Repo erstellen, z.B. `sysadmin-rpi5-dad`. Kein README,
kein .gitignore — komplett leer.

### 3. Auf der Maschine

```bash
# Template klonen
git clone git@github.com:you/sysadmin-agent.git ~/sysadmin-agent
cd ~/sysadmin-agent

# Setup: Remote-Umbenennung + local/ Seeding + Maschinendaten
./setup.sh --origin git@github.com:you/sysadmin-rpi5-dad.git

# Zum Maschinen-Repo pushen
git push -u origin main

# Telegram konfigurieren
nano local/.env

# Agent starten, System scannen
claude --agent orchestrator
> /inventory
```

Nach `setup.sh` sehen die Remotes so aus:
```
upstream  git@github.com:you/sysadmin-agent.git        (template)
origin    git@github.com:you/sysadmin-rpi5-dad.git     (diese maschine)
```

### 4. Telegram Bot & Cron (optional)

```bash
sudo cp scripts/telegram-bot/sysadmin-agent-telegram.service /etc/systemd/system/
sudo systemctl enable --now sysadmin-agent-telegram
crontab scripts/cron/crontab.example
```

## Benutzung

### Via Telegram

Dem Bot schreiben:
- `"Systemstatus"` → Health Check
- `"Update das System"` → Guided Upgrade
- `"Welche Container laufen?"` → Docker Status

### Via CLI

```bash
claude --agent orchestrator                               # interaktiv
claude --agent orchestrator -p "Zeige fehlgeschlagene Services"  # einmalig
claude --agent caddy -p "Füge upstream für grafana hinzu"        # direkt
```

### Slash Commands

| Command        | Beschreibung                              |
|----------------|-------------------------------------------|
| `/status`      | System-Überblick                          |
| `/upgrade`     | System-Upgrade mit Safety Checks          |
| `/inventory`   | Komplettes System-Inventory               |
| `/contribute`  | Verbesserung ans Template senden          |
| `/sync`        | Template-Updates holen                    |

## Template-Updates verteilen

```bash
# Auf der Maschine:
/sync --dry-run    # was würde sich ändern?
/sync              # merge von upstream/main
git push           # aktualisiertes Repo sichern
```

## Verbesserungen teilen

```bash
# Agent hat z.B. den Caddy-Agent verbessert
/contribute --file .claude/agents/caddy.md "besseres TLS-Handling"

# → Erstellt Branch 'propose/besseres-tls-handling-20260401' auf upstream
# → Du mergst ihn dort (direkt oder per PR)
# → Andere Maschinen holen ihn per /sync
```

## Lokale Agent-Overrides

Wenn eine Maschine abweichendes Verhalten braucht:

```bash
cp .claude/agents/caddy.md local/agents/caddy.md
nano local/agents/caddy.md  # anpassen
# Der Orchestrator prüft local/agents/ zuerst
```

## Agenten

| Agent              | Zweck                                     |
|--------------------|-------------------------------------------|
| `orchestrator`     | Routing, Health Checks, Doku              |
| `system-updater`   | OS-Updates, Security Patches              |
| `caddy`            | Reverse Proxy, TLS                        |
| `k3s`              | Kubernetes                                |
| `kvm`              | KVM/libvirt VMs                           |
| `docker`           | Docker & Compose                          |
| `tailscale`        | Mesh VPN                                  |
| `backup`           | btrfs Snapshots, rsync                    |

## Lizenz

MIT
