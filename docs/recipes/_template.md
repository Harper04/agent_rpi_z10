---
name: "<app-name>"
method: apt|docker|k3s|snap|binary|source
version: "latest"
ports: [8080]
dependencies: []
reverse-proxy: false
domain: ""
data-paths: []
backup: true
---

# Recipe: <App Name>

> Tested on: Debian 12 / Ubuntu 22.04+
> Last updated: YYYY-MM-DD

## Overview

Brief description of what this application does and why someone would install it.

## Prerequisites

- List packages or services that must be present before installation
- Example: `docker`, `curl`, `gpg`

## Installation Steps

Step-by-step commands for installation. Use the method declared in the frontmatter.

```bash
# Installation commands here
```

## Configuration

### Config files to create/modify

```
# /etc/<app>/config.yml or similar
# Paste config template here with {{ placeholder }} variables
```

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `EXAMPLE_VAR` | `value` | Description |

## Reverse Proxy

Caddy site block (only if `reverse-proxy: true` in frontmatter):

```caddyfile
# {domain} {
#     reverse_proxy localhost:{port}
# }
```

## Health Check

```bash
# Command or URL to verify the app is running
# Example: curl -sf http://localhost:8080/health
```

## Post-Install

Steps to perform after installation:
- Initial setup wizard URL
- Default credentials to change
- Recommended first configuration steps

## Known Issues

- Document any quirks, version-specific gotchas, or workarounds
