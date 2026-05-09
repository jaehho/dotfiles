SHELL := /bin/bash

.SILENT:
.DEFAULT_GOAL := help

REPO_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Stow packages split by distro
COMMON_PACKAGES := fish git tmux nvim claude rclone sshfs bin kitty ssh mime restic zathura visidata tridactyl
ARCH_PACKAGES   := hypr swaync rofi waybar

# Detect distro family by package manager rather than os-release ID. This
# catches derivatives (Manjaro/EndeavourOS as arch, Pop/Mint/Kali as debian)
# without an explicit allowlist.
ifneq (,$(shell command -v pacman 2>/dev/null))
  DISTRO_FAMILY := arch
else ifneq (,$(shell command -v apt-get 2>/dev/null))
  DISTRO_FAMILY := debian
else
  DISTRO_FAMILY := unknown
endif

ifeq ($(DISTRO_FAMILY),arch)
  STOW_PACKAGES := $(COMMON_PACKAGES) $(ARCH_PACKAGES)
else
  STOW_PACKAGES := $(COMMON_PACKAGES)
endif

# Per-host config: capability-based variation (distro, cloudflared, gcloud,
# ssh reachability, etc.) is auto-detected elsewhere. This block handles
# *choices* — flags persisted in hosts/<hostname>.mk by scripts/setup-host.sh
# (which sync runs once on first install of a new machine).
#
# Flags:
# - HOST_DEV_TOOLS  : 1 = build hypr-tools submodule into ~/.local/bin (overrides AUR)
# - HOST_RESTIC     : 1 = enable restic backup timer; 0 = disable
# - HOST_DROP_PKGS  : whitespace-separated stow packages to skip on this host
HOSTNAME := $(shell uname -n)
-include $(REPO_ROOT)/hosts/$(HOSTNAME).mk

# Conservative defaults for any flag the host file didn't set.
HOST_DEV_TOOLS ?= 0
HOST_RESTIC    ?= 1
HOST_DROP_PKGS ?=

STOW_PACKAGES := $(filter-out $(HOST_DROP_PKGS),$(STOW_PACKAGES))

PKGDIR := $(REPO_ROOT)/packages

# Boot-critical configs (grub, mkinitcpio, modprobe) are COPIED, not symlinked,
# so they survive broken /home mounts and work in rescue/chroot environments.
# nvidia.conf splits by driver variant: Arch runs proprietary nvidia-beta-dkms
# (full tuning); Debian-family installs here run nvidia-driver-*-open (minimal,
# since the proprietary-only options break suspend on the open module).
ARCH_SYSTEM_COPIES := \
	grub/grub:/etc/default/grub \
	mkinitcpio/mkinitcpio.conf:/etc/mkinitcpio.conf \
	modprobe/nvidia.conf:/etc/modprobe.d/nvidia.conf

DEBIAN_SYSTEM_COPIES := \
	modprobe/nvidia-open.conf:/etc/modprobe.d/nvidia.conf

ifeq ($(DISTRO_FAMILY),arch)
  SYSTEM_COPIES := $(ARCH_SYSTEM_COPIES)
else ifeq ($(DISTRO_FAMILY),debian)
  SYSTEM_COPIES := $(DEBIAN_SYSTEM_COPIES)
else
  SYSTEM_COPIES :=
endif

TOOLS := hypr-tools

## General
help: ## Show this help message
	echo "Available targets:"
	echo "=================="
	grep -hE '(^[a-zA-Z_%-]+:.*?## .*$$|^## )' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; \
		     /^## / {gsub("^## ", ""); print "\n\033[1;35m" $$0 "\033[0m"}; \
		     /^[a-zA-Z_%-]+:/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

