# attune

README covers what this is and how to use it. This file is agent rules only.

- **`results/` is personal health data** (the owner's color-vision
  measurements). Keep the repo private; before any public remote, move
  `results/` out. Do not paste results into other projects' issues.
- The live test is the artifact
  https://claude.ai/artifact/T6TtRZTGsHfFmNMqWLz1TG with `db` rules
  `runs` read and write `owner`. `web/trivector.html` is its source:
  republish to that URL, never a new one, or saved runs are orphaned.
  Pull new runs with ArtifactData into
  `results/trivector/<at, UTC>Z-<mode>.json`, one file per run, as stored.
- The pair test is served at https://attune.jaehho.com/pairs.html from
  wonlab (home LAN and tailnet only; `src/attune/server.py` keeps each
  run as a file). `web/pairs.html` is its source; publish with
  `bash deploy/wonlab/deploy.sh`, which never touches saved runs. Pull
  runs with `scripts/pull_runs.sh` into
  `results/pairs/<at, UTC>Z-<palette>.json`. Its old artifact
  (LyrWGph8EgY1AWpmMjWTom) is retired once the site works: do not
  republish to it.
- The palette comparison artifact is
  https://claude.ai/artifact/Sy5DUeoePWSykTyQdgu6Lw (`web/palettes.html`).
- The age norms in the test page are typed from Paramei & Oakley 2014,
  Table 2. Do not commit the paper; its license forbids reproduction.
- App theme files for the desktop belong to dotfiles (stow packages,
  decisions in dotfiles issues). This repo owns the palette and the
  measurements; do not write app configs here.
