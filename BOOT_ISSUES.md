# Boot / Sleep / Hibernate Issues Log

Persistent record of boot failures, hibernate/resume failures, hangs, and forced shutdowns on `omnibook` (HP OmniBook 17, Lunar Lake + RTX 4050 Max-Q).

Newest entries at the top. Each entry should include: date, symptom, what the logs showed, and what was done (if anything).

See also: `~/.claude/projects/-home-jaeho-dotfiles/memory/project_nvidia_hibernate_fix.md` for the running root-cause notes.

---

## 2026-04-18 — Hyprland login freeze post-hard-shutdown (nvidia GSP init deadlock)

**Trigger:** User reported the previous session froze while windows were refusing to close during shutdown, forcing a hard power-off. On the next boot, TTY1 login succeeded but Hyprland hung before actually drawing anything; user hard-shutdown a second time to escape. BIOS ran memory training on both subsequent boots.

**Timeline reconstructed from journalctl:**
- Boot -2 (2026-04-17 07:14 → 2026-04-18 17:14:25). **Pre-shutdown GSP instability**: kernel logged `NVRM: _kgspIsHeartbeatTimedOut` + `GSP RM heartbeat timed out` twice on Apr 17 (11:06:02 and 21:36:25), both right after `printk: Suspending console(s)` — i.e. GSP died going into sleep twice during that session, a known failure mode on nvidia-open 595.58.03 without a proprietary fallback. The shutdown at 17:14:25 itself LOOKS clean in the journal (systemd-journald got SIGTERM, `Finished System Power Off` printed), but the journal collapsing every shutdown line into a single second and the user's description ("windows refused to close") suggest the UI was already wedged on the GPU before systemd got the poweroff signal — a short-press power button would still hand off to logind and produce a clean-looking log even if the compositor was frozen.
- Boot -1 (2026-04-18 ~17:14 → 17:52:23). RTC reset to `Mar 23 09:30:30` at kernel start (DDR retrain / CMOS reset after unclean shutdown). nvidia.ko loaded 17:14:25, nvidia-modeset 17:14:27, `[drm] [nvidia-drm] [GPU ID 0x00002b00] Loading driver` **started but never printed `Initialized nvidia-drm 0.0.0`** — i.e. `nv_drm_dev_load` was still in progress. User logged in at 17:47:16, started Hyprland at ~17:48:16. At 17:50:18 kernel hung_task fired:
  ```
  INFO: task (udev-worker):569 blocked for more than 122 seconds.
  INFO: task Hyprland:3066     blocked for more than 122 seconds.
  Both <writer> blocked on an rw-semaphore likely owned by task kworker/1:2:317
  ```
  Both stack traces go through `os_acquire_rwlock_write` → `rmapiLockAcquire` in nvidia, with the udev-worker pinned inside `finit_module → nv_drm_probe_devices → nv_drm_dev_load → AllocateDevice → nvkms_open_gpu → nvidia_dev_get → nv_open_device → nv_start_device → RmInitAdapter → kgspInitRm_IMPL`. The lock owner, `kworker/1:2` (pid 317), is idle in `mm_percpu_wq` — the kworker that would release the lock is not running because whatever RPC/sync primitive it needs from GSP is never completing. 17:52:21 the same hang logged again at 245s; 17:52:23 user pressed power button.

**Diagnosis:** **nvidia-open GSP RM initialization deadlocked** on the first boot after an unclean shutdown. `kgspInitRm_IMPL` is where the host kernel module uploads/starts GSP firmware and waits for it to respond via the RM API. GSP on this GPU was left in an undefined state by the previous session's unclean shutdown (aggravated by the GSP heartbeat timeouts that had already happened twice earlier in boot -2). nvidia-open has no procfs `suspend` interface and no non-GSP code path — if GSP won't talk, there is no fallback; the kernel thread just sleeps on the RM API rw-semaphore forever, which back-pressures every other nvidia ioctl (udev `nvidia_drm` probe, Hyprland GL context allocation) behind the same lock.

Memory training by the BIOS on the next boot is **a symptom, not a cause** — HP's Insyde firmware retrains DDR after detecting an unclean power-off. It doesn't reset the dGPU state; laptop dGPUs often keep a small power island across warm reboots, which is exactly how the bad GSP state propagates forward.

