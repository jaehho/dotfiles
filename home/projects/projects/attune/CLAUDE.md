# attune

README covers what this is and how to use it. This file is agent rules only.

- **`results/` is personal health data** (the owner's color-vision
  measurements). Keep the repo private; before any public remote, move
  `results/` out. Do not paste results into other projects' issues.
- The pages in `web/` are served at https://attune.jaehho.com from
  wonlab (home LAN and tailnet only; `src/attune/server.py` keeps each
  run as a file). Publish with `bash deploy/wonlab/deploy.sh`, which
  never touches saved runs. Pull runs with `scripts/pull_runs.sh` into
  `results/trivector/<at, UTC>Z-<mode>.json` and
  `results/pairs/<at, UTC>Z-<palette>.json`, one file per run, as
  stored. The old artifacts (T6TtRZTGsHfFmNMqWLz1TG, LyrWGph8EgY1AWpmMjWTom,
  Sy5DUeoePWSykTyQdgu6Lw) are retired: do not republish to them.
- The age norms in the test page are typed from Paramei & Oakley 2014,
  Table 2. Do not commit the paper; its license forbids reproduction.
- App theme files for the desktop belong to dotfiles (stow packages,
  decisions in dotfiles issues). This repo owns the palette and the
  measurements; do not write app configs here.
