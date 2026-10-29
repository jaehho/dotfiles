#!/usr/bin/env bash
# Emit JSON for the waybar custom/playwright module.
# Claude's Playwright Chrome (class "playwright") is parked on the silent
# special workspace special:playwright by a rule in hyprland.lua. Empty text
# while no such window exists hides the module; class=shown while the
# workspace is raised over the current one.

set -u

windows=$(hyprctl clients -j | jq '[.[] | select(.class == "playwright")] | length')

if [ "${windows:-0}" -eq 0 ]; then
    printf '{"text":"","class":"none"}\n'
    exit 0
fi

if hyprctl monitors -j \
    | jq -e 'any(.[]; .specialWorkspace.name == "special:playwright")' \
    >/dev/null; then
    printf '{"text":"󰖟","tooltip":"Playwright browser: shown (click to hide)","class":"shown"}\n'
else
    printf '{"text":"󰖟","tooltip":"Playwright browser: hidden (click to show)","class":"hidden"}\n'
fi
