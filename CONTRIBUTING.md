# Contributing

## Before

1. Read [README.md](README.md)
2. Search [`gotcha`](https://github.com/jaehho/dotfiles/issues?q=label%3Agotcha)
   issues, open and closed
3. Design choices are [`decision`](https://github.com/jaehho/dotfiles/issues?q=label%3Adecision)

## Where things go

| Path | What |
|---|---|
| `home/<pkg>/` | stow package -> `~` |
| `system/` | root file -> `/etc` (see `system/README.md` for which are copies) |

## Testing

```sh
stow --no-folding -n -v -d home -t ~ <pkg>
```

## Git

Small WIP commits. Never discard uncommitted work; stowed files are live.
