# Route53 DNS Management

> **Status:** ✅ Configured
> **Last verified:** 2026-04-02
> **Managed by agent:** `orchestrator`
> **Installation method:** `apt` (awscli)
> **Recipe:** `docs/recipes/route53-dns.md`

## Overview

File-based DNS record management for AWS Route53. Records are defined as files in
`local/dns/records/` and synced to Route53 on demand via `/dns sync`.

## Installation

```bash
sudo apt install -y awscli
mkdir -p local/dns/records
```

## Version

| Component    | Version      | Source              |
|--------------|--------------|---------------------|
| awscli       | see `aws --version` | apt              |
| jq           | 1.7.1        | apt                 |
| dns-sync.sh  | 1.0.0        | scripts/dns/        |

## Configuration

### Config files

| File                        | Purpose                    |
|-----------------------------|----------------------------|
| `local/dns/dns.conf`       | Owner tag, default TTL     |
| `local/dns/records/*`      | DNS record definitions     |
| `local/.env`               | AWS credentials            |

### Key settings

- `OWNER_TAG=min-core` — identifies our records in shared hosted zones
- `DEFAULT_TTL=300` — default TTL for records
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
/dns add app.example.com A 178.104.28.233
```

### Remove a record
```
/dns remove app.example.com A
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
| (none yet) | — | — |

## Known Issues & Gotchas

- Owner tags are TXT records (`_owner.<fqdn>`) — don't manually delete them in Route53
- Zone auto-detection requires at least one public hosted zone in the AWS account
- AWS credentials must have Route53 full access (ListHostedZones + ChangeResourceRecordSets)

## Changelog (app-specific)

| Date       | Change                  | Agent           |
|------------|-------------------------|-----------------|
| 2026-04-02 | Initial setup           | orchestrator    |
