---
name: orcaslicer-presets
description: Create or refine OrcaSlicer machine, filament, or process presets by writing JSON files for the user to import. Use when the user wants to add a new filament, tune temperatures or retraction, set up a new printer profile, or adjust any OrcaSlicer slicing settings.
user-invocable: true
---

# OrcaSlicer preset authoring

The user runs OrcaSlicer 2.3.2 on Linux with a Creality Ender-3 Pro (bowden, currently 0.6 mm nozzle). Their config tree lives at `~/.config/OrcaSlicer/` and their user folder is `~/.config/OrcaSlicer/user/798534545/`.

The user explicitly does not want GUI walkthroughs. Always write the preset JSON file yourself, then tell them the single import action.

## Workflow

1. **Identify the preset type**: machine, filament, or process.
2. **Find the right parent (`inherits`)**. List system presets that match the user's setup, then pick the closest one. Common locations:
   - Filaments: `~/.config/OrcaSlicer/system/Creality/filament/` and `~/.config/OrcaSlicer/system/OrcaFilamentLibrary/filament/`
   - Machines: `~/.config/OrcaSlicer/system/Creality/machine/`
   - Processes: `~/.config/OrcaSlicer/system/Creality/process/`
3. **Read the parent JSON** to see what fields are already set, so you only override what differs. Don't redeclare inherited settings.
4. **Read an existing user preset of the same type** (under `~/.config/OrcaSlicer/user/798534545/<type>/`) as a format template. This guarantees the field shape (arrays vs strings) matches what Orca's importer expects.
5. **Write the new preset** to the user folder, e.g. `~/.config/OrcaSlicer/user/798534545/filament/<name>.json`.
6. **Tell the user**: open OrcaSlicer → **File → Import → Import Configs...** and pick the file. Dropping JSON into the user folder does NOT auto-load it; the importer is the only reliable path.

## Required JSON fields

All preset types need:
- `"type"`: `"machine"`, `"filament"`, or `"process"`
- `"name"`: display name
- `"from"`: `"User"` (exact)
- `"inherits"`: exact name of an existing system preset (empty string fails silently)
- `"version"`: must match installed Orca version. For 2.3.2: `"2.3.2.0"`
- `"is_custom_defined"`: `"0"` (string, not boolean)
- ID field matching the type:
  - machine → `"printer_settings_id": "<name>"`
  - filament → `"filament_settings_id": ["<name>"]`  (array)
  - process → `"print_settings_id": "<name>"`

Plus the override fields you actually want to change.

**Never include** `"setting_id"` or `"instantiation"` (system-only, will be rejected). `"compatible_printers"` is tolerated via the importer but omit it for filament/process unless the user is hitting a CLI compat-check failure (see CLI gotcha below).

## Filament value shape

Most filament numeric fields are arrays of strings, one entry per extruder. For a single-extruder Ender-3:
```json
"nozzle_temperature": ["200"],
"nozzle_temperature_initial_layer": ["205"],
"nozzle_temperature_range_low": ["195"],
"nozzle_temperature_range_high": ["220"],
"hot_plate_temp": ["55"],
"hot_plate_temp_initial_layer": ["60"],
"cool_plate_temp": ["55"],
"cool_plate_temp_initial_layer": ["60"]
```

Set both `hot_plate_*` and `cool_plate_*` for PLA-class filaments unless the user has specified a build plate, since the active plate switches in the GUI and each has independent temps.

Other commonly tuned filament fields:
- `filament_max_volumetric_speed`: melt-rate cap, e.g. `["12"]` for stock PLA, `["15"]` for PLA+
- `filament_flow_ratio`: e.g. `["0.98"]`
- `filament_retraction_length` / `filament_retraction_speed`: filament-specific retraction overrides

## Machine value shape

Machine numeric fields that are per-extruder are also arrays. Single string for non-extruder fields. Example overrides:
```json
"retraction_length": ["6"],
"retraction_speed": ["45"],
"z_hop": ["0.4"]
```

For bowden setups (like the Ender-3 Pro), retraction past 6 mm risks chewing filament against the plastic-arm extruder; default starting point is 6 mm.

## Process value shape

Process fields are mostly plain strings or numbers (not arrays). Common overrides:
```json
"layer_height": "0.2",
"sparse_infill_density": "20%",
"outer_wall_speed": "40"
```

## Naming convention

The user's existing presets follow the pattern `<base name> <distinguisher>`, e.g. `Generic PLA Low Ooze 185C`, `Ender-3 Pro 0.6 Low Ooze`. Use a similar shape: include the parent class plus the distinguishing detail (color, temp, or use case).

## Reference: working filament example

Adapted from the user's `Generic PLA Low Ooze 185C.json`:
```json
{
    "type": "filament",
    "name": "Generic PLA Low Ooze 185C",
    "from": "User",
    "inherits": "Creality Generic PLA",
    "filament_settings_id": ["Generic PLA Low Ooze 185C"],
    "version": "2.3.2.0",
    "is_custom_defined": "0",
    "filament_extruder_variant": ["Direct Drive Standard"],
    "nozzle_temperature": ["185"],
    "nozzle_temperature_initial_layer": ["190"],
    "nozzle_temperature_range_low": ["180"],
    "nozzle_temperature_range_high": ["220"]
}
```

## Reference: working machine example

```json
{
    "type": "machine",
    "name": "Ender-3 Pro 0.6 Low Ooze",
    "from": "User",
    "inherits": "Creality Ender-3 Pro 0.6 nozzle",
    "printer_settings_id": "Ender-3 Pro 0.6 Low Ooze",
    "version": "2.3.2.0",
    "is_custom_defined": "0",
    "retraction_length": ["6"],
    "retraction_speed": ["45"]
}
```

## Refining an existing user preset

To adjust an existing user preset (e.g. tweak retraction on a saved machine), edit the JSON in place at `~/.config/OrcaSlicer/user/798534545/<type>/<name>.json`. The user must restart OrcaSlicer (or trigger a config reload) for changes to apply. There's no in-place hot reload.

If the preset has been edited via the GUI, Orca strips the `"type"` field on save. Add it back if you intend to use the preset with the CLI's `--load-settings` (see below).

## CLI gotcha (when using `slice` workflow)

The user has a `slice` fish function (`~/.config/fish/functions/slice.fish`) that uses OrcaSlicer's CLI to wrap STLs into project 3MFs (working around the broken positional-arg loader, GH issue #8592). When a process preset is fed to `--load-settings`:
- `"type"` field must be present (the GUI strips it on save).
- `"compatible_printers"` must list every printer name the wrapper might pair with, including the user's custom printer preset name (not just the inherited system one). The CLI's strict compat check rejects pairings otherwise; `--no-check` does not bypass it.

If creating or refining a process preset that the `slice` workflow will use, include both. Otherwise omit `compatible_printers`.

## Verification

After writing a preset, surface to the user:
1. The full path of the file you wrote.
2. The single GUI action: **File → Import → Import Configs...** then select that file.
3. (Optional) A short summary of what overrides you set vs the parent, so they can sanity-check.
