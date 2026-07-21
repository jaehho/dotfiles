SHELL := /bin/bash

.SILENT:
.DEFAULT_GOAL := help

REPO_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# This file is a dispatcher only. All logic lives in scripts/ — see
# scripts/lib.sh for the package/config lists and scripts/sync.sh for the
# phases. Run a single phase directly when debugging:
#   ./scripts/sync.sh --list
#   ./scripts/sync.sh system

## General
help: ## Show this help message
	echo "Available targets:"
	echo "=================="
	grep -hE '(^[a-zA-Z_%-]+:.*?## .*$$|^## )' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; \
		     /^## / {gsub("^## ", ""); print "\n\033[1;35m" $$0 "\033[0m"}; \
		     /^[a-zA-Z_%-]+:/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	echo ""
	echo -e "\033[1;35mVariables\033[0m"
	printf "  \033[36m%-22s\033[0m %s\n" "PHASE=<name>"    "run one sync phase (see ./scripts/sync.sh --list)"
	printf "  \033[36m%-22s\033[0m %s\n" "FORCE_UPGRADE=1" "upgrade packages even if one ran in the last 24h"
	printf "  \033[36m%-22s\033[0m %s\n" "FORCE=1"         "apply boot-config changes without prompting"

## Sync — the only setup command you need to remember
sync: ## One-shot, idempotent: pkgs, dotfiles, system, services, Claude config, default shell
	DOTFILES=$(REPO_ROOT) FORCE=$(FORCE) FORCE_UPGRADE=$(FORCE_UPGRADE) \
		bash $(REPO_ROOT)/scripts/sync.sh $(PHASE)

## Status (read-only)
status: ## Show stow / system / service / package state
	DOTFILES=$(REPO_ROOT) bash $(REPO_ROOT)/scripts/status.sh

.PHONY: help sync status
