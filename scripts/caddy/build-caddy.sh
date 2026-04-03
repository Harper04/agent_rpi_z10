#!/usr/bin/env bash
# build-caddy.sh — Download or build a custom Caddy binary with required plugins
# Plugins: caddy-security (auth portal) + caddy-dns/route53 (DNS-01 ACME)
#
# Usage: ./scripts/caddy/build-caddy.sh [--install] [--method api|xcaddy]
#   --install   Replace /usr/bin/caddy with the new binary (requires sudo)
#   --method    Force build method: 'api' (Caddy download API) or 'xcaddy'
#               Default: tries API first, falls back to xcaddy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Plugins to include
PLUGINS=(
    "github.com/greenpau/caddy-security"
    "github.com/caddy-dns/route53"
)

# Parse arguments
INSTALL=false
METHOD="auto"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) INSTALL=true; shift ;;
        --method)  METHOD="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--install] [--method api|xcaddy]"
            echo "  --install   Replace /usr/bin/caddy with the new binary"
            echo "  --method    Force: 'api' (download) or 'xcaddy' (build)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$ARCH" in
    amd64|x86_64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) echo "ERROR: Unsupported architecture: $ARCH"; exit 1 ;;
esac

OUTPUT="/tmp/caddy-custom-$(date +%s)"

# --- Method: Caddy Download API ---
download_api() {
    echo "=== Downloading custom Caddy via Download API ==="
    local url="https://caddyserver.com/api/download?os=linux&arch=${ARCH}"
    for plugin in "${PLUGINS[@]}"; do
        url="${url}&p=${plugin}"
    done

    echo "URL: $url"
    echo "Downloading..."

    if curl -fSL "$url" -o "$OUTPUT" --progress-bar; then
        chmod +x "$OUTPUT"
        echo "Downloaded to: $OUTPUT"
        return 0
    else
        echo "Download API failed"
        return 1
    fi
}

# --- Method: xcaddy build ---
xcaddy_build() {
    echo "=== Building custom Caddy via xcaddy ==="

    if ! command -v xcaddy &>/dev/null; then
        if ! command -v go &>/dev/null; then
            echo "ERROR: Neither xcaddy nor go found. Install Go first:"
            echo "  sudo snap install go --classic"
            echo "Then: go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest"
            return 1
        fi
        echo "Installing xcaddy..."
        go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
        XCADDY="$HOME/go/bin/xcaddy"
    else
        XCADDY="xcaddy"
    fi

    local with_args=""
    for plugin in "${PLUGINS[@]}"; do
        with_args="${with_args} --with ${plugin}"
    done

    echo "Building..."
    eval "$XCADDY build $with_args --output $OUTPUT"
    echo "Built: $OUTPUT"
}

# --- Execute ---
echo "=== Caddy Custom Build ==="
echo "Architecture: $ARCH"
echo "Plugins: ${PLUGINS[*]}"
echo ""

case "$METHOD" in
    api)     download_api ;;
    xcaddy)  xcaddy_build ;;
    auto)
        download_api || {
            echo ""
            echo "Falling back to xcaddy build..."
            xcaddy_build
        }
        ;;
    *) echo "ERROR: Unknown method: $METHOD"; exit 1 ;;
esac

# Verify the binary
echo ""
echo "=== Verification ==="
"$OUTPUT" version
echo ""
echo "Loaded modules:"
"$OUTPUT" list-modules 2>/dev/null | grep -E "security|route53" || echo "WARNING: Expected modules not found!"

# Install if requested
if $INSTALL; then
    echo ""
    echo "=== Installing to /usr/bin/caddy ==="

    # Backup current binary
    if [ -f /usr/bin/caddy ]; then
        BACKUP="/usr/bin/caddy.bak.$(date -I)"
        echo "Backing up current binary to $BACKUP"
        sudo cp /usr/bin/caddy "$BACKUP"
    fi

    # Stop, replace, start
    echo "Stopping caddy..."
    sudo systemctl stop caddy 2>/dev/null || true

    echo "Installing new binary..."
    sudo install -m 755 "$OUTPUT" /usr/bin/caddy

    echo "Starting caddy..."
    sudo systemctl start caddy

    echo "Verifying..."
    caddy version
    systemctl is-active caddy && echo "Caddy is running" || echo "WARNING: Caddy not running!"
else
    echo ""
    echo "Binary ready at: $OUTPUT"
    echo "To install: sudo install -m 755 $OUTPUT /usr/bin/caddy"
fi

# Cleanup
rm -f "$OUTPUT"
echo ""
echo "Done."
