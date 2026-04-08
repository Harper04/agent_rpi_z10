# Caddy

> **Status:** ✅ Running
> **Last verified:** 2026-04-07
> **Managed by agent:** `caddy`
> **Installation method:** `binary` (custom build via caddyserver.com/api/download)
> **Recipe:** `docs/recipes/caddy.md`

## Overview

Caddy is the reverse proxy and TLS termination layer for all web services on s85.
It provides automatic HTTPS via Let's Encrypt DNS-01 (Route53), and an SSO auth
portal (caddy-security) scoped to the ZeroTier domain.

**Flavor:** ZT-primary with LAN open access
- `*.s85.zt.tiny-systems.eu` — auth required (SSO via portal)
- `*.s85.local.tiny-systems.eu` — open (LAN-trusted, no auth)

## Installation

Downloaded custom binary with `caddy-security` and `caddy-dns/route53` plugins
from Caddy's official download API.

```bash
curl -fSL "https://caddyserver.com/api/download?os=linux&arch=arm64&p=github.com/greenpau/caddy-security&p=github.com/caddy-dns/route53" -o /tmp/caddy-custom
sudo install -m 755 /tmp/caddy-custom /usr/bin/caddy
```

## Version

| Component        | Version   | Source                              |
|------------------|-----------|-------------------------------------|
| caddy            | v2.11.2   | caddyserver.com/api/download (arm64)|
| caddy-security   | latest    | github.com/greenpau/caddy-security  |
| caddy-dns/route53| latest    | github.com/caddy-dns/route53        |

## Configuration

### Config files

| File                          | Purpose                              |
|-------------------------------|--------------------------------------|
| `/etc/caddy/Caddyfile`        | Main config (global + import sites/) |
| `/etc/caddy/env`              | Secrets (AWS keys, JWT key, admin creds) — mode 600 |
| `/etc/caddy/sites/*.caddy`    | Per-app site blocks                  |
| `/etc/caddy/static/`          | Static files (fallback landing page) |
| `/var/lib/caddy/users.json`   | Auth portal user database            |
| `/var/lib/caddy/.local/share/caddy/` | TLS cert storage              |

### Key settings

| Setting              | Value                                    |
|----------------------|------------------------------------------|
| TLS method           | Route53 DNS-01 (wildcard + per-domain)   |
| ACME email           | futur3.tom@googlemail.com                |
| Auth portal domain   | auth.s85.zt.tiny-systems.eu              |
| Cookie domain        | s85.zt.tiny-systems.eu                   |
| Admin user           | tomjaster (futur3.tom@googlemail.com)    |
| JWT key              | Random 32-byte hex (in /etc/caddy/env)   |

### Environment variables

| Variable               | Location          | Purpose                         |
|------------------------|-------------------|---------------------------------|
| `AWS_ACCESS_KEY_ID`    | `/etc/caddy/env`  | Route53 DNS-01 ACME challenge   |
| `AWS_SECRET_ACCESS_KEY`| `/etc/caddy/env`  | Route53 DNS-01 ACME challenge   |
| `AWS_REGION`           | `/etc/caddy/env`  | eu-central-1                    |
| `JWT_SHARED_KEY`       | `/etc/caddy/env`  | Signs auth portal JWT tokens    |
| `AUTHP_ADMIN_USER`     | `/etc/caddy/env`  | Initial admin username          |
| `AUTHP_ADMIN_EMAIL`    | `/etc/caddy/env`  | Initial admin email             |
| `AUTHP_ADMIN_SECRET`   | `/etc/caddy/env`  | Initial admin password          |

## Network

| Port | Protocol | Purpose            | Exposed to |
|------|----------|--------------------|------------|
| 80   | TCP      | HTTP → HTTPS redir | All        |
| 443  | TCP/UDP  | HTTPS + HTTP/3     | All        |

## Active Site Blocks

| File                         | Domain                        | Auth   | Upstream       |
|------------------------------|-------------------------------|--------|----------------|
| `sites/_auth.caddy`          | auth.s85.zt.tiny-systems.eu   | portal | caddy-security |
| `sites/default-zt.caddy`     | s85.zt.tiny-systems.eu        | yes    | localhost:3100 |
| `sites/default-local.caddy`  | s85.local.tiny-systems.eu     | no     | localhost:3100 |

## Data & Storage

| Path                                  | Purpose          | Backed up? |
|---------------------------------------|------------------|------------|
| `/var/lib/caddy/`                     | Certs, user DB   | ✅ Yes     |
| `/etc/caddy/`                         | Config files     | ✅ Yes     |

## Dependencies

- Depends on: ZeroTier (for ZT domain reachability), aws-cli credentials (Route53)
- Depended on by: dashboard, all future web apps

## Health Check

```bash
systemctl is-active caddy
caddy validate --config /etc/caddy/Caddyfile
curl -sk https://s85.zt.tiny-systems.eu/ -o /dev/null -w "%{http_code}"
curl -sk https://s85.local.tiny-systems.eu/ -o /dev/null -w "%{http_code}"
```

## Common Operations

### Reload config (no downtime)
```bash
sudo systemctl reload caddy
```

### Add a new app
```bash
# Create /etc/caddy/sites/<app>.caddy with @annotations
# Then: sudo systemctl reload caddy
```

### Manage users
```bash
/home/tomjaster/sysadmin-agent/scripts/caddy/manage-users.sh
```

### Rebuild binary (after Caddy upgrade)
```bash
/home/tomjaster/sysadmin-agent/scripts/caddy/build-caddy.sh
```

## Known Issues & Gotchas

- First cert acquisition may time out on attempt 1 (DNS propagation check). Caddy
  retries automatically — certs are usually obtained on attempt 2 (~3 min total).
- The snap version of aws-cli fails due to capability restrictions in service context.
  Use the official binary at `/usr/local/bin/aws`.
- Auth portal cookie is scoped to `s85.zt.tiny-systems.eu` only. Sessions don't
  carry over to `.local` domains (by design — LAN is open).
- `caddy validate` as non-caddy user may warn about env vars — cosmetic only.

## Changelog (app-specific)

| Date       | Change                                              | Agent        |
|------------|-----------------------------------------------------|--------------|
| 2026-04-07 | Installed v2.11.2 with caddy-security + route53; ZT auth + LAN open config | orchestrator |
