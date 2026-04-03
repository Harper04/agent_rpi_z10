#!/usr/bin/env bash
# add-site.sh — Generate a Caddy site block for a reverse-proxied app
#
# Usage: ./scripts/caddy/add-site.sh <app-name> --port <port> [options]
#   --port <port>         Upstream port (required)
#   --domain <fqdn>       Full domain (default: <app>.<hostname>.tiny-systems.eu)
#   --no-auth             Skip auth (default for LAN flavor)
#   --auth                Force auth on (for LAN flavor opt-in)
#   --api-path <path>     API path prefix to exempt from auth (e.g., /api)
#   --dry-run             Print site block to stdout, don't write file
#   --flavor <flavor>     internet|lan-zt|lan-local (auto-detected from Caddyfile)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOSTNAME_SHORT="$(hostname -s)"

# Defaults
APP_NAME=""
PORT=""
DOMAIN=""
AUTH=""  # empty = use flavor default
API_PATH=""
DRY_RUN=false
FLAVOR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)      PORT="$2"; shift 2 ;;
        --domain)    DOMAIN="$2"; shift 2 ;;
        --no-auth)   AUTH="off"; shift ;;
        --auth)      AUTH="on"; shift ;;
        --api-path)  API_PATH="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=true; shift ;;
        --flavor)    FLAVOR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 <app-name> --port <port> [--domain <fqdn>] [--no-auth|--auth] [--api-path /api] [--dry-run]"
            exit 0
            ;;
        -*)          echo "Unknown option: $1"; exit 1 ;;
        *)           APP_NAME="$1"; shift ;;
    esac
done

# Validate
if [ -z "$APP_NAME" ]; then
    echo "ERROR: App name is required"
    echo "Usage: $0 <app-name> --port <port>"
    exit 1
fi

if [ -z "$PORT" ]; then
    echo "ERROR: --port is required"
    exit 1
fi

# Auto-detect flavor from Caddyfile
if [ -z "$FLAVOR" ]; then
    if grep -q "\.zt\." /etc/caddy/Caddyfile 2>/dev/null; then
        FLAVOR="lan-zt"
    elif grep -q "\.local\." /etc/caddy/Caddyfile 2>/dev/null; then
        FLAVOR="lan-local"
    else
        FLAVOR="internet"
    fi
fi

# Determine zone
case "$FLAVOR" in
    internet)  ZONE="${HOSTNAME_SHORT}.tiny-systems.eu" ;;
    lan-zt)    ZONE="${HOSTNAME_SHORT}.zt.tiny-systems.eu" ;;
    lan-local) ZONE="${HOSTNAME_SHORT}.local.tiny-systems.eu" ;;
    *) echo "ERROR: Unknown flavor: $FLAVOR"; exit 1 ;;
esac

# Default domain
if [ -z "$DOMAIN" ]; then
    DOMAIN="${APP_NAME}.${ZONE}"
fi

# Determine auth behavior
if [ -z "$AUTH" ]; then
    case "$FLAVOR" in
        internet)  AUTH="on" ;;
        lan-*)     AUTH="off" ;;
    esac
fi

SITE_FILE="/etc/caddy/sites/${APP_NAME}.caddy"

# Generate site block
generate_site_block() {
    local block=""

    block+="# ${DOMAIN} — reverse proxy to ${APP_NAME}\n"
    block+="# Generated: $(date -I)\n"
    block+="# Auth: ${AUTH}\n"
    block+="\n"
    block+="${DOMAIN} {\n"
    block+="    tls {\n"
    block+="        dns route53\n"
    block+="    }\n"

    if [ "$AUTH" = "on" ] && [ -n "$API_PATH" ]; then
        # Auth ON with API exemption
        block+="\n"
        block+="    # API paths — no auth\n"
        block+="    route ${API_PATH}/* {\n"
        block+="        reverse_proxy localhost:${PORT}\n"
        block+="    }\n"
        block+="\n"
        block+="    # All other paths — auth required\n"
        block+="    route {\n"
        block+="        authorize with default_policy\n"
        block+="        reverse_proxy localhost:${PORT}\n"
        block+="    }\n"
    elif [ "$AUTH" = "on" ]; then
        # Auth ON, no API exemption
        block+="\n"
        block+="    route {\n"
        block+="        authorize with default_policy\n"
        block+="        reverse_proxy localhost:${PORT}\n"
        block+="    }\n"
    else
        # Auth OFF
        block+="\n"
        block+="    reverse_proxy localhost:${PORT}\n"
    fi

    block+="}\n"
    echo -e "$block"
}

SITE_BLOCK="$(generate_site_block)"

echo "=== Caddy Site Block ==="
echo "App:     $APP_NAME"
echo "Domain:  $DOMAIN"
echo "Port:    $PORT"
echo "Auth:    $AUTH"
echo "API:     ${API_PATH:-none}"
echo "Flavor:  $FLAVOR"
echo "File:    $SITE_FILE"
echo ""
echo "$SITE_BLOCK"

if $DRY_RUN; then
    echo ""
    echo "(dry-run — not written)"
    exit 0
fi

# Check for existing site block
if [ -f "$SITE_FILE" ]; then
    echo ""
    echo "WARNING: $SITE_FILE already exists!"
    echo "Overwrite? This will backup the existing file."
    read -r -p "Continue? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo "Aborted."
        exit 0
    fi
    sudo cp "$SITE_FILE" "${SITE_FILE}.bak.$(date -I)"
fi

# Write site block
echo "$SITE_BLOCK" | sudo tee "$SITE_FILE" > /dev/null
echo ""
echo "Written to $SITE_FILE"

# Validate
echo ""
echo "=== Validating ==="
if caddy validate --config /etc/caddy/Caddyfile 2>&1; then
    echo "Config valid."
    echo ""
    read -r -p "Reload Caddy now? [Y/n] " reload
    if [[ ! "$reload" =~ ^[Nn] ]]; then
        sudo systemctl reload caddy
        echo "Caddy reloaded."
    fi
else
    echo "ERROR: Validation failed! Removing new site block."
    sudo rm "$SITE_FILE"
    # Restore backup if exists
    if [ -f "${SITE_FILE}.bak.$(date -I)" ]; then
        sudo mv "${SITE_FILE}.bak.$(date -I)" "$SITE_FILE"
    fi
    exit 1
fi
