---
name: "caddy"
method: binary
version: "latest"
ports: [80, 443]
dependencies: [curl, jq]
reverse-proxy: true
domain: "<hostname>.tiny-systems.eu"
data-paths: ["/var/lib/caddy", "/etc/caddy", "/opt/caddy"]
backup: true
flavors: [internet, lan]
plugins:
  - github.com/greenpau/caddy-security
  - github.com/caddy-dns/route53
---

# Recipe: Caddy Web Server — Reverse Proxy + Auth Portal

> Tested on: Debian 12 / Ubuntu 22.04+
> Last updated: 2026-04-03

## Overview

Caddy is a modern web server with automatic HTTPS. This recipe configures it as the
**primary reverse proxy** with an **authentication portal** (caddy-security) providing
SSO via passkeys/WebAuthn for all web applications on the machine.

### Key Features

- **Automatic HTTPS** via Route53 DNS-01 challenge (supports wildcard certs)
- **Authentication portal** with passkey/WebAuthn, TOTP, and password support
- **SSO** — log in once, access all apps via shared cookie on `*.<hostname>.<zone>`
- **Per-app auth policies** — auth ON by default, opt-out for API paths
- **Two flavors** — Internet (auth required) and LAN (auth optional)

### Architecture

```
[Browser] → Caddy (ports 80/443, HTTPS)
  ├── auth.<host>.<zone>           → caddy-security auth portal
  ├── <host>.<zone>                → default static landing page
  ├── <app>.<host>.<zone>          → reverse_proxy → app (auth required)
  └── <app>.<host>.<zone>/api/*    → reverse_proxy → app (auth skipped)
```

SSO works via a JWT cookie scoped to `*.<host>.<zone>`. Once authenticated on
the portal, all subdomains recognize the session.

## Prerequisites

- `curl` and `jq` must be installed
- Ports 80 and 443 must be free (move any existing services first)
- DNS records must point to this machine (use Route53 DNS tool)
- AWS credentials with Route53 permissions (for DNS-01 TLS challenges)
- `local/.env` must contain `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

## Flavor: Internet vs LAN

This recipe has two flavors. Choose based on your deployment:

| Aspect           | Internet                              | LAN (ZeroTier/local)                       |
|------------------|---------------------------------------|--------------------------------------------|
| Domain pattern   | `<svc>.<host>.tiny-systems.eu`        | `<svc>.<host>.<zt\|local>.tiny-systems.eu` |
| Auth default     | **ON** — all routes require login     | **OFF** — open by default, opt-in auth     |
| Bind IPs         | `0.0.0.0` (all interfaces)            | ZeroTier/LAN IP only                       |
| TLS              | Route53 DNS-01 (wildcard)             | Route53 DNS-01 (wildcard)                  |
| Portal           | Always active                         | Active only if auth is opted-in            |
| Firewall         | ufw allow 80,443/tcp                  | ufw allow from ZT subnet to 80,443        |

### DNS Patterns

**Internet flavor:**
```
<hostname>.tiny-systems.eu          → A/AAAA → public IP
*.<hostname>.tiny-systems.eu        → CNAME  → <hostname>.tiny-systems.eu
```

**LAN flavor (ZeroTier):**
```
<hostname>.zt.tiny-systems.eu       → A → ZeroTier IP
*.<hostname>.zt.tiny-systems.eu     → CNAME → <hostname>.zt.tiny-systems.eu
```

**LAN flavor (local):**
```
<hostname>.local.tiny-systems.eu    → A → LAN IP
*.<hostname>.local.tiny-systems.eu  → CNAME → <hostname>.local.tiny-systems.eu
```

## Installation Steps

### Step 1 — Install custom Caddy binary

Caddy needs two plugins not in the default build:
- `caddy-security` (auth portal with passkeys)
- `caddy-dns/route53` (DNS-01 ACME challenge via AWS Route53)

**Option A — Caddy Download API (recommended, no build tools needed):**

```bash
# Download custom Caddy binary with both plugins
curl -fSL "https://caddyserver.com/api/download?os=linux&arch=$(dpkg --print-architecture)&p=github.com/greenpau/caddy-security&p=github.com/caddy-dns/route53" \
  -o /tmp/caddy-custom

