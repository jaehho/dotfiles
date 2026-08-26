# System Issues Log

Persistent record of failures on `omnibook` (HP OmniBook 17, Lunar Lake + RTX 4050 Max-Q): boot, sleep/hibernate, and package-management breakage.

Two parts. **Recurring failures** is what to read when something that worked last month breaks today — each entry is a known trap with a fix to copy. **Incident log** is dated history, newest first; each entry: date, symptom, what the logs showed, what was done.

---

# Recurring failures

## `make sync`: nvidia beta upgrade deadlocks paru

**Symptom:** the `arch` phase fails — three identical times, since paru retries — with

```
error: failed to prepare transaction (could not satisfy dependencies)
:: installing nvidia-utils-beta (NEW) breaks dependency
   'nvidia-utils-beta=OLD' required by nvidia-beta-dkms
```

**Not a real conflict.** `nvidia-beta-dkms`'s `.SRCINFO` pins `nvidia-utils-beta=<pkgver>` exactly. paru installs a built AUR dependency *before* building its dependent, so it tries to install the new utils while the old dkms package still demands the old utils — and never gets as far as building the new dkms. Recurs on every bump where both packages move.

**Fix** — build the dkms package with dependency resolution off, then install the whole set in one transaction (paru has already built the utils set by the time it dies, so only dkms is missing):

```bash
cd ~/.cache/paru/clone/nvidia-beta-dkms
makepkg -df --noconfirm --nocheck

sudo pacman -U \
  ~/.cache/paru/clone/nvidia-beta-dkms/nvidia-beta-dkms-<VER>-x86_64.pkg.tar.zst \
  ~/.cache/paru/clone/nvidia-utils-beta/nvidia-utils-beta-<VER>-x86_64.pkg.tar.zst \
  ~/.cache/paru/clone/nvidia-utils-beta/opencl-nvidia-beta-<VER>-x86_64.pkg.tar.zst \
  ~/.cache/paru/clone/nvidia-utils-beta/nvidia-settings-beta-<VER>-x86_64.pkg.tar.zst
```

Reboot after (the module and the userspace libs are only in sync again post-reboot), then re-run `make sync` — the arch drift check skips itself on any run where install failed.

**The exit, if this stops being worth it:** the 2026-04-20 entry below says to leave DKMS "if proprietary nvidia returns to `extra/`". It hasn't, and won't — `extra/` ships only `nvidia-open*` now. The only way off the AUR is accepting the open modules, which is what the April suspend failures were about.

## `make sync`: global cargo tools stop building

**Symptom:** the `cargo` phase fails with `requires rustc X or newer, while the currently active rustc version is Y`.

**Cause:** Arch's `rustup` package updates the installer, never the toolchain — `stable` sits at whatever version it was installed at while crates raise their MSRV. It drifted three releases (1.94 → 1.97) before biting.

**Fix:** handled in `scripts/packages.sh` — the cargo upgrade step runs `rustup update` first.

## `nextcloud.wonhomelab.net` unreachable on the home LAN

**Symptom:** browser and `curl` fail outright — `Failed to connect`, `No route to host` — while the server is fine from anywhere else. `ping` the pinned IP gives `Destination Host Unreachable` and `ip neigh` shows it `FAILED` (ARP never resolves).

**Cause:** a hand-written split-horizon override in `/etc/hosts`

```
192.168.1.42	nextcloud.wonhomelab.net # reel: nextcloud LAN override
```

It was added to dodge a NAT-hairpin problem: LAN clients reaching the name via the router's WAN IP used to get the router's snakeoil cert instead of the real one. That is **no longer true** — the hairpin now serves the valid Let's Encrypt `*.wonhomelab.net` cert. Meanwhile the server left `192.168.1.42`, so the override points at nothing. The workaround outlived the problem and became the outage.

**Check before assuming DNS or the server is at fault** — this separates a dead LAN pin from a genuinely down service:

```bash
getent hosts nextcloud.wonhomelab.net          # what the pin forces
curl -sS --resolve nextcloud.wonhomelab.net:443:24.47.180.85 \
  -o /dev/null -w '%{http_code} ssl_verify=%{ssl_verify_result}\n' \
  https://nextcloud.wonhomelab.net/status.php  # real path, strict cert check
```

`200 ssl_verify=0` means the server and cert are healthy and only the pin is wrong.

**Fix:** delete the override line from `/etc/hosts` and let public DNS answer (`24.47.180.85`). Nothing in this repo writes that line — it is a manual edit, so `make sync` will not bring it back.

