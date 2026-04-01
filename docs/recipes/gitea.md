---
name: "gitea"
method: docker
version: "latest"
ports: [3000, 2222]
dependencies: [docker]
reverse-proxy: true
domain: "git.example.com"
data-paths: ["/opt/stacks/gitea/data", "/opt/stacks/gitea/db"]
backup: true
---

# Recipe: Gitea (Git hosting)

> Tested on: Debian 12 / Ubuntu 22.04+
> Last updated: 2026-04-01

## Overview

Gitea is a lightweight, self-hosted Git service. Provides web UI, API, SSH access,
and issue tracking. Runs as a Docker Compose stack with PostgreSQL.

## Prerequisites

- Docker and Docker Compose must be installed and running
- Caddy (or another reverse proxy) for HTTPS termination
- At least 512 MB free RAM, 1 GB disk for initial setup

## Installation Steps

```bash
# Create stack directory
mkdir -p /opt/stacks/gitea

# Write docker-compose.yml (see Configuration below)
# Then start the stack
cd /opt/stacks/gitea
docker compose up -d

# Verify containers are running
docker compose ps
```

## Configuration

### Config files to create/modify

```yaml
# /opt/stacks/gitea/docker-compose.yml
services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: unless-stopped
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=gitea-db:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=${DB_PASSWORD}
      - GITEA__server__ROOT_URL=https://${DOMAIN}/
      - GITEA__server__SSH_DOMAIN=${DOMAIN}
      - GITEA__server__SSH_PORT=2222
    ports:
      - "3000:3000"
      - "2222:22"
    volumes:
      - ./data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    depends_on:
      gitea-db:
        condition: service_healthy

  gitea-db:
    image: postgres:16-alpine
    container_name: gitea-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=gitea
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=gitea
    volumes:
      - ./db:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "gitea"]
      interval: 10s
      timeout: 5s
      retries: 5
```

```bash
# /opt/stacks/gitea/.env
DOMAIN=git.example.com
DB_PASSWORD=<generated-secure-password>
```

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOMAIN` | `git.example.com` | Public domain for Gitea |
| `DB_PASSWORD` | (generated) | PostgreSQL password |

## Reverse Proxy

```caddyfile
# /etc/caddy/sites/gitea.caddy
git.example.com {
    reverse_proxy localhost:3000
}
```

After placing the file:
```bash
systemctl reload caddy
```

## Health Check

```bash
docker compose -f /opt/stacks/gitea/docker-compose.yml ps
curl -sf http://localhost:3000/api/v1/version && echo " OK" || echo "FAIL"
```

## Post-Install

- Open `https://git.example.com` in a browser to complete the initial setup wizard
- Create an admin account during first-run setup
- Configure SSH: users can clone via `ssh://git@git.example.com:2222/user/repo.git`
- Optionally enable fail2ban for the SSH port

## Known Issues

- The first user to register becomes admin if not configured otherwise.
  Set `INSTALL_LOCK=true` in app.ini after initial setup to prevent re-configuration.
- PostgreSQL data in `./db` must be backed up separately (not just the Gitea data dir).
- SSH port 2222 must be opened in the firewall and documented in network docs.
- If Gitea container restarts loop, check PostgreSQL health first: `docker logs gitea-db`.
