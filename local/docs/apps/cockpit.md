# Cockpit

> **Status:** ✅ Running
> **Last verified:** 2026-04-03
> **Managed by agent:** `orchestrator`
> **Installation method:** `apt`
> **Recipe:** manual

## Overview

Cockpit is a web-based system management interface providing real-time monitoring
and administration of the server. Running in local-session mode (no built-in auth)
behind Caddy's authentication portal for SSO.

## Installation

```bash
sudo apt-get install -y cockpit cockpit-storaged cockpit-networkmanager cockpit-packagekit
```

## Version

| Component       | Version | Source |
|-----------------|---------|--------|
| cockpit         | 314-1   | apt    |
| cockpit-ws      | 314-1   | apt    |
| cockpit-bridge  | 314-1   | apt    |

## Configuration

### Config files

| File                                      | Purpose                              |
|-------------------------------------------|--------------------------------------|
| `/etc/cockpit/cockpit.conf`               | Main config (proxy headers, origins) |
| `/etc/systemd/system/cockpit-local.service` | Custom systemd unit (local-session)  |
| `/etc/caddy/sites/cockpit.caddy`          | Caddy reverse proxy site config      |

### Key settings

- **Local-session mode:** `cockpit-ws --local-session=cockpit-bridge` — skips Cockpit's
  own authentication entirely. Auth is handled by Caddy's security portal.
- **No TLS:** `--no-tls` — Caddy handles TLS termination.
- **Runs as:** `ubuntu` user (has sudo access for system management).
- **Default cockpit.socket:** stopped, should be masked (pending operator confirmation).

### cockpit.conf

```ini
[WebService]
Origins = https://cockpit.mini-core.tiny-systems.eu
ProtocolHeader = X-Forwarded-Proto
ForwardedForHeader = X-Forwarded-For
LoginTo = false
AllowUnencrypted = true

[Session]
Banner =
```

## Network

| Port | Protocol | Purpose       | Exposed to     |
|------|----------|---------------|----------------|
| 9090 | TCP     | Cockpit HTTP  | localhost only |

## Data & Storage

| Path                      | Purpose              | Backed up? |
|---------------------------|----------------------|------------|
| `/etc/cockpit/`           | Configuration        | ✅ Yes     |

## Dependencies

- Depends on: Caddy (reverse proxy + auth), systemd
- Depended on by: none

## Health Check

```bash
systemctl is-active cockpit-local.service
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9090/
# Should return: active / 200
```

## Common Operations

### Restart
```bash
sudo systemctl restart cockpit-local.service
```

### View logs
```bash
journalctl -u cockpit-local --since "1 hour ago"
```

### Update
```bash
sudo apt-get update && sudo apt-get install cockpit cockpit-storaged cockpit-networkmanager cockpit-packagekit
sudo systemctl restart cockpit-local.service
```

## Access

- URL: https://cockpit.mini-core.tiny-systems.eu/
- Auth: Caddy portal (no separate Cockpit login)
- Portal link: appears in auth portal navigation

## Known Issues & Gotchas

- Default `cockpit.socket` should be masked to prevent accidental activation on port 9090
  with built-in auth. Currently stopped but not masked (hook blocked `systemctl mask`).
- Cockpit uses WebSockets heavily — Caddy handles this natively.
- Running as `ubuntu` user — all Cockpit sessions share this user context.
- If cockpit-ws crashes, systemd will restart it (RestartSec=5).

## Changelog (app-specific)

| Date       | Change                                          | Agent        |
|------------|-------------------------------------------------|--------------|
| 2026-04-03 | Initial installation with local-session + Caddy | orchestrator |
