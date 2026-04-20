SHELL := /bin/bash

.SILENT:
.DEFAULT_GOAL := help

REPO_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Stow packages split by distro
COMMON_PACKAGES := fish git tmux nvim claude rclone sshfs bin kitty ssh mime restic zathura
ARCH_PACKAGES   := hypr mako rofi waybar

DISTRO := $(shell . /etc/os-release 2>/dev/null && echo $$ID)
ifeq ($(DISTRO),arch)
  STOW_PACKAGES := $(COMMON_PACKAGES) $(ARCH_PACKAGES)
else
  STOW_PACKAGES := $(COMMON_PACKAGES)
endif

## General
help: ## Show this help message
	echo "Available targets:"
	echo "=================="
	grep -hE '(^[a-zA-Z_%-]+:.*?## .*$$|^## )' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; \
		     /^## / {gsub("^## ", ""); print "\n\033[1;35m" $$0 "\033[0m"}; \
		     /^[a-zA-Z_%-]+:/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

## Submodule tools (Arch only)
TOOLS := hypr-tools

install-tools: ## Install tools from submodules to ~/.local/bin (dev override)
ifeq ($(DISTRO),arch)
	@git -C $(REPO_ROOT) submodule update --init --recursive $(TOOLS)
	@for tool in $(TOOLS); do \
		echo "Installing $$tool..."; \
		$(MAKE) -C $(REPO_ROOT)/$$tool install; \
	done
	@echo ""
	@echo "Dev copies installed to ~/.local/bin (overrides AUR packages on PATH)."
	@echo "Run 'make uninstall-tools' to revert to AUR versions."
else
	@echo "Skipped: tools are Arch/Hyprland only."
endif

uninstall-tools: ## Remove dev overrides, revert to AUR package versions
	@for tool in $(TOOLS); do \
		if [ -f "$(REPO_ROOT)/$$tool/Makefile" ]; then \
			echo "Uninstalling $$tool..."; \
			$(MAKE) -C $(REPO_ROOT)/$$tool uninstall; \
		fi; \
	done
	@echo "Reverted to AUR package versions in /usr/bin."

## Stow
stow-all: ## Stow all packages (idempotent — safe to re-run after adding files)
	@for pkg in $(STOW_PACKAGES); do \
		echo "Stowing $$pkg..."; \
		stow -d $(REPO_ROOT) -t ~ --no-folding $$pkg; \
	done
	@echo "All packages stowed."
	@echo ""
	@echo "To reload without restarting:"
	@echo "  fish     exec fish"
	@echo "  tmux     tmux source-file ~/.tmux.conf"
	@echo "  nvim     :source \$$MYVIMRC"
	@if echo "$(STOW_PACKAGES)" | grep -qw hypr; then \
		echo "  hypr     hyprctl reload"; \
		echo "  mako     makoctl reload"; \
		echo "  waybar   killall -SIGUSR2 waybar"; \
	fi
	@if [ "$$SHELL" != "/usr/bin/fish" ]; then \
		echo ""; \
		echo "To set fish as your default shell:"; \
		echo "  chsh -s /usr/bin/fish"; \
	fi

stow-%: ## Stow a single package (e.g., make stow-nvim)
	stow -d $(REPO_ROOT) -t ~ --no-folding $*

unstow-%: ## Unstow a single package (e.g., make unstow-nvim)
	stow -d $(REPO_ROOT) -t ~ -D $*

## System configs (require sudo)
# Boot-critical configs (grub, mkinitcpio, modprobe) are COPIED, not symlinked,
# so they survive broken /home mounts and work in rescue/chroot environments.
# keyd and libinput are symlinked (non-boot-critical, read at runtime).
COMMON_SYSTEM_COPIES := \
	modprobe/nvidia.conf:/etc/modprobe.d/nvidia.conf

ARCH_SYSTEM_COPIES := \
	grub/grub:/etc/default/grub \
	mkinitcpio/mkinitcpio.conf:/etc/mkinitcpio.conf

ifeq ($(DISTRO),arch)
  SYSTEM_COPIES := $(COMMON_SYSTEM_COPIES) $(ARCH_SYSTEM_COPIES)
else
  SYSTEM_COPIES := $(COMMON_SYSTEM_COPIES)
endif

