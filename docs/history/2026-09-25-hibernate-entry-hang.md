# 2026-09-25 — Hung at hibernate entry, 59% → 1%

## Incident

suspend-then-hibernate at 14:38 (hypridle). S2idle for `HibernateDelaySec=1h`, then
hibernate at 15:38:11. Journal ends at `PM: hibernation: hibernation entry` with
userspace still logging (tailscaled). No image. Machine stayed powered until a
power-cycle at 19:08; battery 37.96 Wh → 0.46 Wh (59% → 1%).

- S2idle hour: ~0.6 Wh (normal).
- 15:38→19:08: ~37 Wh over 3.5 h (~10.5 W) — kernel running, not S4.
- Boot at 19:08: `Unable to resume from device … offset 0` / no valid image.

Same signature as 2026-09-10 (see below), but on the **stock** post-reset config
(no lz4, no `image_size` override). Boot `-1` had already completed three real
s2h power cycles that day (08:22, 18:32, 03:22→13:31). Intermittent.

## Journal gap ≠ slow freeze

Do not read a multi-hour gap after `hibernation entry` as freeze or snapshot
running slowly.

- **Success:** `hibernation entry` → (quiet) → later timestamps show
  `Preallocating` / `Allocated … in N seconds` / `hibernation exit` /
  `Operation finished` on the **same boot id**, plus `smpboot: Booting Node 0
  Processor N` and NVS restore. Those create_image lines were in the kernel log
  buffer inside the image and flush after restore. The gap is real S4 power-off.
- **Hang:** `hibernation entry` is the last kernel PM line; next boot is a new
  boot id with `Image not found` / `Unable to resume`. battery-log has a hole
  and the next `start` sample shows a large energy drop. Freeze did **not**
  crawl for hours.

`Filesystems sync: N.NNN` is printed only **after** `ksys_sync()` returns. It
often appears ~100 ms after entry on a clean path; when it is missing from the
pre-power-off journal it may be sitting unflushed in the ring buffer (seen on
the 03:22 success, flushed at 13:31). Absence alone is not proof of stage —
combine with “userspace still logging” and “no freeze timeout line”.

## Hang stage (kernel 7.2, `kernel/power/hibernate.c`)

```
pr_info("hibernation entry")
pm_prepare_console()
PM_HIBERNATION_PREPARE notifiers     ← no timeout
pm_sleep_fs_sync() → ksys_sync()     ← then prints "Filesystems sync: …"
filesystems_freeze()
freeze_processes()                   ← 20s timeout, WOULD log failure
create_basic_memory_bitmaps()
hibernation_snapshot() → prealloc → dpm_suspend → create_image → power_down
```

This hang has no `Freezing user space processes` and no `Freezing of tasks
failed` after 20 s, and userspace (tailscaled) still writes logs after entry.
So the stall is in **PREPARE notifiers or `ksys_sync`**, before
`freeze_processes`. `pm_freeze_timeout` cannot fire there. `hung_task` may
miss killable waits and IRQs-off GPU paths.

Successful freezes on the same box complete in ~4 ms once freeze starts.

## Ranked causes

1. **NVIDIA `PM_HIBERNATION_PREPARE` / VRAM preserve** (best fit). Proprietary
   615.71.09, `NVreg_PreserveVideoMemoryAllocations=1`,
   `NVreg_UseKernelSuspendNotifiers=1` (from `nvidia-utils.conf`, not the repo
   file). s2h hibernate leg does **not** run `nvidia-hibernate.service`
   (`WantedBy=systemd-hibernate.service` only). `/usr/lib/systemd/system-sleep/nvidia`
   only `echo hibernate` on `pre:hibernate` (`SYSTEMD_SLEEP_ACTION=hibernate`,
   systemd 262) and **ignores write errors**. Kernel notifier can still re-enter
   the driver to save ~6 GiB VRAM (`TemporaryFilePath=/var/tmp`).
2. **`ksys_sync` on FUSE / unfrozen clients.** `fuse-mounts` stops
   `sshfs-conway` before sleep; `gvfsd-fuse` and `xdg-document-portal` stay.
   Claude/Node was the top CPU process at presleep.
3. **`SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false`** (NVIDIA drop-in) is not the
   hang site (freeze has not started) but lets user tasks race prepare/sync.
   Same setting was present on the three successes.

**Not this hang:** initramfs `MODULES=(xe)` (that is the resume-side
`nv_pmops_freeze -5` / cold-boot-after-good-image bug); swap/image size;
`HibernateOnACPower=no` (kept at default on purpose).

Open-modules [#1335](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1335)
/ [#1343](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1343) are
the same notifier family but **abort with errors**, not hang. Do not treat
those fixes as proven for this symptom.

## Next-hang diagnostics (read-only)

```bash
grep -H . /proc/*/stack 2>/dev/null | grep -E 'nvidia|sync|hibernate|pm_'
ls -la /var/tmp/nvidia* 2>/dev/null
journalctl -k -b -1 -g 'PM:|NVRM|nv_|Freezing|Filesystems sync|hibernation'
```

| After `hibernation entry` | Stage |
| --- | --- |
| nothing (this case) | PREPARE notifier or `ksys_sync` |
| `Filesystems sync` then silence | `filesystems_freeze` / later |
| `Freezing user space` w/o `completed` + 20 s fail | `freeze_processes` |
| `Preallocating` but no image written | snapshot / write |

**One controlled A/B if it recurs:** plain `systemctl hibernate` (pulls
`nvidia-hibernate.service`) vs s2h handoff. If only s2h hangs, it is the
handoff/procfs path. A second isolated A/B is
`NVreg_UseKernelSuspendNotifiers=0` in `system/modprobe/nvidia.conf` via
converge `boot`. Do not drop `PreserveVideoMemoryAllocations` or put nvidia
back in `MODULES`.

## Relation to 2026-09-10

09-10 also ended at `hibernation entry` / `Filesystems sync` with no image and
~31 Wh burned. That write-up correlated it with the then-new lz4 + 8 GiB
`hibernate.conf`. **2026-09-25 reproduces the hang on stock defaults**, so
`hibernate.conf` was correlation only, not cause. Desk retests that night did
not reproduce; the remaining uniques then (9-day session, 7.2.2 on disk) are
also absent here (1.5-day session, running 7.2.6).
