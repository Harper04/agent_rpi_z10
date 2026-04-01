---
name: upgrade
description: Run a system upgrade with safety checks
argument-hint: "[--security-only]"
user-invocable: true
---

Delegate to the `system-updater` agent:

1. Run the `system-upgrade` skill with provided arguments
2. Document results via `doc-update` skill
3. Send summary via `notify` skill if Telegram is configured