system-install: ## Copy boot configs and symlink runtime configs
	@if [ ! -d "$(HOME)/.tmux/plugins/tpm" ]; then \
		echo "Installing TPM..."; \
		git clone https://github.com/tmux-plugins/tpm "$(HOME)/.tmux/plugins/tpm"; \
	else \
		echo "TPM already installed."; \
	fi
	sudo mkdir -p /etc/keyd /etc/libinput /etc/modprobe.d /etc/default /etc/systemd /etc/sysctl.d /etc/alsa/conf.d
	sudo ln -sf $(REPO_ROOT)/keyd/default.conf /etc/keyd/default.conf
	sudo ln -sf $(REPO_ROOT)/libinput/local-overrides.quirks /etc/libinput/local-overrides.quirks
	sudo ln -sf $(REPO_ROOT)/sysctl/99-sysrq.conf /etc/sysctl.d/99-sysrq.conf
	sudo sysctl --system >/dev/null
	sudo ln -sf $(REPO_ROOT)/systemd/sleep.conf /etc/systemd/sleep.conf
	# system-sleep hooks must go in /usr/lib/, not /etc/ — systemd-sleep(8) v260+
	# only scans /usr/lib/systemd/system-sleep/ (verified via `strings` on the
	# binary). /etc/systemd/system-sleep/ is silently ignored.
	sudo ln -sf $(REPO_ROOT)/systemd/system-sleep/fuse-mounts /usr/lib/systemd/system-sleep/fuse-mounts
	sudo ln -sf $(REPO_ROOT)/systemd/system-sleep/hyprlock-restart /usr/lib/systemd/system-sleep/hyprlock-restart
	# Clean up any stale /etc/ symlinks from before this was understood.
	sudo rm -f /etc/systemd/system-sleep/fuse-mounts /etc/systemd/system-sleep/hyprlock-restart
	sudo ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/99-pipewire-default.conf
	@changed=""; \
	for pair in $(SYSTEM_COPIES); do \
		src=$${pair%%:*}; dst=$${pair##*:}; \
		if [ ! -f "$$dst" ]; then \
			sudo cp "$(REPO_ROOT)/$$src" "$$dst"; \
			echo "  $$dst: installed (new)"; \
		elif diff -q "$(REPO_ROOT)/$$src" "$$dst" >/dev/null 2>&1; then \
			echo "  $$dst: up to date"; \
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
				y|Y) \
					sudo cp "$$dst" "$${dst}.bak"; \
					echo "  backed up $$dst -> $${dst}.bak"; \
					sudo cp "$(REPO_ROOT)/$$src" "$$dst"; \
					echo "  $$dst: applied"; \
					changed="$$changed $$dst"; \
					;; \
				q|Q) \
					echo "  aborted."; \
					exit 1; \
					;; \
				*) \
					echo "  $$dst: skipped"; \
					;; \
			esac; \
		fi; \
	done; \
	if ! command -v keyd >/dev/null 2>&1 && [ "$(DISTRO)" = "ubuntu" ]; then \
		echo "Installing keyd from source..."; \
		tmp=$$(mktemp -d); \
		git clone https://github.com/rvaiya/keyd "$$tmp/keyd"; \
		make -C "$$tmp/keyd"; \
		sudo make -C "$$tmp/keyd" install; \
		rm -rf "$$tmp"; \
	fi; \
	if command -v keyd >/dev/null 2>&1; then \
		sudo systemctl enable --now keyd; \
	fi; \
	echo "System configs installed."; \
	case "$$changed" in \
		*/grub*)       echo "  -> Run: sudo grub-mkconfig -o /boot/grub/grub.cfg" ;; \
	esac; \
	case "$$changed" in \
		*/mkinitcpio*) echo "  -> Run: sudo mkinitcpio -P" ;; \
	esac

