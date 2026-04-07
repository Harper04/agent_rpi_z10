# System Services

> **Last updated:** 2026-04-07

## Running Services

| Service                      | Status  | Purpose                            |
|------------------------------|---------|------------------------------------|
| avahi-daemon                 | running | mDNS/DNS-SD stack                  |
| chrony                       | running | NTP client/server                  |
| cron                         | running | Scheduled task daemon              |
| dbus                         | running | D-Bus system message bus           |
| getty@tty1                   | running | TTY1 login                         |
| ModemManager                 | running | Modem manager                      |
| networkd-dispatcher          | running | systemd-networkd dispatcher        |
| polkit                       | running | Authorization manager              |
| rsyslog                      | running | System logging                     |
| serial-getty@ttyAMA0         | running | Serial console                     |
| snapd                        | running | Snap package daemon                |
| ssh                          | running | OpenSSH server (port 22)           |
| sysadmin-agent               | running | Sysadmin Claude Agent              |
| systemd-hostnamed            | running | Hostname service                   |
| systemd-journald             | running | Journal service                    |
| systemd-logind               | running | User login management              |
| systemd-networkd             | running | Network configuration              |
| systemd-resolved             | running | Network name resolution            |
| systemd-udevd                | running | Device event manager               |
| udisks2                      | running | Disk manager                       |
| unattended-upgrades          | running | Unattended upgrades                |
| wpa_supplicant               | running | WPA supplicant (wlan0, inactive)   |

## Failed Services

```
0 loaded units listed — no failed services.
```

## Timers (scheduled)

```
UNIT                           NEXT                           ACTIVATES
sysstat-collect.timer          Tue 2026-04-07 11:30:00 UTC    sysstat-collect.service
fwupd-refresh.timer            Tue 2026-04-07 12:20:57 UTC    fwupd-refresh.service
man-db.timer                   Tue 2026-04-07 15:04:42 UTC    man-db.service
motd-news.timer                Tue 2026-04-07 15:51:48 UTC    motd-news.service
apt-daily.timer                Tue 2026-04-07 18:10:12 UTC    apt-daily.service
dpkg-db-backup.timer           Wed 2026-04-08 00:00:00 UTC    dpkg-db-backup.service
sysstat-rotate.timer           Wed 2026-04-08 00:00:00 UTC    sysstat-rotate.service
sysstat-summary.timer          Wed 2026-04-08 00:07:00 UTC    sysstat-summary.service
logrotate.timer                Wed 2026-04-08 00:12:17 UTC    logrotate.service
apt-daily-upgrade.timer        Wed 2026-04-08 06:50:36 UTC    apt-daily-upgrade.service
update-notifier-download.timer Wed 2026-04-08 10:16:50 UTC    update-notifier-download.service
systemd-tmpfiles-clean.timer   Wed 2026-04-08 10:26:50 UTC    systemd-tmpfiles-clean.service
update-notifier-motd.timer     Fri 2026-04-10 01:15:40 UTC    update-notifier-motd.service
e2scrub_all.timer              Sun 2026-04-12 03:10:15 UTC    e2scrub_all.service
fstrim.timer                   Mon 2026-04-13 00:29:11 UTC    fstrim.service
```
