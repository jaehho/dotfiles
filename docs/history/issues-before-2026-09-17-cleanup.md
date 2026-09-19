# Archived troubleshooting notes — 2026-09-17 snapshot

Historical evidence, **not current operating instructions**. Use [ISSUES.md](../../ISSUES.md) for current diagnosis and recovery. The snapshot below preserves the pre-cleanup text, including mistakes and superseded fixes.

Known corrections:

- The claim that hibernation never completes was disproved by later power-cycle tests; missing post-snapshot log lines do not establish failure.
- `make sync` / `make status` and removed sleep hooks are historical. Follow the current dispatcher and configs.
- Lua DPMS dispatch takes a table; old string-form examples below may toggle instead.
- Temporary scripts named below are session artifacts, not maintained recovery tools.
- Live configs, package versions, network addresses, and upstream issue status may have changed.

---

# System Issues Log

Persistent record of failures on `omnibook` (HP OmniBook 17, Lunar Lake + RTX 4050 Max-Q): boot, sleep/hibernate, and package-management breakage.

Two parts. **Recurring failures** is what to read when something that worked last month breaks today — each entry is a known trap with a fix to copy. **Incident log** is dated history, newest first; each entry: date, symptom, what the logs showed, what was done.

---

# Recurring failures

## Claude Code via OpenRouter: "API Error: stream closed before completion"

A provider that dies *mid-stream* is not covered by OpenRouter's failover: once tokens
have been sent, they cannot be replayed elsewhere, so the connection just ends and
Claude Code reports "stream closed before completion". Failover only covers providers
that fail before the first token.

First suspect the preset, not the provider. **`provider.sort` or `provider.order`
disables load balancing**, and with it the uptime filter that normally skips providers
with recent outages (the default balancer filters on uptime, then weights by inverse
square of price). A preset sorted by price will happily pin you to the cheapest host
even at 45% uptime.

```sh
KEY=$(sed -n 's/^OPENROUTER_API_KEY=//p' ~/.config/openrouter.env)
# who is healthy right now (status 0 = fine, negative = degraded):
curl -sS https://openrouter.ai/api/v1/models/z-ai/glm-5.3-flash/endpoints \
  | jq -r '.data.endpoints[] | "\(.provider_name)\t\(.status)\t\(.uptime_last_30m)"'
# what a preset is actually set to, and who served a call:
curl -sS "https://openrouter.ai/api/v1/presets/cc-flash-high" -H "Authorization: Bearer $KEY" \
  | jq -c '.data.designated_version.config'
curl -sS https://openrouter.ai/api/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"@preset/cc-flash-high","max_tokens":20,"messages":[{"role":"user","content":"hi"}]}' \
  | jq -r .provider
```

A re-POST to `/api/v1/presets/<slug>/chat/completions` replaces the config version
rather than merging it, so repeat the whole `provider`/`reasoning` block every time,
and never send `max_tokens` (it persists and caps every later response).

Exclude a provider (`provider.ignore`) only when one host repeatedly truncates while
the rest are healthy. A dip across *all* providers is an upstream or OpenRouter-side
incident and no preset edit fixes it. Not a network problem either — long streams
through a captive-portal guest WiFi passed fine (guest portals instead cause
`SSL certificate hostname mismatch` on connect, a different error).

## `make sync`: nvidia beta upgrade deadlocks paru

**Symptom:** the `arch` phase fails — three identical times, since paru retries — with

```
error: failed to prepare transaction (could not satisfy dependencies)
:: installing nvidia-utils-beta (NEW) breaks dependency
   'nvidia-utils-beta=OLD' required by nvidia-beta-dkms
```

**Not a real conflict.** `nvidia-beta-dkms`'s `.SRCINFO` pins `nvidia-utils-beta=<pkgver>` exactly. paru installs a built AUR dependency *before* building its dependent, so it tries to install the new utils while the old dkms package still demands the old utils — and never gets as far as building the new dkms. Recurs on every bump where both packages move.

**Fix** — refresh the clones (a *held* run builds nothing), build the set with dependency resolution off, then install the whole set in one transaction (in the deadlock paru has already built the utils set, so only dkms is missing):

```bash
for d in nvidia-beta-dkms nvidia-utils-beta lib32-nvidia-utils-beta; do
  git -C ~/.cache/paru/clone/$d pull --ff-only
done

cd ~/.cache/paru/clone/nvidia-beta-dkms
makepkg -df --noconfirm --nocheck
cd ../lib32-nvidia-utils-beta
makepkg -df --noconfirm --nocheck   # its build dep pins nvidia-utils-beta>= too
cd ../nvidia-utils-beta
makepkg -df --noconfirm --nocheck

sudo pacman -U \
  ~/.cache/paru/clone/nvidia-beta-dkms/nvidia-beta-dkms-<VER>-x86_64.pkg.tar.zst \
  ~/.cache/paru/clone/nvidia-utils-beta/nvidia-utils-beta-<VER>-x86_64.pkg.tar.zst \
  ~/.cache/paru/clone/nvidia-utils-beta/opencl-nvidia-beta-<VER>-x86_64.pkg.tar.zst \
  ~/.cache/paru/clone/nvidia-utils-beta/nvidia-settings-beta-<VER>-x86_64.pkg.tar.zst \
  ~/.cache/paru/clone/lib32-nvidia-utils-beta/lib32-nvidia-utils-beta-<VER>-x86_64.pkg.tar.zst
```

Reboot after (the module and the userspace libs are only in sync again post-reboot), then re-run `make sync` — the arch drift check skips itself on any run where install failed.

**The exit, if this stops being worth it:** the 2026-04-20 entry below says to leave DKMS "if proprietary nvidia returns to `extra/`". It hasn't, and won't — `extra/` ships only `nvidia-open*` now. The only way off the AUR is accepting the open modules, which is what the April suspend failures were about.

## Waybar taskbar: a Firefox icon for a window that no longer exists

**Symptom:** the `hyprland/workspaces` taskbar shows a window icon (seen: Firefox
PiP on workspace 3) that nothing can focus — clicking it does nothing — and
`hyprctl clients` has no matching window. Firefox may not even be running.

**Cause:** waybar missed the `closewindow` event, so its taskbar keeps an entry
for a destroyed window. The known orphan-map fix is already in the installed
build (checked 2026-09-17, `0.15.0.r1008.g2a12740`), so this is a still-unfixed
missed-event bug in `workspace-taskbar`; upstream master has nothing newer.

**Fix:** the bar is the only thing that's wrong. Restart it (relaunch the way
`hyprland.lua` does, from its config dir):

```sh
pkill -x waybar; (cd ~/.config/waybar && setsid sh -c "waybar 2>&1 | grep -v 'Gtk-CRITICAL\|GTK_IS_ACCEL_GROUP'" &)
```

**Prevention:** none local — waybar's taskbar state can't be queried from
outside, so there is nothing to diff against `hyprctl clients`. Worth an
upstream report if it recurs.

## Hyprland Lua config: an edited module silently does nothing

**Symptom:** you edit a file that `hyprland.lua` pulls in with `require()`, run
`hyprctl reload`, and nothing changes. No error, no log line, no notification.

**Two separate traps, and they stack:**

1. **`require` caches in `package.loaded`, and that cache survives a reload.**
   The module body runs once, at session start. Every later `hyprctl reload`
   re-executes `hyprland.lua` but hands back the *cached* module, so your edit
   is invisible until a full Hyprland restart. Fix — clear it before requiring:

   ```lua
   package.loaded["monitors"] = nil
   local monitors = require("monitors")
   ```

