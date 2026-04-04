# System Services

> **Last updated:** 2026-04-02

## Critical Services

| Service                     | Status   | Enabled | Purpose                       |
|-----------------------------|----------|---------|-------------------------------|
| ssh                         | running  | yes     | Remote access                 |
| systemd-networkd            | running  | yes     | Network configuration         |
| systemd-resolved            | running  | yes     | DNS resolution                |
| systemd-timesyncd           | running  | yes     | NTP time sync                 |
| systemd-journald            | running  | yes     | System logging                |

## Application Services

| Service                     | Status   | Enabled | Agent       | Purpose              |
|-----------------------------|----------|---------|-------------|----------------------|
| caddy                       | n/a      | n/a     | caddy       | Not installed        |
| k3s                         | n/a      | n/a     | k3s         | Not installed        |
| libvirtd                    | n/a      | n/a     | kvm         | Not installed        |
| docker                      | n/a      | n/a     | docker      | Not installed        |
| tailscaled                  | n/a      | n/a     | tailscale   | Not installed        |

## Other Running Services

| Service                     | Status   | Purpose                       |
|-----------------------------|----------|-------------------------------|
| atd                         | running  | Deferred execution scheduler  |
| cron                        | running  | Scheduled tasks               |
| dbus                        | running  | System message bus             |
| multipathd                  | running  | Multipath device controller   |
| polkit                      | running  | Authorization manager         |
| qemu-guest-agent            | running  | QEMU/KVM guest agent          |
| rsyslog                     | running  | System logging                |
| unattended-upgrades         | running  | Automatic security updates    |

## Failed Services

```
None
```

## Timers (scheduled)

```
NEXT                            LEFT          UNIT                              ACTIVATES
Thu 2026-04-02 13:00:00 UTC     periodic      sysstat-collect.timer             sysstat-collect.service
Thu 2026-04-02 18:26:57 UTC     ~5h           apt-daily.timer                   apt-daily.service
Thu 2026-04-02 19:45:39 UTC     ~6h           motd-news.timer                   motd-news.service
Fri 2026-04-03 00:00:00 UTC     ~11h          dpkg-db-backup.timer              dpkg-db-backup.service
Fri 2026-04-03 00:00:00 UTC     ~11h          logrotate.timer                   logrotate.service
Fri 2026-04-03 00:07:00 UTC     ~11h          sysstat-summary.timer             sysstat-summary.service
Fri 2026-04-03 01:15:58 UTC     ~12h          man-db.timer                      man-db.service
Fri 2026-04-03 06:21:35 UTC     ~17h          apt-daily-upgrade.timer           apt-daily-upgrade.service
Fri 2026-04-03 11:50:25 UTC     ~22h          update-notifier-download.timer    update-notifier-download.service
Fri 2026-04-03 12:00:06 UTC     ~23h          systemd-tmpfiles-clean.timer      systemd-tmpfiles-clean.service
Sun 2026-04-05 03:10:49 UTC     ~2d           e2scrub_all.timer                 e2scrub_all.service
Mon 2026-04-06 01:17:48 UTC     ~3d           fstrim.timer                      fstrim.service
Mon 2026-04-06 07:21:01 UTC     ~3d           update-notifier-motd.timer        update-notifier-motd.service
```