## Sync — the only setup command you need to remember
sync: ## One-shot, idempotent: pkgs, dotfiles, system, services, Claude config, default shell
	@DOTFILES=$(REPO_ROOT) bash $(REPO_ROOT)/scripts/setup-host.sh
	@$(MAKE) -s _sync-pkgs
	@$(MAKE) -s _sync-ubuntu-extras
	@$(MAKE) -s _sync-tools
	@$(MAKE) -s _sync-stow
	@$(MAKE) -s _sync-system
	@$(MAKE) -s _sync-rclone
	@$(MAKE) -s _sync-sshfs
	@$(MAKE) -s _sync-restic
	@$(MAKE) -s _sync-claude
	@$(MAKE) -s _sync-shell
	@echo ""
	@echo "==> Sync complete."
	@echo "    Reload running tools to pick up dotfile changes:"
	@echo "      fish     exec fish"
	@echo "      tmux     tmux source-file ~/.tmux.conf"
	@echo "      nvim     :source \$$MYVIMRC"
	@if echo "$(STOW_PACKAGES)" | grep -qw hypr; then \
		echo "      hypr     hyprctl reload"; \
		echo "      swaync   swaync-client -rs"; \
		echo "      waybar   killall -SIGUSR2 waybar"; \
	fi

# --- internal _sync-* helpers (not in help) -------------------------------

_sync-pkgs:
	@echo "==> Packages..."
