#!/usr/bin/env bash
# Stream swaync state for the waybar custom/swaync module.
#
# Why a script and not an inline `swaync-client -swb | jq` in the config:
# waybar starts a continuous exec as `sh -c CMD` in its own process group
# with PR_SET_PDEATHSIG=SIGTERM, which signals only that sh. When waybar
# dies without running module destructors (SIGTERM, SIGKILL, crash) the
# sh dies and its pipeline stays alive; the idle swaync-client
# subscription never writes, so it never takes SIGPIPE. They piled up
# (issue #50). This script is the process-group leader, catches that
# SIGTERM and takes the whole group down.
#
# The pipeline runs in the background and the script `wait`s, because bash
# defers a trap while a foreground job runs.
#
# {icon}{text}: jq adds the space only when there is a count to show.
# Under DND the count is hidden (the tooltip still has it).

set -u

trap 'trap - TERM HUP INT EXIT; kill 0' TERM HUP INT EXIT

swaync-client -swb | jq --unbuffered -c '
    .text = (if .text == "0" or (.alt | startswith("dnd")) then ""
             else " " + .text end)' &
wait
