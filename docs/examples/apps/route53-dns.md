# Route53 DNS Management

> **Example doc** — sanitized from a real machine. Copy to `local/docs/apps/apt/route53-dns.md` and fill in your values.

> **Status:** ✅ Configured
> **Last verified:** YYYY-MM-DD
> **Managed by agent:** `orchestrator`
> **Installation method:** `apt` (awscli)
> **Recipe:** `docs/recipes/route53-dns.md`

## Overview

File-based DNS record management for AWS Route53. Records are defined as files in
`local/dns/records/` and synced to Route53 on demand via `/dns sync`. Uses owner
tags for safe multi-system shared hosted zones.

## Installation

```bash
sudo apt install -y awscli
mkdir -p local/dns/records
```

## Version

| Component    | Version             | Source              |
|--------------|---------------------|---------------------|
| awscli       | see `aws --version` | apt                 |
| jq           | (installed)         | apt                 |
| dns-sync.sh  | shared              | scripts/dns/        |

## Configuration

### Hosted Zone

| Key            | Value                   |
|----------------|-------------------------|
| Zone           | `<domain>.`             |
| Zone ID        | `<zone-id>`             |
| Owner tag      | `<hostname>`            |
| Default TTL    | `60`                    |

### Config files

| File                        | Purpose                    |
|-----------------------------|----------------------------|
| `local/dns/dns.conf`       | Owner tag, default TTL     |
| `local/dns/records/*`      | DNS record definitions     |
| `local/.env`               | AWS credentials            |

### Key settings

- `OWNER_TAG=<hostname>` — identifies our records in shared hosted zones
- `DEFAULT_TTL=60` — default TTL for records
- Hosted zones auto-detected from record FQDNs

### Environment variables

| Variable               | Value        | Purpose                |
|------------------------|-------------|------------------------|
| `AWS_ACCESS_KEY_ID`    | (in .env)   | AWS IAM access key     |
| `AWS_SECRET_ACCESS_KEY`| (in .env)   | AWS IAM secret key     |
| `AWS_DEFAULT_REGION`   | (in .env)   | AWS region             |

## Network

No listening ports — outbound HTTPS to AWS API only.

## Data & Storage

| Path                      | Purpose          | Backed up? |
|---------------------------|------------------|------------|
| `local/dns/records/`     | Record files     | ✅ Yes (git) |
| `local/dns/dns.conf`     | Config           | ✅ Yes (git) |

## Dependencies

- Depends on: `awscli`, `jq`, `bash`
- Depended on by: any service needing DNS records

## Health Check

```bash
aws route53 list-hosted-zones --output text | head -5
scripts/dns/dns-sync.sh --dry-run
```

## Common Operations

### Add a record
```
/dns add app.<domain> A <server-ip>
```

### Remove a record
```
/dns remove app.<domain> A
```

### Show planned changes
```
/dns diff
```

### Apply changes
```
/dns sync
```

### List all records
```
/dns list
```

## Managed Records

| FQDN | Types | Notes |
|-------|-------|-------|
| `<hostname>.<domain>` | A, AAAA | Server root |
| `*.<hostname>.<domain>` | CNAME | Wildcard for TLS certs only |
| `<app>.<hostname>.<domain>` | A, AAAA | Per-app subdomain (repeat per app) |

## Dynamic DNS (IP Change Detection)

Records can be automatically updated when interface IPs change.

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

- Owner tags are TXT records (`_owner.<fqdn>`) — don't manually delete them in Route53
- Zone auto-detection requires at least one public hosted zone in the AWS account
- AWS credentials must have Route53 full access (ListHostedZones + ChangeResourceRecordSets)
- Route53 API: 5 req/sec rate limit — batched per zone
- `networkd-dispatcher` must be enabled if using dynamic DNS (`systemctl enable networkd-dispatcher`)

## Changelog (app-specific)

| Date       | Change                  | Agent           |
|------------|-------------------------|-----------------|
| YYYY-MM-DD | Initial setup           | orchestrator    |