2. **Hyprland's `require` swallows errors raised inside the module** and returns
   an empty table instead. `pcall(require, ...)` reports success. So a module
   that blew up on line 3 is indistinguishable from one that loaded fine, and
   `hyprland.log` says nothing either. Check the shape of what you got back:

   ```lua
   if ok and (type(monitors) ~= "table" or monitors.apply == nil) then
       ok, monitors = false, "module did not return its table"
   end
   ```

**To see the actual error**, bypass `require` entirely — `loadfile` + `pcall`
reports it properly:

```lua
local chunk = loadfile("/home/jaeho/.config/hypr/monitors.lua")
local ok, err = pcall(chunk)   -- err is the real message, with a line number
```

**The bug that started this:** `hl.timer(fn, { timeout = 500 })` returns **nil**
— `opts.type` is mandatory and must be `"repeat"` or `"oneshot"`. The next line
indexed nil, the module died, and all three behaviours above conspired to make
it look like the file simply wasn't being read. The binary knows the rule even
though the wiki example is easy to misread:
`strings /usr/bin/Hyprland | grep 'hl\.timer'`.

**A fired `"oneshot"` timer is spent.** Afterwards `is_enabled()` returns nil and
`set_enabled(true)` revives nothing, so a debounce that re-arms one timer runs
exactly once (monitors.lua did, until 2026-09-14: hotplug never re-applied).
Re-arm while `is_enabled()` is true, otherwise create a new timer.

## Wallpaper: the photo doesn't change, but nothing errors

Four silent-success traps, all hit while building `wallhelper fetch`.

**hyprpaper's wildcard monitor does nothing over IPC.** In `hyprpaper.conf`, an
empty `monitor =` is the documented wildcard. Over IPC it is not:

```bash
hyprctl hyprpaper wallpaper ",/path/to.jpg"   # exit 0, empty reply, no change
hyprctl hyprpaper wallpaper "eDP-1,/path/to.jpg"   # works
```

Every output has to be named explicitly. `hyprpaper preload` and
`hyprpaper reload` were removed in 0.8 and now answer `invalid hyprpaper
request`, so old snippets fail loudly — this one fails quietly instead.

```bash
hyprctl monitors -j | jq -r '.[].name' |
  while read -r m; do hyprctl hyprpaper wallpaper "$m,$IMG"; done
```

**wallhaven 403s on a User-Agent containing a parenthesized URL.** The
conventional `tool (+https://example.com/repo)` form is rejected by its WAF; a
bare `tool/1.0` is fine, and so is curl's default. Verify with:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' -A 'x/1.0' \
  'https://wallhaven.cc/api/v1/search?categories=100&purity=100&page=1'
```

**hyprpaper never re-reads its config.** 0.8 has no `reload` verb, so editing
`hyprpaper.conf` changes nothing until the process is restarted — the old
behaviour just keeps going and looks like the edit was ignored:

```bash
pgrep -x hyprpaper | while read -r p; do kill "$p"; done
setsid hyprpaper >/dev/null 2>&1 </dev/null &
```

(`pkill -f hyprpaper` from a shell here matches its own command line and kills
the shell — exit 144. So does `pgrep -f 'wallhelper[-]gui'` when the *rest* of
the same command mentions that path: the bracket trick only hides the literal,
it doesn't stop another copy of the string in the command line from matching.
Filter on the process name instead:

```bash
for p in $(pgrep -f 'wallhelper gui'); do
  [ "$(ps -o comm= -p "$p")" = python3 ] && kill "$p"
done
```
)

**A directory path plus `order = random` re-rolls on every start.** Not just on
a `timeout`: each session restart and each hyprpaper restart picks a fresh
random image from the whole tree, which reads as "my wallpaper keeps changing by
itself". `hyprpaper.conf` therefore points at a single `.current` symlink that
`wallhelper fetch` repoints once a day. Verify determinism by restarting it twice
and confirming the same image both times.

**Check the whole path when the wallpaper looks stuck:**

```bash
systemctl --user list-timers wallhelper-fetch.timer
journalctl --user -u wallhelper-fetch -n 20
hyprctl hyprpaper listactive
readlink -f ~/Media/wallpapers/.current
```

Note `wallhelper fetch` only ever deletes files it recorded in
`~/Media/wallpapers/.credits`. That restriction exists because the first
version pruned by mtime alone and wiped a twelve-image hand-built library on its
first run — every file in it was already past the 30-day cutoff. Images you add
by hand are never aged out, and anything kept is hardlinked into `kept/`, so
pruning the daily copy cannot destroy it.

## `make sync`: global cargo tools stop building

**Symptom:** the `cargo` phase fails with `requires rustc X or newer, while the currently active rustc version is Y`.

**Cause:** Arch's `rustup` package updates the installer, never the toolchain — `stable` sits at whatever version it was installed at while crates raise their MSRV. It drifted three releases (1.94 → 1.97) before biting.

**Fix:** handled in `scripts/packages.sh` — the cargo upgrade step runs `rustup update` first.

## `make sync`: drift offers to delete a package that is installed

**Symptom:** the same one or two packages show up under `[arch] drift` /
`Tracked but not installed` on every run, while the install step above them
says `warning: <pkg> is up to date -- skipping`. Answering `Y` drops them from
the manifest; they come back the next time anything re-adds them.

**Cause:** the manifest is compared against `pacman -Qqe` (explicitly
installed). A tracked package that some *other* package also depends on can be
recorded as a dependency instead, and `paru -S --needed` will not change that
— so it is missing and up-to-date at the same time, forever.

**Fix:** handled in `scripts/packages.sh` — the arch install step follows paru
with `pacman -D --asexplicit` for anything in the missing set that pacman still
calls a dependency. To repair one by hand:

```bash
sudo pacman -D --asexplicit <pkg>
```

Do not answer `Y` to the removal prompt: the package is wanted, and deleting
the entry only means nothing reinstalls it if its dependent goes away.

## User units: `not-found` in `--failed`, or enable links point at an old repo path

**Symptom:** `systemctl --user --failed` lists units whose files were deleted
from the repo (`not-found failed`), or `find ~/.config/systemd/user -mindepth 2 -xtype l`
shows `*.wants/` links into a pre-move path (e.g. after the `home/` refactor).

**Fix:** the failed rows are only the manager's memory of a unit that is gone:
`systemctl --user reset-failed <unit>`. For a dangling enable link, delete just
that link and rerun the stow step (`./scripts/converge.sh user stow`), which
re-enables its unit list; anything outside that list needs `systemctl --user enable`.

**Never `systemctl --user disable`/`reenable` a stow-linked unit.** The unit file
in `~/.config/systemd/user/` is a symlink out of the search path, so systemd treats
it like a `systemctl link` and deletes the stow link along with the enable link
(2026-09-13: seven units went `not-found` at once). The stow step puts them back.

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

## `*.wonhomelab.net` unreachable on the home LAN (Nextcloud, and restic backups fail)

Backups go to `restic.wonhomelab.net` (rest-server behind the same Caddy and public IP), so everything below applies to them unchanged; probe that host instead of `nextcloud` when it is the backup that fails.

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
An attempt that gets no HTTP answer over a valid cert from `restic.wonhomelab.net` is skipped by
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

## Media/brightness keys dead — swayosd-server refuses every action

**Symptom:** volume and brightness keys silently do nothing. No error, no OSD.

**The binds are not the problem** — don't go hunting in `hyprland.lua`, `keyd`,
or xkb. `hyprctl binds | grep XF86` lists them, `hyprctl configerrors` is empty,
and `hyprctl submap` says `default`.

**Confirm it.** A healthy server answers `b true` *and* the value moves:

```sh
wpctl get-volume @DEFAULT_AUDIO_SINK@
busctl --user call org.erikreider.swayosd-server /org/erikreider/swayosd \
  org.erikreider.swayosd HandleAction 'ssa(ss)' SINK-VOLUME-LOWER "" 0
