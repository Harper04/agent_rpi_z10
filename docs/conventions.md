# System Conventions

> Cross-cutting rules that ALL agents and skills must follow.
> Loaded globally via `@docs/conventions.md` in CLAUDE.md.
>
> Machine-specific conventions live in `local/docs/conventions.md`.

## How to use this file

- **Before** modifying a system component, scan this file for conventions that match your scope.
- **When adding** a new convention, use the template below.
- Conventions here are **shared upstream** — they apply to all machines.
- Machine-specific conventions go in `local/docs/conventions.md`.

## Convention format

```markdown
## id-slug
**Scope:** Which agents/skills/files this applies to
**Convention:** What MUST be done
**Reason:** Why — what breaks if you skip it
**Added:** ISO date
**Owner:** Which agent owns this convention
```

---

## caddy-site-metadata

**Scope:** Any agent or skill creating/modifying `/etc/caddy/sites/*.caddy`
**Convention:** Every `.caddy` site file MUST include annotation comments at the top:
```
# @name Display Name
# @icon las la-icon-class
# @description One-liner about this service
# @dashboard true|false
```
- `@name` — Human-readable service name (falls back to domain if missing)
- `@icon` — [Line Awesome](https://icons8.com/line-awesome) CSS class (falls back to `las la-globe`)
- `@description` — Brief description for dashboard display
- `@dashboard true` — Show on the system dashboard. Set `false` for internal/infra sites (auth portal, etc.)

**Reason:** The system dashboard auto-discovers services by parsing these annotations. Without them, new services won't appear on the dashboard.
**Added:** 2026-04-04
**Owner:** orchestrator

## dns-via-skill

**Scope:** Any agent managing DNS records
**Convention:** Use the `dns` skill for Route53 record management. Never use raw `aws route53 change-resource-record-sets` directly. After changes, verify with `aws route53 list-resource-record-sets`.
**Reason:** The skill handles idempotency, TTL defaults, and documentation updates. Raw CLI calls risk drift between actual DNS state and `local/docs/system/dns.md`.
**Added:** 2026-04-04
**Owner:** orchestrator

## app-onboarding-checklist

**Scope:** Any agent or skill installing a new application
**Convention:** When adding a new app to the system, complete ALL of these:
1. App running (systemd unit or container)
2. Caddy site file with `@` annotations (see `caddy-site-metadata`)
3. DNS record created (see `dns-via-skill`)
4. App doc created at `local/docs/apps/<app>.md` following `docs/apps/_template.md`
5. App listed in `local/CLAUDE.local.md` → Installed Applications table
6. Port listed in `local/CLAUDE.local.md` → Custom Ports table
7. Changelog entry appended

**Reason:** Ensures every app is discoverable, documented, and visible on the dashboard. Skipping steps leads to "ghost services" that exist but nobody knows about.
**Added:** 2026-04-04
**Owner:** orchestrator

## backup-before-edit

**Scope:** Any agent modifying system config files outside the repo
**Convention:** Before editing a config file (e.g., `/etc/caddy/Caddyfile`, `/etc/systemd/system/*.service`), create a backup: `cp <file> <file>.bak.<ISO-date>`. This is a reinforcement of Core Rule 5 in CLAUDE.md.
**Reason:** Enables quick rollback. Agents check for `.bak.*` files when troubleshooting.
**Added:** 2026-04-04
**Owner:** orchestrator
