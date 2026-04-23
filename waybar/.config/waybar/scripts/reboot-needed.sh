#!/usr/bin/env bash
# Emit JSON for the waybar custom/reboot-needed module.
# class=pending when /lib/modules/$(uname -r)/ no longer exists — that is the
# exact failure condition: the running kernel's module tree was removed by a
# kernel package upgrade, so any modprobe of a not-yet-loaded driver will fail
# until reboot.
#
# Checking the directory directly is kernel-agnostic: works for linux,
# linux-lts, linux-zen, etc. without needing to know which package the running
# kernel came from.

set -u

running=$(uname -r)

if [ -d "/lib/modules/${running}" ]; then
    printf '{"text":"","class":"ok"}\n'
    exit 0
fi

installed=$(ls -1 /lib/modules 2>/dev/null | paste -sd, -)
: "${installed:=none}"
printf '{"text":"󰜉 Reboot","tooltip":"Kernel upgrade pending reboot\\nrunning: %s\\ninstalled: %s","class":"pending"}\n' "$running" "$installed"
