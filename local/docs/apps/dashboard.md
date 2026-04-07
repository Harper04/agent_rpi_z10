# Dashboard

> **Status:** ✅ Running
> **Last verified:** 2026-04-07
> **Managed by agent:** `orchestrator`
> **Installation method:** `source` (Bun TypeScript server)
> **Recipe:** `docs/recipes/dashboard.md`

## Overview

Lightweight system dashboard for s85. Displays system health, auto-discovered
services (from Caddy `@` annotations), Route53 DNS tree, ZeroTier network
members, and an agent restart button.

## Installation

Source files live in `local/dashboard/` (seeded from `templates/local/dashboard/`).
Bun was already installed. Service created and started.

## Version

| Component | Version   | Source              |
|-----------|-----------|---------------------|
| Bun       | installed | bun.sh              |
| Dashboard | 1.0.0     | local/dashboard/    |

## Configuration

### Config files

| File                                          | Purpose                    |
|-----------------------------------------------|----------------------------|
| `local/dashboard/server.ts`                   | Bun HTTP server            |
| `local/dashboard/static/`                     | Frontend (Alpine.js + CSS) |
| `/etc/systemd/system/strandstr-pi-dashboard.service` | Systemd unit         |
| `/etc/sudoers.d/dashboard-agent-restart`      | Allows restart button      |

### Key settings

| Setting             | Value                            |
|---------------------|----------------------------------|
| Listen port         | 3100                             |
| Subtitle            | strandstr-pi                     |
| Caddy sites dir     | /etc/caddy/sites                 |
| DNS filter          | `\052,_owner` (hides wildcard + owner TXT records) |

### Environment variables (in local/.env)

| Variable              | Value                   | Purpose                        |
|-----------------------|-------------------------|--------------------------------|
| `DASHBOARD_PORT`      | `3100`                  | Listen port                    |
| `DASHBOARD_SUBTITLE`  | `strandstr-pi`          | Header subtitle                |
| `DNS_RECORD_FILTERS`  | `\052,_owner`           | Records to hide in DNS panel   |
| `CADDY_SITES_DIR`     | `/etc/caddy/sites`      | Service discovery source       |
| `ZEROTIER_API_KEY`    | (from .env)             | ZeroTier members panel         |
| `ZEROTIER_NETWORK_ID` | `8286ac0e476c329b`      | Network to display             |
| `AWS_ACCESS_KEY_ID`   | (from .env)             | Route53 DNS panel              |
| `AWS_SECRET_ACCESS_KEY`| (from .env)            | Route53 DNS panel              |

## Network

| Port | Protocol | Purpose           | Exposed to |
|------|----------|-------------------|------------|
| 3100 | TCP      | Dashboard API     | localhost (via Caddy) |

## Data & Storage

No persistent data. State is read live from system APIs on each request.

## Reverse Proxy

| Key         | Value                                              |
|-------------|----------------------------------------------------|
| ZT domain   | `https://s85.zt.tiny-systems.eu/` (auth required) |
| LAN domain  | `https://s85.local.tiny-systems.eu/` (open)       |
| Upstream    | `http://localhost:3100`                            |
| Site blocks | `/etc/caddy/sites/default-zt.caddy`, `default-local.caddy` |

## Dependencies

- Depends on: Caddy (reverse proxy), ZeroTier (ZT panel), aws-cli (DNS panel)
- Depended on by: nothing

## Health Check

```bash
systemctl is-active strandstr-pi-dashboard
curl -sf http://localhost:3100/api/health | jq .hostname
curl -sf http://localhost:3100/api/services | jq '[.[].name]'
```

## Common Operations

### Restart
```bash
systemctl restart strandstr-pi-dashboard
```

### View logs
```bash
journalctl -u strandstr-pi-dashboard --since "1 hour ago"
```

## Known Issues & Gotchas

- Restarting sysadmin-agent via dashboard button will interrupt any running agent tasks.
  The dashboard itself stays up (separate service).
- DNS panel fetches live from Route53 on each page load — can be slow with many records.

## Changelog (app-specific)

| Date       | Change                                    | Agent        |
|------------|-------------------------------------------|--------------|
| 2026-04-07 | Installed; source files already present from template | orchestrator |
