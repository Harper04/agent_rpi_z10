# <App Name>

> **Status:** ✅ Running | ⚠️ Degraded | 🔴 Down
> **Last verified:** YYYY-MM-DD
> **Managed by agent:** `<agent-name>`
> **Installation method:** `apt` | `docker` | `k3s` | `snap` | `binary` | `source`
> **Recipe:** `docs/recipes/<app>.md` | manual

## Overview

Brief description of what this application does and why it's on this machine.

## Installation

How it was installed (apt, snap, docker, binary, k3s manifest, compiled from source).

```bash
# Installation commands used
```

## Version

| Component    | Version      | Source              |
|--------------|--------------|---------------------|
| Main binary  | `x.y.z`     | apt / docker / etc  |

## Configuration

### Config files

| File                     | Purpose                    |
|--------------------------|----------------------------|
| `/etc/<app>/config.yml`  | Main configuration         |

### Key settings

Document non-default settings and why they were chosen.

### Environment variables

| Variable    | Value     | Purpose               |
|-------------|-----------|------------------------|
| `FOO`       | `bar`     | ...                    |

## Network

| Port   | Protocol | Purpose        | Exposed to       |
|--------|----------|----------------|-------------------|
| 8080   | TCP      | HTTP API       | localhost only    |

## Data & Storage

| Path                  | Purpose          | Backed up? |
|-----------------------|------------------|------------|
| `/var/lib/<app>/`     | Application data | ✅ Yes     |

## Dependencies

- Depends on: (other services this needs)
- Depended on by: (other services that need this)

## Health Check

```bash
# Command to verify the app is healthy
```

## Common Operations

### Restart
```bash
systemctl restart <app>
```

### View logs
```bash
journalctl -u <app> --since "1 hour ago"
```

### Update
```bash
# Steps to update this application
```

## Known Issues & Gotchas

- Document any quirks, workarounds, or things that have broken before.

## Changelog (app-specific)

| Date       | Change                  | Agent           |
|------------|-------------------------|-----------------|
| YYYY-MM-DD | Initial installation    | orchestrator    |
