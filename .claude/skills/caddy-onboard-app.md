---
name: caddy-onboard-app
description: Add a new application behind Caddy reverse proxy with DNS, TLS, and auth configuration.
argument-hint: "<app-name> --port <port> [--domain <fqdn>] [--host <ip>] [--https-upstream] [--zt] [--no-auth] [--api-path /api]"
user-invocable: true
---

# Caddy Onboard App Skill

Add a new application behind the Caddy reverse proxy. Handles DNS records, site block
creation, auth policy selection, and verification.

## Phase 1 — Gather Information

### 1.1 Load context

```bash
# Machine identity
HOSTNAME=$(hostname -s)
source local/.env 2>/dev/null

# Detect flavor from Caddyfile
FLAVOR="internet"
grep -q "\.zt\." /etc/caddy/Caddyfile 2>/dev/null && FLAVOR="lan-zt"
grep -q "\.local\." /etc/caddy/Caddyfile 2>/dev/null && FLAVOR="lan-local"

# Determine zone suffix
case "$FLAVOR" in
    internet)  ZONE="${HOSTNAME}.tiny-systems.eu" ;;
    lan-zt)    ZONE="${HOSTNAME}.zt.tiny-systems.eu" ;;
    lan-local) ZONE="${HOSTNAME}.local.tiny-systems.eu" ;;
esac
```

### 1.2 Interview (skip questions answered by flags)

1. **App name**: Used for DNS record, site block filename, and documentation.
2. **Upstream port**: The port the app listens on.
   - Verify it's actually listening: `ss -tlnp | grep :<port>` (or `curl` for remote hosts)
3. **Upstream host**: Default `localhost`. Override with `--host <ip>` for apps on a
   different IP (e.g., KVM guest, container with its own IP). Verify reachability:
   `curl -s -o /dev/null -w "%{http_code}" http://<host>:<port>/`
4. **Upstream scheme**: Default `http`. Use `--https-upstream` when the app serves HTTPS
   with a self-signed cert (e.g., UniFi OS). Caddy will use `tls_insecure_skip_verify`.
5. **Domain**: Default `<app>.<zone>`. Override with `--domain` for custom FQDNs.
6. **ZeroTier domain**: Use `--zt` to also create a `<app>.<hostname>.zt.tiny-systems.eu`
   domain in the same site block, enabling remote access via ZeroTier.
7. **Auth**: Default ON for internet, OFF for LAN. Override with `--no-auth` or `--auth`.
8. **API path**: If specified, requests matching this path bypass auth. Default: none.
   Use `--api-path /api` to exempt `/api/*` routes.
9. **Additional routes**: Any custom route rules (e.g., websocket upgrade, specific headers).

### 1.3 Pre-flight checks

```bash
echo "=== Pre-flight ==="

# Caddy running?
systemctl is-active caddy || echo "ERROR: Caddy not running"

# Port listening?
ss -tlnp | grep ":${PORT}" || echo "WARNING: Nothing listening on port ${PORT}"

# Site block already exists?
[ -f "/etc/caddy/sites/${APP_NAME}.caddy" ] && echo "WARNING: Site block already exists"

# Domain already configured?
grep -r "${DOMAIN}" /etc/caddy/sites/ 2>/dev/null && echo "WARNING: Domain already in use"
```

## Phase 2 — DNS Records

Always create an explicit DNS record for the new app. Do NOT rely on wildcard DNS
records — wildcards may exist for TLS cert issuance but every virtual hostname must
have its own explicit record.

For LAN apps, use a CNAME pointing to the host's base FQDN. For internet apps, use
an A/AAAA record with the public IP.

```bash
# LAN flavor — CNAME to base host record
BASE_FQDN="${HOSTNAME}.local.tiny-systems.eu"  # or .zt. variant
echo "CNAME ${BASE_FQDN}" > "local/dns/records/${DOMAIN}"

# If --zt flag: also create ZeroTier domain
ZT_DOMAIN="${APP_NAME}.${HOSTNAME}.zt.tiny-systems.eu"
echo "CNAME ${HOSTNAME}.zt.tiny-systems.eu" > "local/dns/records/${ZT_DOMAIN}"

# Internet flavor — A/AAAA with public IP
# echo "A     $(curl -s4 ifconfig.me)" > "local/dns/records/${DOMAIN}"
# echo "AAAA  $(ip -6 addr show scope global | grep inet6 | head -1 | awk '{print $2}' | cut -d/ -f1)" >> "local/dns/records/${DOMAIN}"

# Sync DNS
scripts/dns/dns-sync.sh --dry-run
# Show plan, confirm, then:
scripts/dns/dns-sync.sh
```

## Phase 3 — Create Site Block

### Internet flavor — auth ON, API exempt

```bash
cat > /etc/caddy/sites/${APP_NAME}.caddy << 'CADDY'
# ${DOMAIN} — reverse proxy to ${APP_NAME}
# Added: $(date -I)

${DOMAIN} {
    tls {
        dns route53
    }

    # API paths — no auth required
    route /api/* {
        reverse_proxy localhost:${PORT}
    }

    # All other paths — auth required
    route {
        authorize with default_policy
        reverse_proxy localhost:${PORT}
    }
}
CADDY
```

If `--no-auth` was specified, omit the `authorize` directive:

```bash
cat > /etc/caddy/sites/${APP_NAME}.caddy << 'CADDY'
${DOMAIN} {
    tls {
        dns route53
    }
    reverse_proxy localhost:${PORT}
}
CADDY
```

### LAN flavor — no auth by default

