# 🤖 Sysadmin Agent

Claude Code als autonomer Linux-System-Operator — erreichbar via Telegram.

## Konzept

Dieses Repository ist ein **Shared Template** für Claude Code als Sysadmin-Agent.
Jede Maschine (RPi, VPS, Server) bekommt einen **Fork** dieses Templates.
Verbesserungen an Agenten und Skills fließen per `/contribute` zurück ins Template
und werden per `/sync` auf alle Maschinen verteilt.

```
┌─────────────────────────┐
│   upstream (template)    │   Shared agents, skills, hooks, scripts
│   sysadmin-agent-tpl     │   Keine Secrets, keine Maschinendaten
└────────┬───────▲─────────┘
    fork │       │ /contribute (propose-upstream.sh)
    +    │       │
  /sync  │       │
         ▼       │
┌─────────────────────────┐  ┌─────────────────────────┐
│  origin: rpi5-dad        │  │  origin: vps-hetzner     │
│  local/                  │  │  local/                  │
│  ├── CLAUDE.local.md     │  │  ├── CLAUDE.local.md     │
│  ├── docs/ (maschine)    │  │  ├── docs/ (maschine)    │
│  ├── .env (secrets)      │  │  ├── .env (secrets)      │
│  └── logs/               │  │  └── logs/               │
└──────────────────────────┘  └──────────────────────────┘
```

## Was ist shared, was ist lokal?

| Shared (upstream)                  | Lokal (nur origin)              |
|------------------------------------|---------------------------------|
| `.claude/agents/*.md`              | `local/CLAUDE.local.md`         |
| `.claude/skills/*.md`              | `local/docs/**`                 |
| `.claude/commands/*.md`            | `local/agents/*.md`             |
| `.claude/settings.json`            | `local/.env`                    |
| `scripts/**`                       | `local/logs/**`                 |
| `docs/apps/_template.md`          |                                 |
| `docs/runbooks/_template.md`      |                                 |
| `CLAUDE.md`, `README.md`          |                                 |

## Setup für eine neue Maschine

### 1. Fork des Templates

```bash
# Auf GitHub/Gitea/Forgejo: Fork von sysadmin-agent-tpl erstellen
# Dann:
git clone <your-fork-url> ~/sysadmin-agent
cd ~/sysadmin-agent
```

### 2. Setup-Script

```bash
./setup.sh --upstream <template-repo-url> --origin <fork-url>
```

Das Script:
- Prüft Voraussetzungen (git, jq, claude, curl)
- Setzt Git Remotes (upstream + origin)
- Füllt `local/CLAUDE.local.md` mit Maschinenidentität
- Erstellt `local/.env` aus Template

### 3. Telegram konfigurieren

```bash
nano local/.env
# TELEGRAM_BOT_TOKEN und TELEGRAM_CHAT_ID eintragen
```

### 4. Erstes Inventory

```bash
claude --agent orchestrator
> /inventory
```

### 5. Telegram Bot als Service

```bash
sudo cp scripts/telegram-bot/sysadmin-agent-telegram.service /etc/systemd/system/
# ggf. Pfade in der .service-Datei anpassen
sudo systemctl daemon-reload
sudo systemctl enable --now sysadmin-agent-telegram
```

### 6. Cron-Jobs

```bash
crontab scripts/cron/crontab.example
```

## Benutzung

### Via Telegram

Dem Bot einfach schreiben:
- `"Systemstatus"` → Health Check
- `"Update das System"` → Guided Upgrade
- `"Welche Docker Container laufen?"` → Docker Status
- `"Starte Caddy neu"` → Caddy Reload

### Via CLI

```bash
cd ~/sysadmin-agent

# Interaktiv
claude --agent orchestrator

# Einmal-Kommando
claude --agent orchestrator -p "Zeige alle fehlgeschlagenen Services"

# Direkt mit Sub-Agent
claude --agent caddy -p "Füge upstream für grafana.local hinzu"
```

### Slash Commands

| Command        | Beschreibung                              |
|----------------|-------------------------------------------|
| `/status`      | Schneller System-Überblick                |
| `/upgrade`     | System-Upgrade mit Safety Checks          |
| `/inventory`   | Komplettes System-Inventory               |
| `/contribute`  | Verbesserung an upstream Template senden  |
| `/sync`        | Shared Updates von upstream holen         |

## Git Workflow

### Tägliche Arbeit (Agenten arbeiten automatisch)

```bash
# Agenten committen ihre Doku-Änderungen in local/
git push origin main     # lokale Änderungen sichern
```

### Verbesserung teilen

```bash
# Agent hat z.B. den Caddy-Agent verbessert
/contribute --file .claude/agents/caddy.md "besseres TLS-Handling"
# → Erstellt Branch auf upstream, du machst einen PR
```

### Updates holen

```bash
/sync --dry-run          # Vorschau
/sync                    # Merge von upstream/main
```

### Lokale Agent-Overrides

Wenn eine Maschine abweichendes Verhalten braucht:

```bash
# Shared Agent kopieren und lokal anpassen
cp .claude/agents/caddy.md local/agents/caddy.md
# local/agents/ wird vom Orchestrator bevorzugt geladen
```

## Architektur

| Komponente         | Zweck                                           |
|--------------------|--------------------------------------------------|
| `orchestrator`     | Routing, Health Checks, Dokumentation            |
| `system-updater`   | OS-Updates, Security Patches, Kernel Upgrades    |
| `caddy`            | Reverse Proxy, TLS, Upstreams                    |
| `k3s`              | Kubernetes Cluster Management                    |
| `kvm`              | KVM/libvirt Virtual Machines                     |
| `docker`           | Docker & Compose Stacks                          |
| `tailscale`        | Mesh VPN, Subnet Routing, MagicDNS               |
| `backup`           | btrfs Snapshots, rsync, Restore-Verifikation     |

## Hooks

| Hook                 | Trigger         | Funktion                              |
|----------------------|-----------------|---------------------------------------|
| validate-destructive | Pre: Bash       | Blockiert gefährliche Befehle         |
| log-bash-command     | Post: Bash      | Audit-Trail in `local/logs/`          |
| track-file-changes   | Post: Write/Edit| Trackt geänderte System-Dateien       |

## Eigene Agenten hinzufügen

```bash
cat > .claude/agents/my-app.md << 'EOF'
---
name: my-app
description: Manages MyApp.
tools: Bash, Read, Write, Edit, Glob, Grep
---
# MyApp Agent
...
EOF

# Im Orchestrator-Routing-Table eintragen, dann:
/contribute --file .claude/agents/my-app.md "neuer MyApp Agent"
```

## Lizenz

MIT
