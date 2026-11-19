function wt --description 'Pick a git worktree of this repository and cd into it'
    set -l worktrees (git worktree list --porcelain 2>/dev/null | awk '
        /^worktree / { if (path) print branch "\t" path; path = substr($0, 10); branch = "(detached)" }
        /^branch / { branch = $2; sub("refs/heads/", "", branch) }
        END { if (path) print branch "\t" path }')
    if test (count $worktrees) -eq 0
        echo "wt: not in a git repository" >&2
        return 1
    end
    set -l picked (printf '%s\n' $worktrees | fzf --delimiter '\t' --with-nth 1,2 \
        --preview 'ls {2}/explorations 2>/dev/null; echo; git -C {2} log --oneline --color=always -15')
    or return
    cd (string split -f2 \t -- $picked)
end
