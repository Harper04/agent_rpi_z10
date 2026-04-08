# Machine-Specific Conventions — ziegeleiweg-pi

> These conventions apply ONLY to this machine and override/extend the shared
> conventions in `docs/conventions.md`.
> Loaded globally via `@local/docs/conventions.md` in CLAUDE.md.

---

## host-static-ip

**Scope:** ALL agents and skills that touch networking, VM creation, container
networking, bridge configuration, or anything that modifies `/etc/netplan/`,
network interfaces, or systemd-networkd units.

**Convention:** The host bridge `br0` on this machine MUST always hold the
static IP **192.168.2.32/24** with gateway **192.168.2.1**.

Rules:
- **Never** change br0 to DHCP or any other static address.
- **Never** remove or override `/etc/netplan/50-cloud-init.yaml`.
- When creating KVM bridge (`br0`, `virbr*`): bridge carries `eth0` as a
  member, and the host's IP address is assigned to the **bridge interface**,
  not eth0, at **192.168.2.32/24**.
- When installing Docker: use a non-overlapping subnet for `docker0`
  (e.g. `172.17.0.0/16`). Never assign 192.168.2.x to Docker bridge.
- When installing K3s/Kubernetes: configure `--node-ip 192.168.2.32`. Do not
  let flannel/calico claim the 192.168.2.0/24 range.
- When installing Tailscale: Tailscale gets its own `tailscale0` interface and
  a 100.x.x.x address. br0 stays at 192.168.2.32.
- VMs, containers, and apps MAY use any other IP (192.168.2.x or private
  ranges), but the host itself is always .32.

**Config files:**
- `/etc/netplan/50-cloud-init.yaml` — authoritative static IP config
- `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg` — prevents cloud-init
  from regenerating DHCP config on reboot

**Reason:** Ensures this machine is always reachable at a predictable address
for SSH, reverse proxy, ZeroTier, and other agents. A dynamic or incorrect
host IP would break remote management.

**Bridge state (2026-04-08):** br0 is active with eth0 as member. Host IP 192.168.2.32
is assigned to br0. eth0 has no IP. This is the correct post-KVM-bridge state.

**Added:** 2026-04-08
**Owner:** orchestrator