wpctl get-volume @DEFAULT_AUDIO_SINK@
```

Use `LOWER`, not `RAISE`: a server pinned at 100 % answers `b false` to
`BRIGHTNESS-RAISE` for the honest reason that there is nothing to raise, which
reads exactly like the failure. Check `CAPSLOCK` too — a server that refuses
*that* as well is wedged wholesale, not confused about one backend.

**Fix** (works for every cause below):

```sh
systemctl --user restart swayosd-server
```

Since 2026-09-06 the server is a user unit (`swayosd-server.service`), not a
child of Hyprland. If `journalctl --user -u swayosd-server` loops on
`An instance of SwayOSD is already running!`, a stray server launched outside
the unit holds the app id while the unit crash-loops; the stray can also lose
its `org.erikreider.swayosd-server` bus name, so the client fails with
`The name is not activatable`. Kill it and let the unit own it:

```sh
pkill -x swayosd-server; systemctl --user reset-failed swayosd-server
systemctl --user restart swayosd-server
```

Never launch the server from `hyprland.lua` or `hyprctl dispatch` again; until
2026-09-12 a leftover `exec_cmd("swayosd-server")` did exactly that at every
login.

**Why it fails *silently*, whatever wedged it:** `swayosd-client` exits
non-zero only when nothing owns the bus name at all. A server that answers and
refuses still gets the client a clean exit 0 — so the `|| wpctl ...` fallbacks
in `hyprland.lua` cover the wrong failure. Exit status proves nothing here;
only the D-Bus reply and the resulting value do.

### Cause 1: stale binary after an upgrade

`make sync` upgrades packages but does not restart the daemons Hyprland
launched, so a long-lived session keeps running the *deleted* old binary. When
swayosd bumps its D-Bus signature, the new `swayosd-client` and the stale
in-memory server stop agreeing. (0.3.1 -> 0.3.2 changed `HandleAction` from
`(ss)` to `(ssa(ss))`.) `make sync` now restarts a stale swayosd-server after an
upgrade; the manual fix still applies to a session that has not synced since.

Same trap, other daemons — list everything still running an upgraded-away
binary before blaming config:

```sh
for p in /proc/[0-9]*; do
  readlink "$p/exe" 2>/dev/null | grep -q '(deleted)' &&
    printf '%s\t%s\n' "${p#/proc/}" "$(readlink "$p/exe")"
done
```

### Cause 2: pipewire restarted out from under it

**Confirmed 2026-09-06**, and it is now fixed automatically — the lead recorded
here on 2026-09-05 was right. SwayOSD opens one PulseAudio connection at startup
and never reconnects. Restart pipewire (or just `pipewire-pulse`) and the server
keeps its bus name, keeps answering, and every volume action becomes a no-op.

The proof, if you ever need to re-run it: with the server up and working,
`systemctl --user restart pipewire-pulse`, then call `SINK-VOLUME-LOWER`. It
answers **`b true`** and the volume does not move. That is worse than the
`b false` this recipe opens with — a wedged server can report success.

Brightness is the tell for how bad it is. It has no Pulse dependency, so:

- volume dead, brightness fine → the Pulse connection died; this cause.
- volume *and* brightness dead, `CAPSLOCK` answering `b false` → wedged
  wholesale. Seen on 2026-09-06 after a resume in which the `audio-health` sleep
  hook restarted the full stack (pipewire + wireplumber + pipewire-pulse) twice
  in one second. Same fix; a restart clears both.

**The fix is `swayosd-server.service`**, in the `hypr` package. `PartOf=` plus
`WantedBy=pipewire-pulse.service` makes systemd take the server down and bring
it back whenever the Pulse server moves, in either direction:

- `PartOf` propagates a *stop or restart* of pipewire-pulse to swayosd.
- `WantedBy` covers the rest: `restart pipewire` reaches pipewire-pulse as a
  separate stop and start, which `PartOf` alone would not restart from.

Enabling the unit is what installs the `pipewire-pulse.service.wants` symlink,
so it is not optional decoration — `make sync` enables it. `hyprland.lua` starts
the unit instead of the binary. This also means `audio-health --heal` needs no
swayosd logic of its own; the propagation covers it.

**Do not go back to running it as a Hyprland child.** A child cannot be tied to
another unit's lifetime, which is the whole failure.

---

## Speakers bright and thin again

The speaker EQ is a filter graph inside the speaker sink itself (`speaker-measure --apply`), which WirePlumber loads every time it creates that sink. If the speakers sound raw anyway:

```sh
ls ~/.config/wireplumber/wireplumber.conf.d/60-speaker-eq.conf   # written by --apply
pw-dump | grep -c audioconvert.filter-graph.0                     # 1 while the speakers are the sink
pw-metadata -n default | grep speaker-eq.bypassed                 # bypassed and never restored?
journalctl --user -u pipewire -b -g filter-graph                  # rejected by PipeWire?
```

- **Left bypassed.** Measuring and the quick-settings toggle take the graph out and record `speaker-eq.bypassed`; measuring puts it back on exit, Ctrl+C included. A run killed outright leaves it out: turn Speaker EQ back on in quick settings, or restart wireplumber, which rebuilds the sink with it.
- **Rejected.** `Can't load filter-graph` means PipeWire could not build the graph, yet the sink still carries it in its properties and quick settings still shows it on. The likely cause is a PipeWire upgrade changing the graph format: compare the rule with `man pipewire-props`, fix `eq_conf_body` in `speaker-measure`, and run `--refit <run> --apply`, which warns if it is still rejected.
- **Renamed sink.** A count of 0 with nothing plugged in (quick settings says unavailable) means the rule no longer matches the speaker sink's name, which a kernel or alsa-ucm-conf update can change. `--refit <run> --apply` with nothing plugged in writes the new name.
- **The config is gone.** `speaker-measure --refit <run from ~/.local/state/speaker-measure/applied.json> --apply` writes it again.
- **Measured at another volume.** The amps' protection is level-dependent, so a preset only fits near the volume it was measured at (`sink_db` in the run's `meta.json`). At a much different listening volume, run `--verify` there, and measure again if the EQ scores worse than flat.
- **Running, and still sounds wrong.** A fit is only as right as its mic: the built-in array and a phone at the seat disagree by about 10 dB at 3-5 kHz (`speaker-measure --compare 20260909T235943 20260911T210058`). Tune by ear at your usual volume with music playing: `speaker-eq` (quick settings, Tune speakers). Listen to Edited, Saved or No EQ at matched loudness (Space switches), and Load starts from any other run. Save writes the result as a run and restarts wireplumber; closing without saving puts the saved EQ back.
- **Left mid-edit.** A `speaker-eq` killed outright (`kill -9`, a crash) leaves its last edit playing until the speaker sink is rebuilt: `systemctl --user restart wireplumber`.
- **Proving it runs.** `pw-cli enum-params <id> Props` is no proof either way: a suspended node reports no graph, and after a live change it can return a stale cache. While something plays, the speaker sink's BUSY in `pw-top` is several times higher with the EQ than without.

## Every app goes silent after hiding a filter sink

**Symptom:** `pw-play` works but `paplay` hangs, nothing appears in wiremix's
playback tab, and Firefox, Spotify and Zotero are all silent with healthy-looking
volumes everywhere. `journalctl --user -u pipewire-pulse` shows `timeout on stream`.