**Do not re-add a static pin.** If hairpin ever regresses, fix it at the router with split-horizon DNS so every device on the LAN benefits, rather than pinning one IP in one machine's `/etc/hosts` — that is what silently rotted here.

## Cooper `conway`/`ice00`: REMOTE HOST IDENTIFICATION HAS CHANGED

**Symptom:** `ssh conway` (or `ice`) refuses with `Host key verification failed`, and `sshfs-conway.service` sits in a restart loop logging `read: Connection reset by peer`.

**Do not just `ssh-keygen -R` and reconnect.** Cooper auth is a *plaintext password* (`sshpass -f ~/.ssh/jump_pass`, see `ssh/.ssh/config`), so accepting a forged key hands over the account on the first connect. Pubkey auth would fail safe here; password auth does not.

Two traps specific to these hosts:

- **`conway` and `ice00` used to share one host key set** — imaged from a common template, so a fingerprint matching across both proved nothing and a rotation hit both at once. **This stopped being true on 2026-08-23**, when conway rotated alone and ice00 kept the 2026-08-17 keys. Check both before assuming, and re-pin only the host that actually moved: needlessly clearing the other throws away a known-good pin. The divergence also makes the unchanged host a useful control — if only one moved, the problem is not your `known_hosts`.
- **The warning names one offending line, but more are stale.** `ssh` reports whichever key type it negotiated; the others are usually stale too. Remove by host (`ssh-keygen -R "[host]:31415"` clears all types) rather than deleting the cited line number.

**Fix** — verify the fingerprint over a second network path before trusting it. The script stops the mount loop, scans over the current network, waits while you switch to a phone hotspot, re-scans, and only re-pins if both paths agree:

```bash
bash /tmp/fix-conway-hostkey.sh            # guided two-path check
bash /tmp/fix-conway-hostkey.sh --verified # skip it, if Cooper IT confirmed the fingerprint
```

Regenerate that script by asking Claude, or do it by hand:

```bash
systemctl --user stop sshfs-conway.service sshfs-conway-watchdog.timer
ssh-keyscan -p 31415 conway.ee.cooper.edu | ssh-keygen -lf -   # compare over 2 paths
ssh-keygen -R "[conway.ee.cooper.edu]:31415"
ssh-keygen -R "[ice00.ee.cooper.edu]:31415"
ssh-keyscan -p 31415 conway.ee.cooper.edu ice00.ee.cooper.edu >> ~/.ssh/known_hosts
systemctl --user start sshfs-conway-watchdog.timer sshfs-conway.service
```

Matching fingerprints from two independent paths rules out interception near you, not at Cooper's edge — if the stakes ever rise, get the fingerprint from the EE sysadmin instead.

**Rotation history:**

- **2026-08-17** — both hosts, all three key types at once (OpenSSH 8.0, RHEL-family), consistent with a re-image. Verified over home ISP + cellular.
- **2026-08-23** — **conway only**, all three types; ice00 still serves the 2026-08-17 set. Found because `sshfs-conway.service` had looped 435 restarts (~120 failures/hour) since roughly 10:00 that day.

  ```
  key      pinned 2026-08-17   conway now      ice00 now
  RSA      bKqjCGVn...ohgo     IREj0O7G...kgOY  bKqjCGVn...ohgo
  ECDSA    MZBj7tCg...gczc     1wUFOrOy...oMkw  MZBj7tCg...gczc
  ED25519  YybSGkTt...wIuk     kP1YalCw...UBsA  YybSGkTt...wIuk
  ```

  **Explained by an EEAdmin notice (Thu 2026-08-20 08:52, "ICE System Updates"):**
  ice00-12 and conway were migrated CentOS 7 -> Rocky Linux 8. The migration is
  staggered, which is why hosts change on different days and why the old shared
  key set is breaking up — rebuilt hosts generate their own keys, in-place
  upgrades keep the template ones. As of 2026-08-25 every host answers
  `SSH-2.0-OpenSSH_8.0` (Rocky 8; CentOS 7 shipped 7.4), and conway, ice00 and
  ice03 all serve *different* key sets. Expect the remaining shared pins to
  diverge as the rollout continues.

**Verifying a rotation using a published sibling fingerprint.** The notice quoted
a fingerprint for one host (ice03, ED25519
`SHA256:XNYw3U/hTEfXLtElzR+kqrDJhcIyv3y8DVNReIhrjIQ`). Scanning that host and
comparing is a *better* check than the two-path hotspot dance, because it
compares what you see against an independently published value rather than
against a second observation of your own:

```bash
timeout 25 ssh-keyscan -p 31415 ice03.ee.cooper.edu | ssh-keygen -lf -
```

A match proves your path to `*.ee.cooper.edu:31415` returns genuine keys. It is
not proof for a *different* host — an attacker could pass ice03 through and forge
only conway — but combined with an announcement that explains the change, it
clears the bar. Use `--verified` in that case. With no published fingerprint for
any host, fall back to the two-path check.

**Re-pinned 2026-08-25:** conway (`--verified`, mount healthy again after 435
failed restarts) and ice03 (its pin was stale too, and its live ED25519 matched
the published fingerprint exactly — direct verification, the strongest case of
the three). ice00 still serves its 2026-08-17 keys and was left alone.

**Gotcha: `ssh-keyscan` writes `# host:port SSH-2.0-...` banner lines to STDOUT**,
not stderr. Piping it straight into `known_hosts` appends those as comments —
harmless, since `#` is ignored, but they accumulate a few per host per rotation
and make any `grep -c` count of "keys" wrong. Filter with `grep -v '^#'` when
appending, and count real entries with `grep -c '^\['`.

**Do not try to replace the password with an SSH key.** Investigated 2026-08-18; it cannot work from off campus:

- Home is AFS (`/afs/ee.cooper.edu/user/j/jaeho.cho`). sshd runs as root with no AFS token, so it cannot read `~/.ssh/authorized_keys` — pubkey auth fails before it starts. Granting `fs setacl ~ system:anyuser l` + `fs setacl ~/.ssh system:anyuser rl` makes it readable, at the cost of exposing home-dir filenames cell-wide.
- Even then, a pubkey session gets **no AFS token**, so it cannot read your own home. The password is not just an auth method here: PAM turns it into a Kerberos ticket and runs `aklog`. A key cannot do that.
- GSSAPI would be the right answer, but the FreeIPA realm `EE.COOPER.EDU` declares no KDC in `[realms]` and relies on internal SRV records that do not resolve off campus (`_kerberos._udp.ee.cooper.edu` → NXDOMAIN).

**Beware a false positive when testing this.** sssd-kcm caches credentials per-user per-machine, so shortly after a password login a pubkey session inherits the live cache and looks like it works. Check `klist` — if the cache ID matches the earlier password session (e.g. both `KCM:5340:80342`), the token is borrowed and dies with it. Test on a host you have not password-logged into recently.

**Conclusion:** `sshpass` + `~/.ssh/jump_pass` stays. What actually mitigates the risk is the host-key pinning above plus `StrictHostKeyChecking` defaulting to `ask` — the `no` in `/etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf` is scoped to `unix/*`/`vsock/*`/`machine/*` and does not apply to these hosts.

---

## Dock: keyboard/mouse dead after resume, monitors and ethernet fine

The Anker 364 exposes two independent USB trees: a SuperSpeed path (`usb 2-1`,
ethernet + SD reader) and a USB 2.0 path (`usb 3-1`, keyboard/mouse/MST). They
fail separately. On resume `ucsi_acpi` can time out re-arming EC notifications
(`failed to re-enable notifications (-110)`), the 2.0 lane never renegotiates,
and the dock latches that state across a host reboot — it only clears on full
power loss to the dock.

If input is dead but the screens and ethernet work, in order:
1. Unplug the USB-C cable at the laptop, wait ~10 s, replug.
2. Still dead: pull the dock power too (USB-C PD cable out at both ends).
3. PD partner present in `/sys/class/typec/port0/port0-partner` but no USB
   devices appearing: flip the cable orientation or use the other port.

Confirm before generalizing:
`journalctl -b -1 -k -g 'ucsi|typec|usb 3-1|usb 2-1'` — the signature is the
`-110` plus no `3-1` re-enumeration anywhere after `PM: suspend exit`.

---

## USB hotplug stops working after a kernel upgrade (no reboot yet)

A device enumerates but binds no driver, and udev retries in a loop that looks
like the device is flapping. `modinfo usb-storage` says `Module not found`.

Arch removes `/lib/modules/<oldver>/` the moment `linux` is upgraded, so the
running kernel can no longer modprobe anything it had not already loaded. Any
hotplug needing a new module fails silently until reboot — USB storage,
unusual filesystems, bluetooth.

