# Dashboard — mini-core

> Last verified: 2026-04-04
> Responsible agent: orchestrator
> Source of truth: this file

## Overview

Custom system dashboard served at `https://mini-core.tiny-systems.eu/`.
Built with Bun (TypeScript backend) + Alpine.js (frontend), no npm dependencies.

## Architecture

```
Browser → Caddy (TLS + auth) → localhost:3100 → Bun server.ts
                                                  ├── static/ (HTML/CSS/JS)
                                                  └── API endpoints
```

## Features

| Feature                | Endpoint              | Notes                        |
|------------------------|-----------------------|------------------------------|
| System health          | GET /api/health       | CPU, memory, disk, load      |
| Service links          | GET /api/services     | From hardcoded config        |
| Route53 DNS tree       | GET /api/dns          | All zones + records          |
| ZeroTier network       | GET /api/zerotier     | Members, IPs, online status  |
| Agent status           | GET /api/agent/status | systemd service state        |
| Agent restart          | POST /api/agent/restart | Requires sudoers entry     |

## Files

| Path | Purpose |
|------|---------|
| `local/dashboard/server.ts` | Bun HTTP server |
| `local/dashboard/static/` | Frontend assets |
| `local/dashboard/dashboard.service` | systemd unit template |
| `/etc/systemd/system/mini-core-dashboard.service` | Installed unit |
| `/etc/sudoers.d/dashboard-agent-restart` | Sudo for agent restart |
| `/etc/caddy/sites/default.caddy` | Caddy reverse proxy config |

## Configuration

- **Port:** 3100 (set via `DASHBOARD_PORT` in `local/.env`)
- **Auth:** Caddy `default_policy` (forward_auth) — no auth in the backend
- **AWS:** Uses `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` from `local/.env`
- **ZeroTier:** Uses `ZEROTIER_API_KEY` / `ZEROTIER_NETWORK_ID` from `local/.env`

## Maintenance

```bash
# Restart dashboard
sudo systemctl restart mini-core-dashboard

# View logs
journalctl -u mini-core-dashboard -f

# Edit services list
vi local/dashboard/server.ts  # SERVICES array near top
sudo systemctl restart mini-core-dashboard
```

## Security

- All secrets stay server-side — API endpoints return only derived data
- No secrets exposed to the browser
- Caddy auth portal protects the entire site
- sudoers scoped to only `systemctl restart sysadmin-agent.service`
