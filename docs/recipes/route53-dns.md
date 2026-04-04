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
> Last updated: 2026-04-04

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

# Seed config from template (if not already present)
cp -n templates/local/dns/dns.conf local/dns/dns.conf
mkdir -p local/dns/records

# Edit local/dns/dns.conf — set OWNER_TAG to this machine's hostname
$EDITOR local/dns/dns.conf

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

`local/dns/dns.conf` (seed from `templates/local/dns/dns.conf`):

| Variable        | Default       | Purpose                           |
|-----------------|---------------|-----------------------------------|
| `OWNER_TAG`     | `$(hostname)` | Identifies records owned by this machine |
| `DEFAULT_TTL`   | `300`         | Default TTL if not set per-file   |
| `IP_RECORD_MAP` | (empty)       | Interface-to-FQDN mappings for dynamic DNS (see below) |

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

### Dynamic DNS (automatic IP change detection)

Automatically updates DNS records when interface IPs change (DHCP lease
renewal, reboot on a different network). Requires `networkd-dispatcher`.

**1. Configure interface-to-FQDN mappings** in `local/dns/dns.conf`:
```bash
# Append to existing dns.conf — adjust to your interfaces and FQDNs
# Use + suffix for prefix matching (e.g. zt+ matches zt0, ztly7nnh6j)
IP_RECORD_MAP="br0=app.example.com zt+=app.zt.example.com"
```

**2. Install the networkd-dispatcher hook:**
```bash
sudo cp scripts/dns/networkd-dns-update.sh /etc/networkd-dispatcher/routable.d/50-dns-update
sudo chmod +x /etc/networkd-dispatcher/routable.d/50-dns-update
sudo systemctl enable networkd-dispatcher
```

**3. Verify:**
```bash
scripts/dns/dns-ip-update.sh --dry-run       # check for stale IPs
sudo journalctl -t dns-update --since "10 min ago"  # after a network event
```

## Known Issues

- Route53 record sets don't support AWS resource tags, so we use companion
  `_owner.<fqdn>` TXT records to track ownership.
- Hosted zone is auto-detected by longest suffix match — ensure your zones
  don't overlap ambiguously.
- Route53 API has a 5 requests/sec rate limit — large batches are submitted
  as single API calls per zone to avoid this.
