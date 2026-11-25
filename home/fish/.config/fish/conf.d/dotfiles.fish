# The first interactive shell of the day runs dotfiles-pull in the
# background. pull.err exists only while the last run failed (judged by
# its exit status, not by stderr, which stow fills with notices on
# success) and is replaced whole when a run ends. A shell that finds one
# retries instead of reporting it, so a fixed problem clears itself; a
# shell opened within 5 minutes of the last try reports the error and its age.
status is-interactive; or return

set -l state ~/.local/state/dotfiles
set -l now (date +%s)
set -l last 0
test -e $state/pulled; and set last (path mtime $state/pulled)
set -l age (math $now - $last)
set -l failed 0
test -s $state/pull.err; and set failed 1

if test $age -gt 86400; or begin; test $failed -eq 1; and test $age -gt 300; end
    mkdir -p $state
    touch $state/pulled
    fish -c "dotfiles-pull >/dev/null 2>$state/pull.err.new
        if test \$status -eq 0
            rm -f $state/pull.err.new $state/pull.err
        else
            mv $state/pull.err.new $state/pull.err
        end" &
    disown
else if test $failed -eq 1
    set -l mins (math --scale=0 "($now - "(path mtime $state/pull.err)") / 60")
    echo "dotfiles-pull failed $mins min ago, see $state/pull.err" >&2
end