**Cause:** a filter-chain sink (the speaker EQ, until 2026-09-13) was given a
hidden `media.class` such as `Audio/Sink/Internal`. pipewire-pulse's
`pw_manager_object_is_sink()` matches
only `Audio/Sink` and `Audio/Duplex`, so the filter is invisible to it — but
WirePlumber still links pulse playback streams to it, and `find_peer_for_link()`
then finds no sink object, so the CREATE_PLAYBACK_STREAM reply is never sent and
the client waits out a 35 s timeout. Native PipeWire clients are unaffected,
which is exactly what makes it look like a pulse bug.

**Fix:** a filter sink must be exactly `media.class = "Audio/Sink"`, and
upstream has twice refused a way to hide one (closed MRs !2064 and !2066, the
second proposing `node.hidden`). Hiding a *source* this way is fine. To add no
node at all, run the filter inside the device's own sink instead:
`audioconvert.filter-graph.N` in a `monitor.alsa.rules` `update-props` rule,
which is how the speaker EQ runs now. A 2026-09-11 note here called that inert
on an ALSA sink. It is not (measured on 1.6.8 with `pw-top`, through suspend
and resume); a suspended node just does not report its graph.

## One app has no sound after an audio restart, everything else is fine

**Symptom:** after restarting `pipewire pipewire-pulse wireplumber`, a
long-running app (Chrome, Spotify) is silent and missing from wiremix's playback
tab entirely, while anything launched since works. Quitting and relaunching the
app fixes it.

**Cause:** not a routing bug. Those apps open one PulseAudio connection and never
reconnect when the server goes away, so they sit on a dead stream. Tell it apart
from the `media.class` bug above by what is *absent*: the app has no entry in
`pactl list short clients`, and `journalctl --user -u pipewire-pulse` shows **no**
`timeout on stream` (the hidden-sink bug logs those instead).

**Fix for Chrome without losing tabs** — restart only its audio process (fish):

```fish
kill (pgrep -f "utility-sub-type=audio.mojom.AudioService")
```

Chrome respawns it on demand, so no client reappears until a tab next plays
audio; reload the tab if playback stays stuck. For Spotify, relaunch it.

**Consequence worth remembering:** `speaker-measure --apply` restarts the audio
units, so it will orphan whatever is already playing. Re-measure before opening
what you want to listen to, or expect to nudge those apps afterwards.

## Speakers silent, but every volume readout looks fine

**Symptom:** no sound from the laptop speakers. Waybar, `wpctl`, and the OSD
all show a healthy volume on a `Speaker` sink that is selected and unmuted,
streams are linked to it and playing, and nothing errors anywhere.

**The readouts are lying.** WirePlumber lost its *device* object for the SOF
card while the card's **nodes** survived inside the pipewire daemon. An orphan
node still looks like a sink and still accepts streams, but no session manager
is managing the card, so its volume is applied in software and never reaches
the hardware mixer. Audio plays into a node wired to nothing.

Two facts make this hard to spot by hand, and are why it is worth a script:

- **The hardware mixer is the tell, and only when the card is healthy.** On a
  managed card `wpctl set-volume` moves ALSA's `Master`/`Speaker`. On an
  orphaned one it moves nothing:

  ```sh
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.3
  amixer -c sofhdadsp sget Master     # unchanged => the card is unmanaged
  ```

  Turning `Master` up by hand restores sound, which makes it *look* like a
  stuck mixer. It isn't — the volume is real, the routing is broken, and the
  next resume undoes it.

- **It is self-perpetuating, and restarting WirePlumber does not fix it.** The
  orphan nodes hold the PCM open, so a fresh WirePlumber cannot re-create the
  device either; it comes up clean and still ignores the card. Only restarting
  **pipewire itself** destroys the orphans.

Confirm it in one line — every card in `/proc/asound/cards` should appear here:

```sh
pw-dump | jq -r '.[] | select(.type=="PipeWire:Interface:Device")
                     | .info.props["alsa.card"] // empty'
```

Corroborating symptom: duplicate node *names*. PipeWire suffixes genuinely
distinct nodes (`.2`, `.3`), so two nodes sharing a name verbatim means a
device leaked them. They accumulate silently — 24 duplicate HDMI sinks and 6
duplicate mic sources over ~32 h of uptime, with `capture open failed: Device
or resource busy` storms as they fought each other for the same PCM.

**Fix:**

```sh
audio-health --heal     # no-op when healthy; restarts the stack when not
```

`make status` reports the same check, and a `system-sleep` hook runs `--heal`
after every resume, which is where this originates: the cs35l41 smart amps
reset and reload firmware on each resume (`journalctl -k -g cs35l41`) and the
device object does not always survive it. Volume itself is *not* restored —
that is real user state, and healing the card is what makes it truthful again.

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
Worth a check in a sleep hook:

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

**Since the 2026-09-12 reset the sleep path has no decisions in it.** The 30-min
listener runs `systemctl suspend-then-hibernate` unconditionally, on AC too
(it hibernates after `HibernateDelaySec`). So if it stayed awake, one of these
is true:

- **hypridle is not running** or its config failed to parse:
  `pgrep -a hypridle`; `timeout 3 hypridle` prints every rule it registered.
  It is an `exec-once`, so after editing, `pkill -x hypridle; setsid hypridle &`.
- **A Wayland idle inhibitor is held** (a browser tab playing media is the usual
  one). These are invisible to `systemd-inhibit --list`.
- **A logind sleep inhibitor is held:** `systemd-inhibit --list`.

**Do not re-add a power gate to that listener.** It failed three ways: no
idle→sleep path at all (08-18), a misread power state (08-27, ucsi nodes
latching `online=1`), and a correct "on mains" that went stale when the charger
came out (09-12). To keep the machine awake for a long job, use
`systemd-inhibit --what=idle <cmd>`.

**Backstop:** UPower hibernates at 5%
(`system/upower/UPower.conf.d/70-hibernate-earlier.conf`, installed as a real file
because upower runs `ProtectHome`). Stock is 2%, about 8 min at ~10 W. The same
file sets the low/critical levels `battery-logd` notifies on.

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

**Not every long wake is a bug.** Lid closed on AC is plain `suspend` by design
(`HandleLidSwitchExternalPower=suspend`), so hours in s2idle while plugged in is
correct. Check `Performing sleep operation 'suspend'` vs `'hibernate'` first.

**Never set `HibernateOnACPower=no`.** With it, an s2h timer wake on AC
re-suspends instead of hibernating, and that re-suspend always fails:
`nv_pmops_suspend returns -5`, "PreserveVideoMemoryAllocations module parameter
is set. System Power Management attempted without driver procfs suspend
interface", `Failed to put system to sleep. System resumed again`, and the
machine stays awake. nvidia's `/usr/lib/systemd/system-sleep/nvidia` writes
`resume` to `/proc/driver/nvidia/suspend` on every post, but in the s2h branch
only re-primes it for `hibernate` and `suspend-after-failed-hibernate`, not the
AC loop's plain `suspend`. Keep `PreserveVideoMemoryAllocations=1` and the
`nvidia-*` units: on the proprietary driver `UseKernelSuspendNotifiers=1` does
not cover VRAM preservation (README, 595.45.04 changelog), whatever the Arch
package and ArchWiki imply.

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

