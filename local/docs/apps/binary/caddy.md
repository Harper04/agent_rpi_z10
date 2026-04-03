# Caddy — Reverse Proxy + Auth Portal

> Last verified: 2026-04-03
> Responsible agent: caddy
> Source recipe: docs/recipes/caddy.md

## Status: Running

## Installation Details

| Key               | Value                                    |
|-------------------|------------------------------------------|
| Version           | v2.11.2                                  |
| Install method    | Binary (Caddy Download API)              |
| Plugins           | caddy-security, caddy-dns/route53        |
| Binary path       | `/usr/bin/caddy`                         |
| Config            | `/etc/caddy/Caddyfile`                   |
| Site blocks       | `/etc/caddy/sites/*.caddy`               |
| Static files      | `/etc/caddy/static/`                     |
| Environment       | `/etc/caddy/env`                         |
| User database     | `/var/lib/caddy/users.json`              |
| Systemd service   | `caddy.service`                          |
| TLS certs         | `/var/lib/caddy/.local/share/caddy/`     |
| Flavor            | Internet (auth ON by default)            |

## Domains & Sites

| Domain                              | Site block          | Upstream          | Auth    |
|-------------------------------------|---------------------|-------------------|---------|
| `mini-core.tiny-systems.eu`         | `default.caddy`     | Static files      | ON      |
| `auth.mini-core.tiny-systems.eu`    | `_auth.caddy`       | Auth portal       | Portal  |
| `adguard.mini-core.tiny-systems.eu` | `adguard.caddy`     | localhost:3000    | ON      |

## TLS Certificates

| Domain                              | Issuer         | Method   | Status  |
|-------------------------------------|----------------|----------|---------|
| `mini-core.tiny-systems.eu`         | Let's Encrypt  | DNS-01   | Valid   |
| `auth.mini-core.tiny-systems.eu`    | Let's Encrypt  | DNS-01   | Valid   |
| `adguard.mini-core.tiny-systems.eu` | Let's Encrypt  | DNS-01   | Valid   |

## Auth Portal

- **URL:** https://auth.mini-core.tiny-systems.eu/
- **SSO cookie domain:** `mini-core.tiny-systems.eu` (shared across all subdomains)
- **Initial admin:** `tomjaster` (tom@altow.de)
- **Auth policies:** `default_policy` (require login), `api_policy` (allow all)
- **Passkey support:** Available via Portal Settings → Security

## DNS Records

| Record                              | Type  | Value                         |
|-------------------------------------|-------|-------------------------------|
| `mini-core.tiny-systems.eu`         | A     | 178.104.28.233                |
| `mini-core.tiny-systems.eu`         | AAAA  | 2a01:4f8:1c1b:e5ef::1        |
| `*.mini-core.tiny-systems.eu`       | CNAME | mini-core.tiny-systems.eu     |

## Health Check

```bash
systemctl is-active caddy
caddy validate --config /etc/caddy/Caddyfile
curl -sf https://mini-core.tiny-systems.eu/ -o /dev/null -w "%{http_code}"
curl -sf https://auth.mini-core.tiny-systems.eu/ -o /dev/null -w "%{http_code}"
```

## Ports

| Port | Protocol | Service     |
|------|----------|-------------|
| 80   | TCP      | HTTP→HTTPS redirect |
| 443  | TCP      | HTTPS (all sites)   |

## Backup Paths

- `/etc/caddy/` — config files
- `/var/lib/caddy/users.json` — user database with passkeys
- `/var/lib/caddy/.local/share/caddy/` — TLS certs (auto-renewed, low priority)

## Known Issues

- Custom binary must be re-downloaded on Caddy upgrades
- `users.json` ownership must be `caddy:caddy`
- First cert acquisition may timeout on DNS propagation; Caddy auto-retries
