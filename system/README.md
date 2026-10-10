# system/ → /etc

Root files stow cannot own. Two kinds:

- **Links** are fine as symlinks into the repo; readers can follow `/home`.
- **Copies** must be real root files (boot before `/home`, udev, PAM,
  sandboxed services, NetworkManager dispatchers). The repo wins; if you
  edit `/etc` by hand, either copy it back here first or you will lose it.

## Links

```sh
cd /home/jaeho/dotfiles
sudo ln -sfn "$PWD/system/keyd/default.conf"                 /etc/keyd/default.conf
sudo ln -sfn "$PWD/system/libinput/local-overrides.quirks"   /etc/libinput/local-overrides.quirks
sudo ln -sfn "$PWD/system/security/limits.d/10-rtprio.conf"  /etc/security/limits.d/10-rtprio.conf
sudo ln -sfn "$PWD/system/sysctl/99-sysrq.conf"              /etc/sysctl.d/99-sysrq.conf
sudo ln -sfn "$PWD/system/systemd/system-sleep/fuse-mounts"  /usr/lib/systemd/system-sleep/fuse-mounts
sudo ln -sfn "$PWD/system/systemd/system-sleep/batenergy"    /usr/lib/systemd/system-sleep/batenergy
# Arch drop-ins
sudo ln -sfn "$PWD/system/systemd/paccache.service.d/10-uninstalled.conf" \
        /etc/systemd/system/paccache.service.d/10-uninstalled.conf
sudo ln -sfn "$PWD/system/systemd/linux-modules-cleanup.service.d/10-prune-old.conf" \
        /etc/systemd/system/linux-modules-cleanup.service.d/10-prune-old.conf
sudo ln -sfn "$PWD/system/systemd/reflector.service.d/10-retry.conf" \
        /etc/systemd/system/reflector.service.d/10-retry.conf
```

`keyd` needs `systemctl enable --now keyd` and `keyd reload` after a config
change. `sysctl` applies the next boot, or `sudo sysctl --system`.

## Copies

```sh
cd /home/jaeho/dotfiles
sudo install -D -m 0644 system/grub/grub                 /etc/default/grub
sudo install -D -m 0644 system/mkinitcpio/mkinitcpio.conf /etc/mkinitcpio.conf
sudo install -D -m 0644 system/modprobe/nvidia.conf       /etc/modprobe.d/nvidia.conf
sudo install -D -m 0644 system/reflector/reflector.conf   /etc/xdg/reflector/reflector.conf
sudo install -D -m 0644 system/pam/login                  /etc/pam.d/login
sudo install -D -m 0644 system/pam/passwd                 /etc/pam.d/passwd
sudo install -D -m 0644 system/systemd/logind.conf.d/10-lid.conf \
        /etc/systemd/logind.conf.d/10-lid.conf
sudo install -D -m 0644 system/udev/rules.d/90-no-wake-i2c-hid.rules \
        /etc/udev/rules.d/90-no-wake-i2c-hid.rules
sudo install -D -m 0644 system/upower/UPower.conf.d/70-hibernate-earlier.conf \
        /etc/UPower/UPower.conf.d/70-hibernate-earlier.conf
sudo install -D -m 0644 system/NetworkManager/conf.d/10-dns-resolved.conf \
        /etc/NetworkManager/conf.d/10-dns-resolved.conf
# NM refuses symlinked or non-root dispatchers
sudo install -D -m 0755 system/NetworkManager/dispatcher.d/50-restart-sshfs \
        /etc/NetworkManager/dispatcher.d/50-restart-sshfs
sudo install -D -m 0755 system/NetworkManager/dispatcher.d/60-tzupdate \
        /etc/NetworkManager/dispatcher.d/60-tzupdate
# only if you want 'options no-aaaa'
sudo install -D -m 0755 system/NetworkManager/dispatcher.d/90-no-aaaa \
        /etc/NetworkManager/dispatcher.d/90-no-aaaa
```

After changing grub or mkinitcpio/modprobe:

```sh
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo mkinitcpio -P
```

logind reads drop-ins on reload (`sudo systemctl reload systemd-logind`);
do not restart it in a graphical session. UPower wants a restart.

DNS: `systemd-resolved` owns `/etc/resolv.conf` as a link to
`/run/systemd/resolve/stub-resolv.conf`. NetworkManager is set to
`dns=systemd-resolved`. Keep Tailscale's split DNS as it is.

## Why not stow into /etc

A few of these readers cannot see `/home`: systemd-logind (`ProtectHome=yes`),
udev (private mounts, initramfs), PAM (must work with a broken `/home`),
grub/mkinitcpio (before `/home` is mounted), reflector (`ProtectHome=true`),
and NetworkManager dispatchers (refuse symlinks). A real root-owned file is
the only form that works in all of those.
