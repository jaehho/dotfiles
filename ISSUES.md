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

## AUR node packages fail to build (nvm prefix, npm 12 defaults)

**Symptom:** any AUR package that builds with node dies in `build()`, in one of four places:

```
Your user's .npmrc file (${HOME}/.npmrc) has a `globalconfig` and/or a `prefix` setting,
which are incompatible with nvm.                                  # nvm refuses to activate
npm error code EALLOWGIT ... Refusing to fetch "pkg@git+ssh://git@github.com/..."
git@github.com: Permission denied (publickey)                     # after allow-git is on
npm warn install-scripts N packages had install scripts blocked because they are not
covered by allowScripts                                           # native modules never build
```

**Causes** — four independent ones, hit in that order:

1. `~/.npmrc` sets `prefix=~/.npm-global`, and nvm hard-refuses any user npmrc with `prefix`/`globalconfig`. **Do not delete that line** — the sudo-free npm backend in `scripts/packages.sh` depends on it.
2. npm 12 defaults `allow-git=none` and `allow-remote=none`; git/tarball-URL deps are refused.
3. Those git deps use `git+ssh://git@github.com/`, and there is no GitHub SSH key on this machine.
4. npm 12 blocks dependency install scripts unless listed in `allowScripts`, so `node-gyp` never runs and the build fails a later check on a missing `.node`.

**Fix** — all four are env-only; nothing in `~/.npmrc` or `~/.gitconfig` changes:

```bash
env NVM_DIR=/usr/share/nvm \
    npm_config_allow_git=all npm_config_allow_remote=all \
    npm_config_dangerously_allow_all_scripts=true \
    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0='url.https://github.com/.insteadOf' \
    GIT_CONFIG_VALUE_0='ssh://git@github.com/' \
    paru -S <pkg>
```

`NVM_DIR` works because these PKGBUILDs early-return from their nvm helper when it is already set — the build then uses system node, which `pacman` keeps at the same version nvm would have downloaded. The scripts flag re-enables arbitrary install-script execution for every dependency; that is what a source build implies either way, but keep it env-scoped, never in `~/.npmrc`.

Retry a half-finished build in place with `makepkg -e` (skips extract/prepare, no sudo) in `~/.cache/paru/clone/<pkg>`, then `sudo pacman -U` the result. Wipe `node_modules` first if a previous run installed deps with scripts blocked — npm will not re-run install scripts for packages already on disk.

**Also check the electron major.** `mailspring` 1.23.0-3 declares `electron43` in `.SRCINFO` while upstream `package.json` pins 41, so paru installs 43, `prepare()` resolves 41, and the built package depends on `electron41` — two 95 MB electrons for one app. `pacman -Qi electron*` after installing; `pacman -Rns electron` drops the unused meta and its version package.

**The durable fix is to not build node from source at all.** Prefer a `-bin` package when one exists: it sidesteps every cause above, and the popular ones still link the system electron rather than bundling their own. On 2026-09-01 this machine tried `mailspring` (source) → `mailspring-bin` → dropped it entirely and stayed on `thunderbird`. Nothing installed here builds with node now, so the recipe above is for the next package, not for anything current.

## `nextcloud.wonhomelab.net` unreachable on the home LAN (and restic backups fail)

**Two different causes have produced this. Tell them apart before touching anything.**

**Cause 1 — which network you roamed onto.** `HappyFamily` hands out *two*
subnets, and only one of them can reach the server:

| attachment point | hairpin | backups |
|---|---|---|
| `192.168.1.0/24`, gateway `.1` (main router) | real `*.wonhomelab.net` cert, `status.php` 200 | succeed |
| `192.168.68.0/22` (Deco mesh) | `Server: micro_httpd`, snakeoil `CN=example.com, O=Dis, ST=Denial` | fail |