**Hibernate compression and `image_size` are kernel defaults.** lz4 was tried
from 2026-09-10 and dropped in the 09-12 reset. Don't raise `image_size`: an
8 GiB target swapped out ~7.5 GiB in 115 s before the write (09-10 test).
A kernel upgrade without a reboot is *not* a cause of
cold boots: x86 checks only arch data in the image header, not the kernel
version.

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
`reflector.conf` in `SYSTEM_COPIES`). Re-run `make sync`, or
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

## Black screen after resume, but the compositor is fine

The panel is dark and everything you would normally check says the session is
healthy: `hyprctl` answers, Hyprland holds tty1, no crash, no OOM, the kernel
reports the connector `connected / enabled / dpms On` under
`/sys/class/drm/card0-eDP-1/`, and the backlight is at full.

**It is one stuck flag, not a wedge.** hypridle's 15-min listener dpms'd eDP-1
off, the 30-min listener then slept the machine. On resume Hyprland restores
the CRTC it had, but a connector it believes is disabled stays disabled. The
Hyprland log settles it in one grep:

```bash
grep -nE "Enabling seat|Modesetting eDP-1|is disabled, releasing" \
  /run/user/1000/hypr/*/hyprland.log | tail
```

A healthy resume prints `Modesetting eDP-1 with 1920x1080@60.00Hz` and
`Connector eDP-1 enabledState changed false -> true` about 120 lines after
`[libseat] Enabling seat`. A stuck one prints `eDP-1 is disabled, releasing
crtc 151` on every recheck and never modesets again.

**Under the Lua config, `hl.dsp.dpms("on")` is a toggle.** The dispatcher reads
only a table (`{ action = "on"|"off"|"toggle", monitor = ... }`); any string
falls through to toggle (`hlDpms` in `LuaBindingsDispatchers.cpp`, 0.56.2). So
`after_sleep_cmd` turned a lit panel *off*, and alternating dispatches "failing"
(below) is exactly what a toggle looks like. hypridle.conf used the string form
until 2026-09-14. Always pass the table.

**Why the `dpms on` that normally saves it goes missing.** Two paths turn the
panel back on, and both can miss the same resume:

- **A single `dpms on` right after a resume gets dropped.** Measured
  2026-09-08 on a plain suspend cycle: the first two dispatches returned `ok`
  and left `dpmsStatus` false; the third, 2 s later, took. The old config had
  exactly one shot (`after_sleep_cmd = hyprctl dispatch dpms on`) and no way to
  notice it had missed.
- `key_press_enables_dpms` needs a keypress **into the Hyprland session**. Wake
  the machine and walk away, or switch to a text VT to investigate, and nothing
  ever generates one.

(An earlier draft of this entry blamed the seat handover — `after_sleep_cmd`
firing while libseat still had the seat disabled. That is wrong: the signal
hypridle waits on, `PrepareForSleep(false)`, arrives ~20 s *after* the seat is
back. The `ERR drm: Session inactive` pairs in the log sit before every
`Enabling seat`, on healthy resumes too, so they are not the tell.)

From another VT every `hyprctl dispatch` is swallowed the same way. That is why
the softer recoveries all reported success and changed nothing, and why this
looked for two incidents like it needed the session killed.

**Fixed by `hypr-wake-panel`** (hypridle's `after_sleep_cmd`, 2026-09-16,
after the fourth recurrence). It sends `dpms on`, waits for the session to be
Active, then checks `grim -o eDP-1`; if no frame comes back it cycles
`dpms off` → `on` and checks again, up to 10 times. That covers both the
dropped first dispatch and the `dpmsStatus: true` variant below, which the
stock single `dpms on` could not reach. It logs only when it had to act:
`journalctl -t hypr-wake-panel`. (It replaces `hypr-dpms-guard`, removed in the
2026-09-12 reset, minus its before-sleep half.)

**A blinking underscore is a different screen: VT 63.** On
suspend-then-hibernate, `nvidia-sleep.sh suspend` runs `chvt 63`. The switch
back comes only from `nvidia-resume.service`, which is ordered after the sleep
service, so it waits on every `system-sleep` post hook. Until then no key
reaches Hyprland. From 09-04 to 09-11 the `audio-health` hook held that for
~41 s on every s2h wake (2026-09-11 incident). The hook was later deleted
outright in the 09-12 reset. If the underscore comes back, run
`systemctl list-jobs` and look for a sleep service still running, then check
which post hook is holding it. Ctrl+Alt+F1 gets you out without killing
anything. SysRq-E (Alt+PrtSc+E) takes the whole session with it, and
NetworkManager and dbus too, so a login afterwards has no network.

**Variant: `dpmsStatus` already true, so no keypress helps.** 2026-09-15,
after a suspend-then-hibernate resume, with the table-form `after_sleep_cmd`.
The log showed the stuck signature, but `hyprctl monitors` reported
`dpmsStatus: true`, so `key_press_enables_dpms` had nothing to do. hyprlock was
alive and taking keys the whole time (a blind password attempt failed at
12:42:21 with the panel still off). What brought it back was an explicit
`dpms off` then `on`, dispatched while tty1 was active, which logged
`Modesetting eDP-1` right away:

```bash
hyprctl dispatch 'hl.dsp.dpms({ action = "off", monitor = "eDP-1" })'; sleep 2
hyprctl dispatch 'hl.dsp.dpms({ action = "on", monitor = "eDP-1" })'
```

**Run it from a waiter, not from your text VT.** `loginctl activate 6` makes
the session Active, but the moment you switch back to read the result it goes
inactive again and every later dispatch is dropped in silence — that is what
made 2026-09-16 take three rounds. Arm a `systemd-run --user` script that polls
`loginctl show-session <id> -p Active` first, *then* press Ctrl+Alt+F1 and stay
there. `drm: Disabling output eDP-1` / `enabledState true -> false` at the tail
of the log is just that switch away, not a relapse.

Verify from the log, never from the dispatcher: count `Modesetting eDP-1`
before and after, since `ok` with no new modeset means nothing happened. A
`grim -o eDP-1` that succeeds (it needs `WAYLAND_DISPLAY=wayland-1`) proves
frames reach the connector; it times out while the output is disabled.

If the cycle logs no modeset even with the VT active, force the output down and
back:

```bash
hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = true })'; sleep 2
hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = "auto" })'
```

