---
name: notify
description: Send a notification to the operator via Telegram.
argument-hint: "<message>"
user-invocable: true
---

# Telegram Notification Skill

Send a message to the operator's Telegram channel.

## Configuration

Credentials are read from `local/.env`:
```bash
source local/.env 2>/dev/null || true
```

## Usage

```bash
source local/.env
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d parse_mode="Markdown" \
  -d text="$1"
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