**Why the pattern self-terminated:** the second hard shutdown (17:52:23) was long enough for the dGPU to drop residual state (probably — or BIOS explicitly power-cycled it on the next cold boot), so boot 0 initialized nvidia cleanly. There was nothing "fixed" in dotfiles — the bad state just aged out.

**Action taken:**
- Logged. No config change; the underlying issue (nvidia-open 595 GSP robustness) is upstream, and the immediate incident resolved itself on the next boot.

**Recommendations for user (all unvalidated, ranked by expected payoff):**
1. **Avoid hard shutdown when the compositor is frozen.** Try Ctrl+Alt+F2 (or F3/F4) to escape to a TTY first — the kernel usually still schedules VT switch even when wlroots is jammed. From TTY: `sudo systemctl poweroff`. Even a `Ctrl+Alt+Backspace`-style Hyprland kill is gentler on the GPU than a 5-sec power-button hold. If nothing responds to keys, **SysRq** is the last resort before hardware force-off: hold `Alt+SysRq` and tap `r e i s u b` in sequence (unraw / terminate / kill / sync / unmount / reboot). `REISUB` gives the kernel a chance to run nvidia's shutdown path, which is what preps GSP for a clean re-init.
2. **If a hard shutdown was unavoidable, cold-boot with a pause.** Hold power off for 10+ seconds and optionally unplug AC before powering on, so the dGPU power island actually drains. This is the minimum-effort way to skip the deadlock-on-first-boot pattern without a config change.
3. **Build a safety net for this exact failure mode.** Add a systemd unit that forces `echo 1 > /sys/bus/pci/devices/0000:2b:00.0/reset` early (before udev fires the `nvidia_drm` finit_module). If the GPU was in a bad state from a previous unclean shutdown, a FLR at boot time usually recovers it. This needs testing — some OmniBook BIOSes block FLR on the dGPU.
4. **Watch for repeat GSP heartbeat timeouts.** Two in one session (Apr 17 11:06, 21:36) is already a yellow flag. If the user sees this start accumulating, preemptively reboot *before* the GPU gets so wedged that the compositor won't respond to a clean shutdown request.

**Follow-ups:**
1. If this recurs, capture `dmesg -T | grep -iE 'NVRM|GSP|gpu'` immediately on the stuck boot — confirm it's still `kgspInitRm_IMPL` vs. something new.
2. Periodic check of `pacman -Si nvidia` — a proprietary 595+ package reappearing would give us back the procfs suspend interface and more resilient teardown on unclean shutdown.

---

## 2026-04-17 — Hard freeze, hard shutdown (memory pressure, not hibernate-related)

**Trigger:** System became unresponsive around 07:12 EDT; required hard power cycle. Boot -1 lasted from 2026-04-15 15:47:05 to 2026-04-17 07:12:15 (≈40 hours).

**Not a hibernate issue.** `journalctl -b -1 -k -g 'hibernation entry|hibernation exit'` has no hits in the 3+ hours before the freeze. No NVRM errors, no `nv_pmops_freeze`, no freezer timeouts.

**Actual cause (probable): user-process memory leak.** Two tmux scopes showed huge memory consumption just before the freeze:
```
07:05:49 tmux-spawn-a2eff5cb-…: 310.4M peak / 314.5M swap peak over 7h 8m
07:10:47 tmux-spawn-90600d72-…: 10.8G peak / 274.5M swap peak over 27m 32s   ← likely culprit
07:11:35 new tmux child pane launched (PID 3861794)
07:12:15 freeze / last log entry
```
The 10.8 GB scope ended ~90 s before the freeze, then a new pane started, and the system locked up shortly after. Without process accounting there's no direct evidence of which binary was inside that pane (Claude Code subprocess, a build, a notebook, a script that grew unbounded — plausible candidates). No OOM kill logged, which suggests the OOM killer either didn't get a chance to run or the freeze was kernel-side before journald could write.

**Background noise, not causal but worth flagging:**
- `sshfs-ice.service` restart counter hit **890** over the 40-hour session — server at `ice:` refuses every connect with "Connection reset by peer", systemd retries every 10 s via the unit's `Restart=always, RestartSec=10`. On the current boot it's already at counter 3 and climbing. Might be Cooper Union jump host being flaky, or credentials expired, or ServerAlive timed out the TCP connection permanently.
- wifi (`wlo1`) kept losing AP association briefly around 01:02–01:03.