# Verify it runs
chmod +x /tmp/caddy-custom
/tmp/caddy-custom version
/tmp/caddy-custom list-modules | grep -E "security|route53"
# Expected: dns.providers.route53, http.handlers.authenticate, http.handlers.authorize, security

# Install
sudo systemctl stop caddy 2>/dev/null || true
sudo install -m 755 /tmp/caddy-custom /usr/bin/caddy
caddy version
```

**Option B — Build with xcaddy (for pinned versions / reproducibility):**

```bash
# Install Go (if not present)
sudo snap install go --classic

# Install xcaddy
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# Build
~/go/bin/xcaddy build \
  --with github.com/greenpau/caddy-security \
  --with github.com/caddy-dns/route53

# Install
sudo systemctl stop caddy 2>/dev/null || true
sudo install -m 755 ./caddy /usr/bin/caddy
caddy version
```

### Step 2 — Create directory structure

```bash
sudo mkdir -p /etc/caddy/sites
sudo mkdir -p /etc/caddy/static
sudo mkdir -p /var/lib/caddy/.local/share/caddy
sudo chown -R caddy:caddy /var/lib/caddy
```

### Step 3 — Create systemd service

If Caddy was installed via apt previously, the unit file already exists.
Otherwise create it:

```bash
sudo tee /etc/systemd/system/caddy.service > /dev/null << 'EOF'
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
EnvironmentFile=-/etc/caddy/env
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-server.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable caddy
```

### Step 4 — Create environment file

```bash
# Source secrets
source local/.env

sudo tee /etc/caddy/env > /dev/null << EOF
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_REGION=${AWS_DEFAULT_REGION:-eu-central-1}
JWT_SHARED_KEY=$(openssl rand -hex 32)
AUTHP_ADMIN_USER=<admin-username>
AUTHP_ADMIN_EMAIL=<admin-email>
AUTHP_ADMIN_SECRET=<admin-password>
EOF

sudo chmod 600 /etc/caddy/env
sudo chown caddy:caddy /etc/caddy/env
```

## Configuration

### Caddyfile — Global config (Internet flavor)

```caddyfile
# /etc/caddy/Caddyfile — Main config
{
    email admin@tiny-systems.eu

    order authenticate before respond
    order authorize before basicauth

    # Wildcard TLS via Route53 DNS-01
    acme_dns route53

    security {
        local identity store localdb {
            realm local
            path /var/lib/caddy/users.json
        }

        authentication portal myportal {
            crypto default token lifetime 86400
            crypto key sign-verify {env.JWT_SHARED_KEY}
            enable identity store localdb
            cookie domain <hostname>.tiny-systems.eu
            cookie lifetime 86400
            ui {
                links {
                    "Home" https://<hostname>.tiny-systems.eu/ icon "las la-home"
                    "My Identity" "/whoami" icon "las la-user"
                    "Portal Settings" "/settings" icon "las la-cog"
                }
                password_recovery_enabled no
            }
            transform user {
                match origin local
                action add role authp/user
            }
        }

        authorization policy default_policy {
            set auth url https://auth.<hostname>.tiny-systems.eu/
            crypto key verify {env.JWT_SHARED_KEY}
            allow roles authp/admin authp/user
            acl rule {
                comment allow authenticated users
                match role authp/user authp/admin
                allow stop log info
            }
            acl rule {
                comment default deny
                match any
                deny log warn
            }
        }

        authorization policy api_policy {
            set auth url https://auth.<hostname>.tiny-systems.eu/
            crypto key verify {env.JWT_SHARED_KEY}
            # API policy: allow all (no auth required)
            acl rule {
                comment allow all API access
                match any
                allow stop log info
            }
        }
    }
}

