# Per-host config for wonlab (homelab server: Nextcloud, rest-server, Headscale).
# Written by scripts/bootstrap.sh on first run. Safe to hand-edit.
#
# Choices below are from the 2026-09-23 Docker dry-run on an Ubuntu 24.04
# server image. Confirm before the real bootstrap:
#   HOST_RESTIC=0  — wonlab is the rest-server destination the laptop already
#                    pushes to. Set 1 only if this box should also snapshot
#                    $HOME into a rest-server user of its own.
#   HOST_NO_AAAA=0 — set 1 only if this box has no IPv6 and AAAA lookups hang
#                    (the omnibook quirk). Leave 0 while Headscale/Tailscale
#                    split DNS is healthy.
HOST_RESTIC=0
HOST_SSHFS_SKIP="conway"
HOST_DROP_PKGS="kitty mime zathura tridactyl theme audio"
HOST_NO_AAAA=0