Nothing is misconfigured when this happens and nothing needs fixing at the
router; the laptop simply roamed. It looks exactly like a deleted port-forward,
and in September 2026 it was misdiagnosed as one. **Check `ip -4 -o addr show`
first**, and re-probe from the other subnet before concluding anything. The
Deco side also sometimes fails to resolve the name at all (`Temporary failure
in name resolution`), which is the same cause wearing a different error.

**Cause 2 — a stale `/etc/hosts` pin.** Symptom is different: `No route to
host`, and `ip neigh` shows the pinned address `FAILED`. A hand-written
`192.168.1.42 nextcloud.wonhomelab.net # reel: nextcloud LAN override` was
added years ago to dodge the hairpin, the server later left that address, and
the workaround became the outage. **Delete the line.** Nothing in this repo
writes it, so `make sync` will not bring it back, and **do not re-add a pin** —
if the hairpin regresses, fix it at the router with split-horizon DNS so every
device benefits.

**Triage, in this order:**

```bash
ip -4 -o addr show                             # cause 1: which subnet?
grep -i wonhomelab /etc/hosts                  # cause 2: any pin at all?
curl -sS --resolve nextcloud.wonhomelab.net:443:24.47.180.85 \
  -o /dev/null -w '%{http_code} ssl_verify=%{ssl_verify_result}\n' \
  https://nextcloud.wonhomelab.net/status.php
```

`200 ssl_verify=0` means the server and its certificate are healthy, so the
problem is on this machine's side of the wire.

From the Deco side the server cannot be found by name, and the main router's
`/24` does not contain it. To locate it, sweep the subnet you are actually on
for anything serving HTTPS:

```bash
base=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 |
       head -1 | cut -d. -f1-3)
for i in $(seq 1 254); do
  ( timeout 1 bash -c "echo > /dev/tcp/$base.$i/443" 2>/dev/null &&
    curl -sk --max-time 5 "https://$base.$i/status.php" | grep -q '"installed"' &&
    echo "$base.$i  <- Nextcloud" ) &
done; wait
```

**Backups do not depend on you catching this quickly.** The timer makes four
attempts a day (`00,06,12,18:10`, jittered), so a stretch on the wrong subnet
costs hours rather than a day. Individual failures are therefore normal and are
*not* announced -- announcing them would train you to dismiss the notification.
An attempt that cannot reach `status.php` (with a valid cert) is skipped by
`ExecCondition=` instead of failing, so it does not light waybar's failed-units
indicator; a unit that *does* fail got through to the server and broke anyway.
`ExecStopPost=` runs `~/.local/bin/backup-outcome` on every outcome: a success
touches `~/.local/state/restic-last-success`, and a failure speaks up only when
that marker is more than 48 h old. To see where you stand without waiting for it:

```bash
stat -c %y ~/.local/state/restic-last-success   # last successful run
systemctl --user list-timers restic-backup.timer
```

This replaced a silent setup in which `restic-backup.service` failed three
nights running in September 2026 and nothing said so; the gap was found by
hand, three days in.

## Cooper `conway`/`ice00`: REMOTE HOST IDENTIFICATION HAS CHANGED

**Symptom:** `ssh conway` (or `ice`) refuses with `Host key verification failed`, and `sshfs-conway.service` sits in a restart loop logging `read: Connection reset by peer`.

**Do not just `ssh-keygen -R` and reconnect.** Cooper auth is a *plaintext password* (`sshpass -f ~/.ssh/jump_pass`, see `home/ssh/.ssh/config`), so accepting a forged key hands over the account on the first connect. Pubkey auth would fail safe here; password auth does not.

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

## Cooper X2Go: seconds per keypress, and closed windows leave ghosts

Two separate faults that look like one "the connection is slow". Neither is the
network — check that first and stop blaming the coffee-shop wifi:

```sh
ping -c8 conway.ee.cooper.edu                       # ~40 ms, 0% loss is normal
r1=$(cat /sys/class/net/wlo1/statistics/rx_bytes); sleep 5
echo $(( ($(cat /sys/class/net/wlo1/statistics/rx_bytes)-r1)/5/1024 )) KiB/s
```

