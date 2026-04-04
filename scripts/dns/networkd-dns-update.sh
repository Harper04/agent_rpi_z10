#!/usr/bin/env bash
# networkd-dns-update.sh — networkd-dispatcher hook for DNS IP updates.
#
# Install to /etc/networkd-dispatcher/routable.d/ to trigger DNS updates
# whenever an interface reaches the "routable" state (DHCP lease obtained).
#
# networkd-dispatcher sets these environment variables:
#   IFACE              — interface name (e.g. br0, eth0)
#   AdministrativeState — up/down
#   OperationalState   — routable/degraded/...
#
# Installation (done by dns-sync recipe or manually):
#   sudo cp scripts/dns/networkd-dns-update.sh /etc/networkd-dispatcher/routable.d/50-dns-update
#   sudo chmod +x /etc/networkd-dispatcher/routable.d/50-dns-update

set -eo pipefail

# networkd-dispatcher provides IFACE
IFACE="${IFACE:-}"

# Find the repo — try common locations, then fall back
for candidate in /home/*/sysadmin-agent; do
  if [[ -f "$candidate/scripts/dns/dns-ip-update.sh" ]]; then
    REPO_ROOT="$candidate"
    break
  fi
done

if [[ -z "${REPO_ROOT:-}" ]]; then
  logger -t dns-update "sysadmin-agent repo not found, skipping"
  exit 0
fi

# Source env for AWS credentials
ENV_FILE="$REPO_ROOT/local/.env"
if [[ -f "$ENV_FILE" ]]; then
  while IFS='=' read -r key value; do
    value="${value%%#*}"
    value="${value%"${value##*[![:space:]]}"}"
    if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    export "$key=$value"
  done < <(grep -E '^[A-Z_][A-Z0-9_]*=' "$ENV_FILE")
fi

# Ensure snap bin is in PATH for aws-cli
export PATH="/snap/bin:$PATH"

logger -t dns-update "Interface $IFACE reached routable state, checking DNS records"

# Run the update script, filtering to this interface
"$REPO_ROOT/scripts/dns/dns-ip-update.sh" --iface "$IFACE" 2>&1 | \
  while IFS= read -r line; do logger -t dns-update "$line"; done

exit 0
