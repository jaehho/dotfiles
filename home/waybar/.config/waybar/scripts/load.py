#!/usr/bin/env python3
"""Stream JSON for the waybar custom/load module.

The bar shows one ramp glyph each for CPU, RAM and GPU, colored by level (calm,
busy, pegged) rather than by metric; hovering drops a panel with bars and
details, labeled in each metric's own hue. One process samples everything, so each GPU is queried
once per tick.

Colors come from the @define-color load-* lines in style.css, the only file
theme-apply rewrites, so a reskin reaches the markup too.

Intel (xe) has no busy-percent file, but each GT reports how long it has been
idle; busy = 1 - idle delta / wall delta, from the render GT (gt*-rc). NVIDIA
goes through nvidia-smi. A missing GPU is skipped.
"""

import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

INTERVAL = 5
BUSY = 75
CRITICAL = 90
RAMP = "▁▂▃▄▅▆▇█"
BAR_CELLS = 12

CSS = Path("~/.config/waybar/style.css").expanduser()


def read(path):
    return Path(path).read_text()


def colors():
    try:
        css = read(CSS)
    except OSError:
        css = ""
    found = dict(re.findall(r"@define-color\s+load-(\w+)\s+(#[0-9a-fA-F]{6})", css))
    defaults = {"calm": "#9da7a9", "warn": "#b0954a", "alert": "#cf7f79",
                "cpu": "#9d8ccf", "ram": "#43ac9b", "gpu": "#609fd2",
                "track": "#41494c", "dim": "#778184"}
    return {**defaults, **found}


def cpu_times():
    v = [int(x) for x in read("/proc/stat").splitlines()[0].split()[1:]]
    idle = v[3] + v[4]
    return sum(v), idle


def cpu_freq_ghz():
    freqs = []
    for p in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq"):
        try:
            freqs.append(int(read(p)))
        except (OSError, ValueError):
            pass
    return sum(freqs) / len(freqs) / 1e6 if freqs else None


def meminfo():
    m = {}
    for line in read("/proc/meminfo").splitlines():
        k, v = line.split(":", 1)
        m[k] = int(v.split()[0])
    gib = 1024 * 1024
    total, avail = m["MemTotal"], m["MemAvailable"]
    swap = (m.get("SwapTotal", 0) - m.get("SwapFree", 0)) / gib
    return round(100 * (total - avail) / total), (total - avail) / gib, total / gib, swap


def xe_idle_file():
    for name in glob.glob("/sys/class/drm/card*/device/tile0/gt*/gtidle/name"):
        try:
            if read(name).strip().endswith("-rc"):
                return os.path.join(os.path.dirname(name), "idle_residency_ms")
        except OSError:
            pass
    return None


def nvidia():
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=3, check=False).stdout
        util, used, total, temp, power = [x.strip() for x in out.splitlines()[0].split(",")]
        return int(util), int(used) / 1024, int(total) / 1024, temp, float(power)
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        return None


def glyph(pct):
    return RAMP[min(pct, 100) * (len(RAMP) - 1) // 100]


def level(pct, c, color, can_alert=True):
    """The metric's color while calm, amber when busy, red when pegged."""
    if can_alert and pct >= CRITICAL:
        return c["alert"]
    if pct >= BUSY:
        return c["warn"]
    return color


def bar(pct, color, c):
    filled = round(pct * BAR_CELLS / 100)
    return (f"<span color='{color}'>{'━' * filled}</span>"
            f"<span color='{c['track']}'>{'━' * (BAR_CELLS - filled)}</span>")


def row(label, pct, color, detail, c, can_alert=True):
    fill = level(pct, c, color, can_alert)
    return (f"<span color='{color}'><b>{label:<4}</b></span> {bar(pct, fill, c)} {pct:>3}%"
            f"  <span color='{c['dim']}'>{detail}</span>")


def main():
    c = colors()
    xe = xe_idle_file()
    has_nvidia = shutil.which("nvidia-smi") is not None
    prev_cpu = cpu_times()
    prev_xe = (int(read(xe)), time.monotonic() * 1000) if xe else (0, 0.0)
    time.sleep(1)

    while True:
        total, idle = cpu_times()
        dt, di = total - prev_cpu[0], idle - prev_cpu[1]
        prev_cpu = (total, idle)
        cpu = round(100 * (dt - di) / dt) if dt else 0
        freq = cpu_freq_ghz()
        ram, used, mem_total, swap = meminfo()

        rows = [
            row("CPU", cpu, c["cpu"], f"{freq:.1f} GHz" if freq else "", c),
            row("RAM", ram, c["ram"], f"{used:.1f} / {mem_total:.1f} GiB  ·  swap {swap:.1f}", c),
        ]
        gpus = []
        if xe:
            now_idle, now = int(read(xe)), time.monotonic() * 1000
            busy = 100 - round(100 * (now_idle - prev_xe[0]) / max(now - prev_xe[1], 1))
            prev_xe = (now_idle, now)
            busy = max(0, min(100, busy))
            gpus.append(busy)
            rows.append(row("iGPU", busy, c["gpu"], "Intel", c, can_alert=False))
        nv = nvidia() if has_nvidia else None
        if nv:
            util, vused, vtotal, temp, power = nv
            gpus.append(util)
            rows.append(row("dGPU", util, c["gpu"],
                            f"{vused:.1f} / {vtotal:.1f} GiB  ·  {temp}°C  ·  {power:.0f} W", c,
                            can_alert=False))

        def chip(pct, can_alert=True):
            return f"<span color='{level(pct, c, c['calm'], can_alert)}'>{glyph(pct)}</span>"

        text = chip(cpu) + chip(ram)
        if gpus:
            # A long job pegs the dGPU on purpose, so the GPU glyph stops at amber
            text += chip(max(gpus), can_alert=False)

        out = {
            "text": text,
            "tooltip": "<tt>" + "\n".join(rows) + "</tt>",
            "class": "critical" if max(cpu, ram) >= CRITICAL else "",
        }
        print(json.dumps(out), flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        sys.stdout = None  # nothing left to flush into a closed pipe
        sys.exit(0)
