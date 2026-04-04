---
name: "dashboard"
method: source
version: "1.0.0"
ports: [3100]
dependencies: [bun, aws-cli]
reverse-proxy: true
domain: "<hostname>.tiny-systems.eu"
data-paths: ["local/dashboard"]
backup: false
---

# Recipe: System Dashboard

> Tested on: Ubuntu 24.04 (amd64), Debian 12+
> Last updated: 2026-04-04

## Overview

A lightweight system dashboard for sysadmin-agent managed machines. Displays system
health, service links (auto-discovered from Caddy), Route53 DNS records in a tree view,
ZeroTier network members, and agent control (restart button).

Built with Bun (TypeScript backend, ~280 lines) + Alpine.js + Line Awesome icons.
Zero npm dependencies, no build step, mobile-first dark theme.

### Features

- **System health** — CPU load, memory, disk usage with auto-refresh
- **Service discovery** — Auto-discovers services from Caddy `@` annotations
- **Route53 DNS** — Collapsible tree of all hosted zones and records
- **ZeroTier network** — Online/offline members with IP addresses
- **Agent control** — Restart sysadmin-agent.service via dashboard button
- **Generic** — No hardcoded hostnames; pulls identity from system + env vars

### Architecture

```
Browser → Caddy (TLS + auth) → localhost:3100 → Bun server.ts
                                                  ├── /api/config    → hostname + subtitle
                                                  ├── /api/health    → system metrics
                                                  ├── /api/services  → parses Caddy sites
                                                  ├── /api/dns       → aws route53 CLI
                                                  ├── /api/zerotier  → ZeroTier Central API
                                                  ├── /api/agent/*   → systemctl
                                                  └── static/        → HTML/CSS/JS
```

All secrets stay server-side. Frontend only receives derived JSON.

## Prerequisites

- **Bun** runtime installed (`curl -fsSL https://bun.sh/install | bash`)
- **Caddy** running as reverse proxy (see `caddy` recipe)
- **AWS CLI** installed with Route53 read permissions (for DNS panel; optional)
- **AWS credentials** in `local/.env` (optional — DNS panel shows error if missing)
- **ZeroTier API key** in `local/.env` (optional — ZT panel shows error if missing)
- Caddy site files with `@` annotations (see `caddy-site-metadata` convention)

## Installation Steps

### Step 1 — Create dashboard directory

```bash
mkdir -p local/dashboard/static
```

### Step 2 — Deploy source files

Copy these files into `local/dashboard/`:

| File | Purpose |
|------|---------|
| `server.ts` | Bun HTTP server with API endpoints |
| `static/index.html` | Dashboard HTML (Alpine.js) |
| `static/style.css` | Dark theme, mobile-first CSS |
| `static/app.js` | Frontend logic (data fetching, rendering) |

Source files are maintained in the machine repo at `local/dashboard/`.
A reference copy ships in `templates/local/dashboard/` for new machines.

### Step 3 — Create systemd service

```bash
sudo tee /etc/systemd/system/<hostname>-dashboard.service > /dev/null << 'UNIT'
[Unit]
Description=<hostname> Dashboard (Bun)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=<linux-user>
WorkingDirectory=<repo-path>/local/dashboard
EnvironmentFile=<repo-path>/local/.env
Environment=PATH=<home>/.bun/bin:/snap/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=<home>/.bun/bin/bun run server.ts
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now <hostname>-dashboard.service
```

### Step 4 — Configure sudoers for agent restart

```bash
echo '<linux-user> ALL=(root) NOPASSWD: /usr/bin/systemctl restart sysadmin-agent.service' \
  | sudo tee /etc/sudoers.d/dashboard-agent-restart
sudo chmod 440 /etc/sudoers.d/dashboard-agent-restart
sudo visudo -cf /etc/sudoers.d/dashboard-agent-restart
```

### Step 5 — Configure Caddy reverse proxy

Update the default site block to proxy to the dashboard:

```caddyfile
# @name Dashboard
# @icon las la-tachometer-alt
# @description System dashboard & service overview
# @dashboard true
<hostname>.tiny-systems.eu {
    tls {
        dns route53
    }
    route {
        authorize with default_policy
        reverse_proxy localhost:3100
    }
}
```

**Note:** The `@` annotations are required — the dashboard reads them for service
discovery (see `caddy-site-metadata` convention in `docs/conventions.md`).

```bash
caddy validate --config /etc/caddy/Caddyfile  # may warn about env vars if run as non-caddy user
sudo systemctl reload caddy
```

### Step 6 — Add @ annotations to existing Caddy site files

Every `.caddy` file in `/etc/caddy/sites/` should have annotation comments at the top.
Set `@dashboard true` for services that should appear on the dashboard, `false` for
infrastructure sites (auth portal, etc.):

```
# @name AdGuard Home
# @icon las la-shield-alt
# @description DNS filtering & ad blocking
# @dashboard true
```

Icons: browse [Line Awesome](https://icons8.com/line-awesome) for class names.

## Configuration

### Environment variables

Add to `local/.env`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DASHBOARD_PORT` | `3100` | Listen port for Bun server |
| `DASHBOARD_SUBTITLE` | `Managed Server` | Subtitle shown in header (e.g. "Hetzner vServer") |
| `DNS_RECORD_FILTERS` | `\052,_owner` | Comma-separated substrings to hide from DNS panel |
| `CADDY_SITES_DIR` | `/etc/caddy/sites` | Path to Caddy site configs |
| `ZEROTIER_API_KEY` | _(none)_ | ZeroTier Central API token |
| `ZEROTIER_NETWORK_ID` | _(none)_ | ZeroTier network to display |
| `AWS_ACCESS_KEY_ID` | _(none)_ | AWS credentials for Route53 |
| `AWS_SECRET_ACCESS_KEY` | _(none)_ | AWS credentials for Route53 |

### Optional panels

The dashboard gracefully handles missing configuration:
- **No AWS credentials** → DNS panel shows "not configured" error
- **No ZeroTier credentials** → ZeroTier panel shows "not configured" error
- Both panels are hidden entirely if the API returns an error on first load

## Reverse Proxy

The dashboard replaces the static landing page on the default domain.
It is protected by Caddy's `default_policy` (auth portal SSO).

## Health Check

```bash
# Service running
systemctl is-active <hostname>-dashboard

# API responding
curl -sf http://localhost:3100/api/health | jq .hostname

# Services discovered
curl -sf http://localhost:3100/api/services | jq '.[].name'
```

## Post-Install

1. Visit `https://<hostname>.tiny-systems.eu/` — log in via auth portal
2. Verify all panels load (health, services, DNS, ZeroTier)
3. Test the agent restart button
4. Add `@` annotations to any Caddy site files that are missing them
5. Update `local/CLAUDE.local.md`:
   - Add `dashboard` to Installed Applications table
   - Add port 3100 to Custom Ports table

## Known Issues

- **DNS panel slow on first load** — Route53 API calls are sequential per zone.
  Results are not cached server-side (each page load re-fetches). Consider adding
  server-side caching if you have many zones.
- **Agent restart kills the agent process** — If the dashboard triggers a restart,
  the Telegram bot and any running agent tasks will be interrupted. The dashboard
  itself stays up (separate systemd service).
- **`caddy validate` may fail outside Caddy's env** — The validate command doesn't
  load `/etc/caddy/env`, so `{env.JWT_SHARED_KEY}` fails. This is cosmetic; the
  actual running Caddy instance loads the env file correctly.
- **Bun on arm64** — Bun supports arm64 Linux but was historically less stable.
  Test thoroughly on Raspberry Pi / ARM servers.
