SHELL := /bin/bash

.SILENT:
.DEFAULT_GOAL := help

REPO_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# All stow packages (top-level dirs that contain dotfiles mirroring $HOME)
STOW_PACKAGES := bash git tmux nvim claude hypr mako rofi waybar

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
system-install: ## Symlink system configs and enable services
	sudo mkdir -p /etc/keyd /etc/libinput
	sudo ln -sf $(REPO_ROOT)/keyd/default.conf /etc/keyd/default.conf
	sudo ln -sf $(REPO_ROOT)/libinput/local-overrides.quirks /etc/libinput/local-overrides.quirks
	sudo systemctl enable --now keyd
	@echo "System configs installed."

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
	@echo "System configs:"
	@for f in /etc/keyd/default.conf /etc/libinput/local-overrides.quirks; do \
		if [ -L "$$f" ]; then \
			echo "  $$f: linked"; \
		elif [ -f "$$f" ]; then \
			echo "  $$f: exists (not linked)"; \
		else \
			echo "  $$f: missing"; \
		fi; \
	done
	@echo ""
	@echo "Services:"
	@for svc in keyd; do \
		if systemctl is-active "$$svc" >/dev/null 2>&1; then \
			echo "  $$svc: active"; \
		else \
			echo "  $$svc: inactive"; \
		fi; \
	done
