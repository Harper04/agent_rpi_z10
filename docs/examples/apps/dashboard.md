# Dashboard

> Last verified: YYYY-MM-DD
> Responsible agent: orchestrator
> Source recipe: docs/recipes/dashboard.md

## Overview

Custom system dashboard built with Bun (TypeScript backend) + Alpine.js (frontend).
No npm dependencies. Served at the machine's root domain behind Caddy auth.

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
| Service links          | GET /api/services     | Auto-discovered from Caddy @ annotations |
| Route53 DNS tree       | GET /api/dns          | All zones + records          |
| ZeroTier network       | GET /api/zerotier     | Members, IPs, online status  |
| Agent status           | GET /api/agent/status | systemd service state        |
| Agent restart          | POST /api/agent/restart | Requires sudoers entry     |

## Files

| Path | Purpose |
|------|---------|
| `local/dashboard/server.ts` | Bun HTTP server |
| `local/dashboard/static/` | Frontend assets (HTML, CSS, JS) |
| `local/dashboard/dashboard.service` | systemd unit template |
| `/etc/systemd/system/<hostname>-dashboard.service` | Installed unit |
| `/etc/sudoers.d/dashboard-agent-restart` | Scoped sudo for agent restart |
| `/etc/caddy/sites/default.caddy` | Caddy reverse proxy config |

## Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `DASHBOARD_PORT` | `3100` | Listen port |
| `DASHBOARD_SUBTITLE` | `Managed Server` | Header subtitle |
| `DNS_RECORD_FILTERS` | `\052,_owner` | Comma-separated DNS record filters |

## Maintenance

```bash
# Restart dashboard
sudo systemctl restart <hostname>-dashboard

# View logs
journalctl -u <hostname>-dashboard -f
```

## Security

- All secrets stay server-side — API endpoints return only derived data
- Caddy auth portal protects the entire site
- sudoers scoped to only `systemctl restart sysadmin-agent.service`
