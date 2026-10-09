# Contributing

## Before making changes

1. Read [README.md](README.md)
2. Search [`gotcha`](https://github.com/jaehho/dotfiles/issues?q=label%3Agotcha)
   issues, open and closed
3. Design choices are [`decision`](https://github.com/jaehho/dotfiles/issues?q=label%3Adecision)
   issues

## Where things go

| Path | What |
|---|---|
| `home/` | stow package -> `~` |
| `system/` | root file -> `/etc` (or a link, if the reader can follow one) |
| `scripts/` | apply, status, bootstrap |
| `packages/bootstrap.txt` | bare necessities for a new machine |
| `hosts/` | per-host choices written by bootstrap |

Adding a config is a file under `home/` or `system/` plus, for `/etc`,
an entry in `SYSTEM_LINKS`, `SYSTEM_INSTALLS`, or `SYSTEM_COPIES` in
`scripts/lib.sh`.

## Testing

```bash
dotfiles status
dotfiles apply
sudo scripts/apply.sh system
```

## Git

Small WIP commits. Never discard uncommitted work; stowed files are live.