ifeq ($(DISTRO_FAMILY),arch)
	@cat $(PKGDIR)/arch/*.txt | grep -vE '^(#|$$)' | sort -u | sudo pacman -S --needed -
	@command -v paru >/dev/null 2>&1 || { echo "paru not found — install it first for AUR packages."; exit 1; }
	@# Strip comments, blanks, and *-debug split packages (auto-produced when paru
	@# builds with OPTIONS=(debug); not individually installable from AUR).
	@grep -vE '^(#|$$)' $(PKGDIR)/aur.txt | grep -vE -- '-debug$$' | paru -S --needed -
else ifeq ($(DISTRO_FAMILY),debian)
	@sudo apt-get update -qq
	@sudo apt-get install -y $$(grep -v '^#' $(PKGDIR)/ubuntu.txt | grep -v '^$$')
else
	@echo "  skipped: unsupported distro ($(DISTRO_FAMILY))."
endif

# Submodule-built tool overrides (Arch + dev hosts only). HOST_DEV_TOOLS=1 builds
# hypr-tools from the submodule into ~/.local/bin, shadowing the AUR /usr/bin
# copies. Use `make uninstall-tools` to revert temporarily; next sync re-installs.
_sync-tools:
ifeq ($(HOST_DEV_TOOLS),1)
ifeq ($(DISTRO_FAMILY),arch)
	@echo "==> hypr-tools (dev override active)..."
	@git -C $(REPO_ROOT) submodule update --init --recursive $(TOOLS) 2>&1 | sed 's/^/  /'
	@for tool in $(TOOLS); do \
		$(MAKE) -C $(REPO_ROOT)/$$tool install >/dev/null 2>&1 && \
			echo "  $$tool: installed to ~/.local/bin"; \
	done
endif
endif

# Debian-family only: tools not in apt, or apt names that need ~/.local/bin shims.
_sync-ubuntu-extras:
ifeq ($(DISTRO_FAMILY),debian)
	@mkdir -p $(HOME)/.local/bin
	@if ! command -v bat >/dev/null 2>&1 && [ -x /usr/bin/batcat ]; then \
		ln -sf /usr/bin/batcat $(HOME)/.local/bin/bat; \
		echo "  bat: symlinked /usr/bin/batcat -> ~/.local/bin/bat"; \
	fi
	@if ! command -v fd >/dev/null 2>&1 && [ -x /usr/bin/fdfind ]; then \
		ln -sf /usr/bin/fdfind $(HOME)/.local/bin/fd; \
		echo "  fd: symlinked /usr/bin/fdfind -> ~/.local/bin/fd"; \
	fi
	@if ! command -v eza >/dev/null 2>&1; then \
		echo "==> Installing eza..."; \
		if apt-cache show eza >/dev/null 2>&1; then \
			sudo apt-get install -y eza; \
		elif command -v cargo >/dev/null 2>&1; then \
			cargo install eza; \
		else \
			echo "  eza: install manually from https://github.com/eza-community/eza/releases"; \
		fi; \
	fi
	@if ! command -v zoxide >/dev/null 2>&1; then \
		echo "==> Installing zoxide..."; \
		curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash; \
	fi
	@if ! infocmp xterm-kitty >/dev/null 2>&1; then \
		echo "==> Installing kitty terminfo..."; \
		tmp_ti=$$(mktemp); \
		(curl -fsSL "https://raw.githubusercontent.com/kovidgoyal/kitty/master/terminfo/kitty.terminfo" -o "$$tmp_ti" \
			&& tic -x "$$tmp_ti" \
			&& echo "  kitty terminfo installed") \
			|| echo "  kitty terminfo install failed"; \
		rm -f "$$tmp_ti"; \
	fi
endif

# Pre-stow cleanup handles three legacy/edge cases that would otherwise damage
# files or block stow:
#   1. Absolute symlinks pointing into the repo: stow doesn't recognize these as
#      "owned" and refuses to re-stow. Remove so stow can recreate them as relative.
#   2. Regular files reachable via a symlinked parent dir (target's realpath lives
#      inside the repo): a naive `mv` would follow the parent symlink and trash
#      the dotfiles file. Skip these — they're already linked in effect.
#   3. Regular files outside the repo: back up so stow can take over.
_sync-stow:
	@echo "==> Stowing dotfiles..."
	@for pkg in $(STOW_PACKAGES); do \
		while IFS= read -r -d '' file; do \
			rel="$${file#$(REPO_ROOT)/$$pkg/}"; \
			target="$(HOME)/$$rel"; \
			if [ -L "$$target" ]; then \
				lt=$$(readlink "$$target"); \
				case "$$lt" in \
					"$(REPO_ROOT)"/*) rm -f "$$target" ;; \
				esac; \
				continue; \
			fi; \
			if [ -e "$$target" ]; then \
				real=$$(readlink -f "$$target" 2>/dev/null || echo ""); \
				case "$$real" in \
					"$(REPO_ROOT)"/*) : ;; \
					*) mv "$$target" "$${target}.bak"; \
					   echo "  backed up $$target -> $${target}.bak" ;; \
				esac; \
			fi; \
		done < <(find "$(REPO_ROOT)/$$pkg" -type f -print0); \
		stow -d $(REPO_ROOT) -t ~ --no-folding $$pkg; \
	done
	@$(MAKE) -s _sync-mime

# mimeapps.list is owned here, not stow (mime/.stow-local-ignore excludes it).
# GLib's safe-write writes the tempfile next to the resolved target; a relative
# symlink would resolve from CWD instead of the link's directory, so Thunar et al.
# fail to update mimeapps.list unless CWD happens to be ~/.config/. An absolute
# symlink makes the tempfile land in the right directory regardless of CWD.
_sync-mime:
	@if command -v update-mime-database >/dev/null 2>&1 && [ -d "$(HOME)/.local/share/mime/packages" ]; then \
		update-mime-database "$(HOME)/.local/share/mime"; \
	fi
	@target=$(REPO_ROOT)/mime/.config/mimeapps.list; \
	link=$(HOME)/.config/mimeapps.list; \
	mkdir -p "$$(dirname "$$link")"; \
	if [ -e "$$link" ] && [ ! -L "$$link" ]; then \
		mv "$$link" "$${link}.bak"; \
		echo "  mimeapps.list: backed up regular file to $${link}.bak"; \
	fi; \
	if [ ! -L "$$link" ] || [ "$$(readlink "$$link")" != "$$target" ]; then \
		ln -sfn "$$target" "$$link"; \
	fi

# Boot/system configs (require sudo). Symlinked configs are runtime-read; copied
# configs (grub, mkinitcpio, modprobe) need to survive broken /home mounts.
# nvidia.conf splits by driver variant. NetworkManager dispatcher hook is
# install-copied (NM refuses symlinks/non-root for security).
# system-sleep hooks live in /usr/lib/, not /etc/ — systemd-sleep(8) v260+
# only scans /usr/lib/systemd/system-sleep/.
_sync-system:
	@echo "==> System configs..."
	@if [ ! -d "$(HOME)/.tmux/plugins/tpm" ]; then \
		git clone https://github.com/tmux-plugins/tpm "$(HOME)/.tmux/plugins/tpm"; \
	fi
	@sudo mkdir -p /etc/keyd /etc/libinput /etc/modprobe.d /etc/default /etc/systemd /etc/systemd/logind.conf.d /etc/sysctl.d /etc/alsa/conf.d
	@sudo ln -sf $(REPO_ROOT)/keyd/default.conf /etc/keyd/default.conf
	@sudo ln -sf $(REPO_ROOT)/libinput/local-overrides.quirks /etc/libinput/local-overrides.quirks
	@sudo ln -sf $(REPO_ROOT)/sysctl/99-sysrq.conf /etc/sysctl.d/99-sysrq.conf
	@sudo sysctl --system >/dev/null
	@sudo ln -sf $(REPO_ROOT)/systemd/sleep.conf /etc/systemd/sleep.conf
	@sudo ln -sf $(REPO_ROOT)/systemd/logind.conf.d/10-lid.conf /etc/systemd/logind.conf.d/10-lid.conf
	@sudo rm -f /etc/systemd/logind.conf.d/10-lid-hibernate.conf
	@sudo systemctl reload systemd-logind.service
	@sudo ln -sf $(REPO_ROOT)/systemd/system-sleep/fuse-mounts /usr/lib/systemd/system-sleep/fuse-mounts
	@sudo ln -sf $(REPO_ROOT)/systemd/system-sleep/hyprlock-restart /usr/lib/systemd/system-sleep/hyprlock-restart
	@sudo rm -f /etc/systemd/system-sleep/fuse-mounts /etc/systemd/system-sleep/hyprlock-restart
	@sudo ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/99-pipewire-default.conf
	@sudo install -D -m 0755 -o root -g root \
		$(REPO_ROOT)/NetworkManager/dispatcher.d/50-restart-sshfs \
		/etc/NetworkManager/dispatcher.d/50-restart-sshfs
	@changed=""; \
	for pair in $(SYSTEM_COPIES); do \
		src=$${pair%%:*}; dst=$${pair##*:}; \
		if [ ! -f "$$dst" ]; then \
			sudo cp "$(REPO_ROOT)/$$src" "$$dst"; \
			echo "  $$dst: installed (new)"; \
		elif diff -q "$(REPO_ROOT)/$$src" "$$dst" >/dev/null 2>&1; then \
			:; \
		else \
			echo ""; \
			echo "  $$dst differs from repo:"; \
			git diff --no-index --color=always "$$dst" "$(REPO_ROOT)/$$src" || true; \
			echo ""; \
			if [ "$${FORCE:-0}" = "1" ]; then \
				apply=y; \
			else \
				printf '  Apply this change? [y/N/q] '; \
				read -r apply < /dev/tty; \
			fi; \
			case "$$apply" in \
				y|Y) sudo cp "$$dst" "$${dst}.bak"; \
				     sudo cp "$(REPO_ROOT)/$$src" "$$dst"; \
				     echo "  $$dst: applied (backup at $${dst}.bak)"; \
				     changed="$$changed $$dst" ;; \
				q|Q) echo "  aborted."; exit 1 ;; \
				*)   echo "  $$dst: skipped" ;; \
			esac; \
		fi; \
	done; \
	if ! command -v keyd >/dev/null 2>&1 && [ "$(DISTRO_FAMILY)" = "debian" ]; then \
		echo "  Installing keyd from source..."; \
		tmp=$$(mktemp -d); \
		git clone https://github.com/rvaiya/keyd "$$tmp/keyd"; \
		make -C "$$tmp/keyd"; \
		sudo make -C "$$tmp/keyd" install; \
		rm -rf "$$tmp"; \
	fi; \
	if command -v keyd >/dev/null 2>&1; then \
		sudo systemctl enable --now keyd >/dev/null 2>&1 || sudo systemctl restart keyd; \
	fi; \
	case "$$changed" in \
		*/grub*)       echo "  -> Run: sudo grub-mkconfig -o /boot/grub/grub.cfg" ;; \
	esac; \
	case "$$changed" in \
		*/mkinitcpio*) echo "  -> Run: sudo mkinitcpio -P" ;; \
	esac