**Both ends pegged at ~100% CPU while the link moves <50 KiB/s means the
bottleneck is rendering, not bandwidth.** Keystrokes are seconds late because
they queue behind a saturated X server at each hop, not because they are in
flight. Measure both ends before changing anything:

```sh
top -bn1 -o %CPU | head            # local: Xwayland / nxproxy
sshpass -f ~/.ssh/jump_pass ssh conway 'top -bn2 -d2 -u $USER | grep x2goagent'
```

**Ghosting — remote xfwm4 compositing.** Closing a window leaves its rectangle
on screen showing whatever was underneath; mousing over the area clears it
piece by piece. xfwm4's compositor redirects windows off-screen and nxagent's
damage tracking does not follow redirected windows, so the region a destroyed
window covered is never re-sent. Hovering clears it because motion generates
fresh damage there. It also gives the agent a constant stream of damage to
encode, so it costs latency as well as looks wrong.

```sh
sshpass -f ~/.ssh/jump_pass ssh conway '
  wpid=$(pgrep -u $USER -x xfwm4 | head -1)
  eval "$(tr "\0" "\n" < /proc/$wpid/environ |
          grep -E "^(DISPLAY|DBUS_SESSION_BUS_ADDRESS|XAUTHORITY)=" | sed "s/^/export /")"
  xfconf-query -c xfwm4 -p /general/use_compositing -s false
  xrefresh'
```

Takes effect live and persists — xfconf writes it to `~/.config/xfce4/
xfconf/xfce-perchannel-xml/xfwm4.xml` in AFS, so new sessions inherit it. It
comes back `true` on any fresh profile: that is xfwm4's own compiled-in
default and conway has no `/etc/xdg/xfce4/.../xfwm4.xml` overriding it. X2Go
starts a stock XFCE session and nothing in the stack knows the display is a
network agent, so expect to redo this on a new account.

**Latency — client-side settings.** Two knobs in `~/.x2goclient/sessions`:

- `quality=9` with `pack=16m-jpeg` is near-lossless JPEG: PNG-sized payloads
  *and* JPEG's encode cost, on both ends. Use `quality=5`, or `16m-png` if the
  session is mostly text.
- `speed` sets the NX link profile. `speed=4` (LAN) is right for campus; the
  session's live options are readable on the server at
  `~/.x2go/C-*/options` (`link=lan,pack=16m-jpeg-5,...`).

**Do not run the client inside Xephyr.** A `home/bin/.local/bin/x2go-launch`
wrapper did this until 2026-09-01 to "isolate X11 from Hyprland". It cost a
full core — a nested software X server re-blitting every frame on its way to
XWayland — and bought nothing: Hyprland's binds are compositor-level, so Super
was intercepted before XWayland either way. `x2goclient` on plain XWayland is
correct. With compositing off and quality 5, idle CPU is ~0% on both ends
where it used to be 93% local / 80% remote.

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

## Media/brightness keys dead after a package upgrade

`make sync` upgrades packages but never restarts the daemons Hyprland already
launched, so a long-lived session keeps running the *deleted* old binary. When
swayosd bumps its D-Bus signature, the new `swayosd-client` and the stale
in-memory `swayosd-server` stop agreeing and every volume/brightness key
silently does nothing. (0.3.1 -> 0.3.2 changed `HandleAction` from `(ss)` to
`(ssa(ss))`.)

The binds are not the problem — don't go hunting in `hyprland.lua`, `keyd`, or
xkb. `hyprctl binds | grep XF86` lists them and `hyprctl configerrors` is empty.

Confirm it. A healthy server answers `b true`:

```sh
busctl --user call org.erikreider.swayosd-server /org/erikreider/swayosd \
  org.erikreider.swayosd HandleAction 'ssa(ss)' SINK-VOLUME-RAISE "" 0
```

Fix:

```sh
pkill -x swayosd-server; hyprctl dispatch 'hl.dsp.exec_cmd("swayosd-server")'
```

