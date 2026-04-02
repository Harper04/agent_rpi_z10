# Route53 DNS Management

> **Status:** ✅ Running
> **Last verified:** 2026-04-02
> **Managed by agent:** `orchestrator`
> **Installation method:** `snap` (aws-cli) + script
> **Recipe:** `docs/recipes/route53-dns.md`

## Overview

File-based DNS record management for AWS Route53. Records are defined as simple
files in `local/dns/records/`, synced to Route53 via `scripts/dns/dns-sync.sh`.
Uses owner tags for safe multi-system shared hosted zones.

## Version

| Component    | Version    | Source |
|--------------|------------|--------|
| aws-cli      | `2.34.22`  | snap   |
| dns-sync.sh  | shared     | git    |

## Configuration

### Hosted Zone

| Key            | Value                   |
|----------------|-------------------------|
| Zone           | `tiny-systems.eu.`      |
| Zone ID        | `ZUS1MBK3O5V24`         |
| Owner tag      | `ziegeleiweg-pi`        |
| Default TTL    | `300`                   |

### Config files

| File                         | Purpose              |
|------------------------------|----------------------|
| `local/dns/dns.conf`        | Owner tag & TTL      |
| `local/dns/records/`        | Record files (1/FQDN)|
| `local/.env`                | AWS credentials      |

## Network

No ports — outbound HTTPS only (Route53 API).

## Data & Storage

| Path                        | Purpose          | Backed up? |
|-----------------------------|------------------|------------|
| `local/dns/records/`        | Record files     | ✅ in git  |
| `local/dns/dns.conf`        | Config           | ✅ in git  |

## Dependencies

- Depends on: aws-cli, jq, network connectivity
- Depended on by: (any service needing DNS records)

## Health Check

```bash
aws route53 list-hosted-zones --output text | head -5
scripts/dns/dns-sync.sh --dry-run
```

## Common Operations

### Add a record
```bash
/dns add app.tiny-systems.eu A 1.2.3.4
```

### Show diff
```bash
/dns diff
```

### Sync to Route53
```bash
/dns sync
```

### List local records
```bash
/dns list
```

## Known Issues & Gotchas

- Owner tag (`_owner.<fqdn>` TXT records) prevents deleting records managed by other machines.
- Route53 API: 5 req/sec rate limit — batched per zone.
- AWS credentials in `local/.env` (gitignored, never committed).

## Changelog (app-specific)

| Date       | Change                                  | Agent        |
|------------|-----------------------------------------|--------------|
| 2026-04-02 | Initial install: aws-cli 2.34.22, zone tiny-systems.eu | orchestrator |
