# Dotfiles System

A converged dotfiles management system that syncs configuration from a Git repo to multiple machines via systemd timers.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     dotfiles repo                            │
│                                                              │
│  ├── system/         (root-owned, boot-critical)            │
│  │   ├── converge/    systemd units for auto-sync           │
│  │   ├── keyd/        keyboard config                       │
│  │   ├── NetworkManager/ dispatcher scripts                 │
│  │   ├── reflector/   mirror ranking                        │
│  │   └── ...          boot configs, PAM, etc.               │
│                                                              │
│  ├── home/           (user-owned, daily sync)               │
│   └── hypr/          Hyprland WM config                      │
│                                                              │
│  ├── scripts/        converge.sh + helpers                   │
│  │   ├── converge.sh   main sync orchestration              │
│  │   ├── lib.sh        shared functions                      │
│  │   └── packages.sh   package management                    │
│                                                              │
│  ├── system/         system-level configs                    │
│  │   ├── boot/        kernel, initramfs, grub                │
│  │   ├── PAM/         login security                        │
│  │   └── ...          udev, NetworkManager, etc.            │
│                                                              │
│  └── state/          runtime state (decisions, logs)        │
└─────────────────────────────────────────────────────────────┘
```

## How It Works

### System Half (login + daily)
- **Boot configs** → copied to `/etc` on first run, regenerated on change
- **PAM/shell** → applied once at login
- **NetworkManager** → DNS, tailscale, udev rules
- **systemd-resolved** → takes over DNS from plain resolv.conf
- **keyd** → keyboard config (remap, hotkeys)
- **paccache** → keeps 3 newest versions
- **linux-modules-cleanup** → cleans dead kernel modules

### User Half (login + daily)
- **stow** → dotfiles from repo to `~`
- **tools** → user packages
- **sshfs** → remote filesystem mounts
- **restic** → backups (if configured)
- **claude** → plugin reconciliation
- **wallpaper** → waypaper config

## Key Files

| File | Purpose |
|------|---------|
| `scripts/converge.sh` | Main sync script (system + user halves) |
| `scripts/lib.sh` | Shared utilities (decide, digest_of, etc.) |
| `scripts/packages.sh` | Package management |
| `system/converge/` | systemd service + timer units |
| `home/hypr/` | Hyprland WM config |
| `state/` | Runtime state (decisions.json, logs) |

## Quick Start

```bash
# First time on a new machine
sudo ./scripts/bootstrap.sh   # asks host-specific questions

# Then run converge
sudo ./scripts/converge.sh system
./scripts/converge.sh user

# Or use the systemd units directly
sudo systemctl --user enable --now dotfiles-converge.timer
```

## Server (wonlab)

```bash
dotfiles server          # from the laptop; or: dotfiles server HOST
```

One command sets up and updates the homelab server. It SSHes in, clones or
fast-forwards `~/dotfiles` from GitHub, and runs `scripts/server.sh`: stow links
fish, tmux, nvim, claude and theme (the tmux bar's colors); Neovim and the tree-sitter CLI track their latest
upstream release in `~/.local` (noble's nvim is 0.9.5); plugins follow the
laptop's `lazy-lock.json`. sudo is asked for only when an apt package is
missing. The first run moves wonlab's own `~/.claude/settings.json` to `.bak`.

Nothing runs on a timer and nothing runs as root: the server changes only when
you run this, and only to what is pushed. `git` is left out because its pager
needs `diff-highlight` from `bin`, which is otherwise laptop scripts.

## Troubleshooting

See [ISSUES.md](ISSUES.md) for known issues and fixes.

## Notes

- All decisions are logged to `state/decisions.json`
- Failed steps are recorded and retried on next run
- System half runs as root, user half as owner
- Hyprland config is managed separately (not part of converge)