_sync-rclone:
	@echo "==> rclone OneDrive..."
	@command -v rclone >/dev/null 2>&1 || { \
		if command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm rclone; \
		elif command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y rclone; \
		else echo "  no supported package manager — skipping"; exit 0; fi; \
	}
	@if ! rclone listremotes 2>/dev/null | grep -q '^onedrive:'; then \
		echo "  No 'onedrive' remote — starting interactive config (choose 'onedrive', blank client_id/secret, auto-config: yes)..."; \
		rclone config; \
	fi
	@mkdir -p ~/OneDrive
	@systemctl --user daemon-reload
	@if rclone listremotes 2>/dev/null | grep -q '^onedrive:'; then \
		systemctl --user enable --now rclone-onedrive >/dev/null 2>&1 && echo "  OneDrive mounted at ~/OneDrive" || true; \
	else \
		echo "  'onedrive' remote not configured — re-run sync once it exists."; \
	fi

_sync-sshfs:
	@echo "==> sshfs..."
	@command -v sshfs >/dev/null 2>&1 || { \
		if command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm sshfs; \
		elif command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y sshfs; \
		else echo "  no supported package manager — skipping"; exit 0; fi; \
	}
	@mkdir -p ~/ice ~/mililab ~/cdn ~/msi
	@systemctl --user daemon-reload
	@# Always-on mounts: ice (jump-host), mililab (cloudflared)
	@if command -v cloudflared >/dev/null 2>&1; then \
		systemctl --user enable --now sshfs-mililab >/dev/null 2>&1 && echo "  mililab mounted at ~/mililab" || true; \
	else \
		echo "  cloudflared missing — skipping mililab mount"; \
	fi
	@if [ ! -f "$$HOME/.ssh/jump_pass" ]; then \
		echo "  ~/.ssh/jump_pass missing — skipping ice mount"; \
		echo "    Create with: echo PASSWORD > ~/.ssh/jump_pass && chmod 600 ~/.ssh/jump_pass"; \
	else \
		systemctl --user enable --now sshfs-ice >/dev/null 2>&1 && \
		systemctl --user enable --now sshfs-ice-watchdog.timer >/dev/null 2>&1 && \
		echo "  ice mounted at ~/ice"; \
	fi
	@# Opt-in mounts: only attach if the remote is already reachable. The
	@# manual `make sshfs-cdn-mount` target handles the start-instance case.
	@if command -v gcloud >/dev/null 2>&1; then \
		state=$$(gcloud compute instances describe cdn-project --zone=us-east4-b --format='value(status)' 2>/dev/null); \
		if [ "$$state" = RUNNING ]; then \
			systemctl --user start sshfs-cdn >/dev/null 2>&1 && echo "  cdn mounted at ~/cdn (instance running)" || true; \
		fi; \
	fi
	@if ssh -o ConnectTimeout=2 -o BatchMode=yes msi true 2>/dev/null; then \
		systemctl --user start sshfs-msi >/dev/null 2>&1 && echo "  msi mounted at ~/msi (host reachable)" || true; \
	fi

