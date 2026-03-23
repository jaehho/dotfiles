SHELL := /bin/bash

.SILENT:
.DEFAULT_GOAL := help

REPO_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# All stow packages (top-level dirs that contain dotfiles mirroring $HOME)
STOW_PACKAGES := fish git tmux nvim claude hypr mako rofi waybar rclone bin

## General
help: ## Show this help message
	echo "Available targets:"
	echo "=================="
	grep -hE '(^[a-zA-Z_%-]+:.*?## .*$$|^## )' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; \
		     /^## / {gsub("^## ", ""); print "\n\033[1;35m" $$0 "\033[0m"}; \
		     /^[a-zA-Z_%-]+:/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

## Stow
stow-all: ## Stow all packages
	@for pkg in $(STOW_PACKAGES); do \
		echo "Stowing $$pkg..."; \
		stow -d $(REPO_ROOT) -t ~ --no-folding --adopt $$pkg; \
	done
	@echo "All packages stowed."

stow-%: ## Stow a single package (e.g., make stow-nvim)
	stow -d $(REPO_ROOT) -t ~ --no-folding --adopt $*

unstow-%: ## Unstow a single package (e.g., make unstow-nvim)
	stow -d $(REPO_ROOT) -t ~ -D $*

## System configs (require sudo)
# Boot-critical configs (grub, mkinitcpio, modprobe) are COPIED, not symlinked,
# so they survive broken /home mounts and work in rescue/chroot environments.
# keyd and libinput are symlinked (non-boot-critical, read at runtime).
SYSTEM_COPIES := \
	grub/grub:/etc/default/grub \
	modprobe/nvidia.conf:/etc/modprobe.d/nvidia.conf \
	modprobe/intel-sof-hp-leds.conf:/etc/modprobe.d/intel-sof-hp-leds.conf \
	mkinitcpio/mkinitcpio.conf:/etc/mkinitcpio.conf

system-install: ## Copy boot configs and symlink runtime configs
	sudo mkdir -p /etc/keyd /etc/libinput /etc/modprobe.d /etc/default
	sudo ln -sf $(REPO_ROOT)/keyd/default.conf /etc/keyd/default.conf
	sudo ln -sf $(REPO_ROOT)/libinput/local-overrides.quirks /etc/libinput/local-overrides.quirks
	@changed=""; \
	for pair in $(SYSTEM_COPIES); do \
		src=$${pair%%:*}; dst=$${pair##*:}; \
		if [ -f "$$dst" ] && ! diff -q "$(REPO_ROOT)/$$src" "$$dst" >/dev/null 2>&1; then \
			sudo cp "$$dst" "$${dst}.bak"; \
			echo "  backed up $$dst -> $${dst}.bak"; \
		fi; \
		sudo cp "$(REPO_ROOT)/$$src" "$$dst"; \
		echo "  copied $$src -> $$dst"; \
		changed="$$changed $$dst"; \
	done; \
	sudo systemctl enable --now keyd; \
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
rclone-setup: stow-rclone ## Install rclone, configure OneDrive remote, and enable mount
	@command -v rclone >/dev/null 2>&1 || { echo "Installing rclone..."; sudo pacman -S --needed --noconfirm rclone; }
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

rclone-unmount: ## Unmount OneDrive and disable service
	@systemctl --user disable --now rclone-onedrive 2>/dev/null || true
	@echo "OneDrive unmounted and service disabled."

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
	@for f in /etc/keyd/default.conf /etc/libinput/local-overrides.quirks; do \
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
	@for svc in keyd rclone-onedrive; do \
		if [ "$$svc" = "rclone-onedrive" ]; then \
			active=$$(systemctl --user is-active "$$svc" 2>/dev/null); \
		else \
			active=$$(systemctl is-active "$$svc" 2>/dev/null); \
		fi; \
		if [ "$$active" = "active" ]; then \
			echo "  $$svc: active"; \
		else \
			echo "  $$svc: inactive"; \
		fi; \
	done
