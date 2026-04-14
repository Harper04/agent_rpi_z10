Subject: WebRTC remote access broken on UOS 5.0.6 with pasta networking (generic ARM64) — root cause identified + workaround

Hi Ubiquiti team,

I'm running UniFi OS Server 5.0.6 on a Raspberry Pi 5 (generic ARM64, Ubuntu 25.10) with pasta networking. Remote access via unifi.ui.com and the UniFi mobile app does not work — connections time out after ~20 seconds. Direct LAN access works fine.

I've identified the root cause and have a workaround.

## Environment

- UOS Server 5.0.6, container image 0.0.54
- Podman 5.4.2 with pasta networking (auto-selected by installer on ARM64)
- Host has a bridge interface `br0` as its default route
- ARM64 / aarch64, Ubuntu 25.10

## Root Cause

Pasta networking creates a separate network namespace for the container with a TAP interface named `eth0`. However, pasta also exposes the **host's** `/proc/net/route` and `/sys/class/net/` into the container (these are not namespace-aware and show the host's view).

Here's what happens:

1. `unifi-core` inside the container reads `/proc/net/route` to determine the default route interface. It finds `br0` (the host's bridge), not `eth0` (the container's actual interface).

2. `unifi-core` passes this to the WebRTC addon as `allowed_interfaces: ['br0']` (visible in `webrtc.log`: "Setting addon allowed interfaces: ['br0']").

3. The WebRTC addon tries to gather ICE candidates on `br0`. But `br0` does not exist in the container's network namespace — only `eth0` does.

4. ICE gathering completes in ~2ms with **zero candidates**. Every remote connection attempt times out.

From `webrtc_addon.log` (before fix):
```
PeerConnection::doOnIceConnectionChange === CONNECTION FAILED _connectionId=X in 23315 ms ===
```

## Workaround

Creating a dummy `br0` interface inside the container's network namespace with the host's IP resolves the issue:

```bash
# Find container init PID (child of conmon running as uosserver user)
CONMON_PID=$(pgrep -u uosserver conmon)
CONTAINER_PID=$(pgrep -P $CONMON_PID)

# Create dummy br0 in the container namespace
nsenter -t $CONTAINER_PID -n ip link add br0 type dummy
nsenter -t $CONTAINER_PID -n ip link set br0 up
nsenter -t $CONTAINER_PID -n ip addr add 192.168.2.32/32 dev br0
```

After this, the WebRTC addon finds `br0`, binds to its IP, and traffic routes through pasta's `eth0` TAP device. ICE candidates are generated (host, srflx, and relay), and TURN relay connections succeed in ~1 second.

From `webrtc_addon.log` (after fix):
```
PeerConnection::doOnIceSelectedCandidatePairChanged _connectionId=17 in 981 ms ========= TURN CONNECTION
PeerConnection::doOnIceConnectionChange === CONNECTION CONNECTED _connectionId=17 in 1173 ms ===
```

I run this as a systemd oneshot service after `uosserver.service` starts to make it persistent across reboots.

## Suggested Fix

The interface detection in `unifi-core` should not rely on `/proc/net/route` when running inside a pasta network namespace, since pasta exposes the host's proc filesystem. Possible fixes:

1. **Read actual namespace interfaces**: Use `getifaddrs()` or enumerate `/sys/class/net/` from within the network namespace (via `NETLINK_ROUTE`) instead of parsing `/proc/net/route`.

2. **Fall back gracefully**: If the detected default-route interface doesn't exist as an actual network interface in the current namespace, fall back to all available interfaces rather than restricting to a non-existent one.

3. **Don't restrict WebRTC interfaces**: If `allowed_interfaces` is meant as an optimization, consider making it advisory rather than exclusive — or allow `0.0.0.0` binding when the specified interface isn't found.

This likely affects all UOS installations on generic ARM64 hardware where the host uses a bridge interface (`br0`) as its default route, since the installer auto-selects pasta networking on ARM64.

Happy to provide full logs or test any patches.

Best regards