_sync-restic:
ifneq ($(HOST_RESTIC),1)
	@echo "==> restic: disabled for $(HOSTNAME)"
	@systemctl --user disable --now restic-backup.timer 2>/dev/null || true
else
	@echo "==> restic..."
	@command -v restic >/dev/null 2>&1 || { \
		if command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm restic; \
		elif command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y restic; \
		else echo "  no supported package manager — skipping"; exit 0; fi; \
	}
	@mkdir -p $(HOME)/.config/restic
	@if [ ! -f "$(HOME)/.config/restic/password" ]; then \
		echo "  Set a restic repository password:"; \
		read -rsp "  Password: " pw < /dev/tty && echo && \
		read -rsp "  Confirm:  " pw2 < /dev/tty && echo && \
		[ "$$pw" = "$$pw2" ] || { echo "  passwords do not match — skipping"; exit 0; } && \
		install -m 600 /dev/null "$(HOME)/.config/restic/password" && \
		printf '%s' "$$pw" > "$(HOME)/.config/restic/password" && \
		echo "  Password saved to ~/.config/restic/password"; \
	fi
	@if ! rclone listremotes 2>/dev/null | grep -q '^onedrive:'; then \
		echo "  'onedrive' remote not configured — skipping repo init."; \
	else \
		if ! RESTIC_REPOSITORY=rclone:onedrive:Backups/restic \
			RESTIC_PASSWORD_FILE=$(HOME)/.config/restic/password \
			restic snapshots >/dev/null 2>&1; then \
			echo "  Initializing restic repo at onedrive:Backups/restic..."; \
			RESTIC_REPOSITORY=rclone:onedrive:Backups/restic \
			RESTIC_PASSWORD_FILE=$(HOME)/.config/restic/password \
			restic init; \
		fi; \
		systemctl --user daemon-reload; \
		systemctl --user enable --now restic-backup.timer >/dev/null 2>&1 && \
			echo "  backup timer enabled — next run: $$(systemctl --user list-timers restic-backup.timer --no-legend | awk '{print $$1, $$2}')" || true; \
	fi