Check: `uname -r` against `pacman -Q linux` and `ls /lib/modules/`. The fix is
a reboot; there is no runtime workaround.

---

## Laptop dead in the morning, "it died in sleep"

**It probably did not die in sleep.** Check whether it was ever asleep for that
whole window:

```bash
journalctl -k -g 'PM: suspend (entry|exit)|PM: hibernation' --since '-2 days'
awk '$1>'"$(date -d '2 days ago' +%s)" /var/lib/upower/history-rate-FZ06083XL-83-1152.dat \
  | awk '{print strftime("%m-%d %H:%M", $1), $2" W"}'
```

A `suspend exit` with no matching re-entry, followed by hours of ~13 W samples
in the upower log, means it **woke and stayed awake**, not that s2idle is
leaky. s2idle on this box costs roughly 1 %/h; awake-with-screen-off costs
~13 W, which flattens a full battery in about five hours.

**Why it can happen:** there is exactly one automatic path back to sleep, the
30-min hypridle listener in `hypr/.config/hypr/hypridle.conf`. logind
`IdleAction` is `ignore`, and the lid switch cannot re-fire while the lid is
already open. If hypridle is dead or its config failed to parse, nothing
sleeps the machine.

```bash
pgrep -a hypridle || setsid hypridle &   # must be running
loginctl show-session $XDG_SESSION_ID -p IdleHint -p IdleSinceHint
```

**Then check the drain is not itself the bug:** ~13 W idle with the panel off
is high for Lunar Lake. `/tmp/measure-idle-power.sh` (see the 2026-08-18 entry)
attributes it between CPU package, dGPU, and the rest of the board.

## Hibernate resumes into a cold boot (session lost, looks like a shutdown)

**Symptom:** you hibernated, and the machine came back on a fresh desktop with
everything gone. It looks identical to a power-off, so it gets misread as "it
died" or "I must have shut down".

```bash
journalctl -b 0 -k -g 'Image successfully loaded|nv_pmops_freeze|resume failed'
```

If the image *loaded* and then the handoff died, you will see:

```
PM: Image successfully loaded
NVRM: GPU 0000:2b:00.0: PreserveVideoMemoryAllocations module parameter is set.
      System Power Management attempted without driver procfs suspend interface.
nvidia 0000:2b:00.0: PM: pci_pm_freeze(): nv_pmops_freeze [nvidia] returns -5
PM: hibernation: Failed to load image, recovering.
PM: hibernation: resume failed (-5)
```

Hibernating is fine; only the resume side breaks. Nothing is wrong with the
image (it reads back at ~2 GB/s), and the swap/`resume=` setup is fine.

**Cause:** nvidia is in `MODULES=` in `mkinitcpio.conf`. With
`NVreg_PreserveVideoMemoryAllocations=1`, the driver requires userspace to
prime `/proc/driver/nvidia/suspend` before any kernel PM freeze. On the resume
side no userspace has run yet — the boot kernel loads the image and must freeze
devices to hand off — so a dGPU bound in the initramfs refuses to freeze and
the kernel throws the image away.

**Fix:** `MODULES=(xe)` in `mkinitcpio/mkinitcpio.conf`, then `sudo mkinitcpio -P`.
nvidia loads from the real root after switch-root; `nvidia-drm.modeset=1` still
applies, and the panel is on the iGPU so late loading costs nothing.

**This has regressed once already.** It was fixed in April 2026, then commit
`30be42a` ("migrate to proprietary nvidia") put nvidia back, on the reasoning
that proprietary exposes the procfs interface so early-KMS was safe again. That
covers the hibernate side only. Do not re-add it — the comment above `MODULES=`
in the repo says so.

**Keep `NVreg_PreserveVideoMemoryAllocations=1`.** On proprietary nvidia the
procfs interface exists and `nvidia-sleep.sh` works, so VRAM survives sleep.
Only the initramfs binding has to go. (April also removed the parameter, but
that was for nvidia-open, where the interface never exists at all.)

## logind ignores its drop-in (and `cat-config` lies about it)

**Symptom:** `/etc/systemd/logind.conf.d/10-lid.conf` sets something,
`systemd-analyze cat-config systemd/logind.conf` shows it applied, and logind
behaves as though the file does not exist.

```bash
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager HandleLidSwitch
```

If that disagrees with the file, the file is not reaching logind.

