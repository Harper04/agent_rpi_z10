---
name: inventory
description: Scan and document the current system state
user-invocable: true
---

Perform a full system inventory and update all documentation in `local/docs/`:

1. **Hardware & OS** → update `local/docs/system/overview.md`
   ```bash
   hostnamectl
   cat /proc/cpuinfo | head -20
   free -h
   lsblk
   ip addr
   ```

2. **Installed packages** → update `local/docs/system/packages.md`
   ```bash
   dpkg --list | grep ^ii | awk '{print $2, $3}'
   apt-mark showhold
   ```

3. **Running services** → update `local/docs/system/services.md`
   ```bash
   systemctl list-units --type=service --state=running --no-pager
   systemctl --failed --no-pager
   systemctl list-timers --all --no-pager
   ```

4. **Network** → update `local/docs/system/network.md`
   ```bash
   ss -tlnp
   ip route
   ip addr
   tailscale status 2>/dev/null
   cat /etc/caddy/Caddyfile 2>/dev/null
   ufw status 2>/dev/null || iptables -L -n 2>/dev/null
   ```

5. **Per-app docs** → scan for installed apps, ensure each has a doc in `local/docs/apps/`.
   For any app without a doc, copy `docs/apps/_template.md` and fill it.

6. **Update local machine identity** → update `local/CLAUDE.local.md` with current values.

7. **Git commit** all updated docs:
   ```bash
   git add local/
   git commit -m "docs: full system inventory $(date -I)"
   ```
