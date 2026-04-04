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

| Domain                                | Site block          | Upstream          | Auth    |
|---------------------------------------|---------------------|-------------------|---------|
| `<hostname>.tiny-systems.eu`          | `default.caddy`     | Dashboard / static| ON      |
| `auth.<hostname>.tiny-systems.eu`     | `_auth.caddy`       | Auth portal       | Portal  |
| `<app>.<hostname>.tiny-systems.eu`    | `<app>.caddy`       | localhost:<port>  | ON      |

## TLS Certificates

All domains use Let's Encrypt via DNS-01 challenge (Route53).
Wildcard cert covers `*.<hostname>.tiny-systems.eu`.

## Auth Portal

- **Login URL:** `https://auth.<hostname>.tiny-systems.eu/` (redirects to `/auth/login`)
- **Base path:** `/auth/` (required — caddy-security profile SPA expects this)
- **SSO cookie domain:** `<hostname>.tiny-systems.eu` (shared across all subdomains)
- **Auth policies:** `default_policy` (require login), `api_policy` (allow all)

## Configuration Changes

Log any changes to the Caddy config here:

| Date | Change | Reason |
|------|--------|--------|
| YYYY-MM-DD | Initial install | Fresh deployment |

## Troubleshooting

See `docs/recipes/caddy.md` for common issues and solutions.
