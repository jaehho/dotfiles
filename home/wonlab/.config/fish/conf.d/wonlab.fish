# wonlab only. The first interactive shell of the day runs dotfiles-pull
# in the background; a failed pull is reported by the next shell.
status is-interactive; or return

set -l state ~/.local/state/dotfiles
if test -s $state/pull.err
    echo "dotfiles-pull failed, see $state/pull.err" >&2
end
if not test -e $state/pulled
    or test (math (date +%s) - (path mtime $state/pulled)) -gt 86400
    mkdir -p $state
    touch $state/pulled
    fish -c dotfiles-pull >/dev/null 2>$state/pull.err &
    disown
end