`hyprctl keyword` is rejected under the Lua config ("keyword can't work with
non-legacy parsers"). A forced re-enable can come back at 40 Hz or leave only
`FALLBACK`; `hyprctl reload` re-runs `monitors.lua` and restores the layout.

The same day, the `hyprlock-restart` sleep hook was deleted rather than fixed:
it killed a live hyprlock and cycled the session lock on every resume, inside
the exact window this bug lives in, for a crash that stopped happening in April.
`make sync` removes the installed copy.

**If it happens anyway**, get back to the Hyprland VT and let a keypress land:

```bash
chvt 1            # or: loginctl activate <id>
```

then touch the keyboard. Killing the session
(`loginctl terminate-session <id>`) still works, still costs every GUI app in
`session-<id>.scope`, and is no longer the first move.

**Three things this is NOT** — each cost time on 2026-09-02:

- **Not a compositor wedge.** On an *inactive* VT, `grim` timing
  out, `hyprctl dispatch` returning `ok` with no effect, and hyprlock's threads
  sitting in `futex_do_wait` are all NORMAL. Check
  `loginctl show-session <id> -p Active` **before** reading anything else into
  those. State `S` is idle waiting, not a hang.
- **Not seatd.** `Backend 'seatd' failed to open seat, skipping` is on every
  boot; the next line reads `Seat opened with backend 'logind'`.
  `seatd.service` is disabled by preset and should stay that way.
- **Not a `monitors.lua` bug.** If the last `Modesetting` before the sleep is a
  clean `1920x1080@60.00Hz`, the layout code is innocent. This entry used to
  read that as proof dpms was innocent too — it is not. dpms is the whole bug.

---

## `suspend-then-hibernate` has never actually hibernated

Worth knowing before you debug a sleep: on this machine the hibernate leg
always aborts. It is not a regression and not the wake-source bug below.

```bash
# attempts vs. images actually written, this boot
journalctl -k -b | grep -c "hibernation: hibernation entry"
journalctl -k -b | grep -c "Image saving progress:   0%"
```

Measured 2026-09-08: **0 images in 11 attempts** on 7.2.2-arch1-1, and 2 in 18
on 7.1.8. Every attempt allocates the snapshot (~12.8 GB in ~12 s), enters the
ACPI S4 path, comes straight back out, and exits without writing:

```
PM: hibernation: Allocated 12781556 kbytes in 11.67 seconds
ACPI: PM: Preparing to enter system sleep state S4
ACPI: PM: Saving platform NVS memory
ACPI: PM: Restoring platform NVS memory      <- no "Image saving progress"
ACPI: PM: Waking up from system sleep state S4
PM: hibernation: hibernation exit
```

**Do not "fix" it on the strength of that log alone.** What the machine lands
in afterwards is *better* than s2idle, measured from `battery.db`:

```bash
sqlite3 ~/.local/state/battery.db "
WITH s AS (SELECT ts, capacity, LAG(ts) OVER (ORDER BY ts) pts,
                  LAG(capacity) OVER (ORDER BY ts) pcap FROM samples)
SELECT datetime(pts,'unixepoch','localtime'), round((ts-pts)/3600.0,2) AS hours,
       pcap||'->'||capacity, round((pcap-capacity)/((ts-pts)/3600.0),2) AS pct_hr
FROM s WHERE ts-pts > 1200 ORDER BY pts;"
```

The 1.02 h rows are the s2idle leg before the handoff: **~1 %/h**. The long
rows are what follows the aborted hibernate: **0.06–0.14 %/h** over 7–17 h,
with RAM and the session intact. Ten times cheaper than the s2idle it replaced.

So the arrangement is worth keeping, but call it what it is: there is no image
on disk, so **losing power while "hibernated" loses the session**. The one real
cost was the black screen above, and that is fixed at the compositor end rather
than by taking the hibernate leg away.

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

---

# Incident log

## 2026-09-16 — Fourth black screen after resume; SysRq-E made it look like dead wifi

Suspend 04:02:30, resume 04:15:05 (s2idle leg only), wifi reconnected by
04:15:11, panel dark on tty1. Mashing keys at 04:16:17 sent SysRq (Alt+PrtSc)
T/W/E. E SIGTERMed everything: NetworkManager `exiting (success)` 04:16:18,
Hyprland, the user manager. The tty1 login and Hyprland that followed had no
NetworkManager, which read as "the wifi driver is down". The driver was fine.
SysRq U/I/O then powered off at 04:16:55. The Hyprland log was lost with
`/run`, so the variant is unconfirmed, but the setup is the same. Rather than
recover by hand a fifth time, `after_sleep_cmd` is now `hypr-wake-panel`
(verify with grim, cycle dpms). Escape without killing anything is still
Ctrl+Alt+F1 and the off→on recipe.

## 2026-09-16 — Black screen after an s2h resume; third one, and dpms was true again

Suspend 00:31:50, resume 00:48:28, same stuck signature (`eDP-1 is disabled,
releasing crtc 151`, no `Modesetting` after `Enabling seat`) and the same
2026-09-15 variant: `dpmsStatus: true`, so no keypress could help. Recovered by
the documented `dpms off` → `on` cycle. The delay was entirely operational: the
first cycle ran from tty2 after `loginctl activate 6`, the user switched back to
tty2 to read the result, and every dispatch after that was swallowed — three
rounds of "ok" with an empty log delta. A forced `hl.monitor` disable/enable in
the middle left `FALLBACK` and then 40 Hz, both cleared by `hyprctl reload`.
Once the cycle ran from an armed waiter while tty1 stayed active it logged
`Modesetting eDP-1` and `enabledState false -> true` immediately, and `grim`
went from timing out to a full capture. Two occurrences now with `dpmsStatus`
true, which is the case stock `after_sleep_cmd` cannot reach: the dispatch it
sends is a no-op when Hyprland already believes the panel is on. The next
recurrence should fix that end (`after_sleep_cmd` doing off→on, or restoring
`hypr-dpms-guard`'s verify-and-retry) rather than another manual round.

## 2026-09-15 — Claude Code "stream closed before completion": model-wide provider dip

Three failures 23:53–00:02, each ~65 s in at ~2k output tokens. OpenRouter's generation endpoint showed `finish_reason: "error"` on all three, all `provider_name: "AtlasCloud"` (health-flagged −2); healthy requests landed on StreamLake. The key is a free-tier OpenRouter key via `claude-or` on the `opus` slot; network was cleared as a suspect by two 53–78 s streams through the `_PBGuest` guest WiFi passing clean. Fix at the time: preset `cc-opus-flash` with `provider.ignore: ["atlas-cloud"]`. **Partly wrong** — the next day OpenRouter's uptime tracker showed the dip hit every provider of this model, not just AtlasCloud, which was back at 97.5% and unflagged; the three failures landing on it look like coincidence. Superseded by the all-Flash layout (`cc-flash-high`/`cc-flash-med`/`cc-glm-flash-low`), which drops the exclusion and, more importantly, drops a `provider.sort` that had been disabling the uptime filter.

## 2026-09-14 — restic moved off Nextcloud WebDAV to rest-server

Every `forget --prune` filled Nextcloud's Activity feed with "You deleted <hash>, …" for the pack files, and Activity cannot hide a folder. The repo now lives behind rest-server on the homelab: stack `/Totoro/Docker/Restic/` (container `rest-server`, `--private-repos`, UID 1002, proxy-net only), data `/Totoro/Restic_Backups/jaeho` (mode 700), Caddy `@restic` block in jaewon's Caddyfile (`Caddyfile.bak-restic-20260914`). The login is in `~/.config/restic/rest.env`, which the service reads and `bootstrap.sh` writes. The repo was moved with `cp -al` from `NextCloud_AIO_Data/jaeho/files/Backups/restic`, so both paths shared inodes until the Nextcloud copy was deleted.


As a WirePlumber smart filter, the EQ put "Speaker EQ", "Monitor of Speaker EQ" and a "corrected output" playback stream in every mixer and picker, which was confusing. `speaker-measure` now writes it as `audioconvert.filter-graph.0` on the speaker ALSA node (`wireplumber.conf.d/60-speaker-eq.conf`), and the quick-settings toggle bypasses it with a live Props param instead of the `filters` metadata. The same preset (run `20260911T210058`) was carried over unchanged. `speaker-measure` was first committed with this change. The old `pipewire.conf.d/60-speaker-eq.conf` never was; restic snapshots before 09-13 22:10 have it.

## 2026-09-13 — Mic echo canceller removed

The PipeWire echo canceller (`audio` package, `99-echo-cancel.conf`, added 09-11) put two permanent recording streams in every mixer and ran the microphone whenever anything woke the speaker path, level meters included. It was taken out along with waybar's privacy ignore entries for its streams. Expect echo back in speaker calls from apps without working cancellation of their own: on 09-11 Firefox's did nothing, and Claude's voice mode echoed on the raw mic until the canceller went in. If that returns, restore the file; it was never committed, and restic snapshot `e167eb98` (09-13 18:13) and earlier have it.

## 2026-09-12 — s2h timer wake on AC could not re-suspend; awake from 22:40

Suspended 21:40 (s2h, battery 72%, charger went in while asleep). At 22:40 the `HibernateDelaySec` timer woke it on AC, so with `HibernateOnACPower=no` systemd re-suspended; both s2idle attempts failed in a second with `nv_pmops_suspend returns -5` / "attempted without driver procfs suspend interface", `systemd-suspend-then-hibernate.service` failed, and the machine stayed up. Same signature on 2026-09-07 00:15 (unrecorded at the time). Journal since 06-07: 45 battery `suspend → hibernate` handoffs all clean, the only 2 `suspend → suspend` handoffs both failed. Cause and rule under "Never set `HibernateOnACPower=no`". Fix: dropped that line from `system/systemd/sleep.conf`, so the AC wake hibernates like the battery one. Upstream gap worth reporting to NVIDIA: the hook's s2h branch has no `pre:suspend` case.

## 2026-09-12 — Sleep reset to near-stock after a third battery drain

Reported as "failed to sleep/hibernate again". The 09:26 hibernate itself worked (restored 12:58) — it was `hypr-battery-monitor`'s 7% backstop. At 23:35 the idle listener's gate had correctly read `on mains (99%, Charging)` and declined; hypridle fires `on-timeout` once per idle period, so after the charger came out nothing looked again. 99% → 7%.

That was the third fix to the same gate, on top of hooks that had caused their own incidents (`audio-health` holding VT 63 on 09-11). So instead of patching it again, everything not stock or tied to a hardware fault was removed:

- **Removed:** the idle listener's AC gate (`hypr-sleep-if-idle`), `hypr-battery-monitor`, `hypr-dpms-guard`, the `audio-health` sleep hook (`audio-health --heal` stays as a manual tool), `tmpfiles/hibernate.conf` (lz4), `tmpfiles/pm-debug.conf`. `make sync` removes the installed copies.
- **Now stock:** hypridle in its example shape (sleep at 30 min, ungated). Low-battery hibernate is UPower's `CriticalPowerAction`, raised from 2% to 5%.
- **Kept, each for a documented hardware or driver fault:** the nvidia modprobe options, no nvidia in `MODULES`, swap + `resume=`, the lid drop-in and `sleep.conf` (s2idle-only platform), `fuse-mounts` (sshfs D-state), and the i2c-hid no-wake rule.

Behavior changes: a plugged-in idle machine now sleeps after 30 min (`systemd-inhibit --what=idle` to hold it), and low-battery warnings come from `battery-logd`, which shows UPower's warning level (thresholds in the same UPower drop-in) as a notification. If a removed layer's bug returns, restore just that layer and add a dated line here rather than a new mechanism. `hypr-sleep-if-idle` and `hypr-battery-monitor` are in git; `hypr-dpms-guard`, the `audio-health` hook, and `tmpfiles/` were never committed and exist only in restic snapshots from before 2026-09-12.

## 2026-09-11 — "Authentication required" keyring prompt at a random point after every login

gcr-prompter asked for the "Default keyring" password whenever the first secret reader started (Chrome, VS Code, Firefox, Zen, Zotero, Nextcloud, LosslessCut all keep a key in it), so the prompt had no visible cause. Two gaps stacked. A tty1 login goes through `/etc/pam.d/login`, which never loaded `pam_gnome_keyring` (only the unused `sddm` stack does). And the module unlocks only the keyring named `login`, but this one was `Default_keyring.keyring`, so it would not have been unlocked even from sddm.

Renamed it to `login.keyring` with the daemon stopped, and set `default` to `login` (backup in `~/.local/share/keyrings.bak-2026-09-11`). `system/pam/login` and `system/pam/passwd` (SYSTEM_COPIES) add the module, and `passwd` keeps the keyring password in step with the login one. The keyring's label inside the file is still "Default keyring". If the prompt comes back, the keyring and login passwords have drifted apart.

## 2026-09-11 — Blinking underscore after an s2h wake; SysRq-E, reboot

On battery, the idle timer started suspend-then-hibernate at 15:11. A keypress woke it at 15:46:59, before `HibernateDelaySec`. The kernel resumed cleanly (`PM: suspend exit`), but the screen was a black console with a blinking underscore. The user pressed SysRq-W/R/Q/W at 19–32 s and then E. That killed the session, and they rebooted.

Nothing was hung. The console was VT 63, where `nvidia-sleep.sh suspend` parks it. For s2h, the `nvidia` post hook only writes `resume` to procfs, and the `chvt` back is left to `nvidia-resume.service`, which starts after the sleep service exits. The sleep service was still inside the `audio-health` post hook. That hook waited its 20 s settle, found both cards "unmanaged", restarted pipewire and waited again. SysRq-E killed it at 15:47:32, and `nvidia-resume` ran at 15:47:34. The cards read as unmanaged only because VT 63 has no session, so logind had taken the user's ACLs off `/dev/snd`. The journal shows the same `unmanaged` → restart → `still unhealthy after restart` on **every** s2h wake since 09-07, adding 41 s each time. On the alarm-to-hibernate path that 41 s is lid-shut awake time, and it included the 09-10 19:50 hang. The needless pipewire restart is also what took EasyEffects down on 09-10. The 09-08 note that "~20 s of dark is normal" was this bug, misread.

The hook now starts `audio-health-resume` with `systemd-run` and returns. That transient unit waits until seat0's active session is the user's again (counting polls, so a hibernate in between doesn't use up the wait), then runs the same `--heal`. The `irq/108-GTX7937` thread stuck in D in SysRq-W is the known free-running touchscreen (it sits in D on a healthy boot too) and is unrelated.

## 2026-09-10 — Hung at hibernate entry in a bag; ~2 h hot, 61% → 12%

Lid shut 18:50 on battery; s2idle until the `HibernateDelaySec` alarm at 19:50. The journal ends at `PM: hibernation: hibernation entry` / `Filesystems sync` (19:50:45). Found burning hot with a blinking-underscore console that ignored every key including power; held power off. The 21:58 boot logged `PM: Image not found (code -22)`, so no image was ever finished. battery-log: 40.2 Wh at `presleep`, 8.2 Wh at the next `start`. An hour of s2idle is under 1 Wh, so about 31 Wh went in roughly 2 h (~15 W): the kernel was running, not off. No pstore record. Afterwards temps, dGPU (P8) and battery full capacity were normal.

It was the first hibernate since `tmpfiles/hibernate.conf` (lz4, 8 GiB `image_size`) was applied at 14:10. The identical s2h cycles at 11:39 and 12:48, same nvidia sleep path, hibernated and restored on the kernel defaults. Correlation only: nothing after `Filesystems sync` reaches disk. Re-tested at a desk the same night on 7.2.4. The test raised the console loglevel to 8, set `console_suspend=N`, and stopped keyd, whose frozen exclusive grab is why no key (SysRq included) did anything. Four runs all passed as real power cycles: `pm_test=core`, a real hibernate, the full s2h path with a 2 min delay, and a real hibernate holding 12 GiB of random anonymous memory. Not reproduced. The differences left can't be recreated: the 9-day session, and running 7.2.2 with 7.2.4 installed. The pressure run did expose the 8 GiB target's cost: 115 s swapping out ~7.5 GiB before the write. So `image_size` went back to the default, and only lz4 stayed.

## 2026-09-10 — Speaker EQ gone after resume; EasyEffects had aborted at 11:39

Resumed 11:38:50; `audio-health` found both cards unmanaged and restarted pipewire at 11:39:10. EasyEffects aborted with a core dump and nothing restarted it, because `speaker-measure --apply` had installed an XDG autostart entry this Hyprland session never runs. Restarted by hand later, it applied the speaker correction to the earphones that were plugged in by then. Fixed with `easyeffects.service` tied to pipewire, and presets autoloaded per output (Speaker route gets the correction, everything else `flat`). Testing the unit turned up the second failure: the same restart rewrote WirePlumber's saved default sink to Headphones, bypassing the EQ with EasyEffects alive; the unit's `ExecStartPost` now sets it back. Verified by repeating the exact restart `audio-health` performs: EasyEffects back under a new pid, default still `easyeffects_sink`. Corrected the same afternoon: that `ExecStartPost` was backwards and is gone. EasyEffects moves streams into its sink itself and ignores its own sink as a default, so with `easyeffects_sink` as the default it would have stayed on the earphones' sink after an unplug; `--apply` now puts a hardware sink back instead.

## 2026-09-08 — Resumed to a black screen; the panel had been dpms'd off since before the sleep

**Trigger:** "tty1 stuck on black screen again", the second occurrence after
2026-09-02. Session 85 looked healthy on every check that matters: `hyprctl`
answering, the connector `connected / enabled / dpms On` under
`/sys/class/drm/card0-eDP-1/`, backlight at 38400/38400, tty2 rendering fine.

**One grep of the Hyprland log settled it.** A healthy resume prints
`Modesetting eDP-1 with 1920x1080@60.00Hz` and `enabledState changed
false -> true` about 120 lines after `[libseat] Enabling seat`. This one
printed `eDP-1 is disabled, releasing crtc 151` on every recheck and never
modeset again. Hyprland restores the CRTC across a resume; it does not re-enable
a connector it believes is disabled — and hypridle's 15-min listener had dpms'd
the panel off before the 30-min listener slept the machine.

**Why both of the usual saves missed.** The single `dpms on` in
`after_sleep_cmd` was dropped: a dispatch issued in the first seconds after a
resume answers `ok` and changes nothing, and the config had no retry and no
check. Reproduced on the fix's own verification run — three dispatches were
needed, 2 s apart. `key_press_enables_dpms` needs a keypress into the Hyprland
session; the machine woke on lid-open, and the next thing that happened was a
VT switch to go debugging, after which every dispatch was swallowed for the
separate inactive-session reason.

**The 09-02 entry's "lost pageflip" reading was wrong,** and so was the rule it
produced ("nothing softer than a compositor restart works"). Both were
artifacts of diagnosing from an inactive VT.

**Fixed by** `hypr-dpms-guard` on both hypridle sleep hooks — `before` locks
and turns the panel on so nothing sleeps dpms'd off, `after` waits for the
session to be Active, dispatches, verifies `dpmsStatus` and retries — and by
**deleting the `hyprlock-restart` sleep hook**. That hook had been killing a
live hyprlock and cycling `unlock-sessions`/`lock-sessions` on every resume,
304 invocations deep, for a crash last seen 2026-04-17. Its premise expired
with nvidia-open: we run proprietary nvidia with
`NVreg_PreserveVideoMemoryAllocations=1`, VRAM survives, and the log shows
hyprlock alive before every one of those kills.

**Also established:** the hibernate leg never completes on this box, and should
be left alone anyway — see the recurring entry above.

## 2026-09-05 — Volume/brightness keys dead; swayosd-server refusing every action

**Trigger:** user said "function keys not working for like volume and
brightness". The obvious suspects all came back clean: `hyprctl binds` had all
21 XF86 entries, `hyprctl configerrors` was empty, submap was `default`, and
keyd's config only remaps capslock (it grabs Video Bus, HP WMI hotkeys and
Intel HID events, which looks alarming and was not the problem).

**The action side was broken, not the key path.** `swayosd-client
--output-volume raise` exited 0 and moved nothing. Calling D-Bus directly got
`b false` from `SINK-VOLUME-LOWER`, `BRIGHTNESS-LOWER` and `CAPSLOCK` alike —
a server alive, owning its bus name, answering, and refusing everything.

**Not the documented upgrade trap.** The entry above was written for a stale
post-upgrade binary, and this server was not one: started 2026-09-02 11:49,
a week after the 0.3.1 -> 0.3.2 upgrade, `exe` not `(deleted)`, introspection
reporting the new `ssa(ss)` signature. So the "should not recur once `make
sync` restarts it" claim was wrong — the same restart is the fix, but
staleness is not the test. The entry above now leads with the D-Bus reply.

**Origin:** most likely the previous day's audio fix. pipewire, wireplumber and
pipewire-pulse all restarted at 18:27:45 on 09-04; this swayosd-server predated
that by 31 h and would have been left holding a dead pulse connection. Does not
fully explain brightness and capslock also refusing, so it is recorded as a
lead. `/sys/class/backlight/intel_backlight` was also recreated at 18:45 the
same evening — same window, weaker fit.

**Fixed by** `pkill -x swayosd-server` plus the Lua-form relaunch. No
automation yet; the candidate is having anything that restarts pipewire —
`audio-health --heal` included — restart swayosd-server after it.

**Also found:** the fix line in the entry above only works in its
`hyprctl dispatch 'hl.dsp.exec_cmd("swayosd-server")'` form. Plain
`hyprctl dispatch exec swayosd-server` errors with `')' expected near
'swayosd'` and kills the server without replacing it.

## 2026-09-04 — Speakers silent; WirePlumber had lost the SOF card 32 h earlier

**Trigger:** user said "speaker not working". First look was misleading in
both directions: `wpctl` showed the `Speaker` sink selected, unmuted, at 0.75
with streams actively linked, while ALSA showed `Master` and `Speaker` at 0 %
(-65.25 dB). Raising them by hand restored sound, which read as a stuck mixer.

**It was not the mixer.** Two checks settled it:

- `wpctl set-volume` did not move `Master` or `Speaker` at all — not a desync,
  no linkage. PipeWire was applying volume in software.
- `pw-dump` had **no** device object for `alsa_card.pci-0000_00_1f.3`, and
  `wireplumber` held `/dev/snd/controlC0` but not `controlC1`. The card was
  unmanaged, yet 24 duplicate HDMI sinks and 6 duplicate mic sources named
  after it were still alive in the pipewire daemon.

So audio was routing through an orphaned node whose hardware stage sat at
0 dB, and every UI was reading that orphan's software volume. The `capture
open failed: Device or resource busy` storms in the journal were the duplicate
mic nodes fighting for one PCM, not a cause.

**Why it survived a restart:** WirePlumber had been restarted cleanly at 12:34
that day (after burning 51 min CPU over 1 d 8 h — it had been spinning) and
*still* did not adopt the card, because the orphan nodes held the PCM busy.
Restarting `pipewire` itself was what cleared them; WirePlumber then picked up
both cards immediately, duplicates went to zero, and `wpctl set-volume` began
driving the hardware mixer again. It also restored a genuinely persisted
volume of 0.00 for the Speaker route — the volume really had been turned down
at some point, and the orphan node is what hid that for a day and a half.

**Origin:** most likely resume. The cs35l41 smart amps reset and reload
firmware on every resume, the last one was 18:03:59 and the report came ~18:12.
Not reproduced deliberately, so the hook treats resume as a *check* point
rather than assuming it is the only trigger.

**Fixed by** `home/bin/.local/bin/audio-health` (check/heal on the invariant "every
card in `/proc/asound/cards` has a PipeWire device"), a `system-sleep` hook
running `--heal` after resume, and an Audio section in `make status`. See
"Speakers silent, but every volume readout looks fine" above.

---

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