**Action taken:** Logged here. No fix applied to the system — this was a one-off user-process runaway, not a recurring systemic issue.

**Recommendations for user:**
1. Figure out what was running in that tmux pane around 06:45–07:10 EDT today. Prime suspects: a Claude Code subprocess, a Jupyter/marimo notebook, a script you forgot was looping, or a build. If it's reproducible, consider adding cgroup limits (`MemoryHigh=` / `MemoryMax=` on `user-1000.slice` or on specific scopes) so a runaway process gets throttled/killed before the system freezes.
2. Stop the sshfs-ice restart loop. Either:
   - `systemctl --user mask sshfs-ice.service` until `ice:` is reachable, or
   - Edit the unit to add `StartLimitIntervalSec=60 StartLimitBurst=5` so it stops retrying after a few consecutive failures.
3. Hibernate/nvidia/freezer fixes from 2026-04-15/16 are not implicated — this was unrelated.

---

## 2026-04-16 (evening) — hyprlock crashed post-resume ("lockscreen app died")

**Trigger:** Two hibernate cycles after the freeze-session fix was installed:
- 19:02:26 entry → 19:12:29 exit (10 min off, freeze elapsed 0.003 s)
- 19:13:50 entry → 19:41:11 exit (27 min off, freeze elapsed 0.002 s)

Both froze cleanly — the FUSE freezer issue is resolved. But at 19:41:14 (3 s after the second resume), hyprlock aborted with SIGABRT. `coredumpctl list hyprlock` confirms; the stack trace shows multiple worker threads stuck in `pthread_cond_wait` inside `libgallium-26.0.4-arch1.1.so`, plus the main hyprlock thread stuck the same way. Hyprland surfaces this as the message "it looks like you locked your screen but the lockscreen app died".

**Diagnosis:** The exact trade-off documented when removing `NVreg_PreserveVideoMemoryAllocations=1` earlier today. nvidia-open with that flag unset does not preserve VRAM/GL context across hibernate, so any GPU app running pre-hibernate has an invalid context post-resume. Mesa's gallium driver responds by hanging in `pthread_cond_wait` instead of cleanly returning an error or rebuilding the context, so hyprlock can't render a frame and aborts.

This is recoverable but ugly — Hyprland keeps the session locked, but the lock UI is broken until a fresh hyprlock is started. Earlier hyprlock crashes are visible in `coredumpctl` (Mar 31, Apr 1, Apr 13), suggesting hyprlock has an upstream robustness issue against GL context loss in general; the new wrinkle is that we now reliably trigger it on every hibernate.

