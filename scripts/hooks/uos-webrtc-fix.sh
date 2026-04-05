#!/usr/bin/env bash
# uos-webrtc-fix.sh — Create dummy br0 in UOS container namespace
#
# Problem: UOS WebRTC addon reads host's /proc/net/route (exposed by pasta),
# sees br0 as default route, sets allowed_interfaces=['br0']. But the container
# network namespace only has eth0 (pasta TAP). ICE gathering finds zero
# candidates → remote access times out.
#
# Fix: Create a dummy br0 interface in the container namespace with the host's
# br0 IP. WebRTC addon finds br0, binds to its IP, traffic routes through
# pasta's eth0 TAP device. ICE candidates are generated, remote access works.
#
# This script is called by uos-webrtc-fix.service after uosserver.service starts.

set -euo pipefail

MAX_WAIT=120  # seconds to wait for container to be running + healthy
POLL_INTERVAL=5

log() { echo "$(date -Iseconds) [uos-webrtc-fix] $*"; }

# Wait for the container's conmon process (runs as uosserver user).
# conmon's direct child is the container init (PID 1 inside container),
# which lives in the pasta network namespace.
waited=0
while [ $waited -lt $MAX_WAIT ]; do
    CONMON_PID=$(pgrep -u uosserver conmon 2>/dev/null | head -1) || true
    if [ -n "$CONMON_PID" ]; then
        PID=$(pgrep -P "$CONMON_PID" 2>/dev/null | head -1) || true
        if [ -n "$PID" ] && [ "$PID" -gt 0 ] 2>/dev/null; then
            # Verify this PID is in a non-host network namespace with eth0
            if nsenter -t "$PID" -n ip link show eth0 &>/dev/null; then
                break
            fi
        fi
    fi
    log "Waiting for container... (${waited}s/${MAX_WAIT}s)"
    sleep $POLL_INTERVAL
    waited=$((waited + POLL_INTERVAL))
done

if [ $waited -ge $MAX_WAIT ]; then
    log "ERROR: Container not ready after ${MAX_WAIT}s, giving up"
    exit 1
fi

log "Container PID: $PID"

# Check if br0 already exists in the namespace
if nsenter -t "$PID" -n ip link show br0 &>/dev/null; then
    log "br0 already exists in container namespace, nothing to do"
    exit 0
fi

# Get the host IP from br0 (the bridge interface)
HOST_IP=$(ip -4 addr show br0 | grep -oP 'inet \K[0-9.]+' | head -1)
if [ -z "$HOST_IP" ]; then
    # Fallback: get primary IP from default route interface
    HOST_IP=$(ip -4 addr show "$(ip route show default | awk '{print $5}' | head -1)" | grep -oP 'inet \K[0-9.]+' | head -1)
fi

if [ -z "$HOST_IP" ]; then
    log "ERROR: Could not determine host IP"
    exit 1
fi

log "Creating dummy br0 with IP $HOST_IP in container namespace (PID $PID)"

nsenter -t "$PID" -n ip link add br0 type dummy
nsenter -t "$PID" -n ip link set br0 up
nsenter -t "$PID" -n ip addr add "${HOST_IP}/32" dev br0

log "Done. br0 created in container namespace."