Why it fails *silently*: `swayosd-client` exits non-zero only when nothing
owns the bus name at all. A stale server answers and refuses, and the client
still exits 0 — so the `|| wpctl ...` fallbacks in `hyprland.lua` cover the
wrong failure. Exit status proves nothing here; only the D-Bus reply does.

`make sync` now restarts a stale swayosd-server after an upgrade, so this
should not recur. The manual fix above still applies to a session that has
not synced since.

Same trap, other daemons — list everything still running an upgraded-away
binary before blaming config:

```sh
for p in /proc/[0-9]*; do
  readlink "$p/exe" 2>/dev/null | grep -q '(deleted)' &&
    printf '%s\t%s\n' "${p#/proc/}" "$(readlink "$p/exe")"
done
```

---

## dGPU wedges during a sleep cycle and silently burns ~18 W

**Symptom:** nothing looks broken. The desktop is fine (the panel is on the
iGPU), but the battery empties two to three times faster than usual.

```bash
nvidia-smi   # "Unable to determine the device handle for GPU0 ... Unknown Error"
cat /sys/bus/pci/devices/0000:2b:00.0/power/{control,runtime_status}   # on / active
cat /sys/bus/pci/devices/0000:2b:00.0/power_state                      # D0
```

D0 + driver bound + unreachable = wedged. Measured cost on 2026-08-31:

```
Aug 27 baseline            10.26 W
2026-08-31 before 09:04    13.06 W
2026-08-31 after  09:04    31.34 W    <- +18 W
```

It also pins `Pkg%pc2/pc6/pc10` and `SLP_S0` at **0%** — a device stuck in D0
stops the package reaching any deep C-state — so it poisons any power
measurement taken while it is wedged.

**What it looks like in the journal** (this is the moment it happens, during
`suspend-then-hibernate`):

```
WARNING: nvidia/nv.c:4472 at nv_set_system_power_state+0x589 [nvidia]
WARNING: nvidia/nv.c:4713 at nv_set_system_power_state+0x5a5 [nvidia]
WARNING: nvidia/nv.c:4422 at nv_restore_user_channels+0x4e [nvidia]
nvidia-sleep.sh: line 45: echo: write error: Input/output error
nvidia-suspend-then-hibernate.service: Failed with result 'exit-code'
```

then afterwards, on every later sleep attempt:

```
[drm:drm_setmaster_ioctl] *ERROR* [nvidia-drm] Failed to grab modeset ownership
[drm:__nv_drm_connector_detect_internal] *ERROR* Failed to detect display state
/usr/lib/systemd/system-sleep/nvidia: line 22: echo: write error: Input/output error
```

The `Input/output error` is `/proc/driver/nvidia/suspend` refusing writes — the
VRAM save/restore that `NVreg_PreserveVideoMemoryAllocations=1` depends on died
mid-transition and the driver's power-state machine never recovered.

**Recovery: reboot.** `nvidia-smi -r` cannot work (it cannot reach the GPU), and
unbind/rebind is unsafe while `nvidia_drm` has users. There is no runtime fix.

**Detection is the real problem** — it is invisible until you notice the battery.
Worth a check in `hypr-battery-monitor` or a sleep hook:

```bash
nvidia-smi -L >/dev/null 2>&1 || notify-send -u critical "dGPU wedged" "Reboot: ~18 W wasted"
```

**Open:** whether `NVreg_DynamicPowerManagement=0x02` (RTD3 on) makes this less
likely by keeping the GPU powered down when unused, so system sleep has far less
GPU state to preserve. Currently `0x00`, which pins it out of RTD3 — that is why
it sits in D0 rather than D3cold. Not yet tested.

## Woke up on its own and then never slept again (battery flat)

The damaging failure is not the wake — a spurious wake is harmless if the box
goes back to sleep. It is that **hypridle is the only thing that sleeps this
machine**, and logind's idle tracking is inert here (`IdleSinceHint=0`), so
there is no second line of defence. When the sleep path declines, nothing
retries and the battery runs to empty.

