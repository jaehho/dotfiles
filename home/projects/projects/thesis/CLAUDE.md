# Chopper Amplifier — Neural Front-End

Sub-1 V chopper amplifier for neural recording in TSMC CRN65G+. Behavioral model in Python (package `nfe`), Cadence schematics on the ICE server, IEEE-style manuscript in `paper.typ`. Repo path is historical (`/home/jaeho/thesis`).

The working tree holds live publication work only. Nothing finished is kept in it: git tags freeze each delivered thing. The authoring root is `paper.typ`; don't drag thesis- or talk-era framing into it.

## Pointers

- Open work: `gh issue list`.
- Decisions are issues labeled `decision`: `gh issue list --label decision --state all --search <term>`. File one only after the user confirms. Title `YYYY-MM-DD — [status] Short description`; body **Decision**, **Why**, optional **Alternatives considered**, **Trade-offs / risks**, **Expected result**, **Follow-up**, **Source**. Close once decided; leave `[provisional]`/`[open]` open. To revise, file a new issue and comment "Superseded by #N" on the old one; never rewrite the old body. Status tags: `[locked]`, `[provisional]`, `[superseded by #N]`.
- `PROSE.md` is the style guide for `paper.typ`; read it before any rendered prose edit. Add a rule only after the user confirms it.
- Finished work is in git tags. `archive` is a complete snapshot under `archive/` (thesis, defense, talk sources and every delivered PDF/deck; `defense_notes.md` is the best on-ramp when the material has gone cold). Also `thesis-submission` (2026-05-15) and `talk-chiappe` (same commit as `archive`).
  - Whole tree: `git worktree add /tmp/archive archive`, then `git worktree remove /tmp/archive`. One file: `git show archive:archive/thesis/thesis.pdf > thesis.pdf`.
  - Read-only: never edit a tag's checkout back into the working tree.

## Code

Notebooks and scripts import `from nfe.<module> import …`; module purpose is in each docstring. Run `uv sync` after pulling.

- Marimo: `_`-prefixed names are cell-private; shared values use plain names. Keep the module docstring on one line so `import marimo` lands in the first 512 bytes. Notebooks derive `root` from `Path(__file__).resolve()` so figures land in `<repo>/figures/`; fix the parent depth when moving one.
- The Merk 2022 STN-LFP corpus is not vendored: `nfe.lfp.dataset_root()` reads `$NFE_LFP_ROOT`, else `~/data/merk2022` (`doi:10.7910/DVN/IO2FLM`).
- Typst `//` comments hold derivation notes, Razavi references, and verification thoughts.
- Citations: Razavi refs are `§<section>, Eq. (<n>), p. <page>` (*Design of Analog CMOS Integrated Circuits*, 2nd ed., Zotero `YD6A9AIB`). Papers are `<First author> <year> <venue>` plus the Zotero key, e.g. `Fan 2011 JSSC [UF3SHXPW]`.

## Remote server (Cadence/Spectre)

Schematics and simulations run on Cooper Union's EE servers, reached through a manual **sshfs mount of `conway:/`** at `~/mnt/conway`; `~/mnt/ice` symlinks to it. `nfe.cadence_export.ICE` resolves the root (override with `NFE_ICE_ROOT`).

    $ICE = ~/mnt/ice/afs/ee.cooper.edu/user/j/jaeho.cho/

Remount if `$ICE` goes stale:

```
fusermount3 -u ~/mnt/conway
sshfs conway:/ ~/mnt/conway -o ServerAliveInterval=5,ServerAliveCountMax=2 \
      -o ConnectTimeout=10 -o dir_cache=no,no_readahead \
      -o ssh_command="sshpass -f $HOME/.ssh/jump_pass ssh"
```

Run remote commands with `ssh ice` / `ssh conway`. The password is `~/.ssh/jump_pass`, consumed by `sshpass -f`: **never hardcode it, never echo it**. For batches, write them to `$ICE/claude_run.sh` for the user to run.

| What | Path |
|------|------|
| Cadence session log | `$ICE/CDS.log` |
| Schematics | `$ICE/VLSI_tsmc65/Thesis/` (legacy name; live) |
| Testbench netlist | `$ICE/simulation/<tb>/spectre/schematic/netlist/input.scs` |
| Spectre stdout | `$ICE/simulation/<tb>/spectre/schematic/psf/spectre.out` |
| PSF results | `$ICE/simulation/<tb>/spectre/schematic/psf/*.{ac,pss,pnoise,dc}` |

### Reading simulation results

Read PSF through `nfe.cadence_export` (no Cadence license needed); `--help` and `list <tb>` are the catalogue. If you extract the same metric twice, add it as a subcommand in `src/nfe/cadence_export.py` instead of a `/tmp` script. A new subcommand uses `_find_diff_pair`, `_find_power_names`, `_find_noise_traces` (no hardcoded signal names), returns NaN + `_warn()` on missing data, and reads the PSF, not assumed ADE state.

- Chopper analysis is PSS+PAC/PNoise, not HB: hard switching needs 50–100+ harmonics for HB to converge.
- Take scalar FOMs (gain, UGB, PM, integrated IRN, power) from the user's Cadence Outputs panel. Post-process in Python only for what Cadence doesn't compute (custom FOMs, sweep aggregation, NEF).
- RF testbenches (`_1db_compression`, `_iip3`, `_S11`) are stale for the neural use case.

## Gotchas

- **Weak inversion invalidates square-law.** At µA currents with L=2 µm devices are subthreshold. Don't hand-compute `g_m`; read DC OP via `python -m nfe.cadence_export dcop` (or `DeviceOP` on `nfe.design.neural`). Topology-level sizing goes through `nfe.gmid.GmIdLUT`.
- **Gate leakage corrupts high-impedance nodes.** ~1.4 nm oxide gives nA tunneling, ΔV ≈ I_leak · R_eff; networks above ~100 MΩ are vulnerable. Check DC OP node voltages.
- **Check operating regions after resizing.** `dcop` shows per-device region; a device can land in triode with no netlist error.
- **Differential drive is 2, not 1.** `tb_op_amp_neural` sources use `mag=1` at phases 0 and 180. Cadence expressions handle it; Python post-processing must divide `(V+ − V−)` by 2 before magnitude, or gain is overstated by 6 dB.
