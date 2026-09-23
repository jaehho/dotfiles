# Troubleshooting

Current checks and recovery for this dotfiles setup, primarily `omnibook`. Start with the symptom and confirm its signature before applying a fix. Commands below are diagnostic unless labeled **Recovery**; do not run every recipe as a checklist.

Use `dotfiles` for status and `dotfiles sync` to converge. Step names come from `./scripts/converge.sh --list`. For privileged repairs, prepare a reviewed executable script in `/tmp/` for the owner; do not run sudo. Temporary scripts mentioned in old incidents are not maintained tools.

[Historical evidence and original incident log](docs/history/issues-before-2026-09-17-cleanup.md) are archived separately. That snapshot contains superseded diagnoses and commands; this file takes precedence. Keep new entries short: symptom, evidence, recovery, verification. Put long investigations in `docs/history/`.

## Find a symptom

| Area | Recipes |
| --- | --- |
| Convergence and packages | [NVIDIA beta transaction](#nvidia-beta-upgrade-deadlocks-paru), [toolchain and package drift](#toolchain-and-package-drift), [stow-linked units](#stow-linked-user-units), [AUR Node builds](#aur-node-builds) |
| Desktop | [swaync](#swaync-width-hover-and-navigation), [Lua reloads](#hyprland-lua-reloads-and-timers), [Waybar ghosts](#waybar-shows-a-closed-window), [wallpaper](#wallpaper-does-not-change), [media keys](#media-and-brightness-keys) |
| Audio and speech | [silent speakers](#speakers-silent-with-healthy-volume-readouts), [speaker EQ](#speaker-eq-sounds-wrong), [Pulse clients](#pulse-clients-silent-after-audio-changes), [Kokoro](#kokoro-and-speech-dispatcher) |
| Network | [homelab and backups](#homelab-and-backup-connectivity), [Cooper SSH](#cooper-ssh-host-key-changes), [X2Go](#x2go-latency-and-ghost-windows) |
| Hardware and sleep | [dock](#dock-input-dead-after-resume), [missing modules](#usb-hotplug-after-a-kernel-upgrade), [battery drain](#battery-drain-and-unexpected-wakes), [battery not charging](#battery-not-charging-while-plugged-in-charge-led-lit), [dark panel](#black-screen-after-resume), [cold boot](#hibernate-returns-to-a-fresh-session), [logind](#logind-ignores-its-drop-in), [wedged GPU](#dgpu-wedges-during-sleep), [touchpad while typing](#touchpad-still-moves-while-typing) |
| API sessions | [OpenRouter stream interruption](#openrouter-stream-interruption) |

## NVIDIA beta upgrade deadlocks paru

**Signature:** `nvidia-beta-dkms` requires an exact old `nvidia-utils-beta` version while paru tries to install the new utils first. The package versions must move together. `scripts/packages.sh` holds the beta set and records a decision; do not simply remove that hold.

**Recovery:** inspect current `.SRCINFO` files, refresh the affected AUR clones, and build the mutually pinned packages before installing them in one transaction. The known set includes `nvidia-beta-dkms`, `nvidia-utils-beta`, and `lib32-nvidia-utils-beta`; derive actual output filenames with `makepkg --packagelist` rather than guessing versions or globbing old archives.

The historical build used `makepkg -df --noconfirm --nocheck` because dependency checks would otherwise insist on the still-installed old/new counterpart. Use dependency-check bypass only after checking that specific version cycle and confirming build prerequisites. Prepare the root install script with the exact matched package archives. Reboot after installation, then run `dotfiles sync` and confirm the decision clears.

See the archived **“make sync: nvidia beta upgrade deadlocks paru”** recipe for the original transaction. Package availability and driver alternatives must be checked afresh; old predictions about what Arch will ship are not constraints.

## Toolchain and package drift

- **Cargo MSRV errors:** a distro `rustup` update does not itself update the Rust toolchain. `scripts/packages.sh` runs `rustup update` during tool upgrades. Compare `rustc --version` with the failing crate's requirement and inspect the user `tools` step log.
- **Tracked package installed only as a dependency:** `pacman -Qqe` omits it even though `pacman -Q <pkg>` finds it. The package step promotes tracked dependencies with `pacman -D --asexplicit`. Do not delete the manifest entry to hide this discrepancy.
- **Held or failed upgrade:** read the recorded decision and step log before changing gates. Converge never offers an interactive manifest-removal prompt; references to answering `Y` in old notes describe the retired sync script.

## Stow-linked user units

**Signature:** `systemctl --user --failed` reports `not-found`, or an enable link points at a deleted repo path.

```bash
systemctl --user --failed
find ~/.config/systemd/user -mindepth 2 -xtype l
```

**Recovery:** reset failure state only for the identified missing unit, remove only its dangling enable link, then run `./scripts/converge.sh user stow`. Units outside converge's enable list need deliberate enabling.

Do not use `systemctl --user disable` or `reenable` on a stow-linked unit to repair its enable links: systemd can delete the unit's stow symlink too. The stow step restores those links.

## AUR Node builds

The archived September 2026 investigation found independent failures from an nvm-incompatible user npm prefix, restrictions on git/remote dependencies and install scripts, and SSH GitHub URLs without a usable key. Match the actual error before changing anything.

Preserve the user npm prefix used by `scripts/packages.sh`. Scope any build workaround to that build's environment; do not globally permit dependency scripts or rewrite Git URLs. The old `NVM_DIR` bypass depended on the particular PKGBUILD helper, not an nvm guarantee. Inspect the current PKGBUILD and declared Electron dependency; compare with upstream's package manifest if the built package pulls an unexpected major. Prefer a maintained binary package when appropriate.

## swaync width, hover, and navigation

**Ownership:** jaehho fork in `~/projects/forks/swaync`, packaged through `packaging/PKGBUILD`; dotfiles owns `home/swaync/.config/swaync/` and `hypr-swaync-keys`. A newer Arch package can replace the fork: check the installed version before diagnosing missing fork behavior.

**Verified width correction (2026-09-17):** title/DND cards measured 408px, notifications 372px even with the fork's Stack expansion patch. A GTK allocation dump traced the 18px inset per side to `.widget`'s 8px margin + 8px padding on `.widget-notifications`, plus 2px Adwaita list-row padding. `style.css` now zeroes those outer insets; inner card margins supply the spacing. All four card types measured 408px with 8px gaps. Do not restore a fixed min-width or assume hexpand alone fixes it.

**Hover:** the packaged theme paints `.notification-default-action:hover` and `.notification-action:hover`. User overrides must beat those selectors; only the card and actual button should paint their hover backgrounds. Verify body-hover and button-hover separately. A valid stylesheet and successful reload are not visual proof.

**Navigation:** the fork moves directly between rows. Arrows/Home/End go directly to swaync. Action buttons show `</>` as a dim corner badge (digits 3–9 for a rare 3rd+ action) and activate on either `</>` or `,/.`; Enter runs the default action and closes the panel, `x` or Delete clears the focused notification and focus moves to the next row. `hide-on-action` is false: activating an action dismisses that notification but leaves the panel open. Ctrl+n/p use `hypr-swaync-keys send`; the helper checks visibility before injecting a key and restoring the submap. The watcher must stop and reap its subscriber cleanly. The removed AT-SPI key-stepping workaround was slow; do not restore it. Restart swaync (fish):

```fish
pkill -x swaync
sleep 1
hyprctl dispatch 'hl.dsp.exec_cmd("swaync")'
pgrep -x swaync
```

Every step guards a real failure. Kill first: launching while an old daemon holds the D-Bus name makes the new one exit silently, so the stale binary keeps serving. No `; and` after pkill: it exits 1 when nothing is running, silently skipping the launch. Sleep: the dying process must release the D-Bus name first. Hyprland exec, never a terminal `&` job: those die with the terminal (looks like "Super+. does nothing"). Plain `hyprctl dispatch exec X` is invalid under the Lua config — `dispatch` takes a Lua expression like `hl.dsp.exec_cmd(...)`.

**Keys silent only with panel open:** check `hyprctl submap` and `hyprctl binds -j`. A submap is exclusive; screenshot/media keys must also be bound there. **Album art:** swaync reads remote URIs through GIO; check `gvfs` and the art-load error before blaming the media player.

**Recovery/verification:** `swaync-client -rs` reloads CSS without clearing notifications. Restarting the daemon clears its history. For automated visual tests, use an isolated instance and retain IDs returned by `Notify`; `notification-log` database IDs are unrelated. The successful test used a temporary fork copy adapted for GTK Broadway, a private bus, and a fake MPRIS player. The production binary still requires Wayland.

## Hyprland Lua reloads and timers

**Signature:** module edits do nothing after reload, or `require()` appears successful but returns an empty table.

- Clear `package.loaded["module"]` before re-requiring; the module cache has survived reloads here.
- Check the returned module's expected API. To expose a swallowed error, run the file through `loadfile` and `pcall` rather than relying on `pcall(require, ...)` alone.
- `hl.timer` requires `type = "oneshot"` or `"repeat"`. A fired oneshot must be recreated; enabling a spent timer did not re-arm it.

Follow the existing handling in `home/hypr/.config/hypr/monitors.lua`. Check `hyprctl configerrors` and verify the behavior after reload. These are observed API traps; inspect the installed API again when upgrading Hyprland.

## Waybar shows a closed window

**Signature:** a taskbar icon remains but `hyprctl clients -j` has no corresponding client. This was observed even with the then-current orphan-map fix; the exact missed event was not proven.

**Recovery:** restart only waybar using the launch command in `hyprland.lua`. Recheck clients versus the bar. Do not change workspace rules or restart the compositor to repair stale bar state. Check upstream status anew if preparing a report.

## Wallpaper does not change

Check the pipeline before restarting anything:

```bash
systemctl --user list-timers wallhelper-fetch.timer
journalctl --user -u wallhelper-fetch -n 20
hyprctl hyprpaper listactive
readlink -f ~/Media/wallpapers/.current
```

Observed with hyprpaper 0.8: wallpaper IPC needs an explicit output name; an empty wildcard returned success without applying. Config edits required a process restart; old `preload`/`reload` IPC commands no longer worked. Use the current `wallhelper` implementation in its own project as the reference.

A directory with random ordering reselected on startup. The single `.current` link avoids that. Retention must delete only files recorded as fetched, not arbitrary old files in the wallpaper collection. A Wallhaven 403 was also resolved by simplifying the User-Agent; that is a historical clue, not proof for every HTTP failure.

## Media and brightness keys

Check the binding path first: `hyprctl submap`, `hyprctl binds -j`, and `hyprctl configerrors`. If bindings are present, inspect `systemctl --user status swayosd-server` and its journal.

A SwayOSD client exit of 0, or even a D-Bus reply of `true`, has occurred without a volume change. Verify the resulting value with `wpctl get-volume @DEFAULT_AUDIO_SINK@`. A refused “raise” at the upper limit is not a server failure.

**Recovery:** `systemctl --user restart swayosd-server`. If it reports another instance already running, identify and stop the stray instance, then let the unit own the server. Do not launch a second server from Hyprland.

Known causes were an old running executable after upgrade and a lost Pulse connection after an audio restart. `home/hypr/.config/systemd/user/swayosd-server.service` ties its lifetime to `pipewire-pulse`; preserve both its ordering/PartOf relationship and enable link.

## Speakers silent with healthy volume readouts

**Signature:** streams and volume appear normal, but an ALSA card has no PipeWire device object. Surviving orphan nodes can accept streams without working hardware control; duplicate node names corroborate it.

```bash
audio-health --check
cat /proc/asound/cards
pw-dump | jq -r '.[] | select(.type=="PipeWire:Interface:Device") | .info.props["alsa.card"] // empty'
```

**Recovery:** `audio-health --heal` restarts the stack only if its invariant fails. Restarting WirePlumber alone did not clear the orphan nodes. Recheck health and actual playback; preserve the user's volume. Applications may need reconnecting afterward.

The old automatic `audio-health` sleep hook was removed during the sleep reset. Do not infer that it is still installed from the archived September 4 incident.

## Speaker EQ sounds wrong

The recorded CS35L41 setup loaded speaker-protection firmware without vendor tone tuning; brightness alone did not establish a driver failure. EQ runs inside the speaker sink as `audioconvert.filter-graph.0`, configured by `speaker-measure`; headphones use a separate sink. `speaker-eq` loads that script as a module, so keep their shared API compatible.

```bash
ls ~/.config/wireplumber/wireplumber.conf.d/60-speaker-eq.conf
pw-metadata -n default | grep speaker-eq.bypassed
journalctl --user -u pipewire -b -g filter-graph
```

- **Bypassed or interrupted edit:** use the quick-settings EQ toggle; a sink rebuild reloads the saved graph. Restarting WirePlumber interrupts audio, so do not use it as a harmless probe.
- **Rejected graph:** sink properties can retain a graph that PipeWire failed to load. Inspect the error and `eq_conf_body` in `speaker-measure`; refit/apply only after resolving the mismatch.
- **Missing config or renamed sink:** inspect `~/.local/state/speaker-measure/applied.json` and the current sink name, then refit the saved run with `--apply`.
- **EQ runs but sounds wrong:** fits depend on mic position and listening volume. The built-in mic and a phone disagreed substantially; use `speaker-eq` for matched-loudness comparisons at the usual volume. Runs are under `~/.local/state/speaker-measure/`.

**Proof:** use `--verify` for off/on remeasurement, or compare `pw-top` busy time during playback. Suspended nodes and stale `pw-cli enum-params` results are not proof of graph execution. Mixer level meters wake the node too.

## Pulse clients silent after audio changes

Distinguish two observed failures:

| Evidence | Cause and recovery |
| --- | --- |
| One old app absent from `pactl list short clients`; newly opened apps work | Its Pulse connection died. Relaunch that app or reconnect its audio; avoid another full stack restart. |
| Native PipeWire playback works, Pulse playback hangs, journal says `timeout on stream` | Check filter sink classes. Giving a sink a hidden class made it invisible to pipewire-pulse while WirePlumber still routed streams to it. Restore `Audio/Sink`. |

The speaker EQ no longer needs a separate filter sink; it runs inside the device sink. Do not hide nodes by changing their class just to simplify a mixer.

## Kokoro and speech-dispatcher

See `home/audio/.config/speech-dispatcher/` and `home/audio/.local/bin/kokoro-tts-server`.

- Gecko's local-voice list used only the default speech-dispatcher module; Kokoro is set as default for that reason.
- `SymbolsPreproc` removed punctuation before the module saw it, so it is omitted.
- `sd_generic` delimiters split text such as “Fig. 3b”; an empty `GenericDelimiters` did not override the default.
- `uv run` forks the script, so socket activation cannot assume `LISTEN_PID` matches the Python process.

Verify the actual text received and spoken, not just successful service startup.

## Homelab and backup connectivity

**First distinguish the network and name resolution.** September observations differed between the main-router `192.168.1.0/24` network and Deco's `192.168.68.0/22`: the former reached the proper HTTPS service, while the latter sometimes returned a router certificate or failed DNS. Recheck rather than assuming the topology or public IP is unchanged.

```bash
ip -4 -o addr show
resolvectl status
resolvectl query restic.wonhomelab.net
grep -i wonhomelab /etc/hosts
curl -sS -o /dev/null --max-time 10 -w '%{http_code} ssl_verify=%{ssl_verify_result}\n' https://restic.wonhomelab.net/
```

A stale hosts-file pin once produced `No route to host` and a failed neighbor entry. Do not add a replacement hardcoded address as a generic fix. DNS belongs to systemd-resolved; check its stub link and NetworkManager integration before changing resolver ownership. Preserve Tailscale split DNS.

Backup reachability is guarded by `ExecCondition` in `home/restic/.config/systemd/user/restic-backup.service`: any HTTP answer with valid TLS establishes reachability; authentication failure alone is not a network outage. Unreachable runs are skipped. Scheduling and stale-backup notification policy live in the timer and `backup-outcome`, not this document.

```bash
stat -c %y ~/.local/state/restic-last-success
systemctl --user list-timers restic-backup.timer
journalctl --user -u restic-backup -n 40
```

**wonhomelab.net unreachable with Tailscale up, fine with it down (2026-09-20).** Split DNS answers `192.168.1.42`, which is only reachable through wonlab's subnet route — the laptop sits on the outer subnet of the double-NAT, so an ARP FAILED for `192.168.1.42` is normal from here, not evidence wonlab is down. The hairpin path (tailscale down → router DNS → public IP `24.47.180.85`) serves ssh/web/restic independently and stays up even when wonlab's tailnet presence is gone. Cause this time: wonlab's control-plane checkins to headscale silently stalled (~40 min; wonlab still reported "Connected" — half-open conn), so the peer showed offline, the subnet route vanished, and split DNS timed out. A fresh `tailscale up` re-registered and wonlab went online instantly. Triage: with Tailscale up, check `tailscale status --json` for the peer's `Online`; if false, the fix is re-establishing control (laptop `tailscale down`/`up`, or wonlab's `sudo journalctl -u tailscaled`), not DNS or hosts-file changes.

**ssh to wonhomelab.net refused with Tailscale up (2026-09-18).** With Tailscale up, split DNS answers `192.168.1.42` and the accepted subnet route sends it via `tailscale0`; the fix lives on wonlab, not the laptop. Instant `Connection refused` on exactly one port means a `reject` rule (fail2ban's `@addr-set-sshd` chain, `reject with icmp port-unreachable`), not an ACL or ufw DROP — those time out. wonlab now has `ufw allow in on tailscale0 to any port 22 proto tcp` and `ignoreip = 127.0.0.1/8 ::1 100.64.0.0/10` in `/etc/fail2ban/jail.d/ignoreip-tailnet.local`, so TOTP failures can no longer ban tailnet sources. The laptop's ts IP (`100.64.0.1`) is what wonlab sees on both paths; the `ControlPersist 4h` master masks connection failures while alive — test with `ssh -o ControlPath=none -o BatchMode=yes` (reaching `Permission denied (keyboard-interactive)` means the path is fine).

## Cooper SSH host-key changes

**Signature:** host verification fails and `sshfs-conway.service` retries. Password-based access makes a wrong pin consequential: never clear keys and accept replacements blindly.

Stop the affected mount/watchdog while investigating. Inspect the host/port and credential handling in `home/ssh/.ssh/config`. Verify the changed host's fingerprint with an authoritative source; comparison across independent networks is supporting evidence, not equivalent verification. A genuine fingerprint for a sibling host does not authenticate this one.

Only after verification, update all stale key types for the affected host and restart its mount. Do not clear unchanged hosts. Conway and ice hosts once shared keys, then diverged during the 2026 migration; old sibling equality is not a current invariant. Filter keyscan banner comments when counting or appending keys.

The earlier auth investigation found that password/PAM login supplies Kerberos/AFS credentials; SSH keys alone did not give a usable home directory off campus. Cached credentials can make a key-only test look successful. Check `klist` and test without a borrowed cache before changing the authentication model. Detailed rotation evidence is in the archive.

## X2Go latency and ghost windows

Check latency, traffic, and CPU at both ends. A saturated Xwayland/nxproxy locally and x2goagent remotely, with little traffic, points to rendering/encoding rather than bandwidth.

Observed recoveries:

- Disable xfwm4 compositing in the **remote session's** environment when closed windows leave stale rectangles. Confirm the remote display and D-Bus before running `xfconf-query`; do not apply it to the local desktop.
- Lower near-lossless JPEG quality when encoding dominates; compare with PNG for text. Check the live NX session options, not just saved client settings.
- Run the client on ordinary XWayland. The removed Xephyr wrapper consumed a core and did not bypass Hyprland's compositor-level shortcuts.

Remote profile changes persist in AFS. See the archive for the measured September case and command context; do not reuse an old remote PID or display.

## Dock input dead after resume

**Signature:** Anker dock monitors/ethernet work but USB keyboard/mouse do not. The USB 2 and SuperSpeed paths can fail separately. The recorded kernel signature was a UCSI notification timeout (`-110`) followed by no input-tree re-enumeration.

**Recovery, in order:** unplug/replug the laptop USB-C connection after about 10 seconds; if still dead, remove dock power as well; if a PD partner appears but no USB devices enumerate, try the other port or cable orientation. The dock's latched state survived a host reboot in the recorded incident.

Confirm against kernel USB/type-C logs before applying this explanation to every dock failure.

## Touchpad still moves while typing

**Signature:** `input:touchpad:disable_while_typing` is true in Hyprland, but palm contact still moves the cursor. libinput pairs each touchpad with one internal keyboard; with keyd running, the AT keyboard is EVIOCGRAB'd and delivers no events, so DWT waits on the wrong device. libinput's second internal keyboard logs `too many internal keyboards for dwt`.

**Recovery:** `system/libinput/local-overrides.quirks` marks `AT Translated Set 2 keyboard` external and `keyd virtual keyboard` internal. It is already stow-linked into `/etc/libinput/`; restart Hyprland so libinput re-reads quirks and re-pairs. Do not remove the keyd quirk — that is what makes typing visible to DWT.

**Verification:** `libinput quirks list /dev/input/event2` shows `external`, `libinput quirks list` on the keyd node shows `internal`. Type and brush the pad; the cursor should freeze for the DWT timeout.

## USB hotplug after a kernel upgrade

**Signature:** a device enumerates but no driver binds; `modinfo <driver>` cannot find a module for the running kernel.

Compare `uname -r`, the installed kernel package, and `/lib/modules/`. Missing modules for the still-running old kernel explain this failure; reboot into the installed kernel. Do not rebuild unrelated USB config merely because hotplug started failing after an upgrade.

## Battery drain and unexpected wakes

Determine whether the machine stayed asleep. A suspend exit followed by hours of awake samples is different from high suspend drain.

```bash
journalctl -k --since '-2 days' -g 'PM: suspend (entry|exit)|PM: hibernation'
pgrep -a -x hypridle
systemd-inhibit --list
cat /sys/power/pm_wakeup_irq
cat /sys/power/suspend_stats/last_hw_sleep
```

Battery history belongs to `~/projects/battery-log`; its database is `~/.local/state/battery-log/history.db`. Inspect its schema before querying; archived queries against `battery.db` target the retired logger.

**Current policy:** read `hypridle.conf`, `system/systemd/sleep.conf`, and the logind drop-in. The idle sleep listener is deliberately ungated; the September reset removed AC/battery guards and extra retry daemons. Wayland idle inhibitors are not all visible in `systemd-inhibit --list`. Low-battery levels belong to the UPower drop-in, not a second daemon's independent thresholds.

**Wake attribution:** read the wake IRQ and counters before disabling sources. The ELAN touchpad was a demonstrated phantom wake source; `system/udev/rules.d/90-no-wake-i2c-hid.rules` handles it, including the `bind` event when the wakeup attribute appears. Resolve current IRQ/device paths instead of copying old numeric IDs. Armed USB controllers alone did not prove they caused a wake.

`/proc/acpi/wakeup` writes toggle state; check before changing it. Do not disable the wake alarm needed for suspend-then-hibernate. On this NVIDIA setup, `HibernateOnACPower=no` caused the timer's AC re-suspend path to fail with `nv_pmops_suspend ... -5`; current config leaves it at the default. Reproduce a regression before restoring removed sleep layers.

**Correction to old notes:** hibernation did work in later real power-cycle tests. Missing “Image saving progress” lines do not prove the image was never written: post-snapshot messages can disappear on restore. Retained uptime is also expected. Compare actual power-cycle/restore evidence and wall-clock gaps; a `pm_test` success message alone is insufficient.

## Battery not charging while plugged in (charge LED lit)

**Signature:** `BAT0` reports `Not charging` with `power_now` 0 while `ADP1` is online, the charge LED lit, and the ucsi input holding 20 V. **Cause confirmed live 2026-09-19:** the EC pauses charging while CPU package temp (`x86_pkg_temp`) spikes into the ~90-96°C range and resumes below ~70°C. Verified mid-blip: pkg 96°C, input 20 V, charge 0 W. The spikes are seconds-long boost bursts (seen at load ~2, single Firefox processes), so minute-sampled history shows the pauses without always showing the spike; even 0.25 s sampling of `x86_pkg_temp` swings 54→82→54 between reads, so a dropout whose transition sample reads cool (observed: 2 s pause at sampled 63°C, 2026-09-19) is not counter-evidence. With temp oscillating near the threshold, charging flaps on/off in ~7 s ramps; it settles when heat subsides. This is protective EC behavior, not a fault — replug, modprobe cycles, and waiting do not "fix" it; the workload does.

**Not causes:** the adapter (input holds 20 V through dropouts) and `modprobe -r/-i ucsi_acpi` (only re-registers deregistered ucsi source PSYs, restoring telemetry; earlier entries wrongly credited both). `journalctl -k -g ucsi` still shows `failed to re-enable notifications (-110)` on every resume since 2026-09-16 — a separate telemetry loss in the same wake-path family as the touchscreen rate quirk, not the charge dropout cause.

**Check a blip:** query battery-log history (`~/.local/state/battery-log/history.db`, minute samples; `temp_c` is `x86_pkg_temp`) — abnormal dropouts show `status='Not charging' AND ac=1` below the cap with `temp_c` ≥ ~89. Long Not-charging stretches at exactly 79-80% are the EC's separate, normal charge-hold cap (1519 samples the week of 2026-09-13); don't mistake them for this.

## Black screen after resume

Separate a dark Hyprland output from NVIDIA's temporary VT 63 console. Check the active session/VT and pending sleep jobs before interpreting an unresponsive screen.

```bash
loginctl list-sessions
systemctl list-jobs
journalctl -t hypr-wake-panel -b
hyprctl monitors -j
```

**Known signature:** Hyprland's log repeatedly says `eDP-1 is disabled, releasing crtc` after seat enable, without a new modeset. `dpmsStatus` has been either false or misleadingly true. Dispatches from an inactive Hyprland VT returned `ok` without changing the output.

**Recovery:** return to the Hyprland VT (normally Ctrl+Alt+F1). The current `hypr-wake-panel` helper waits for that session to be active, checks frame capture, and cycles DPMS if necessary. It is called by hypridle's `after_sleep_cmd`; read the helper before duplicating its logic. A manual cycle in the active session uses the table form:

```bash
hyprctl dispatch 'hl.dsp.dpms({ action = "off", monitor = "eDP-1" })'
sleep 2
hyprctl dispatch 'hl.dsp.dpms({ action = "on", monitor = "eDP-1" })'
```

The old string form fell through to toggle on the tested Lua API. Verify a modeset and successful bounded `grim -o eDP-1` capture; the dispatcher reply alone is not proof. Use the actual output name on another host.

A blinking underscore can mean NVIDIA's VT switch is waiting for sleep post-hooks. Inspect jobs and hooks; do not restart hyprlock or kill the session as the first fix. SysRq-E also killed NetworkManager in a recorded recovery, creating a second outage. Removed audio-health/hyprlock sleep hooks must not be restored from old incident snippets.

## Hibernate returns to a fresh session

**Signature:** kernel logs show `Image successfully loaded`, then `nv_pmops_freeze ... -5`, `Failed to load image`, or `resume failed`. The image may be valid while the resume handoff fails.

The demonstrated cause was early NVIDIA loading from initramfs while `NVreg_PreserveVideoMemoryAllocations=1` required userspace procfs preparation that had not yet run. Keep NVIDIA out of `MODULES` in the host's mkinitcpio config; the panel uses the iGPU. Do not remove VRAM preservation just to mask early-loading failure.

**Recovery:** correct the repo's boot config and apply through converge's system `boot` step, which copies/rebuilds with rollback. If manual privileged repair is required, prepare the script for the owner. Verify the rebuilt image and a real resume. Compression and image-size overrides were removed in the sleep reset; do not copy the archived experimental values.

## logind ignores its drop-in

**Signature:** `systemd-analyze cat-config` shows a setting that logind's actual D-Bus property does not reflect.

```bash
systemctl show systemd-logind -p ProtectHome -p ProtectSystem
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch
```

A symlink into `/home` can be unreadable in the consumer's sandbox even when a shell or `cat-config` reads it. The drop-in is a real installed file via `SYSTEM_INSTALLS` in `scripts/lib.sh`; converge's `configs` step copies it and reloads logind when changed. Apply the same consumer-namespace check to other system files.

**Do not restart logind to force a reload:** it terminated the graphical session in the recorded incident. The earlier “reload only partly works” diagnosis was a misreading of the inaccessible symlink. Verify the effective property after installing/reloading.

## dGPU wedges during sleep

**Signature:** unexplained high battery draw, `nvidia-smi` cannot obtain the device handle, and the GPU remains powered/bound. The recorded failure added roughly 18 W and logged NVIDIA power-state warnings plus I/O errors on `/proc/driver/nvidia/suspend`.

Check the current GPU address and runtime power state rather than copying the old PCI path. Do not interpret power measurements as a baseline while the GPU is wedged.

**Recovery in the recorded case:** reboot. Do not unbind a DRM device with active users. RTD3 changes were an untested hypothesis, not a verified fix; inspect current driver/config state before proposing them.

## OpenRouter stream interruption

**Signature:** the response starts, then Claude reports “API Error: stream closed before completion.” Separate a mid-response disconnect from an initial connection/TLS error; one successful short request does not establish long-stream health.

The September investigation considered provider health and preset routing. Record the actual provider, timing, and error; compare endpoints before changing exclusions. A model-wide provider dip does not establish that local networking or one provider is at fault.

Routing/failover and preset APIs can change. Verify current provider documentation before changing a preset; historical notes about sorting, load balancing, or replacement semantics are not sufficient authority. Keep credentials out of output and do not send a mutating preset request as a diagnostic probe. Detailed observations remain in the archive.

## Betterbird profile prefs

`~/.thunderbird/72gsfuug.default-default` is not stow-managed: the profile is 8 GiB of mutable mail data for restic, and the process name is `betterbird-bin`, not `betterbird`. The profile directory name is generated at first run, so re-apply these to whatever profile exists after a rebuild.

Deliberate prefs live in `user.js` in the profile (re-applied at every startup, never rewritten by the app); `prefs.js` is app-owned:

- `mail.minimizeToTray` = true, plus `hyprland` in `mail.minimizeToTray.supportedDesktops` — without it, close-to-tray is swallowed (fixed 2026-09-10).
- `mail.biff.alert.enabled_actions` = "mark-as-read,archive" — buttons on the new-mail notification. Upstream default is `"mark-as-read,delete"` (defaults/pref/mailnews.js in the installed omni.ja). Trap hit 2026-09-21: appending this pref to `prefs.js` while Betterbird sat in the tray was silently wiped by its next prefs flush — which is why the value lives in `user.js` now.