**First: did the sleep listener fire, and what did it decide?**

```bash
journalctl -t hypr-sleep -t hypr-idle --since '-2 days'
```

`hypr-idle` is a 120 s heartbeat and `hypr-sleep` logs every sleep decision, so
you can tell the three cases apart:

| journal | meaning |
|---|---|
| no `hypr-idle` lines at all | idle clock never advanced — something holds a **Wayland** idle inhibitor (a browser tab is the usual culprit; these are invisible to `systemd-inhibit --list`) |
| `hypr-idle` but no `hypr-sleep` | never reached 30 min idle |
| `hypr-sleep ... staying awake` | it fired and the gate declined — read the reason it logged |

Before that instrumentation existed the whole path was silent, which is what
made 2026-08-27 take so long to pin down.

**The trap that caused it: `online` is not the same as "on AC".**

```sh
grep -qx 1 /sys/class/power_supply/*/online || systemctl suspend-then-hibernate   # WRONG
```

That glob matches the `ucsi-source-psy-USBC000:*` USB-C nodes as well as `ADP1`.
A docked machine whose PD state has latched (the `ucsi_acpi ... -110` signature,
see the Anker dock entry) can report `online=1` on a ucsi node while `ADP1=0`
and the battery genuinely drains. The gate reads "on AC" and skips the sleep,
and since hypridle fires `on-timeout` only **once per idle period**, it never
retries. Use the battery's own `status` instead — `Discharging` is unambiguous —
and **fail toward sleeping** on anything unrecognised. A spurious sleep costs a
keypress; a spurious stay-awake costs the session. Lives in
`home/hypr/.local/bin/hypr-sleep-if-idle`.

**Backstop:** `hypr-battery-monitor` hibernates at 7% (below its own `CRIT=10`
notification so the ladder still works, and well above UPower's `PercentageAction=2`,
which at ~10 W leaves only about 8 minutes). It gates on `status == Discharging`
and is deliberately independent of hypridle and of *why* the machine is awake.

**Attributing a wake — do this before disabling any wake source.** Counters are
cumulative since boot:

```bash
sudo awk 'NR==1 || ($3+0)>0' /sys/kernel/debug/wakeup_sources   # wakeup_count column
cat /sys/bus/usb/devices/*/power/wakeup_count
grep '\*enabled' /proc/acpi/wakeup
```

**A worked example of getting this wrong.** On 2026-08-28 a
`disable-usb-s4-wakeup.service` was written to disarm `XHCI`/`TXHC`/`TDM0`/`TRP0`,
on the reasoning that no RTC alarm was armed, no timer sets `WakeSystem=true`,
and those controllers *were* armed — so it must be USB. The counters said
otherwise: the Logitech receiver's `wakeup_count` was **0**, and every
`wakeup_count` in `wakeup_sources` was 0. Elimination is not attribution. It was
reverted; it cost wake-on-external-keyboard for no demonstrated benefit. The
wake source remains unidentified — `ucsi` (`active_count=101`) is the open
candidate, given the dock logged `-110` at the moment of that resume. If
spurious wakes recur, investigate `TXHC`/`TDM0`/`TRP0`, **not** `XHCI`.

**`/proc/acpi/wakeup` is a toggle, not a setting** — writing a name flips it, so
anything re-applying unconditionally re-arms what it just disabled. Test state
first, and anchor the pattern, because `enabled` is a substring of `disabled`:
`grep -qE "^$d[[:space:]]+S4[[:space:]]+[*]enabled"`.

**Never disarm `AWAC`.** It is the ACPI wake alarm `suspend-then-hibernate` uses
to wake itself once `HibernateDelaySec` expires. Disable it and the machine sits
in s2idle forever and never hibernates — a worse version of the bug.