system-diff: ## Show differences between repo and system configs
	@dirty=0; \
	for pair in $(SYSTEM_COPIES); do \
		src=$${pair%%:*}; dst=$${pair##*:}; \
		if [ -f "$$dst" ]; then \
			if ! diff -q "$(REPO_ROOT)/$$src" "$$dst" >/dev/null 2>&1; then \
				printf '\033[33m%s differs from repo:\033[0m\n' "$$dst"; \
				diff --color=auto -u "$(REPO_ROOT)/$$src" "$$dst" || true; \
				dirty=1; \
			fi; \
		else \
			printf '\033[31m%s: missing on system\033[0m\n' "$$dst"; \
			dirty=1; \
		fi; \
	done; \
	if [ "$$dirty" = 0 ]; then printf '\033[32mAll system configs match repo.\033[0m\n'; fi

system-pull: ## Pull system configs into repo (overwrite repo copies)
	@for pair in $(SYSTEM_COPIES); do \
		src=$${pair%%:*}; dst=$${pair##*:}; \
		if [ -f "$$dst" ]; then \
			cp "$$dst" "$(REPO_ROOT)/$$src"; \
			echo "  pulled $$dst -> $$src"; \
		else \
			echo "  $$dst: missing, skipped"; \
		fi; \
	done
	@echo "Run 'git diff' to review changes."

## Rclone
rclone-onedrive-setup: stow-rclone ## Configure OneDrive remote and enable mount
	@command -v rclone >/dev/null 2>&1 || { \
		echo "Installing rclone..."; \
		if command -v pacman >/dev/null 2>&1; then \
			sudo pacman -S --needed --noconfirm rclone; \
		elif command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get install -y rclone; \
		else \
			echo "No supported package manager found"; exit 1; \
		fi; \
	}
	@if ! rclone listremotes 2>/dev/null | grep -q '^onedrive:'; then \
		echo "No 'onedrive' remote found. Starting interactive config..."; \
		echo "  -> Choose 'onedrive' type, leave client_id/secret blank, auto-config: yes"; \
		rclone config; \
	else \
		echo "Remote 'onedrive' already configured."; \
	fi
	@mkdir -p ~/OneDrive
	@systemctl --user daemon-reload
	@systemctl --user enable --now rclone-onedrive
	@echo "OneDrive mounted at ~/OneDrive"

rclone-onedrive-unmount: ## Unmount OneDrive and disable service
	@systemctl --user disable --now rclone-onedrive 2>/dev/null || true
	@echo "OneDrive unmounted and service disabled."

sshfs-setup: stow-sshfs ## Install sshfs and enable ice + mililab mounts
	@command -v sshfs >/dev/null 2>&1 || { \
		echo "Installing sshfs..."; \
		if command -v pacman >/dev/null 2>&1; then \
			sudo pacman -S --needed --noconfirm sshfs; \
		elif command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get install -y sshfs; \
		else \
			echo "No supported package manager found"; exit 1; \
		fi; \
	}
	@mkdir -p ~/ice ~/mililab
	@systemctl --user daemon-reload
	@systemctl --user enable --now sshfs-ice
	@systemctl --user enable --now sshfs-mililab
	@echo "ice mounted at ~/ice, mililab mounted at ~/mililab"

sshfs-unmount: ## Unmount ice + mililab SSHFS and disable services
	@systemctl --user disable --now sshfs-ice 2>/dev/null || true
	@systemctl --user disable --now sshfs-mililab 2>/dev/null || true
	@echo "SSHFS mounts unmounted and services disabled."

## Restic
restic-setup: stow-restic ## Install restic, set password, init repo on OneDrive, enable timer
	@command -v restic >/dev/null 2>&1 || { \
		echo "Installing restic..."; \
		if command -v pacman >/dev/null 2>&1; then \
			sudo pacman -S --needed --noconfirm restic; \
		elif command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get install -y restic; \
		else \
			echo "No supported package manager found"; exit 1; \
		fi; \
	}
	@if [ ! -f "$(HOME)/.config/restic/password" ]; then \
		echo "Enter a password for the restic repository:"; \
		read -rsp "Password: " pw && echo && \
		read -rsp "Confirm:  " pw2 && echo && \
		[ "$$pw" = "$$pw2" ] || { echo "Passwords do not match."; exit 1; } && \
		install -m 600 /dev/null "$(HOME)/.config/restic/password" && \
		printf '%s' "$$pw" > "$(HOME)/.config/restic/password" && \
		echo "Password saved to ~/.config/restic/password (not tracked by git)"; \
	else \
		echo "Password file already exists."; \
	fi
	@if ! RESTIC_REPOSITORY=rclone:onedrive:Backups/restic \
		RESTIC_PASSWORD_FILE=$(HOME)/.config/restic/password \
		restic snapshots >/dev/null 2>&1; then \
		echo "Initializing restic repository at onedrive:Backups/restic ..."; \
		RESTIC_REPOSITORY=rclone:onedrive:Backups/restic \
		RESTIC_PASSWORD_FILE=$(HOME)/.config/restic/password \
		restic init; \
	else \
		echo "Repository already initialized."; \
	fi
	@systemctl --user daemon-reload
	@systemctl --user enable --now restic-backup.timer
	@echo ""
	@echo "Restic backup timer enabled. Next run:"
	@systemctl --user list-timers restic-backup.timer --no-legend

restic-backup-now: ## Run a backup immediately (blocks until done, then shows logs)
	@systemctl --user daemon-reload
	@echo "Starting backup (this will block until complete)..."
	@systemctl --user start restic-backup.service && \
		journalctl --user -u restic-backup.service -n 50 --no-pager || \
		{ journalctl --user -u restic-backup.service -n 50 --no-pager; exit 1; }

restic-snapshots: ## List restic snapshots on OneDrive
	@RESTIC_REPOSITORY=rclone:onedrive:Backups/restic \
	RESTIC_PASSWORD_FILE=$(HOME)/.config/restic/password \
	restic snapshots

restic-disable: ## Disable the restic backup timer
	@systemctl --user disable --now restic-backup.timer 2>/dev/null || true
	@echo "Restic backup timer disabled."

## Packages
# Arch: source of truth is packages/arch/*.txt (hand-curated by category).
# packages/arch-snapshot.txt is a snapshot written by pkg-dump — compare against
# categories via pkg-drift. AUR/Ubuntu have single-file sources of truth.
PKGDIR := $(REPO_ROOT)/packages

pkg-dump: ## Snapshot explicitly-installed packages into packages/arch-snapshot.txt (for drift diffing)
ifeq ($(DISTRO),arch)
	pacman -Qqen > $(PKGDIR)/arch-snapshot.txt
	pacman -Qqem > $(PKGDIR)/aur.txt
	@echo "Saved $$(wc -l < $(PKGDIR)/arch-snapshot.txt) official + $$(wc -l < $(PKGDIR)/aur.txt) AUR packages."
	@echo "Run 'make pkg-drift' to diff against packages/arch/*.txt categories."
else ifeq ($(DISTRO),ubuntu)
	apt-mark showmanual | sort > $(PKGDIR)/ubuntu.txt
	@echo "Saved $$(wc -l < $(PKGDIR)/ubuntu.txt) manually installed packages."
else
	@echo "Skipped: unsupported distro ($(DISTRO))."
endif

pkg-install: ## Install packages from categorized lists (Arch: packages/arch/*.txt + packages/aur.txt)
ifeq ($(DISTRO),arch)
	@cat $(PKGDIR)/arch/*.txt | grep -v '^#' | grep -v '^$$' | sort -u | sudo pacman -S --needed -
	@command -v paru >/dev/null 2>&1 || { echo "paru not found — install it first for AUR packages."; exit 1; }
	paru -S --needed - < $(PKGDIR)/aur.txt
else ifeq ($(DISTRO),ubuntu)
	sudo apt-get install -y $$(grep -v '^#' $(PKGDIR)/ubuntu.txt | grep -v '^$$')
else
	@echo "Skipped: unsupported distro ($(DISTRO))."
endif

pkg-drift: ## Arch: diff installed state vs categorized packages/arch/*.txt
ifeq ($(DISTRO),arch)
	@installed=$$(pacman -Qqen | sort -u); \
	tracked=$$(cat $(PKGDIR)/arch/*.txt | grep -v '^#' | grep -v '^$$' | sort -u); \
	untracked=$$(comm -23 <(echo "$$installed") <(echo "$$tracked")); \
	stale=$$(comm -13 <(echo "$$installed") <(echo "$$tracked")); \
	if [ -n "$$untracked" ]; then \
		printf '\033[33mInstalled but not in any category (add to packages/arch/*.txt):\033[0m\n'; \
		printf '  %s\n' $$untracked; \
	fi; \
	if [ -n "$$stale" ]; then \
		printf '\033[33mIn categories but not installed (reinstall or remove from category):\033[0m\n'; \
		printf '  %s\n' $$stale; \
	fi; \
	if [ -z "$$untracked" ] && [ -z "$$stale" ]; then \
		printf '\033[32mCategories match installed state.\033[0m\n'; \
	fi
else
	@echo "Skipped: pkg-drift is Arch-only."
endif

## Status
status: ## Show current dotfiles state
	@echo "Stow packages:"
	@for pkg in $(STOW_PACKAGES); do \
		first_file=$$(find "$(REPO_ROOT)/$$pkg" -type f -print -quit 2>/dev/null); \
		if [ -n "$$first_file" ]; then \
			rel="$${first_file#$(REPO_ROOT)/$$pkg/}"; \
			if [ -L "$$HOME/$$rel" ]; then \
				echo "  $$pkg: stowed"; \
			else \
				echo "  $$pkg: not stowed"; \
			fi; \
		else \
			echo "  $$pkg: empty"; \
		fi; \
	done
	@echo ""
	@echo "System configs (symlinked):"
	@for f in /etc/keyd/default.conf /etc/libinput/local-overrides.quirks /etc/sysctl.d/99-sysrq.conf /etc/systemd/sleep.conf /etc/systemd/system-sleep/fuse-mounts /etc/alsa/conf.d/99-pipewire-default.conf; do \
		if [ -L "$$f" ]; then \
			echo "  $$f: linked"; \
		elif [ -f "$$f" ]; then \
			echo "  $$f: exists (not linked)"; \
		else \
			echo "  $$f: missing"; \
		fi; \
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
	@for svc in keyd rclone-onedrive sshfs-ice sshfs-mililab restic-backup.timer; do \
		case "$$svc" in keyd) \
			active=$$(systemctl is-active "$$svc" 2>/dev/null);; *) \
			active=$$(systemctl --user is-active "$$svc" 2>/dev/null);; esac; \
		if [ "$$active" = "active" ]; then \
			echo "  $$svc: active"; \
		else \
			echo "  $$svc: inactive"; \
		fi; \
	done