**Cause:** `systemd-logind.service` runs `ProtectHome=yes` + `ProtectSystem=strict`,
so `/home` is an empty tmpfs inside its mount namespace. A drop-in symlinked to
`/home/jaeho/dotfiles/...` dangles in there and logind skips it without logging
anything. `systemd-analyze` is not sandboxed, so it happily resolves the link —
which is why this reads as a systemd precedence bug and is not one.

Prove it in one command:

```bash
systemd-run --quiet --pipe --property=ProtectHome=yes --property=ProtectSystem=strict \
    -- /bin/sh -c 'cat /etc/systemd/logind.conf.d/10-lid.conf'
# -> No such file or directory, while a plain `cat` works fine
```

**Fix:** the destination must be a real root-owned file. `10-lid.conf` lives in
`SYSTEM_INSTALLS` in `scripts/lib.sh` for exactly this reason (same class as
`reflector.conf` in `SYSTEM_COPIES`). Re-run `./scripts/sync.sh system`, or
`/tmp/fix-logind-lid.sh`.

**Applying it afterwards:** `systemctl reload systemd-logind` is safe *and*
sufficient — verified 2026-08-18, it set both `HandleLidSwitch` and
`HandleLidSwitchExternalPower` correctly the moment the file was readable.
`make sync` does the reload for you.

The older belief that "SIGHUP only partially re-reads properties, so you need a
restart" (2026-04-21) was a misreading of this same bug: the drop-in was
invisible, so `HandleLidSwitchExternalPower` reported empty because it was
genuinely unset, not because reload half-worked. **Do not
`systemctl restart systemd-logind` to force it** — that kills the Hyprland
session, as it did on 2026-08-18, dropping the user to tty1
(`Leader of session '11' is gone while deserializing`). Reboot if you ever
truly need a fresh logind.

**Which of our files are affected:** only logind. `systemd-{suspend,hibernate,
suspend-then-hibernate}.service` all run `ProtectHome=no`, so `systemd/sleep.conf`
and the `system-sleep/` hooks work fine as symlinks. Before assuming a config is
live, check the consuming unit:
`systemctl show <unit> -p ProtectHome -p ProtectSystem`.

---

# Incident log

## 2026-08-19 — Hibernate resumed into a cold boot; nvidia back in `MODULES` (April regression)

**Trigger:** user asked "check if hibernate worked, i think i shut down". Two
separate hibernations were in play and only one had failed.

**The one that worked (same day, 19:51 → 21:45):** the new sleep policy from the
2026-08-18 entry ran end to end for the first time.

```
19:51:03  woke from s2idle after exactly 1h0m1s   (HibernateDelaySec=1h fired)
19:51:06  PM: hibernation: hibernation entry
21:45:46  PM: hibernation: hibernation exit       (nvidia-resume ran, no NVRM errors)
```

Session survived: Hyprland pid 8664 started 12:21:06 and was still running
afterwards, spanning the hibernation. So s-t-h itself is healthy.

**The one that failed (Aug 18 23:32 → Aug 19 12:18):** hibernate wrote the image
cleanly. The next power-on found it, read all 11 GB back at 1962 MB/s, and then
died on the handoff:

```
12:18:24  PM: Image successfully loaded
12:18:24  NVRM: GPU 0000:2b:00.0: PreserveVideoMemoryAllocations module parameter is set.
                System Power Management attempted without driver procfs suspend interface.
12:18:24  nvidia 0000:2b:00.0: PM: pci_pm_freeze(): nv_pmops_freeze [nvidia] returns -5
12:18:24  PM: hibernation: Failed to load image, recovering.
12:18:24  PM: hibernation: resume failed (-5)
12:18:24  systemd-hibernate-resume: Unable to resume from device ... continuing boot process.
12:18:25  Switching root.
```

Fell through to a normal boot, so the session was lost and it read as a shutdown.

**Diagnosis: a regression of the 2026-04-15 fix, not a new bug.** This is the
identical failure and the identical NVRM message as April. `MODULES=(xe)` fixed
it then; commit `30be42a` ("migrate to proprietary nvidia, lid suspends again")
re-added `nvidia nvidia_modeset nvidia_uvm nvidia_drm` with a comment arguing
that proprietary nvidia exposes `/proc/driver/nvidia/suspend`, so early-KMS was
now correct for hibernate/resume. That argument holds for the hibernate side,
where `nvidia-hibernate.service` runs in userspace first. It does not hold for
the resume side, where no userspace has run at all. The bug went unnoticed for
four months because nothing exercised hibernate-resume until the 2026-08-18
sleep policy started hibernating nightly.

