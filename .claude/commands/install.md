---
name: install
description: Install a new application on this system with interactive planning
argument-hint: "<app-name> [--method apt|docker|k3s|snap|binary|source] [--recipe <name>]"
user-invocable: true
---

Install a new application on this machine. This command conducts an interactive
interview to gather requirements before executing the installation.

Delegate to the orchestrator:

1. Check for a recipe: `docs/recipes/<app>.md` or `local/recipes/<app>.md`
2. If a recipe exists, load it as context and use its defaults
3. Run the `app-install` skill with provided arguments
4. The skill will conduct an interactive interview before executing
5. Document results via `doc-update` skill
6. Send summary via `notify` skill if Telegram is configured

**Examples:**
- `/install gitea` — Finds gitea recipe, suggests Docker method, interviews for domain/ports
- `/install nginx --method apt` — Skips method question, interviews for remaining options
- `/install myapp --recipe custom-app` — Loads custom-app recipe regardless of app name
