# DNS Records — strandstr-pi

> **Last updated:** 2026-04-07
> **Managed by:** orchestrator
> **Source of truth:** `local/dns/records/` → Route53 zone `tiny-systems.eu` (ZUS1MBK3O5V24)
> **Sync script:** `scripts/dns/dns-sync.sh`

All records are managed declaratively via files in `local/dns/records/`.
Each record file is named after the FQDN and contains zone-file-style entries.
Ownership is tracked via `_owner.<fqdn> TXT "managed-by=s85"` companion records.

## Managed Records

| FQDN                                 | Type | Value               | Notes                        |
|--------------------------------------|------|---------------------|------------------------------|
| s85.local.tiny-systems.eu            | A    | 192.168.2.93        | Host — LAN IP                |
| s85.zt.tiny-systems.eu               | A    | 192.168.195.217     | Host — ZeroTier IP           |
| ha.s85.local.tiny-systems.eu         | CNAME | s85.local.tiny-systems.eu | Home Assistant — LAN |
| ha.s85.zt.tiny-systems.eu            | CNAME | s85.zt.tiny-systems.eu   | Home Assistant — ZT  |
| unifi.s85.local.tiny-systems.eu      | CNAME | s85.local.tiny-systems.eu | UniFi — LAN         |
| unifi.s85.zt.tiny-systems.eu         | CNAME | s85.zt.tiny-systems.eu   | UniFi — ZT          |
| adguard.s85.local.tiny-systems.eu    | CNAME | s85.local.tiny-systems.eu | AdGuard Home — LAN  |
| adguard.s85.zt.tiny-systems.eu       | CNAME | s85.zt.tiny-systems.eu   | AdGuard Home — ZT   |
| cockpit.s85.local.tiny-systems.eu    | A    | 192.168.2.93        | Cockpit — LAN IP             |
| cockpit.s85.zt.tiny-systems.eu       | A    | 192.168.195.217     | Cockpit — ZeroTier IP        |

## Record Files

```
local/dns/records/
  s85.local.tiny-systems.eu               A 192.168.2.93
  s85.zt.tiny-systems.eu                  A 192.168.195.217
  ha.s85.local.tiny-systems.eu            CNAME s85.local.tiny-systems.eu
  ha.s85.zt.tiny-systems.eu               CNAME s85.zt.tiny-systems.eu
  unifi.s85.local.tiny-systems.eu         CNAME s85.local.tiny-systems.eu
  unifi.s85.zt.tiny-systems.eu            CNAME s85.zt.tiny-systems.eu
  adguard.s85.local.tiny-systems.eu       CNAME s85.local.tiny-systems.eu  (legacy .json name)
  adguard.s85.zt.tiny-systems.eu          CNAME s85.zt.tiny-systems.eu     (legacy .json name)
  cockpit.s85.local.tiny-systems.eu       A 192.168.2.93
  cockpit.s85.zt.tiny-systems.eu          A 192.168.195.217
```

## Sync Operations

To preview changes without applying:
```bash
bash scripts/dns/dns-sync.sh --dry-run
```

To apply:
```bash
bash scripts/dns/dns-sync.sh
```

## Notes

- The `adguard.*.json` files in `local/dns/records/` have incorrect `.json` extensions
  and are skipped by dns-sync.sh (it only parses extension-less files). These should be
  renamed to remove the `.json` suffix in a future cleanup.
- TTL for all records: 300 seconds (default)
- Route53 hosted zone: `tiny-systems.eu` (ID: ZUS1MBK3O5V24)
