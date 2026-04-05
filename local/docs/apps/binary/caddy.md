# Caddy — Reverse Proxy + Auth Portal

> **Status:** Running
> **Last verified:** 2026-04-04
> **Managed by agent:** `caddy`
> **Installation method:** Binary (Caddy Download API)
> **Recipe:** `docs/recipes/caddy.md`

## Overview

Caddy v2.11.2 with caddy-security + caddy-dns/route53 plugins. LAN flavor
(auth OFF by default). Provides HTTPS reverse proxy with SSO auth portal
for all web apps on this machine.

## Installation

Installed per `docs/recipes/caddy.md` (LAN flavor).

## Version

| Component       | Version   | Source                    |
|-----------------|-----------|---------------------------|
| Caddy           | `2.11.2`  | Caddy Download API (arm64)|
| caddy-security  | bundled   | greenpau/caddy-security   |
| caddy-dns/route53| bundled  | caddy-dns/route53         |

## Configuration

### Identity

| Key             | Value                                     |
|-----------------|-------------------------------------------|
| Flavor          | LAN (auth OFF by default)                 |
| Cookie domain   | `z10.local.tiny-systems.eu`               |
| Admin user      | `tomjaster`                               |
| Admin email     | `tom@altow.de`                            |

### Domains & Sites

| Domain                              | Site block        | Upstream          | Auth    |
|-------------------------------------|-------------------|-------------------|---------|
| `z10.local.tiny-systems.eu`         | `default.caddy`   | Static landing    | OFF     |
| `auth.z10.local.tiny-systems.eu`    | `_auth.caddy`     | Auth portal       | Portal  |
| `ha.z10.local.tiny-systems.eu`      | `home-assistant.caddy` | `192.168.2.174:8123` | OFF |
| `ha.z10.zt.tiny-systems.eu`        | `home-assistant.caddy` | `192.168.2.174:8123` | OFF |

### Key paths

| Path                                | Purpose                    |
|-------------------------------------|----------------------------|
| `/usr/bin/caddy`                    | Custom binary              |
| `/etc/caddy/Caddyfile`             | Main config                |
| `/etc/caddy/sites/*.caddy`         | Per-app site blocks        |
| `/etc/caddy/static/`               | Static landing page        |
| `/etc/caddy/env`                   | Environment (secrets)      |
| `/var/lib/caddy/users.json`        | Auth user database         |
| `/var/lib/caddy/.local/share/caddy/` | TLS certs (Let's Encrypt)|

## Network

| Port   | Protocol | Purpose             | Exposed to   |
|--------|----------|---------------------|--------------|
| 80     | TCP      | HTTP → HTTPS redir  | LAN          |
| 443    | TCP      | HTTPS reverse proxy | LAN          |

## Data & Storage

| Path                                   | Purpose          | Backed up? |
|----------------------------------------|------------------|------------|
| `/etc/caddy/`                          | Config           | TODO       |
| `/var/lib/caddy/users.json`            | Auth users       | TODO       |
| `/var/lib/caddy/.local/share/caddy/`   | TLS certs        | auto-renew |

## Dependencies

- Depends on: network, Route53 DNS (for TLS)
- Depended on by: (future proxied apps)

## Health Check

```bash
systemctl is-active caddy
caddy validate --config /etc/caddy/Caddyfile
curl -sf https://z10.local.tiny-systems.eu/ -o /dev/null && echo "OK"
curl -sf https://auth.z10.local.tiny-systems.eu/ -o /dev/null -w "%{http_code}"
```

## Common Operations

### Reload (after config change)
```bash
sudo systemctl reload caddy
```

### Add an app behind Caddy
1. Write `/etc/caddy/sites/<app>.caddy`
2. `caddy validate --config /etc/caddy/Caddyfile`
3. `sudo systemctl reload caddy`

## Known Issues & Gotchas

- Auth portal must be served under `/auth*` route (SPA base path requirement).
- First cert acquisition takes ~2 min (Route53 DNS-01 propagation).
- `password_recovery_enabled` directive is not supported in this caddy-security version.
- users.json ownership must be caddy:caddy.

## Changelog

| Date       | Change                                          | Agent        |
|------------|-------------------------------------------------|--------------|
| 2026-04-04 | Initial install v2.11.2 LAN flavor + auth portal | orchestrator |
