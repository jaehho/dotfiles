# Dotfiles

GNU Stow-based dotfiles. Primary target Arch + Hyprland; also supports Ubuntu/Debian — when editing configs, consider both. Package manifests live in `packages/` — `common.txt` (same name on both distros), `arch/*.txt` (by category), `ubuntu.txt`, plus `cargo`/`npm`/`uv`. Gate Arch-only pieces behind the distro checks in `scripts/`. `home/` holds the stow packages, each mirroring `$HOME`; `system/` holds what the `system` phase installs as root; `packages/`, `scripts/` and `hosts/` are helpers.

`make sync` is the only setup command — idempotent, safe to re-run.

## Non-obvious gotchas

- **Boot-critical configs** (`grub`, `mkinitcpio`, `modprobe`) are **copied** by the `system` sync phase, not symlinked — they survive a broken `/home` mount.
- **Stow uses `--no-folding`** (individual symlinks, not directory symlinks).
- **Per-machine choices** live in `hosts/<hostname>.sh` (committed, sourced by `scripts/lib.sh`). Sync prompts on first run for any new host.
- **The Makefile is a dispatcher only** — logic lives in `scripts/`. Shared lists are in `scripts/lib.sh`; run one phase with `./scripts/sync.sh --list` / `./scripts/sync.sh <phase>`.
- **Only `packages/arch/99-inbox.txt` is machine-sorted.** Drift-detected packages land there; the other `arch/*.txt` keep their comments and grouping. File inbox entries by hand.
- **Package upgrades are gated to once per 24h** (read from `pacman.log`), so re-syncing after a config edit is cheap. `FORCE_UPGRADE=1` overrides.
- **Claude Code config** is declarative — see `home/claude/.claude/reconcile/README.md` for reconcile and MCP secrets.
- **`hypr-tools`** lives outside this repo (Rust, two AUR packages). AUR binaries run by default; `HOST_DEV_TOOLS=1` builds from `HOST_DEV_TOOLS_SRC` (default `~/projects/hypr-tools`) and shadows them. A missing checkout is not an error.
- **Speaker tone is a host-side gap, not a driver bug.** The CS35L41 amps load `spk-prot` (protection) firmware and never the vendor tuning, so output is raw and bright until a host EQ supplies the correction. `speaker-measure --apply` sweeps the speakers through a mic, fits the correction, and writes a `wireplumber.conf.d` rule (read at startup) that builds it into the speaker sink itself as `audioconvert.filter-graph.0`: no extra node in mixers or pickers, and headphones, which swap in a sink of their own, never go through it. The sink's properties carry the graph even when PipeWire rejected it, a suspended node reports no graph, and `pw-cli enum-params` can show a stale cache, so prove it runs with `pw-top` busy time or `--verify`, which re-measures with the EQ off then on. A mixer's level meters capture what they show and so wake it: a lit meter in wiremix is not something playing. `--play` then `--from-recording` fit from a phone instead, which beats the built-in array bolted to the same chassis as the drivers. Runs are kept in `~/.local/state/speaker-measure/`.
- **Text-to-speech is Kokoro behind speech-dispatcher**: the `audio` package's `kokoro-tts-server` (socket-activated, exits idle) is the default module, because Gecko apps (Zotero's Local voices) list only the default module's voices. speech-dispatcher's `SymbolsPreproc` deletes `%`, `°`, quotes and brackets before a module sees them, so `speechd.conf` omits it. `sd_generic` cuts text at any delimiter followed by a space, which splits "Fig. 3b" unless `GenericDelimiters` is overridden; an empty value does not override it. `uv run` forks the script, so `LISTEN_PID` never matches it.
- **When `make sync` or the machine breaks, read `ISSUES.md` first** — recurring traps with copy-paste fixes up top, dated incident history below. Add to it rather than special-casing `scripts/`.
