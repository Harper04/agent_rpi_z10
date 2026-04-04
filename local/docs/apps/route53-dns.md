# Route53 DNS Management

> **Status:** ✅ Running
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

### 1. Install aws-cli and jq
```bash
sudo snap install aws-cli --classic
sudo apt install -y jq
```

### 2. Configure AWS credentials
Add to `local/.env`:
```bash
AWS_ACCESS_KEY_ID=<your-key>
AWS_SECRET_ACCESS_KEY=<your-secret>
AWS_DEFAULT_REGION=eu-central-1
```

### 3. Configure dns.conf
Create `local/dns/dns.conf`:
```bash
OWNER_TAG="<hostname>"       # unique per machine, used for ownership TXT records
DEFAULT_TTL=300

# Interface-to-FQDN mapping for dynamic DNS updates.
# Format: "iface=fqdn iface=fqdn ..."
# Use + suffix for prefix matching (e.g. zt+ matches zt0, ztly7nnh6j)
IP_RECORD_MAP="br0=app.example.com zt+=app.zt.example.com"
```

### 4. Add DNS record files
One file per FQDN in `local/dns/records/`:
```bash
# Example: local/dns/records/app.example.com
A 192.168.2.32
```

### 5. Verify access and sync
```bash
aws route53 list-hosted-zones --output text | head -5
scripts/dns/dns-sync.sh --dry-run    # check plan
scripts/dns/dns-sync.sh              # apply
```

### 6. Install networkd-dispatcher hook (dynamic DNS)
This hook automatically updates DNS records when interface IPs change
(e.g. DHCP lease renewal, reboot on a different network).
```bash
sudo cp scripts/dns/networkd-dns-update.sh /etc/networkd-dispatcher/routable.d/50-dns-update
sudo chmod +x /etc/networkd-dispatcher/routable.d/50-dns-update
sudo systemctl enable networkd-dispatcher
```

Verify the hook works:
```bash
# Manual test — should detect any stale IPs
scripts/dns/dns-ip-update.sh --dry-run

# Check dispatcher logs after a network event
sudo journalctl -t dns-update --since "10 min ago"
```

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
| Zone           | `tiny-systems.eu.`      |
| Zone ID        | `ZUS1MBK3O5V24`         |
| Owner tag      | `ziegeleiweg-pi`        |
| Default TTL    | `300`                   |

### Config files

| File                         | Purpose                        |
|------------------------------|--------------------------------|
| `local/dns/dns.conf`        | Owner tag, TTL, IP_RECORD_MAP  |
| `local/dns/records/`        | Record files (1/FQDN)          |
| `local/.env`                | AWS credentials                |
| `scripts/dns/dns-ip-update.sh`     | Dynamic DNS update script      |
| `scripts/dns/networkd-dns-update.sh` | networkd-dispatcher hook     |

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

## Dynamic DNS (IP Change Detection)

Records are automatically updated when interface IPs change. See **Installation step 6** for setup.

**How it works:**
1. `networkd-dispatcher` fires when an interface reaches "routable" state (DHCP lease obtained)
2. Hook at `/etc/networkd-dispatcher/routable.d/50-dns-update` calls `scripts/dns/dns-ip-update.sh`
3. Script compares current interface IP to the record file
4. If different: updates the file, runs `dns-sync.sh`, sends Telegram notification

**Key files:**
| File | Purpose |
|------|---------|
| `scripts/dns/dns-ip-update.sh` | Compares IPs, updates records, triggers sync |
| `scripts/dns/networkd-dns-update.sh` | networkd-dispatcher hook (installed to `/etc/networkd-dispatcher/routable.d/50-dns-update`) |
| `local/dns/dns.conf` → `IP_RECORD_MAP` | Maps interfaces to FQDNs |

**Manual trigger:**
```bash
scripts/dns/dns-ip-update.sh --dry-run   # show what would change
scripts/dns/dns-ip-update.sh             # apply changes
```

## Known Issues & Gotchas

- Owner tag (`_owner.<fqdn>` TXT records) prevents deleting records managed by other machines.
- Route53 API: 5 req/sec rate limit — batched per zone.
- AWS credentials in `local/.env` (gitignored, never committed).
- networkd-dispatcher must be enabled (`systemctl enable networkd-dispatcher`).

## Changelog (app-specific)

| Date       | Change                                  | Agent        |
|------------|-----------------------------------------|--------------|
| 2026-04-02 | Initial install: aws-cli 2.34.22, zone tiny-systems.eu | orchestrator |
| 2026-04-04 | Added dynamic DNS: dns-ip-update.sh + networkd-dispatcher hook | orchestrator |