endif

_sync-claude:
	@echo "==> Claude Code reconcile..."
	@DOTFILES=$(REPO_ROOT) bash $(REPO_ROOT)/scripts/claude-reconcile.sh --interactive

_sync-shell:
	@fish_path=$$(command -v fish); \
	if [ -z "$$fish_path" ]; then \
		echo "==> Default shell: fish not installed, skipping"; \
	elif [ "$$(getent passwd "$$USER" | cut -d: -f7)" = "$$fish_path" ]; then \
		:; \
	else \
		echo "==> Setting fish as default shell..."; \
		grep -qxF "$$fish_path" /etc/shells || echo "$$fish_path" | sudo tee -a /etc/shells; \
		chsh -s "$$fish_path"; \
		echo "  log out and back in for fish to take effect."; \
	fi

## Status (read-only)
status: ## Show stow / system / service state
	@echo "Stow packages:"
	@for pkg in $(STOW_PACKAGES); do \
		stowed=0; \
		while IFS= read -r -d '' file; do \
			rel="$${file#$(REPO_ROOT)/$$pkg/}"; \
			target="$(HOME)/$$rel"; \
			real=$$(readlink -f "$$target" 2>/dev/null || true); \
			if [ "$$real" = "$$file" ]; then stowed=1; break; fi; \
		done < <(find "$(REPO_ROOT)/$$pkg" -type f -print0); \
		if [ "$$stowed" -eq 1 ]; then \
			echo "  $$pkg: stowed"; \
		else \
			echo "  $$pkg: not stowed"; \
		fi; \
	done
	@echo ""
	@echo "System configs (symlinked):"
	@for f in /etc/keyd/default.conf /etc/libinput/local-overrides.quirks /etc/sysctl.d/99-sysrq.conf /etc/systemd/sleep.conf /usr/lib/systemd/system-sleep/fuse-mounts /etc/alsa/conf.d/99-pipewire-default.conf; do \
		if [ -L "$$f" ]; then echo "  $$f: linked"; \
		elif [ -f "$$f" ]; then echo "  $$f: exists (not linked)"; \
		else echo "  $$f: missing"; fi; \
	done
	@echo "System configs (copied):"
	@for pair in $(SYSTEM_COPIES); do \
		src=$${pair%%:*}; dst=$${pair##*:}; \
		if [ -f "$$dst" ]; then \
			if diff -q "$(REPO_ROOT)/$$src" "$$dst" >/dev/null 2>&1; then \
				echo "  $$dst: synced"; \
			else \
				printf '  %s: \033[33mout of sync\033[0m\n' "$$dst"; \
			fi; \
		else \
			echo "  $$dst: missing"; \
		fi; \
	done
	@echo ""
	@echo "Services:"
	@for svc in keyd rclone-onedrive sshfs-ice sshfs-mililab sshfs-cdn sshfs-msi restic-backup.timer; do \
		case "$$svc" in keyd) \
			active=$$(systemctl is-active "$$svc" 2>/dev/null);; *) \
			active=$$(systemctl --user is-active "$$svc" 2>/dev/null);; esac; \
		if [ "$$active" = "active" ]; then echo "  $$svc: active"; \
		else echo "  $$svc: inactive"; fi; \
	done

.PHONY: help sync status \
	_sync-pkgs _sync-ubuntu-extras _sync-tools _sync-stow _sync-mime _sync-system \
	_sync-rclone _sync-sshfs _sync-restic _sync-claude _sync-shell