**Why it is intermittent:** it only bites when the resume-side initramfs has the
dGPU bound *and* the driver has VRAM state to preserve. The 21:45 resume the
same evening succeeded on the same initramfs, so a passing resume proves nothing.

**Action taken:**
- `mkinitcpio/mkinitcpio.conf`: `MODULES=(xe nvidia nvidia_modeset nvidia_uvm
  nvidia_drm)` → `MODULES=(xe)`, with a comment recording why it must not be
  re-added a third time.
- `/tmp/fix-hibernate-resume.sh`: backs the working image up to
  `/var/cache/hibernate-fix` (**not** `/boot` — 511M partition, ~170M free,
  and the image was 324M), rewrites `MODULES`, rebuilds, then diffs the old and
  new module lists and rolls back automatically if anything under
  `drivers/{nvme,ata,scsi,block,md,mmc,usb}/`, `fs/`, `crypto/` or `xe.ko`
  disappeared. Dry-run tested against stubs for the happy path, a failing
  `mkinitcpio`, and a rebuild that loses `nvme.ko`.
- Same script adds a `fallback` preset. There was **no recovery image at all**
  on this box — `PRESETS=('default')`. `grub.cfg` was deliberately not
  regenerated; to use the fallback, press `e` at the GRUB menu and point
  `initrd` at `initramfs-linux-fallback.img`.
- Result: default image 324M -> 129M, fallback 195M, /boot down to 157M free.

**Leftover, not yet acted on:** the default image still carries 661
`usr/lib/firmware/nvidia/` GSP blobs — about 100M of the remaining 129M. They
come from **nouveau**, which the `kms` hook pulls in because the RTX matches its
modalias, and nouveau needs those blobs. nouveau is blacklisted in
`/usr/lib/modprobe.d/nvidia-utils-beta.conf` and never loads, so this is pure
dead weight; `i915` is in there too and Lunar Lake uses `xe`. This mkinitcpio
has no `MODULES=(!nouveau)` exclusion syntax, so the only lever is dropping
`kms` from `HOOKS`. That is safe here — `MODULES=(xe)` already pulls xe and its
deps, and `/sys/class/drm/card0` is xe (the dGPU is card1) — and would reclaim
roughly 200M across the two images. Not urgent: mkinitcpio checks free space
and writes straight to the target instead of a temp file when it is tight
(`mkinitcpio:379`), so a low `/boot` degrades rather than failing a kernel
update.

**Kept deliberately:** `NVreg_PreserveVideoMemoryAllocations=1`. April removed it
too, but that was on nvidia-open where `/proc/driver/nvidia/suspend` never
exists. On proprietary 610.57.04 it does exist, `nvidia-sleep.sh` works, and VRAM
preservation is why suspend/resume looks clean. Only the initramfs binding was
the problem.

**Unresolved:** `sshfs-conway.service` fails to start on the intermediate wake
between s2idle and hibernate ("read: Connection reset by peer") because the
network is not up yet; it is stopped again three seconds later for the hibernate.
Harmless but noisy — the resume-side `start` races the network.

---

## 2026-08-18 — Battery flat overnight: woke at 01:17 and never slept again; no idle→sleep path existed

**Trigger:** User reported the machine "keeps dying in sleep" and asked whether
hibernate was set up.

**What the logs showed:**

```
Aug 17 19:08:54  systemd-logind: Lid closed.        → PM: suspend entry (s2idle)
Aug 18 01:17:01  systemd-logind: Lid opened.        → PM: suspend exit
Aug 18 01:17 → 05:04   AWAKE, panel off, steady 13.3 W, 79 % → 2 %
Aug 18 05:04:37  suspend-then-hibernate requested from client PID 3648 ('upowerd')
Aug 18 06:04:41  PM: hibernation entry              (after HibernateDelaySec=1h)
Aug 18 14:11:50  PM: hibernation exit               — clean, 2 s, no NVRM errors
```

The lid open at 01:17 was real (restic and the wallpaper timer fired as
catch-up jobs on resume, then restic died in 6 s on DNS). Battery history
confirms a flat ~13.3 W for the next 3 h 45 m — for comparison, *active* daytime
use that afternoon averaged 10.3 W.

**Diagnosis: hibernate was never the problem; the absence of an idle→sleep path
was.** Three things had to line up:

