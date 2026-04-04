# Route53 DNS Management

> **Status:** Running
> **Last verified:** 2026-04-04
> **Managed by agent:** `orchestrator`
> **Installation method:** `snap` (aws-cli) + script
> **Recipe:** `docs/recipes/route53-dns.md`

## Overview

File-based DNS record management for AWS Route53. Records are defined as simple
files in `local/dns/records/`, synced to Route53 via `scripts/dns/dns-sync.sh`.
Uses owner tags for safe multi-system shared hosted zones. IP changes are
detected automatically via networkd-dispatcher and synced to Route53.

## Installation

Installed per `docs/recipes/route53-dns.md`, including the dynamic DNS
post-install section.

## Version

| Component          | Version    | Source |
|--------------------|------------|--------|
| aws-cli            | `2.34.22`  | snap   |
| dns-sync.sh        | shared     | git    |
| dns-ip-update.sh   | shared     | git    |

## Configuration

### Hosted Zone

| Key            | Value                   |
|----------------|-------------------------|
| Zone           | `<zone-name>.`          |
| Zone ID        | `<zone-id>`             |
| Owner tag      | `<hostname>`            |
| Default TTL    | `300`                   |

### Config files

| File                                    | Purpose                        |
|-----------------------------------------|--------------------------------|
| `local/dns/dns.conf`                   | Owner tag, TTL, IP_RECORD_MAP  |
| `local/dns/records/`                   | Record files (1/FQDN)          |
| `local/.env`                           | AWS credentials                |
| `scripts/dns/dns-ip-update.sh`         | Dynamic DNS update script      |
| `scripts/dns/networkd-dns-update.sh`   | networkd-dispatcher hook       |

## Network

No ports — outbound HTTPS only (Route53 API).

## Data & Storage

| Path                        | Purpose          | Backed up? |
|-----------------------------|------------------|------------|
| `local/dns/records/`        | Record files     | in git     |
| `local/dns/dns.conf`        | Config           | in git     |

## Health Check

```bash
aws route53 list-hosted-zones --output text | head -5
scripts/dns/dns-sync.sh --dry-run
```

## Common Operations

### Add a record
```bash
/dns add app.example.com A 1.2.3.4
```

### Show diff
```bash
/dns diff
```

### Sync to Route53
```bash
/dns sync
```

## Dynamic DNS (IP Change Detection)

Records are automatically updated when interface IPs change.

**How it works:**
1. `networkd-dispatcher` fires when an interface reaches "routable" state
2. Hook at `/etc/networkd-dispatcher/routable.d/50-dns-update` calls `scripts/dns/dns-ip-update.sh`
3. Script compares current interface IP to the record file
4. If different: updates the file, runs `dns-sync.sh`, sends Telegram notification

**Key files:**
| File | Purpose |
|------|---------|
| `scripts/dns/dns-ip-update.sh` | Compares IPs, updates records, triggers sync |
| `scripts/dns/networkd-dns-update.sh` | networkd-dispatcher hook |
| `local/dns/dns.conf` → `IP_RECORD_MAP` | Maps interfaces to FQDNs |

## Known Issues & Gotchas

- Owner tag (`_owner.<fqdn>` TXT records) prevents deleting records managed by other machines.
- Route53 API: 5 req/sec rate limit — batched per zone.
- AWS credentials in `local/.env` (gitignored, never committed).
- networkd-dispatcher must be enabled (`systemctl enable networkd-dispatcher`).

## Changelog

| Date       | Change                                  | Agent        |
|------------|-----------------------------------------|--------------|
| 2026-04-02 | Initial install                         | orchestrator |
| 2026-04-04 | Added dynamic DNS via networkd-dispatcher | orchestrator |
