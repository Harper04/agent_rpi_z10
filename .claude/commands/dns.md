# DNS Record Management

Manage DNS records in AWS Route53 via local record files.

## Syntax

```
/dns <action> [args...]
```

## Actions

### `/dns add <fqdn> <type> <value>`
Add a DNS record. Creates or appends to the record file, then syncs.

Example:
```
/dns add app.example.com A 178.104.28.233
/dns add app.example.com AAAA 2a01:4f8::1
/dns add mail.example.com MX 10 mail.example.com
/dns add www.example.com CNAME example.com
```

### `/dns remove <fqdn> [type]`
Remove a DNS record. If type is given, removes only that type from the file.
If no type, removes the entire file (all records for that host). Then syncs.

Example:
```
/dns remove app.example.com AAAA    # remove just the AAAA record
/dns remove old.example.com         # remove all records for this host
```

### `/dns list`
Show all record files and their contents.

### `/dns diff`
Show what would change in Route53 without applying (dry-run).

### `/dns sync`
Sync all record files to Route53. Shows dry-run first, asks for confirmation, then applies.

## Implementation

Use the `dns-record` skill to handle each action. The skill:
1. Manipulates files in `local/dns/records/`
2. Runs `scripts/dns/dns-sync.sh` (with `--dry-run` first for sync)
3. Updates documentation and commits changes

## Record File Format

Files live in `local/dns/records/`. Filename = FQDN. Content = zone-file style:

```
A     178.104.28.233
AAAA  2a01:4f8::1
MX    10 mail.example.com
# ttl=600
```