1. `HandleLidSwitch=suspend` meant lid close bought only s2idle, never hibernate.
2. `hypridle.conf` stopped at dpms-off (15 min). Its trailing comment explicitly
   refused to auto-hibernate — but that rule was written against nvidia-open 595,
   where hibernate was a GSP coin flip. We have run proprietary nvidia with
   `NVreg_EnableGpuFirmware=0` since 2026-04-20; the constraint was stale.
3. logind `IdleAction=ignore`, and a lid switch cannot re-fire while the lid is
   open. So once awake, nothing anywhere would ever sleep the machine again.

The only reason it hibernated at all was upower's critical-battery action at 2 %.
That cycle was *flawless* — which is the useful finding: suspend-then-hibernate
works end to end on the current driver, unprompted, including the hyprlock
restart hook.

**Latent bug found while reading the sleep hooks** — `systemd/system-sleep/fuse-mounts`:

```bash
timeout 10 run_user systemctl --user stop "$svc"   # BROKEN
```

`timeout` is a binary and cannot invoke a shell function. Every sleep since this
was written logged `timeout: failed to run command 'run_user': No such file or
directory` three times, and **the pre-sleep FUSE unmount never once ran** — the
exact condition the 2026-04-18 entry blames for wedging suspend-then-hibernate.
Fixed by hoisting the runuser invocation into a `USER_ENV` array and wrapping
the whole tree: `run_user_t 10 systemctl --user stop "$svc"`.

**Changes made:**

- `systemd/system-sleep/fuse-mounts` — fixed the `timeout`-on-a-function bug;
  added a 15 s cap on the resume-side `start` for the same failure mode.
- `systemd/logind.conf.d/10-lid.conf` — `HandleLidSwitch=suspend-then-hibernate`
  on battery; `HandleLidSwitchExternalPower=suspend` on AC.
- `systemd/sleep.conf` — added `HibernateOnACPower=no`, so the 1 h countdown
  only runs unplugged and closing the lid while docked just stays suspended.
- `hypr/.config/hypr/hypridle.conf` — new 1800 s listener, battery-gated:
  `grep -qx 1 /sys/class/power_supply/*/online || systemctl suspend-then-hibernate`.
  Fails toward sleeping if the AC device is ever renamed.
- `packages/arch/20-hardware.txt` — added `powertop`, `turbostat`.

All three system files were already symlinks into the repo, so only
`systemctl reload systemd-logind` was needed (`/tmp/apply-sleep-config.sh`,
which falls back to a full restart when SIGHUP under-applies — see 2026-04-21).

**Follow-on discovery: the lid drop-in had never worked at all.** After the
config change, `busctl` still reported `HandleLidSwitch=suspend`. Cause:
`systemd-logind.service` runs `ProtectHome=yes` + `ProtectSystem=strict`, so the
symlink `/etc/systemd/logind.conf.d/10-lid.conf -> /home/jaeho/dotfiles/...`
dangles inside its namespace and is skipped silently. This is the real
explanation for the 2026-04-21 note that the drop-in "violates systemd's
documented precedence rules but was empirically reproducible" — it was never a
precedence bug. Fixed by adding `SYSTEM_INSTALLS` to `scripts/lib.sh` and
install-copying the file. See the recurring entry above.

Cost of finding out: `/tmp/apply-sleep-config.sh` auto-escalated to
`systemctl restart systemd-logind` when the reload appeared not to take, which
killed the Hyprland session and dropped the user to tty1. The session came back
on re-login. Sleep-path scripts must not restart logind unattended.

**Still open: ~13 W idle with the panel off is too high.** The dGPU is pinned
out of RTD3 (`NVreg_DynamicPowerManagement=0x00`, `power/control=on`, idling at
P8 / 2.5 W), which is the prime suspect, and a dGPU held out of D3cold also
blocks deep package C-states. Deliberately **not** changed — that value is part
of the config that finally made suspend work in April. `/tmp/measure-idle-power.sh`
splits the draw into CPU package (RAPL) / dGPU / remainder and reports PC8/PC10
residency; decide from those numbers, not from the hypothesis.

## 2026-04-09 → 2026-04-25 — the nvidia hibernate/suspend campaign (condensed)

Thirteen entries from the two and a half weeks it took to get this laptop
sleeping.
Every conclusion below has since landed either in a recipe above or in the
config itself, so only the outcomes are kept here. The full forensic text —
timelines, kernel traces, log excerpts, ranked recommendations — is in git
history: `git log --diff-filter=M --follow -p -- ISSUES.md`, or read the file
at the commit before this trim.

