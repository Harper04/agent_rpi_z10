---
name: app-install
description: Install a new application with interactive planning, pre-checks, installation, verification, and documentation.
argument-hint: "<app-name> [--method apt|docker|k3s|snap|binary|source] [--recipe <name>]"
user-invocable: true
---

# App Installation Skill

Install a new application on this system following a structured lifecycle:
Interview → Pre-flight → Install → Configure → Verify → Document.

## Phase 1 — Discovery & Interview

### 1.1 Recipe Lookup

Check if a recipe exists for the requested app:

```bash
# Machine-specific override first, then shared recipes
ls local/recipes/${APP_NAME}.md 2>/dev/null || ls docs/recipes/${APP_NAME}.md 2>/dev/null || echo "No recipe found"
```

If a recipe is found, read it and use its frontmatter values as defaults for the
interview below. Show the operator: "Recipe found for {app} — using defaults from recipe."

If `--recipe <name>` was passed explicitly, load that recipe instead.

### 1.2 Interactive Interview

Conduct a structured interview with the operator. Skip questions where the answer
is already provided via flags or recipe defaults. Present recipe defaults as
suggestions the operator can accept or override.

**Questions to ask (adapt to context — not all are always needed):**

1. **Installation method** (if not provided via `--method` or recipe):
   - Auto-detect: run `apt-cache show ${APP_NAME} 2>/dev/null` to check if it's an apt package
   - Offer: apt / docker / k3s / snap / binary / source
   - Recommend based on: recipe suggestion, apt availability, app type

2. **Version**: "Which version?" — Default: `latest` or recipe version

3. **Ports**: "Which port(s) should {app} listen on?"
   - Default: from recipe or app's standard port
   - Check for conflicts immediately: `ss -tlnp | grep :<port>`

4. **Reverse proxy**: "Set up a Caddy reverse proxy?"
   - If yes: "Which domain/subdomain?" — Default from recipe
   - Only ask if Caddy is installed: `systemctl is-active caddy 2>/dev/null`

5. **Data paths**: "Where should data be stored?"
   - Docker default: `/opt/stacks/{app}/data`
   - apt default: `/var/lib/{app}`
   - Recipe may override

6. **Autostart**: "Start automatically on boot?" — Default: yes

7. **Backup**: "Include data paths in backup?" — Default: yes

8. **Additional configuration**: "Any special configuration requirements?" — Free text

### 1.3 Confirmation

Present a summary of all decisions:

```
╔══════════════════════════════════════════╗
║  Installation Plan: {app}                ║
╠══════════════════════════════════════════╣
║  Method:      docker                     ║
║  Version:     latest                     ║
║  Port(s):     3000, 2222                 ║
║  Domain:      git.example.com            ║
║  Data:        /opt/stacks/gitea/data     ║
║  Autostart:   yes                        ║
║  Backup:      yes                        ║
║  Recipe:      docs/recipes/gitea.md      ║
╚══════════════════════════════════════════╝
```

Ask: "Proceed with installation?" — Wait for confirmation.

## Phase 2 — Pre-flight Checks

Run all checks and report results. Abort if any critical check fails.

```bash
echo "=== Pre-flight Checks ==="

# Disk space
echo "--- Disk Space ---"
USAGE=$(df / --output=pcent | tail -1 | tr -d ' %')
echo "Root partition: ${USAGE}% used"
[ "$USAGE" -gt 85 ] && echo "⚠️ WARNING: Disk usage above 85%"

# Port conflicts
echo "--- Port Conflicts ---"
ss -tlnp | grep -E ':(PORT1|PORT2)\b' && echo "⚠️ PORT CONFLICT" || echo "✅ Ports available"

# Prerequisites
echo "--- Prerequisites ---"
# Method-specific:
# docker: systemctl is-active docker
# k3s: systemctl is-active k3s
# apt: apt update (if not recently run)

# Already installed?
echo "--- Already Installed? ---"
find local/docs/apps/ -name "${APP_NAME}.md" 2>/dev/null && echo "⚠️ App documentation already exists" || echo "✅ Not previously installed"
```

If any check shows a warning, present it and ask whether to continue.
If a critical failure (e.g., Docker not running for a Docker install), abort.

## Phase 3 — Installation

Execute the installation based on the chosen method. Follow the recipe's
Installation Steps if a recipe was loaded, otherwise use the generic procedure:

### Method: apt

```bash
apt update
apt install -y ${PACKAGE_NAME}
dpkg -l | grep ${PACKAGE_NAME}
systemctl enable ${APP_NAME} 2>/dev/null || true
```

### Method: docker

Delegate to the **docker agent** with context:

