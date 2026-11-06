#!/usr/bin/env python3
"""Stream CPU, RAM and GPU load for the bar's load glance, as JSON lines.

One line every five seconds; LoadGlance.qml draws and colours it. The
samples are waybar's scripts/load.py, minus its Pango markup:

- CPU busy share from /proc/stat between ticks, and the mean clock.
- RAM in use (MemTotal - MemAvailable) and swap in use.
- Intel (xe) has no busy-percent file, but each GT reports how long it
  has been idle; busy = 1 - idle delta / wall delta, from the render GT
  (gt*-rc). NVIDIA goes through nvidia-smi. A missing GPU is skipped.
"""

import glob
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

INTERVAL = 5
GIB = 1024 * 1024


def cpu_times():
    """Total and idle jiffies across all CPUs."""
    fields = Path("/proc/stat").read_text().splitlines()[0].split()[1:]
    values = [int(x) for x in fields]
    return sum(values), values[3] + values[4]


def cpu_ghz():
    freqs = []
    pattern = "/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq"
    for path in glob.glob(pattern):
        try:
            freqs.append(int(Path(path).read_text()))
        except (OSError, ValueError):
            pass
    return round(sum(freqs) / len(freqs) / 1e6, 1) if freqs else None


def memory():
    """RAM in use as a percentage, used and total GiB, swap GiB."""
    info = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        key, _, rest = line.partition(":")
        info[key] = int(rest.split()[0])
    total, free = info["MemTotal"], info["MemAvailable"]
    swap = info.get("SwapTotal", 0) - info.get("SwapFree", 0)
    return {
        "ram": round(100 * (total - free) / total),
        "used": round((total - free) / GIB, 1),
        "total": round(total / GIB, 1),
        "swap": round(swap / GIB, 1),
    }


def xe_idle_file():
    """The render GT's idle-residency counter, or None without xe."""
    pattern = "/sys/class/drm/card*/device/tile0/gt*/gtidle/name"
    for name in glob.glob(pattern):
        try:
            if Path(name).read_text().strip().endswith("-rc"):
                return os.path.join(os.path.dirname(name),
                                    "idle_residency_ms")
        except OSError:
            pass
    return None


def nvidia():
    query = "utilization.gpu,memory.used,memory.total,temperature.gpu," \
        "power.draw"
    try:
        out = subprocess.run(
            ["nvidia-smi", f"--query-gpu={query}",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=3, check=False).stdout
        util, used, total, temp, power = (
            x.strip() for x in out.splitlines()[0].split(","))
        return {
            "name": "dGPU",
            "busy": int(util),
            "detail": f"{int(used) / 1024:.1f} / {int(total) / 1024:.1f}"
                      f" GiB  ·  {temp}°C  ·  {float(power):.0f} W",
        }
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        return None


def main():
    xe = xe_idle_file()
    has_nvidia = shutil.which("nvidia-smi") is not None
    last_cpu = cpu_times()
    last_xe = (int(Path(xe).read_text()), time.monotonic() * 1000) \
        if xe else None
    time.sleep(1)

    while True:
        total, idle = cpu_times()
        spent, rested = total - last_cpu[0], idle - last_cpu[1]
        last_cpu = (total, idle)
        sample = {
            "cpu": round(100 * (spent - rested) / spent) if spent else 0,
            "ghz": cpu_ghz(),
            **memory(),
            "gpus": [],
        }
        if xe:
            now_idle, now = int(Path(xe).read_text()), time.monotonic() * 1000
            share = (now_idle - last_xe[0]) / max(now - last_xe[1], 1)
            last_xe = (now_idle, now)
            busy = max(0, min(100, 100 - round(100 * share)))
            sample["gpus"].append(
                {"name": "iGPU", "busy": busy, "detail": "Intel"})
        if has_nvidia and (card := nvidia()):
            sample["gpus"].append(card)
        print(json.dumps(sample), flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        sys.stdout = None  # nothing left to flush into a closed pipe
        sys.exit(0)