- **04-09 → 04-11 — repeated hibernate failures, four causes at once.**
  `NVreg_EnableGpuFirmware=0` (a no-op on nvidia-open, see 04-12);
  `nvidia-suspend-then-hibernate.service` is a separate unit and needed its own
  `systemctl enable`; initramfs was not regenerated after modprobe.d edits; and
  FUSE mounts stalled the kernel freezer, which is why `system-sleep/fuse-mounts`
  exists.

- **04-12 — hibernate image never written; cold boot with `PM: Image not found`.**
  nvidia-open has no non-GSP code path and silently ignores
  `NVreg_EnableGpuFirmware=0`; GSP died during s2idle, so the wake-to-hibernate
  transition could not freeze the GPU. Switched hypridle from
  `suspend-then-hibernate` to direct `hibernate` — image gets written while the
  GPU is still alive.

- **04-15 — lid close hung on hibernate entry.** logind still routed the lid to
  the broken `suspend-then-hibernate` path. Tasks refusing to freeze were a Node
  worker pool, not FUSE.

- **04-15 (afternoon) — `nv_pmops_freeze returns -5`, image discarded.** The
  ordering bug that cost the most time: on resume the kernel freezes devices
  *before any userspace runs*, so `/proc/driver/nvidia/suspend` is never primed —
  and on nvidia-open that file does not exist at all, making every
  `nvidia-*.service` an exit-0 no-op. Fix was `MODULES=(xe)`, keeping the dGPU
  out of the initramfs. That half is driver-independent and still load-bearing;
  see the recurring entry above, since it regressed in August.

- **04-16 (evening) — hyprlock died on every resume.** Without preserved VRAM,
  Mesa hangs in `pthread_cond_wait` rather than rebuilding a lost GL context, so
  hyprlock aborts. Fixed by `system-sleep/hyprlock-restart`. Two earlier
  versions of that hook never ran at all, which surfaced the real find:
  **systemd-sleep only scans `/usr/lib/systemd/system-sleep/`, never `/etc/`** —
  one path is compiled into the binary. It also meant the FUSE fix from 04-09
  had never actually run; the cgroup-freezer override was doing that work.

- **04-17 — hard freeze, unrelated to sleep.** A tmux pane hit a 10.8 GB peak
  ~90 s before the lockup. No OOM kill was logged. One-off user-process runaway.

- **04-18 — Hyprland hung at login after an unclean shutdown.** GSP RM init
  deadlocked in `kgspInitRm_IMPL`, back-pressuring every nvidia ioctl behind one
  rw-semaphore. Nothing was fixed; the bad GPU state aged out on the next cold
  boot. Hence: after a hard shutdown, leave it powered off ~10 s so the dGPU
  power island drains.

- **04-18 (evening) — frozen session, unrecoverable.** With
  `SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=true`, a hung GPU on resume left
  `user-1000.slice` in TASK_FROZEN, so PAM could not even open a TTY session.
  Reverted that override, accepting the opposite failure mode deliberately.
  Also: `REISUB` did nothing on one of these boots because `99-sysrq.conf` had
  not been installed yet — Arch defaults to `kernel.sysrq = 16`, sync only.

- **04-20 → 04-21 — swapped nvidia-open for proprietary `nvidia-beta-dkms`.**
  Suspend worked for the first time on this machine. The same commit put nvidia
  back into `MODULES`, which quietly reintroduced the April 15 bug and went
  unnoticed until nightly hibernates started in August.

- **04-21 (late) — SD reader flapping.** Kernel upgraded without a reboot; see
  the recipe above.

- **04-21 (evening) — Thunar and `ls ~` hung.** rclone died leaving a stale FUSE
  mount, and its unit had retried 964 times against an occupied mountpoint.
  Anything stat-ing `~` blocked on the dead endpoint. Fixed with
  `ExecStartPre=-/bin/fusermount -uz`.

- **04-22 — dock USB 2.0 side dead after resume.** See the recipe above.

- **04-25 — Hyprland NULL deref in `nvidia_modeset` on resume.** With user
  sessions unfrozen, Hyprland issued `DRM_IOCTL_MODE_ADDFB2` before
  `nvidia-sleep.sh resume` had finished restoring VRAM. Recoverable (SysRq R/E,
  reboot); the inverse of the 04-18 deadlock and the tradeoff accepted there. No
  change made. If it recurs, the signature to match is `_nv000555kms` +
  `nv_drm_framebuffer_create`.
