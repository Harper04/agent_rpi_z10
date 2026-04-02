---
name: notify
description: Send a notification to the operator via Telegram.
argument-hint: "<message>"
user-invocable: true
---

# Telegram Notification Skill

Send a message to the operator's Telegram channel.

## Configuration

Credentials are read from `local/.env` via the shared library:
```bash
source scripts/lib/common.sh && common_init "$0"
safe_source
```

## Usage

```bash
source scripts/lib/common.sh && common_init "$0"
safe_source
telegram_send "$1"
```

## Message Formatting

Use Markdown formatting:
- `*bold*` for emphasis
- `` `code` `` for commands/paths
- Prefix with emoji for severity:
  - ✅ Success
  - ⚠️ Warning
  - 🚨 Error / Critical
  - ℹ️ Info

## Templates

### Upgrade complete
```
✅ *System Upgrade Complete*
Host: `$(hostname)`
Packages updated: <n>
Reboot required: Yes/No
```

### Health check alert
```
⚠️ *Health Check Alert*
Host: `$(hostname)`
Issue: <description>
Action required: <recommendation>
```

### Upstream contribution
```
📤 *Upstream Proposal*
Host: `$(hostname)`
Branch: `propose/<slug>`
Files: <list>
Description: <what improved>
```