The `UPSTREAM` variable controls the proxy target:
- Default: `localhost:${PORT}`
- With `--host <ip>`: `<ip>:${PORT}` (e.g., KVM guest, container on bridge network)
- With `--https-upstream`: adds `https://` prefix and `tls_insecure_skip_verify` transport

The `DOMAINS` variable controls the site block address:
- Default: `${DOMAIN}`
- With `--zt`: `${DOMAIN}, ${ZT_DOMAIN}` (comma-separated, both served from same block)

```bash
# Build upstream URL
UPSTREAM="${HOST:-localhost}:${PORT}"
SCHEME="http"
if [ "${HTTPS_UPSTREAM}" = "true" ]; then
    SCHEME="https"
fi

# Build domain list
DOMAINS="${DOMAIN}"
if [ -n "${ZT_DOMAIN}" ]; then
    DOMAINS="${DOMAIN}, ${ZT_DOMAIN}"
fi
```

**Standard (http, localhost or remote host):**

```bash
cat > /etc/caddy/sites/${APP_NAME}.caddy << 'CADDY'
${DOMAINS} {
    tls {
        dns route53
    }
    reverse_proxy ${SCHEME}://${UPSTREAM}
}
CADDY
```

**HTTPS upstream with self-signed cert** (e.g., UniFi OS):

```bash
cat > /etc/caddy/sites/${APP_NAME}.caddy << 'CADDY'
${DOMAINS} {
    tls {
        dns route53
    }
    reverse_proxy https://${UPSTREAM} {
        transport http {
            tls_insecure_skip_verify
        }
    }
}
CADDY
```

If `--auth` was specified (opt-in for LAN):

```bash
cat > /etc/caddy/sites/${APP_NAME}.caddy << 'CADDY'
${DOMAINS} {
    tls {
        dns route53
    }
    route {
        authorize with default_policy
        reverse_proxy ${SCHEME}://${UPSTREAM}
    }
}
CADDY
```

## Phase 3.5 — Post-Proxy App Configuration

Some apps need configuration changes to work correctly behind a reverse proxy.
Check each item and apply if relevant:

### Trusted proxies / X-Forwarded-For

Many apps reject `X-Forwarded-For` headers from untrusted IPs. If the app has
a trusted_proxies or similar setting, add the Caddy host IP(s).

Common apps that need this:
- **Home Assistant**: `configuration.yaml` → `http.trusted_proxies` list
- **Gitea/Forgejo**: `app.ini` → `[server] PROXY_ALLOWED` 
- **Grafana**: `grafana.ini` → `[server] enforce_domain`

```bash
# Identify which IPs Caddy uses to reach the app
# For localhost apps: 127.0.0.1
# For bridge/VM apps: the host's bridge IP
# For container apps: the host's primary IP or docker bridge IP
```

### External URL configuration

Apps that generate callback URLs (OAuth, mobile app pairing, webhooks) need
to know their public URL:

```bash
# Example for Home Assistant configuration.yaml:
# homeassistant:
#   external_url: "https://${DOMAIN}"
#   internal_url: "http://${HOST}:${PORT}"
```

### HTTPS-to-HTTPS conflicts

If the app enforces its own HTTPS redirect (e.g., UniFi OS), Caddy already
terminates TLS. The app's self-signed cert is handled by `tls_insecure_skip_verify`.
No additional config needed — but document this in the app doc.

## Phase 4 — Validate & Reload

```bash
# Backup current config
sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak.$(date -I)

# Validate
caddy validate --config /etc/caddy/Caddyfile
# If validation fails, show error and abort. Remove the new site block.

# Reload
sudo systemctl reload caddy
```

## Phase 5 — Verify

```bash
echo "=== Verification ==="

# Wait for cert acquisition (DNS-01 can take 30-60s)
sleep 5

# HTTPS reachable?
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "https://${DOMAIN}/" --max-time 10 2>/dev/null)
echo "HTTPS response: ${HTTP_CODE}"

# Auth redirect working? (if auth enabled)
# Should get 302 redirect to auth portal for unauthenticated requests
if [ "${AUTH_ENABLED}" = "true" ]; then
    REDIRECT=$(curl -sf -o /dev/null -w "%{redirect_url}" "https://${DOMAIN}/" --max-time 10 2>/dev/null)
    echo "Auth redirect: ${REDIRECT}"
fi

# TLS cert valid?
curl -vI "https://${DOMAIN}" 2>&1 | grep -E "expire|issuer|subject"
```

## Phase 6 — Document

1. **Update app docs** — if `local/docs/apps/*/` has docs for this app, add the
   Caddy reverse proxy section.

2. **Update Caddy docs** — add the app to the site list in `local/docs/apps/binary/caddy.md`

3. **Changelog entry:**
   ```markdown
   ## YYYY-MM-DD HH:MM — caddy

   **Action:** Onboarded <app> behind Caddy reverse proxy
   **Reason:** <operator request>
   **Files changed:** /etc/caddy/sites/<app>.caddy, local/dns/records/<domain>
   **Verification:** HTTPS reachable, auth redirect working, TLS valid
   **Upstream proposed:** no
   ```

4. **Git commit:**
   ```bash
   git add local/dns/records/ local/docs/
   git commit -m "feat(caddy): onboard <app> at <domain>"
   ```

## Rollback

If something goes wrong:

```bash
# Remove the site block
sudo rm /etc/caddy/sites/${APP_NAME}.caddy

# Restore Caddyfile if modified
sudo cp /etc/caddy/Caddyfile.bak.$(date -I) /etc/caddy/Caddyfile

# Reload
sudo systemctl reload caddy

# Remove DNS record if created
rm local/dns/records/${DOMAIN}
scripts/dns/dns-sync.sh
```