**Sources:**
- [hyprlock issue tracker — search for "pthread_cond_wait" / "after suspend"](https://github.com/hyprwm/hyprlock/issues) (multiple reports of similar crashes after sleep on nvidia)

**Action taken:**
- Added `systemd/system-sleep/hyprlock-restart` to the dotfiles repo. Post-hibernate (and post-suspend-then-hibernate) the hook `pkill -KILL hyprlock` then `loginctl lock-session` as user `jaeho`. The lock-session triggers Hyprland's lock signal, which hypridle's `lock_cmd = pidof hyprlock || hyprlock` handles by spawning a fresh hyprlock with a clean GL context.
- Updated `Makefile system-install` target to symlink it into `/etc/systemd/system-sleep/`.
- Wrote `/tmp/hsperfdata_jaeho/install-hyprlock-restart.sh` to install the symlink without re-running the full system-install.

**Verification (today's three cycles, freeze-session fix):**
- `Environment=SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=true` confirmed via `systemctl show systemd-hibernate.service -p Environment` — our `20-` drop-in is overriding nvidia's `10-`.
- All three hibernate cycles since the freeze-session fix went into ACPI S4 cleanly (`Successfully froze unit 'user.slice'`, freeze elapsed 0.002–0.003 s, no "tasks refusing to freeze"). FUSE issue: **resolved.**

**hyprlock-restart hook v1 (19:48 install) did not fix the crash.** Cycle at 21:01–21:06 still ended with `coredumpctl list hyprlock` showing `21:06:11  PID 1743774  SIGABRT`. After resume, `pidof hyprlock` returns nothing — i.e. no fresh hyprlock spawned either, so the user comes back to Hyprland's "lockscreen app died" message with no working lockscreen at all.

Two possible reasons the v1 hook didn't work:
- The hook used `runuser -u jaeho -- ... loginctl lock-session`. Without an arg, `loginctl lock-session` targets the caller's session, but `runuser` doesn't open a PAM session, so loginctl may have had no session to lock and exited silently.
- Even if `loginctl lock-session` did fire and reach Hyprland, the resulting `lock_cmd` (`pidof hyprlock || hyprlock`) may have spawned a fresh hyprlock that ALSO crashed immediately for the same Mesa/gallium reason — and there's no log of either attempt because v1 had no logging.

**hyprlock-restart hook v2 (21:09 install) ALSO did not fire.** Cycle at 21:18–21:19 ended with another `coredumpctl` SIGABRT entry (PID 1866215, 21:19:30) and `/var/log/hyprlock-restart.log` did not exist after resume — i.e. the script wasn't even invoked.

**Real root cause: systemd-sleep(8) v260 only runs scripts in `/usr/lib/systemd/system-sleep/`, NOT `/etc/systemd/system-sleep/`.** Confirmed by:
```
$ strings /usr/lib/systemd/systemd-sleep | grep system-sleep
/usr/lib/systemd/system-sleep
```
Only one path is compiled into the binary. The man page for v260 also only documents `/usr/lib/systemd/system-sleep/`. Either Arch's old behavior of also scanning `/etc/` was patched away upstream, or it never worked and we'd been mistaken about it the whole time.

**This invalidates the older claim in `memory/project_nvidia_hibernate_fix.md` that the fuse-mounts hook was the fix for FUSE freezer failures.** The hook was correctly written but symlinked into `/etc/systemd/system-sleep/`, so it never ran. The reason the FUSE freezer failures stopped happening earlier today is solely the `SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=true` cgroup-freezer override; FUSE services are still active during sleep but the cgroup freezer pauses their consumers cleanly so it doesn't matter.

**Action taken:**
- Updated `Makefile system-install` target to symlink both `fuse-mounts` and `hyprlock-restart` into `/usr/lib/systemd/system-sleep/` instead of `/etc/`. Old `/etc/` symlinks are removed by the same target.
- Wrote `/tmp/hsperfdata_jaeho/relocate-sleep-hooks.sh` to perform the move without re-running the full system-install.

**Status overall:**
- Nvidia hibernate-resume fix: resolved (verified).
- FUSE freezer issue: resolved (verified, but the credit belongs to the cgroup freezer override, not the fuse-mounts hook).
- hyprlock GL-context crash on resume: **fix re-staged with hook now in the actually-scanned path; awaiting next hibernate cycle to verify.** After the next cycle, check `/var/log/hyprlock-restart.log` — if it exists at all, the hook ran. If it shows the fallback's "direct spawn pid: NNNN" with a hyprlock that didn't immediately crash, we have a working lockscreen recovery.

---

## 2026-04-15 — Black screen hang during hibernation entry, hard reboot (lid-close s-t-h)

**Trigger:** Lid close ~05:25 EDT → `systemd-logind` started `suspend-then-hibernate` (logind.conf still has `HandleLidSwitch=suspend-then-hibernate` — the "Still TODO" from 2026-04-12 entry below, never fixed).

**Timeline (journalctl -b -1):**
- 05:25:21 first s-t-h attempt failed immediately: `Failed to put system to sleep. System resumed again: Device or resource busy`. Logind retried.
- 05:25:22 second attempt entered s2idle. NVRM GSP heartbeat already dead (nvidia-open ignores `EnableGpuFirmware=0`).
- 05:29–05:31 five consecutive `Freezing user space processes failed after 20 seconds (8 tasks refusing to freeze)` cycles. The 8 D-state tasks were all named `fd`, pids 2049136–43, parent 2049122 (long gone; looks like a Node/Bun worker pool — not FUSE this time, so the `fuse-mounts` hook wouldn't have helped).
- 06:31:19 `HibernateDelaySec=1h` fired. This time `Freezing user space processes completed (elapsed 0.008 seconds)` — the busy tasks had exited during the hour of s2idle.
- 06:31:21 `PM: hibernation: hibernation entry` — **log ends here.** No further kernel messages. Hibernate image write hung (consistent with nvidia-open GSP dead → `nv_pmops_freeze` can't snapshot VRAM).
- 11:54:42 next boot (cold) after hard power cycle. ~5h gap.

**Diagnosis:** Same root cause as 2026-04-12 — nvidia-open 595.58.03-3 silently ignores `NVreg_EnableGpuFirmware=0`, GSP heartbeat dies in s2idle, hibernate can't freeze the GPU. The proprietary `nvidia` package is still not in Arch repos (`pacman -Si nvidia` → not found), so the module-swap fix is still blocked. Hypridle correctly uses `systemctl hibernate` (direct), but **lid close goes through logind**, which was never updated to `hibernate`, so it still routes through the broken s-t-h path.

**Action taken:** Wrote `/tmp/hsperfdata_jaeho/fix-lid-switch.sh` that installs `/etc/systemd/logind.conf.d/10-lid-hibernate.conf` (drop-in) setting both `HandleLidSwitch=hibernate` and `HandleLidSwitchExternalPower=hibernate`, then reloads logind. **User ran it.** This then caused the 15:37 incident below — lid close now routes to `hibernate`, which turns out to be broken in a different way (resume path).

---

## 2026-04-15 (afternoon) — Hibernate resume fails, `nv_pmops_freeze returns -5`, black screen, hard shutdown

**Trigger:** After running the lid-switch fix above, lid close at ~15:34 EDT went through `systemctl hibernate` (direct, not s-t-h). Hibernate image written successfully (system powered off cleanly at 15:34:33 — bluetooth + tailscale teardown visible). On next power-on at 15:37:57, resume was attempted (`resume=UUID=89dd1d02-665b-4012-ba34-a5deaddd1d2d` in kernel cmdline) and failed.

**Key log excerpt (boot -1, `journalctl -b -1 -k -g 'nvidia|PM:|modules-load'`):**
```
15:37:57 NVRM: loading NVIDIA UNIX Open Kernel Module for x86_64  595.58.03
15:38:20 [drm] Initialized nvidia-drm 0.0.0 for 0000:2b:00.0 on minor 1
15:38:20 NVRM: GPU 0000:2b:00.0: PreserveVideoMemoryAllocations module parameter is set.
         System Power Management attempted without driver procfs suspend interface.
15:38:20 nvidia 0000:2b:00.0: PM: pci_pm_freeze(): nv_pmops_freeze [nvidia] returns -5
15:38:20 nvidia 0000:2b:00.0: PM: failed to quiesce async: error -5
15:38:20 PM: hibernation: Failed to load image, recovering.
15:38:20 systemd-modules-load[178]: Failed to insert module 'nvidia_drm': Interrupted system call
15:38:20 systemd: Failed to start Load Kernel Modules.
```

Second `Load Kernel Modules` invocation ran at 15:38:22 and succeeded, but by then the user had seen the red "Failed to start Load Kernel Modules" line and assumed the system was hung; clean `systemd-poweroff` initiated at 15:39:00 (ACPI power button).

**Diagnosis:** The procfs interface `/proc/driver/nvidia/suspend` is how `nvidia-sleep.sh` tells the driver to stash/restore VRAM. On HIBERNATE, `nvidia-hibernate.service` runs in userspace before sleep and prepares it. On RESUME, the kernel calls `pci_pm_freeze` on the boot kernel's nvidia devices BEFORE the hibernate image is loaded — i.e. before any userspace at all has run — so the procfs interface is unprepared. With `NVreg_PreserveVideoMemoryAllocations=1`, the driver rejects freeze with -5 and the kernel gives up on the image.

This is a fundamental ordering bug in the nvidia-open hibernate flow: hibernate WRITE works (userspace helper runs first), hibernate RESUME does not (kernel freezes before userspace exists). Every resume attempt will fail the same way until either (a) proprietary `nvidia` is installed (not currently in repos), or (b) something runs `echo resume > /proc/driver/nvidia/suspend` from initramfs before the kernel's resume path freezes devices.

**Further finding (investigation):** `/proc/driver/nvidia/suspend` **does not exist on this system**. `ls /proc/driver/nvidia/` shows `suspend_depth` but no `suspend`. `nvidia-open 595.58.03` does not expose that procfs file — only the proprietary driver does. Consequently `nvidia-sleep.sh` short-circuits at its top:

```sh
if [ ! -f /proc/driver/nvidia/suspend ]; then
    exit 0
fi
```

Every `nvidia-{suspend,hibernate,resume,suspend-then-hibernate}.service` unit therefore exits 0 without doing anything. `NVreg_PreserveVideoMemoryAllocations=1` tells the driver to expect userspace to prepare state via that procfs file before any kernel PM freeze — that precondition can never be met on nvidia-open, so `nv_pmops_freeze` returns -5 whenever the kernel tries to freeze the nvidia device. Worst on RESUME (boot kernel has no userspace yet), sometimes also on WRITE.

Parts of `memory/project_nvidia_hibernate_fix.md` are obsolete on this driver stack: enabling those nvidia-*.service units is a no-op. The April 9–11 fixes succeeded by accident (FUSE-mounts hook unblocked the freezer; proprietary driver was still in use at the time).

**Validated fix (community-tested, Arch forum + NVIDIA issue tracker):** disable early KMS for nvidia only. Keep `xe` (iGPU) early-loaded so the console still works, but remove nvidia from `MODULES=` so the boot kernel never has an nvidia driver attached when it runs `pci_pm_freeze` during resume. Also remove `NVreg_PreserveVideoMemoryAllocations=1` since it's actively harmful on nvidia-open.

Sources:
- [Arch Forum: nvidia-resume from hibernation not working with early KMS enabled (post #8)](https://bbs.archlinux.org/viewtopic.php?id=285508)
- [NVIDIA open-gpu-kernel-modules #922 — Hybrid Intel+NVIDIA laptop hibernate fails](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/922)

**Action taken:**
- Edited `mkinitcpio/mkinitcpio.conf`: `MODULES=(xe nvidia nvidia_modeset nvidia_uvm nvidia_drm)` → `MODULES=(xe)`. `nvidia_drm.modeset=1` on the kernel cmdline still enables KMS; it just happens slightly later via udev once the dGPU is detected, and the panel is driven by the iGPU on this laptop so there's no visible late-load gap.
- Edited `modprobe/nvidia.conf`: removed `options nvidia NVreg_PreserveVideoMemoryAllocations=1`. Comment in file explains why. Trade-off: GPU application VRAM contents are lost across hibernate, so Hyprland / Firefox / etc may have to reinitialise GL contexts on resume; some may crash and need relaunching. In exchange, the machine actually resumes.
- Wrote `/tmp/hsperfdata_jaeho/safe-lid-lock.sh`: immediate safety — rewrites the lid drop-in to `HandleLidSwitch=lock` + `HandleLidSwitchExternalPower=lock` so lid close does not trigger the still-broken hibernate until the fix is installed and verified.
- Wrote `/tmp/hsperfdata_jaeho/install-nvidia-hibernate-fix.sh`: runs `make system-install` then `mkinitcpio -P`, verifies nvidia is absent from the new initramfs.

**Verification (2026-04-16, same boot — no reboot was needed):** Nvidia fix confirmed working *on the one cycle that completed*, but a separate FUSE freezer issue caused 6 of 7 hibernate attempts to abort. Triggers were all hypridle's 30-min idle timer firing `systemctl hibernate`; no suspend/s2idle cycles today.

```
Apr 16 04:45:24 entry → 04:45:46  FAILED  (3 tasks refusing to freeze: fuse_dentry_revalidate, fuse_lookup_name)
Apr 16 06:21:23 entry → 06:21:45  FAILED  (FUSE __fuse_simple_request, fuse_readdir_uncached)
Apr 16 07:37:33 entry → 07:37:55  FAILED  (FUSE)
Apr 16 08:40:45 entry → 08:41:08  FAILED  (FUSE)
Apr 16 09:36:40 entry → 09:37:02  FAILED  (FUSE fuse_dir_open, fuse_send_open)
Apr 16 10:21:22 entry → 10:21:44  FAILED  (FUSE)
Apr 16 17:27:28 entry → 17:44:25  SUCCESS — 17 min offline, ACPI S4 reached, clean hibernation exit
```

The kernel `hibernation entry` / `hibernation exit` markers bracket the *attempt*, not the off period — on failure, `exit` comes ~22 s later when the freezer gives up, followed by `systemd-sleep: Failed to put system to sleep. System resumed again: Device or resource busy` and `systemd-hibernate.service: Failed with result 'exit-code'`.

**Two distinct findings from today:**

1. **Nvidia hibernate-resume fix works.** On the 17:27 cycle: no `nv_pmops_freeze returns -5`, no failed image load, `journalctl -b 0 -k -g 'nv_pmops_freeze|returns -5|Failed to load image'` returns nothing, ACPI S4 was actually entered (`ACPI: PM: Preparing to enter system sleep state S4` then `ACPI: PM: Waking up from system sleep state S4` 17 min later). `/etc/mkinitcpio.conf` has `MODULES=(xe)`, `/etc/modprobe.d/nvidia.conf` has no `PreserveVideoMemoryAllocations`, initramfs contains only `xe.ko`. Boot counter didn't increment — hibernate-resume restores the same kernel instance, which is correct. **No clean reboot was ever needed**: the install script's `mkinitcpio -P` produced the new initramfs on disk, and the resume path used it.

2. **FUSE freezer regression — root cause: nvidia-utils disables the systemd cgroup freezer for user sessions.** Investigation:

   The kernel call trace from each failed attempt names the offending task:
   ```
   task:find    state:D    pid:2262012   ppid:2262010
     vfs_statx → path_lookupat → lookup_slow → fuse_lookup → fuse_lookup_name → __fuse_simple_request
   ```
   Some `find` invocation walked into a FUSE mount and was stuck in `request_wait_answer` when the kernel freezer ran. The fuse-mounts hook *is* installed and executable (`ls -lL /etc/systemd/system-sleep/fuse-mounts` confirms), but the find process was not paused beforehand because of an unrelated nvidia-utils setting:

   ```
   $ pacman -Qo /usr/lib/systemd/system/systemd-hibernate.service.d/10-nvidia-no-freeze-session.conf
   ... is owned by nvidia-utils 595.58.03-2
   $ cat /usr/lib/systemd/system/systemd-hibernate.service.d/10-nvidia-no-freeze-session.conf
   [Service]
   Environment="SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false"
   ```
   That drop-in disables systemd's cgroup-based freezing of user sessions before sleep. It exists for the proprietary nvidia driver's procfs suspend interface (`/proc/driver/nvidia/suspend`), which doesn't exist on nvidia-open. Result on this machine: user processes (the rogue `find`) stay runnable up until the kernel freezer pass, where they hit the FUSE D-state wall and refuse to freeze. The systemd-sleep dispatcher even prints the warning each time:
   ```
   systemd-sleep: User sessions remain unfrozen on explicit request ($SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=0).
                  This is not recommended, and might result in unexpected behavior...
   ```
   The fuse-mounts hook can't compensate: it stops the FUSE services, but if some user process is *already* mid-FUSE-call when the hook runs, that task is in D-state until the FUSE backend (sshfs/rclone) responds — and that backend was just stopped, so the request never gets answered.

**Action taken:** Added `systemd/system/systemd-{hibernate,suspend,hybrid-sleep,suspend-then-hibernate}.service.d/20-restore-freeze-session.conf` to the dotfiles repo. Each is a drop-in containing:
```
[Service]
Environment="SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=true"
```
The `20-` prefix sorts after the nvidia `10-` drop-in, so the override wins. Updated `Makefile system-install` target to symlink them into `/etc/systemd/system/<unit>.service.d/`. Wrote `/tmp/hsperfdata_jaeho/install-freeze-session-fix.sh` which installs the symlinks, runs `daemon-reload`, and prints verification.

How this fixes things: with user-session freezing re-enabled, systemd freezes the entire `user-1000.slice` cgroup (including any `find` and the FUSE backend processes) cleanly before invoking the kernel freezer. Pending FUSE requests don't get answered during the cgroup freeze, but they also don't matter — the requesters are already in TASK_FROZEN, not D-state, so the kernel freezer pass succeeds.

**Status:**
- Nvidia hibernate fix: **resolved.**
- FUSE freezer issue: **fix staged, not yet verified.** User needs to run the install script and exercise a hibernate cycle.

**Verification plan:**
1. User runs `bash /tmp/hsperfdata_jaeho/install-freeze-session-fix.sh`.
2. Confirm `systemctl show systemd-hibernate.service -p Environment` shows `SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=true` (overriding the nvidia drop-in).
3. Test: `systemctl hibernate`, wake the machine, check `journalctl -b 0 -k -g 'Freezing user space|hibernation entry|hibernation exit'`. Expected: no `tasks refusing to freeze`, paired entry/exit with non-trivial offline gap.
4. Optional follow-up: if the fix holds for several real hibernate cycles, revert the lid-switch drop-in from `lock` back to `hibernate`.

**Follow-ups:**
1. Run the verification cycle above and append result.
2. Revisit proprietary `nvidia` availability periodically — if it returns, the nvidia drop-ins become legitimate and these overrides can be removed.

---

## 2026-04-12 — Failed hibernate resume (cold boot instead of resume)

**Trigger:** hypridle suspend-then-hibernate at 01:35, transitioned to hibernate at 02:35 after 1h s2idle. Next boot at 15:01 showed `PM: Image not found (code -22)` — no hibernate image to resume, so cold boot.

**Logs (previous boot, just before failure):**
```
02:35:05 Freezing user space processes completed (elapsed 0.004 seconds)   # FUSE fix working
02:35:06 NVRM: _kgspIsHeartbeatTimedOut: ... heartbeat 0 ... diff 2154213569 timeout 5200
02:35:06 NVRM: _kgspRpcRecvPoll: GSP RM heartbeat timed out
02:35:07 PM: suspend exit
02:35:07 PM: hibernation: hibernation entry
(log ends — kernel never made it to writing the image)
```

**Diagnosis:** `nvidia-open 595.58.03-2` is installed. The open kernel module **requires GSP firmware** — it has no non-GSP code path. `NVreg_EnableGpuFirmware=0` is accepted and shows `0` in `/proc/driver/nvidia/params`, but silently ignored. GSP dies during s2idle (`heartbeat 0` = never sent any heartbeats after wake), so when systemd wakes the system to transition to hibernate, nvidia can't freeze the GPU and the hibernate image write fails.

**Blocker on the obvious fix:** Arch dropped the proprietary `nvidia` package for 595.x. `pacman -S nvidia` → `target not found`. Only `nvidia-open`, `nvidia-open-dkms`, `nvidia-open-lts` exist in repos. AUR doesn't have a proprietary replacement either. Hardware only supports `[s2idle]` (no S3 deep sleep) so can't route around the GPU staying partially powered during suspend.

**Action taken:**
- Changed hypridle `on-timeout` from `systemctl suspend-then-hibernate` → `systemctl hibernate` (`hypr/.config/hypr/hypridle.conf`). Direct hibernate avoids s2idle entirely: image is written while GPU is alive.
- **Still TODO:** `/etc/systemd/logind.conf` still has `HandleLidSwitch=suspend-then-hibernate` and `HandleLidSwitchExternalPower=suspend-then-hibernate`. Lid close goes through logind, not hypridle, so lid close still triggers the failing path. Needs sudo edit to change both to `hibernate`.

---

## 2026-04-09 → 2026-04-11 — Repeated hibernate failures (4 root causes)

**Symptoms across the period:**
- "Freezing user space processes failed after 20 seconds (N tasks refusing to freeze)"
- `NVRM: _kgspRpcRecvPoll: GSP RM heartbeat timed out` loops
- Hibernate resume: `nv_pmops_freeze [nvidia] returns -5` → `PM: hibernation: Failed to load image, recovering`
- Black screen on wake from suspend-then-hibernate, hard reboots required
- Kernel stopped logging mid-session (hard hang, no panic written)

**Four root causes fixed together:**
1. GSP firmware unstable across sleep — added `options nvidia NVreg_EnableGpuFirmware=0` to `/etc/modprobe.d/nvidia.conf` (turned out to be a no-op on nvidia-open; see 2026-04-12)
2. `nvidia-suspend-then-hibernate.service` is a separate unit from nvidia-{suspend,hibernate,resume}.service — had to `systemctl enable nvidia-suspend-then-hibernate.service`
3. `/boot/initramfs-linux.img` wasn't being regenerated after modprobe.d edits — `mkinitcpio -P`
4. FUSE mounts (sshfs, rclone) stalled the kernel freezer — added `systemd/system-sleep/fuse-mounts` hook to stop user FUSE services before sleep and restore after

See `memory/project_nvidia_hibernate_fix.md` for full details and verification commands.