# Import site-specific configs
import /etc/caddy/sites/*.caddy
```

### Caddyfile — Global config (LAN flavor, auth OFF by default)

```caddyfile
# /etc/caddy/Caddyfile — LAN flavor
{
    email admin@tiny-systems.eu

    order authenticate before respond
    order authorize before basicauth

    acme_dns route53

    # Auth portal is defined but not enforced by default.
    # Individual sites opt-in with: authorize with default_policy
    security {
        local identity store localdb {
            realm local
            path /var/lib/caddy/users.json
        }

        authentication portal myportal {
            crypto default token lifetime 86400
            crypto key sign-verify {env.JWT_SHARED_KEY}
            enable identity store localdb
            cookie domain <hostname>.zt.tiny-systems.eu
            cookie lifetime 86400
            ui {
                links {
                    "Home" https://<hostname>.zt.tiny-systems.eu/ icon "las la-home"
                    "My Identity" "/whoami" icon "las la-user"
                }
                password_recovery_enabled no
            }
            transform user {
                match origin local
                action add role authp/user
            }
        }

        authorization policy default_policy {
            set auth url https://auth.<hostname>.zt.tiny-systems.eu/
            crypto key verify {env.JWT_SHARED_KEY}
            allow roles authp/admin authp/user
            acl rule {
                comment allow authenticated users
                match role authp/user authp/admin
                allow stop log info
            }
            acl rule {
                comment default deny
                match any
                deny log warn
            }
        }
    }
}

import /etc/caddy/sites/*.caddy
```

### Site blocks

#### Auth portal — `/etc/caddy/sites/_auth.caddy`

```caddyfile
auth.<hostname>.tiny-systems.eu {
    tls {
        dns route53
    }
    route {
        authenticate with myportal
    }
}
```

#### Default landing page — `/etc/caddy/sites/default.caddy`

Internet flavor (auth required):
```caddyfile
<hostname>.tiny-systems.eu {
    tls {
        dns route53
    }
    route {
        authorize with default_policy
        root * /etc/caddy/static
        file_server
    }
}
```

LAN flavor (no auth):
```caddyfile
<hostname>.zt.tiny-systems.eu {
    tls {
        dns route53
    }
    root * /etc/caddy/static
    file_server
}
```

#### App template — `/etc/caddy/sites/<app>.caddy`

Internet flavor (auth required, API paths exempt):
```caddyfile
<app>.<hostname>.tiny-systems.eu {
    tls {
        dns route53
    }

    # API paths — no auth
    route /api/* {
        reverse_proxy localhost:<app-port>
    }

    # Everything else — auth required
    route {
        authorize with default_policy
        reverse_proxy localhost:<app-port>
    }
}
```

LAN flavor (no auth by default, opt-in):
```caddyfile
# Without auth (default for LAN)
<app>.<hostname>.zt.tiny-systems.eu {
    tls {
        dns route53
    }
    reverse_proxy localhost:<app-port>
}

# With auth (opt-in for LAN — add authorize directive)
<app>.<hostname>.zt.tiny-systems.eu {
    tls {
        dns route53
    }
    route {
        authorize with default_policy
        reverse_proxy localhost:<app-port>
    }
}
```

### Static landing page

```html
<!-- /etc/caddy/static/index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ HOSTNAME }}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex; justify-content: center; align-items: center;
            min-height: 100vh; margin: 0;
            background: #0f172a; color: #e2e8f0;
        }
        .card {
            text-align: center; padding: 3rem;
            background: #1e293b; border-radius: 1rem;
            box-shadow: 0 4px 24px rgba(0,0,0,0.3);
        }
        h1 { font-size: 2rem; margin-bottom: 0.5rem; }
        .subtitle { color: #94a3b8; font-size: 0.9rem; }
        .status { margin-top: 1.5rem; color: #22c55e; }
    </style>
</head>
<body>
    <div class="card">
        <h1>{{ HOSTNAME }}</h1>
        <p class="subtitle">Managed by sysadmin-agent</p>
        <p class="status">&#9679; Online</p>
    </div>
</body>
</html>
```

### Environment variables

| Variable               | Location         | Purpose                              |
|------------------------|------------------|--------------------------------------|
| `AWS_ACCESS_KEY_ID`    | `/etc/caddy/env` | Route53 DNS-01 ACME challenge        |
| `AWS_SECRET_ACCESS_KEY`| `/etc/caddy/env` | Route53 DNS-01 ACME challenge        |
| `AWS_REGION`           | `/etc/caddy/env` | AWS region for Route53               |
| `JWT_SHARED_KEY`       | `/etc/caddy/env` | Signs/verifies auth portal JWT tokens|
| `AUTHP_ADMIN_USER`     | `/etc/caddy/env` | Initial admin username               |
| `AUTHP_ADMIN_EMAIL`    | `/etc/caddy/env` | Initial admin email                  |
| `AUTHP_ADMIN_SECRET`   | `/etc/caddy/env` | Initial admin password               |

## Reverse Proxy

Caddy IS the reverse proxy. Each app's recipe should include a site block to be placed
in `/etc/caddy/sites/<app>.caddy`. Use the app template above.

### Adding a new app behind Caddy

1. Create DNS record: `local/dns/records/<app>.<hostname>.tiny-systems.eu`
   (or rely on wildcard CNAME if already set up)
2. Write site block: `/etc/caddy/sites/<app>.caddy`
3. Validate: `caddy validate --config /etc/caddy/Caddyfile`
4. Reload: `systemctl reload caddy`
5. Verify: `curl -I https://<app>.<hostname>.tiny-systems.eu`

## Health Check

```bash
# Service status
systemctl is-active caddy

# Config validation
caddy validate --config /etc/caddy/Caddyfile

# Module verification (plugins loaded)
caddy list-modules 2>/dev/null | grep -cE "security|route53"
# Expected: >= 2

# HTTPS check
curl -sf https://<hostname>.tiny-systems.eu/ -o /dev/null && echo "OK" || echo "FAIL"

# Auth portal check
curl -sf https://auth.<hostname>.tiny-systems.eu/ -o /dev/null -w "%{http_code}" && echo " OK"

# TLS cert check
curl -vI https://<hostname>.tiny-systems.eu 2>&1 | grep -E "expire|issuer|subject"
```

## Post-Install

1. Start Caddy: `sudo systemctl start caddy`
2. Verify TLS cert was obtained: check logs `journalctl -u caddy --since "5 min ago"`
3. Open `https://auth.<hostname>.tiny-systems.eu/` — log in with admin credentials
4. Register a passkey via Portal Settings → Security → Add Hardware Key
5. After passkey registration, password can optionally be disabled
6. Test SSO: visit any app subdomain — should recognize the session without re-login

## Known Issues

- Custom Caddy binary must be rebuilt/re-downloaded after Caddy version upgrades.
  The `scripts/caddy/build-caddy.sh` script handles this.
- `caddy-security` creates `/var/lib/caddy/users.json` on first start with a default
  admin user. Credentials are logged to stdout (visible in `journalctl -u caddy`).
  Change password immediately.
- Cookie domain must match the wildcard scope. For SSO across subdomains, set
  `cookie domain <hostname>.tiny-systems.eu` (no leading dot needed in caddy-security).
- JWT_SHARED_KEY must be the same in the auth portal and all authorization policies.
  It's loaded from `/etc/caddy/env` via `{env.JWT_SHARED_KEY}`.
- Route53 DNS-01 can take 30-60s for propagation. First cert acquisition may be slow.
- If ports 80/443 are occupied, Caddy won't start. Free them first (e.g., move AdGuard
  Home web UI to a non-standard port, then proxy it through Caddy).
- On `caddy reload`, existing connections are gracefully drained. Prefer reload over restart.
- Wildcard certs cover `*.<hostname>.tiny-systems.eu` but NOT `<hostname>.tiny-systems.eu`
  itself. Both the bare domain and wildcard need TLS blocks (Caddy handles this
  automatically when both site blocks exist).