1. Create stack directory: `mkdir -p /opt/stacks/${APP_NAME}`
2. Write `docker-compose.yml` from recipe or interactively
3. Write `.env` file with configured variables
4. Pull and start: `cd /opt/stacks/${APP_NAME} && docker compose up -d`
5. Verify: `docker compose ps`

Standard convention: All Docker stacks live under `/opt/stacks/<app>/`.

### Method: k3s

Delegate to the **k3s agent** with context:

1. Create namespace: `k3s kubectl create namespace ${APP_NAME} --dry-run=client -o yaml | k3s kubectl apply -f -`
2. Write manifest from recipe or interactively
3. Apply: `k3s kubectl apply -f <manifest>`
4. Wait: `k3s kubectl rollout status deployment/${APP_NAME} -n ${APP_NAME}`

### Method: snap

```bash
snap install ${APP_NAME}
snap list | grep ${APP_NAME}
```

### Method: binary

```bash
# Download (URL from recipe or operator)
curl -fSL ${DOWNLOAD_URL} -o /tmp/${APP_NAME}
# Verify checksum if provided
echo "${CHECKSUM}  /tmp/${APP_NAME}" | sha256sum -c 2>/dev/null || echo "No checksum provided"
# Install
install -m 755 /tmp/${APP_NAME} /usr/local/bin/${APP_NAME}
${APP_NAME} --version
```

If the app runs as a daemon, create a systemd unit:
```bash
cat > /etc/systemd/system/${APP_NAME}.service << 'UNIT'
[Unit]
Description=${APP_NAME}
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/${APP_NAME}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now ${APP_NAME}
```

### Method: source

Follow recipe build steps. Generic fallback:
```bash
git clone ${REPO_URL} /opt/src/${APP_NAME}
cd /opt/src/${APP_NAME}
# Build commands from recipe
```

## Phase 4 — Post-Install Configuration

Apply configuration from the recipe and/or interview answers:

1. **Config files**: Write or modify config files as specified
2. **Reverse proxy** (if requested): Delegate to **caddy agent**
   ```bash
   # Write Caddy site block from recipe or generate one
   cat > /etc/caddy/sites/${APP_NAME}.caddy << 'CADDY'
   ${DOMAIN} {
       reverse_proxy localhost:${PORT}
   }
   CADDY
   systemctl reload caddy
   ```
3. **Firewall**: Add rules if needed (e.g., for SSH ports)
4. **Autostart**: `systemctl enable ${APP_NAME}` (already done for apt/binary)

## Phase 5 — Verification

```bash
echo "=== Verification ==="

# Method-specific health check
# apt/binary: systemctl is-active ${APP_NAME}
# docker: docker compose -f /opt/stacks/${APP_NAME}/docker-compose.yml ps
# k3s: k3s kubectl get pods -n ${APP_NAME}
# snap: snap services ${APP_NAME}

# Port check
echo "--- Port Check ---"
ss -tlnp | grep -E ':(EXPECTED_PORTS)\b'

# Health endpoint (from recipe)
# curl -sf http://localhost:${PORT}/health && echo "✅ Health OK" || echo "⚠️ Health check failed"

# Reverse proxy check (if configured)
# curl -sf https://${DOMAIN}/ -o /dev/null && echo "✅ Reverse proxy OK" || echo "⚠️ Reverse proxy not yet working"
```

Present results to the operator.

## Phase 6 — Documentation

1. **Create app documentation:**
   ```bash
   # Determine doc path
   DOC_PATH="local/docs/apps/${METHOD}/${APP_NAME}.md"
   mkdir -p "local/docs/apps/${METHOD}"

   # Copy template
   cp docs/apps/_template.md "${DOC_PATH}"
   ```
   Fill in all sections from the installation context (method, version, ports,
   config files, data paths, health check command, etc.).

2. **Update app registry:**
   ```bash
   # Create _index.md if it doesn't exist
   [ -f local/docs/apps/_index.md ] || cp docs/apps/_index_template.md local/docs/apps/_index.md
   ```
   Add a row to the registry table with app name, method, version, status, ports, domain, doc path.
   Update the summary counts.
   Update the "Last updated" date.

3. **Update changelog:** Invoke the `doc-update` skill with the installation summary.

4. **Update network docs** if new ports were opened: update `local/docs/system/network.md`.

5. **Update packages doc** if apt packages were installed: update `local/docs/system/packages.md`.

6. **Git commit:**
   ```bash
   git add local/docs/
   git commit -m "docs(${APP_NAME}): add documentation after installation via ${METHOD}"
   ```

7. **Notify:** Invoke the `notify` skill with a summary:
   "✅ Installed {app} via {method} on port {port}. Domain: {domain}. Docs: {doc_path}"