**Not every long wake is a bug.** On AC the policy is plain `suspend` by design
(`HandleLidSwitchExternalPower=suspend`, `HibernateOnACPower=no`), so hours in
s2idle while plugged in is correct. Check `Performing sleep operation 'suspend'`
vs `'hibernate'` first.

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
30-min hypridle listener in `home/hypr/.config/hypr/hypridle.conf`. logind
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

**Fix:** `MODULES=(xe)` in `system/mkinitcpio/mkinitcpio.conf`, then `sudo mkinitcpio -P`.
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
suspend-then-hibernate}.service` all run `ProtectHome=no`, so `system/systemd/sleep.conf`
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
- `system/mkinitcpio/mkinitcpio.conf`: `MODULES=(xe nvidia nvidia_modeset nvidia_uvm
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
## Black screen after resume, but the compositor is fine

Hibernate aborted at the very last step and the display never came back. The
session is healthy in every way you would normally check -- `hyprctl` answers,
Hyprland is on the right VT, no crash, no OOM -- and the panel is still dark.

**The one diagnostic that settles it.** From a text VT, force the graphical
session active and see whether Hyprland actually drives the output:

```bash
loginctl activate 17          # the Hyprland session id, from `loginctl`
sleep 3
loginctl show-session 17 -p Active --value    # -> yes
grep -c Modesetting /run/user/1000/hypr/*/hyprland.log
```

`Active=yes` with a **Modesetting count that does not increase** is the whole
finding: the compositor holds the VT and refuses to light the connector. That
rules out the VT path entirely and sends you to the kernel log. Chasing it from
the Hyprland side instead costs an hour (2026-09-02).

**Confirm in the kernel log.** The abort is unmistakable once you look:

```
PM: hibernation: Allocated 12790568 kbytes in 63.71 seconds
ACPI: PM: Preparing to enter system sleep state S4
ACPI: PM: Saving platform NVS memory
ACPI: PM: Restoring platform NVS memory      <- bounced, never entered S4
ACPI: PM: Waking up from system sleep state S4
PM: hibernation: hibernation exit
systemd-logind: Lid opened.
```

A wake event landing during the snapshot makes the S4 entry bounce straight
back out. The image is never written, and the half-finished transition leaves
the GPU in a state Hyprland will not modeset out of. Opening the lid while it
is writing a 12.8 GB image is enough -- that is a ~60s window, and
`HibernateDelaySec=1h` on battery means you hit it regularly. Cross-check the
gap with `journalctl -t tailscaled | grep "time jump"`.

**Recovery** is a compositor restart; nothing softer works (`dpms`,
`hl.monitor`, VT cycling and `loginctl activate` all return success and change
nothing, because IPC is alive and DRM is not).

```bash
loginctl terminate-session 17   # from tty2; agetty respawns a TEXT login on tty1
```

`fish/conf.d/arch.fish` does `exec start-hyprland` on tty1, so logging back in
restarts it. A tmux session under `user@1000.service` survives this
(`KillUserProcesses=no`); anything in `session-17.scope` does not.

**Three things this is NOT** -- each cost time on 2026-09-02:

- **Not a compositor wedge.** On an *inactive* VT, `grim` timing
  out, `hyprctl dispatch` returning `ok` with no effect, and hyprlock's threads
  sitting in `futex_do_wait` are all NORMAL. Check
  `loginctl show-session <id> -p Active` **before** reading anything else into
  those. State `S` is idle waiting, not a hang.
- **Not seatd.** `Backend 'seatd' failed to open seat, skipping` is on every
  boot; the next line reads `Seat opened with backend 'logind'`.
  `seatd.service` is disabled by preset and should stay that way.
- **Not dpms, and not a `monitors.lua` bug.** Grep the log for `Modesetting` --
  if the last one is a clean `1920x1080@60.00Hz`, the layout code is innocent.

---

## Suspend bounces back in seconds, or the screen won't stay off

Both are the same device. The **ELAN touchpad** (`i2c-ELAN012C:00`, IRQ 84) is
armed as a system wake source and emits phantom contacts while nobody is
touching it. As a wake source it kicks the box out of s2idle; as an input
device it defeats `dpms off`.

**Name the culprit — the kernel keeps it, and it survives until the next
suspend, so there is no rush:**

```bash
cat /sys/power/pm_wakeup_irq                  # -> 84
grep -E "^\s*84:" /proc/interrupts           # -> ELAN012C:00
cat /sys/power/suspend_stats/last_hw_sleep    # microseconds ACTUALLY asleep
```

`last_hw_sleep` in the low millions means seconds, not a real sleep. Note the
sleep still logs as a *success* — `suspend_stats/fail` stays 0 — so nothing in
the journal calls this an error.

**Why a 5-second wake costs the whole night:** systemd treats a wake that is
not its own RTC alarm as "the user woke it", so `suspend-then-hibernate`
returns instead of re-suspending. hypridle fires `on-timeout` once per idle
period. Nothing retries. See "Woke up on its own and then never slept again".

**Check for phantom input on a machine nobody is touching:**

```bash
# hands off the laptop for this
a=$(awk '$1=="84:"{s=0;for(i=2;i<=NF;i++)if($i~/^[0-9]+$/)s+=$i;print s}' /proc/interrupts)
timeout 10 tail -f /dev/null
awk -v a="$a" '$1=="84:"{s=0;for(i=2;i<=NF;i++)if($i~/^[0-9]+$/)s+=$i;print "delta",s-a}' /proc/interrupts
```

Idle should be 0. Anything sustained is phantom; corroborate with
`ERR ... Touch jump detected and discarded` in the Hyprland log.

**Fix** — `system/udev/rules.d/90-no-wake-i2c-hid.rules`, installed by `make sync`.
Matched on `DRIVER=="i2c_hid_acpi"`, not on the ACPI HID, and `ACTION` must
include `bind`: `power/wakeup` does not exist until the driver probes, so a
rule firing on `add` alone is silently dropped. Verify:

```bash
cat /sys/devices/.../i2c-ELAN012C:00/power/wakeup   # -> disabled
```

The keyboard (`serio0`), lid (`PNP0C0D:00`) and power button are untouched and
still wake the machine.

**Do not chase the dispatcher.** `hl.dsp.dpms("off")` is correct on 0.56.x and
returns `ok` — `hyprctl dispatch dpms off` is the *stale* spelling and errors.
A working dispatcher that leaves `dpmsStatus: true` is the touchpad, not a
config typo:

```bash
hyprctl dispatch 'hl.dsp.dpms("off")'; sleep 2
hyprctl monitors -j | grep dpmsStatus     # false = worked; true = re-woken
```

**Unrelated but visible in the same logs:** the Goodix touchscreen
(`GTX7937:00`, IRQ 108) free-runs at ~525 interrupts/s untouched — millions per
session. It is not a wake source so it does not block sleep, but it holds the
package out of deep C-states and costs idle battery. Not yet fixed.

---


The only reason it hibernated at all was upower's critical-battery action at 2 %.
That cycle was *flawless* — which is the useful finding: suspend-then-hibernate
works end to end on the current driver, unprompted, including the hyprlock
restart hook.

**Latent bug found while reading the sleep hooks** — `system/systemd/system-sleep/fuse-mounts`:

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

- `system/systemd/system-sleep/fuse-mounts` — fixed the `timeout`-on-a-function bug;
  added a 15 s cap on the resume-side `start` for the same failure mode.
- `system/systemd/logind.conf.d/10-lid.conf` — `HandleLidSwitch=suspend-then-hibernate`
  on battery; `HandleLidSwitchExternalPower=suspend` on AC.
- `system/systemd/sleep.conf` — added `HibernateOnACPower=no`, so the 1 h countdown
  only runs unplugged and closing the lid while docked just stays suspended.
- `home/hypr/.config/hypr/hypridle.conf` — new 1800 s listener, battery-gated:
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
