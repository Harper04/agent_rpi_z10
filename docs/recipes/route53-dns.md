---
name: "route53-dns"
method: snap
version: "latest"
ports: []
dependencies: [aws-cli, jq]
reverse-proxy: false
domain: ""
data-paths: ["local/dns/records"]
backup: true
---

# Recipe: Route53 DNS Management

> Tested on: Ubuntu 24.04+
> Last updated: 2026-04-02

## Overview

File-based DNS record management for AWS Route53. Define records as simple files
(zone-file style), sync to Route53 on demand. Uses owner tags for safe multi-system
shared hosted zones.

## Prerequisites

- `jq` must be installed (usually already present)
- AWS IAM credentials with Route53 permissions:
  - `route53:ListHostedZones`
  - `route53:ListResourceRecordSets`
  - `route53:ChangeResourceRecordSets`

## Installation Steps

```bash
# Install AWS CLI v2
sudo snap install aws-cli --classic

# Create record directory
mkdir -p local/dns/records

# Write config (adjust OWNER_TAG to this machine's hostname)
cat > local/dns/dns.conf << 'EOF'
OWNER_TAG="$(hostname -s)"
DEFAULT_TTL=300
EOF

# Add AWS credentials to local/.env
cat >> local/.env << 'EOF'
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_DEFAULT_REGION=eu-central-1
EOF

# Verify AWS access
source local/.env
aws route53 list-hosted-zones --output table
```

## Configuration

### Record files

Create files in `local/dns/records/` named after the FQDN:

```bash
# local/dns/records/app.example.com
A     178.104.28.233
AAAA  2a01:4f8::1
```

```bash
# local/dns/records/mail.example.com
MX    10 mail1.example.com
MX    20 mail2.example.com
# ttl=600
```

### Config file

`local/dns/dns.conf`:

| Variable      | Default       | Purpose                           |
|---------------|---------------|-----------------------------------|
| `OWNER_TAG`   | `$(hostname)` | Identifies records owned by this machine |
| `DEFAULT_TTL` | `300`         | Default TTL if not set per-file   |

### Environment variables (in local/.env)

| Variable               | Purpose                    |
|------------------------|----------------------------|
| `AWS_ACCESS_KEY_ID`    | AWS IAM access key         |
| `AWS_SECRET_ACCESS_KEY`| AWS IAM secret key         |
| `AWS_DEFAULT_REGION`   | AWS region (e.g. eu-central-1) |

## Health Check

```bash
# Verify AWS access
aws route53 list-hosted-zones --output text | head -5

# Dry-run sync
scripts/dns/dns-sync.sh --dry-run
```

## Post-Install

1. Add AWS credentials to `local/.env`
2. Create your first record file in `local/dns/records/`
3. Run `/dns diff` to verify detection
4. Run `/dns sync` to apply

## Known Issues

- Route53 record sets don't support AWS resource tags, so we use companion
  `_owner.<fqdn>` TXT records to track ownership.
- Hosted zone is auto-detected by longest suffix match — ensure your zones
  don't overlap ambiguously.
- Route53 API has a 5 requests/sec rate limit — large batches are submitted
  as single API calls per zone to avoid this.
