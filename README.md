# 🤖 Sysadmin Agent

Claude Code als autonomer Linux-System-Operator — erreichbar via Telegram.

## Konzept

Ein **Template-Repo** mit Agenten, Skills, Hooks und Scripts. Pro Maschine ein
eigenes Repo per `git clone` + Remote-Rename. Kein SSH-Key, kein Fork nötig —
nur HTTPS mit einem Fine-Grained Personal Access Token pro Maschine.

```
  sysadmin-agent (Template)
        │
        ├── clone → sysadmin-rpi5-dad
        ├── clone → sysadmin-vps-hetzner
        └── clone → sysadmin-office-srv
              │
              ├── upstream → sysadmin-agent      (template, shared)
              ├── origin   → sysadmin-vps-hetzner (machine, inkl. local/)
              └── local/.env → GITHUB_TOKEN       (gitignored)
```

## Setup

### 1. Template-Repo (einmalig)

```bash
# Dieses Repo auf GitHub pushen
cd sysadmin-agent
git init && git add -A && git commit -m "initial template"
git remote add origin https://github.com/you/sysadmin-agent.git
git push -u origin main
```

### 2. GitHub PAT erstellen (pro Maschine)

1. Gehe zu **[github.com/settings/personal-access-tokens/new](https://github.com/settings/personal-access-tokens/new)**
2. Name: `sysadmin-rpi5-dad` (oder wie die Maschine heißt)
3. Expiration: 90 Tage (Erinnerung: `/rotate-token`)
4. **Repository access:** "Only select repositories"
   → `sysadmin-agent` (Template) + `sysadmin-rpi5-dad` (Maschine)
5. **Permissions → Repository:**
   → Contents: **Read and write**
   → Metadata: Read-only (automatisch)
6. Token kopieren: `github_pat_XXXXXXXXXXXX`

### 3. Leeres Maschinen-Repo auf GitHub

Erstelle `sysadmin-rpi5-dad` — **komplett leer** (keine README, kein .gitignore).

### 4. Voraussetzungen auf der Maschine

```bash
# Systempakete (Debian/Ubuntu)
sudo apt install -y git curl jq unzip
```

[Claude Code](https://docs.anthropic.com/claude-code) installieren (falls noch nicht vorhanden).

`bun` wird von `setup.sh` automatisch installiert — es wird vom Telegram-Channel-MCP-Plugin benötigt.

### 5. Auf der Maschine

```bash
# Template klonen (mit Token geht das erstmal ohne Auth, da public)
git clone https://github.com/you/sysadmin-agent.git ~/sysadmin-agent
cd ~/sysadmin-agent

# Setup mit Token
./setup.sh \
  --origin https://github.com/you/sysadmin-rpi5-dad.git \
  --token github_pat_XXXXXXXXXXXX
# → installiert bun (Telegram MCP-Runtime)
# → installiert das Claude Code Telegram-Plugin
# → konfiguriert Git-Credential-Helper, seeded local/

# Zum Maschinen-Repo pushen (Token wird automatisch aus local/.env gelesen)
git push -u origin main

# Telegram konfigurieren
nano local/.env   # TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID eintragen

# Shell neu laden (bun in PATH aufnehmen)
source ~/.bashrc

# Agent starten
claude --agent orchestrator
> /inventory
```

### Was passiert bei `setup.sh`?

1. `origin` (Template) wird zu `upstream` umbenannt
2. Maschinen-Repo wird neues `origin`
3. Token wird in `local/.env` gespeichert (gitignored!)
4. Ein **per-Repo Git Credential Helper** wird konfiguriert:
   - Liest `GITHUB_TOKEN` aus `local/.env` bei jedem `git push/pull`
   - Kein Token in URLs, kein Token in globaler Git-Config
   - Funktioniert nur in diesem Repo
5. `local/` wird aus `templates/local/` geseeded, Maschinendaten eingetragen
6. **`bun`** wird installiert (falls nicht vorhanden) — Runtime für das Telegram-MCP-Plugin
7. **Claude Code Telegram-Plugin** wird installiert (`telegram@claude-plugins-official`)

### Telegram Channel MCP

Das Telegram-Plugin läuft als lokaler MCP-Server via `bun`. Ohne `bun` startet der Channel nicht und Claude Code zeigt `channel/mcp failed` in den Logs.

Manuell nachholen (falls setup.sh übersprungen):
```bash
# bun installieren
curl -fsSL https://bun.sh/install | bash && source ~/.bashrc

# Plugin installieren
claude plugin install telegram@claude-plugins-official
```

### Token-Sicherheit

| Wo?                          | Token? |
|------------------------------|--------|
| `local/.env`                 | ✅ Hier, gitignored |
| Git Remote-URLs              | ❌ Nie |
| Globale `~/.gitconfig`       | ❌ Nie |
| `git remote -v` Output       | ❌ Nie, nur HTTPS-URL ohne Token |
| Git Commit History           | ❌ Nie |
| Shell History                | ⚠️ `setup.sh` versucht History zu deaktivieren |

## Benutzung

### Via Telegram

```
"Systemstatus"               → Health Check
"Update das System"           → Guided Upgrade
"Welche Container laufen?"    → Docker Status
```

### Via CLI

```bash
claude --agent orchestrator                                # interaktiv
claude --agent orchestrator -p "Zeige fehlgeschlagene Services"  # einmalig
claude --agent caddy -p "Füge upstream für grafana hinzu"        # direkt
```

### Slash Commands

| Command          | Beschreibung                              |
|------------------|-------------------------------------------|
| `/status`        | System-Überblick                          |
| `/upgrade`       | System-Upgrade mit Safety Checks          |
| `/inventory`     | Komplettes System-Inventory               |
| `/contribute`    | Verbesserung ans Template senden          |
| `/sync`          | Template-Updates holen                    |
| `/rotate-token`  | GitHub PAT erneuern                       |

## Template-Updates verteilen

```bash
/sync --dry-run    # was ändert sich?
/sync              # merge von upstream/main
git push           # Maschinen-Repo aktualisieren
```

## Verbesserungen teilen

```bash
/contribute --file .claude/agents/caddy.md "besseres TLS-Handling"
# → Branch auf upstream, dort mergen
# → Andere Maschinen holen per /sync
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
