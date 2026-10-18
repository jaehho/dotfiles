# Chopper Amplifier — Neural Front-End

## Overview

Sub-1 V chopper amplifier for neural recording in TSMC CRN65G+. Behavioral model in Python (analytical sizing + signal-flow chopper simulation against measured Spectre PSF), Cadence schematics on the ICE server, IEEE-style manuscript in `paper.typ`. Repo path is historical (`/home/jaeho/thesis`); the Python package is `nfe`.

Repo layout rule: the working tree holds live publication work only. Nothing finished is kept in it — git tags freeze each delivered thing, sources and PDFs alike. The authoring root is `paper.typ` — don't drag thesis- or talk-era framing into it.

## Pointers

- Open work for the publication is in GitHub issues (`gh issue list`).
- Design decisions are GitHub issues labeled `decision` (#10-#78 migrated from the old `DESIGN_LOG.md`, filed in date order). Search with `gh issue list --label decision --state all --search <term>`. File a new decision as an issue only after the user confirms it: title `YYYY-MM-DD — [status] Short description`, body with **Decision**, **Why**, optional **Alternatives considered**, **Trade-offs / risks**, **Expected result**, **Follow-up**, **Source**. Close it once decided; leave `[provisional]`/`[open]` ones open. When a decision is revised, file a new issue and comment "Superseded by #N" on the old one; never rewrite the old body.
- `PROSE.md` — canonical style guide for `paper.typ`. Read before any rendered prose edit.
- Finished work is in git tags, not on disk. **`archive`** is the one to reach for — a complete snapshot under `archive/`: `thesis.typ`, `defense.typ`, `learn.typ`, `talk.typ`, `defense_notes.md` (spoken defense transcript, the best on-ramp when the material has gone cold), `TODO_thesis.md`, the two thesis-era notebooks, and every delivered PDF/deck (`thesis.pdf`, `defense.pdf/pptx`, `talk.pdf/pptx`).
  - Whole tree: `git worktree add /tmp/archive archive`, then `git worktree remove /tmp/archive`. Decks compile there against the figures of the day.
  - One file: `git show archive:archive/thesis/thesis.pdf > thesis.pdf`.
  - Read-only reference — never edit a tag's checkout back into the working tree.
  - Also tagged: `thesis-submission` (whole repo as submitted, 2026-05-15) and `talk-chiappe` (same commit as `archive`).

## Code Layout

The repo is a `uv`/`hatch` project. Library code lives in `src/nfe/`; notebooks and scripts import via `from nfe.<module> import …`. Run `uv sync` after pulling — it installs `nfe` editable.

Per-module purpose lives in each module's docstring; run `tree -L 2 src notebooks scripts` for the inventory.

Marimo notebook conventions: `_`-prefixed names are cell-private (`_tmp`, `_fig`, `_ax`); shared values use plain names so downstream cells can take them as args. Keep the module docstring on one line so `import marimo` lands within the first 512 bytes. Notebooks derive a `root` from `Path(__file__).resolve()` so savefigs land at `<repo>/figures/` regardless of cwd — mind the parent depth when moving one.

Datasets are not vendored. The Merk 2022 STN-LFP corpus resolves through `nfe.lfp.dataset_root()` — `$NFE_LFP_ROOT`, else `~/data/merk2022`; re-fetchable from Harvard Dataverse `doi:10.7910/DVN/IO2FLM`.

## Remote Server (Cadence/Spectre)

Schematics and simulation run on Cooper Union's EE servers. The AFS tree is
reached through an **sshfs mount of `conway:/`** at `~/mnt/conway`, with
`~/mnt/ice` a symlink to it so the historical `$ICE` path still resolves:

    $ICE = ~/mnt/ice/afs/ee.cooper.edu/user/j/jaeho.cho/   (-> ~/mnt/conway/afs/...)

`/afs/ee.cooper.edu` is the same tree from any EE host, so which host serves the
mount does not change what is under `$ICE`. Python tooling reads
`nfe.cadence_export.ICE`; override with `NFE_ICE_ROOT` if the mount moves.

Remount if `$ICE` goes stale (the mount is manual, not an fstab/systemd unit):

```
fusermount3 -u ~/mnt/conway
sshfs conway:/ ~/mnt/conway -o ServerAliveInterval=5,ServerAliveCountMax=2 \
      -o ConnectTimeout=10 -o dir_cache=no,no_readahead \
      -o ssh_command="sshpass -f $HOME/.ssh/jump_pass ssh"
```

Run commands remotely with the `ssh ice` / `ssh conway` aliases (`~/.ssh/config`,
port 31415, user jaeho.cho). The password is at `~/.ssh/jump_pass` (a dotfiles
symlink) and is consumed by `sshpass -f` — **never hardcode it, never echo it**.
For batches of remote commands, write them to `$ICE/claude_run.sh` for the user
to run rather than handing over long ssh invocations.

Where things live on `$ICE`:

| What | Path |
|------|------|
| Cadence session log | `$ICE/CDS.log` |
| Schematics | `$ICE/VLSI_tsmc65/Thesis/` (legacy directory name; live schematics) |
| Testbench netlist | `$ICE/simulation/<tb_name>/spectre/schematic/netlist/input.scs` |
| Spectre stdout | `$ICE/simulation/<tb_name>/spectre/schematic/psf/spectre.out` |
| PSF result files | `$ICE/simulation/<tb_name>/spectre/schematic/psf/*.{ac,pss,pnoise,dc}` |

Discover testbenches: `ls ~/mnt/ice/afs/ee.cooper.edu/user/j/jaeho.cho/simulation/`.

### Reading Simulation Results

PSF binaries are readable through the mount via `nfe.cadence_export`; no Cadence license needed. Run `uv run python -m nfe.cadence_export --help` for the current subcommand catalogue — the source auto-discovers analyses and signals from the PSF directory, so it stays in sync with the testbench.

The tool already handles diff-pair output discovery (`VOUT±`, `_p`/`_n`, `P`/`N`), power supply summing (`*:pwr`), parametric sweep nesting (`<k=v>/` and `.workaround.nfs*/`, plus stale-dir filtering), multi-param sweep aggregation, and graceful NaN-on-missing degradation. `dcop` reads both `dcOp.dc` (nodes) and `dcOpInfo.info` (per-device region/Id/Vgs/Vds/Vth/gm/gds/gm/Id). All subcommands take `-p <param>` to target a specific sweep point.

### Extending the tool

Promote repeated PSF post-processing into `src/nfe/cadence_export.py` over `/tmp` scripts. If you've extracted the same metric twice (across reruns, testbenches, or sessions), it belongs as a subcommand — version-controlled, reproducible, with `--help` as the catalogue. One-shot exploration in `/tmp` is fine.

When adding a subcommand:
- Use the `_find_diff_pair`, `_find_power_names`, `_find_noise_traces` helpers — don't hardcode signal names.
- Return NaN + `_warn()` on missing data, not exceptions.
- Read the PSF source of truth, not assumed ADE session state.

### Analysis Strategy

- **Use PSS+PAC/PNoise for chopper**, not HB. Hard switching needs 50–100+ harmonics for HB convergence; PSS shooting handles clock edges naturally.
- Discover what analyses a testbench runs with `python -m nfe.cadence_export list <tb_name>` — trust that, not a static list here.
- **Read the user's Cadence Outputs panel for scalar FOMs** (gain, UGB, PM, integrated IRN, power). Only post-process in Python for things Cadence isn't computing (custom FOMs, sweep aggregation, NEF).
- RF testbenches (`_1db_compression`, `_iip3`, `_S11`) are stale for the neural use case.

## Gotchas

Non-obvious constraints found during development:

- **Weak inversion invalidates square-law.** At µA-level currents with L=2 µm, devices are subthreshold. Don't hand-compute `g_m = µC_ox·W/L·V_ov` — read DC OP values from Cadence via `python -m nfe.cadence_export dcop` (or `DeviceOP` on `nfe.design.neural`). Topology-level sizing trade-offs go through `nfe.gmid.GmIdLUT`.
- **Gate leakage corrupts high-impedance nodes in 65 nm.** Thin gate oxide (~1.4 nm) gives nA-scale tunneling. Resistive networks with R > ~100 MΩ are vulnerable; ΔV ≈ I_leak · R_eff. Always check DC OP for expected node voltages.
- **Verify operating regions after resizing.** `python -m nfe.cadence_export dcop` shows per-device region (subVt/triode/sat). Devices can land in triode with no obvious netlist error.
- **Differential input-drive magnitude.** `tb_op_amp_neural` input sources use `mag=1` at phases 0 and 180, giving effective differential drive of 2. Cadence's gain/UGB expressions handle this correctly; Python PSF post-processing must divide `(V+ − V−)` by 2 before magnitude, or it overstates gain by +6 dB.

## Build Commands

See `Makefile` for the canonical list. Quick reference:

```bash
uv sync                                             # install `nfe` editable after pull
uv run marimo edit notebooks/<name>.py              # interactive notebooks (ota / chopper / system)
uv run python scripts/plot_cadence_figures.py       # regenerate Cadence PNGs (mount-dependent)
uv run python -m nfe.cadence_export --help          # PSF reader CLI
typst compile paper.typ                             # IEEE manuscript
```

## Conventions

- Typst comments (`//`) hold derivation notes, Razavi references, and verification thoughts.
- `paper.typ` prose style is governed by `PROSE.md`. Add a rule there only after the user has confirmed it (same workflow as `decision` issues).
- Citations: Razavi refs use `§<section>, Eq. (<n>), p. <page>`, referring to *Design of Analog CMOS Integrated Circuits*, 2nd ed., 2017 (Zotero key `YD6A9AIB`). Papers use `<First author> <year> <venue>` with the Zotero key in brackets, e.g., `Fan 2011 JSSC [UF3SHXPW]`.
- Decision status tags: `[locked]` settled, `[provisional]` current-best with known follow-up, `[superseded by #N]` overridden. Dates are ISO (YYYY-MM-DD).
