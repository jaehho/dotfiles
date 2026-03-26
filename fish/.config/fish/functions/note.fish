function _note_git_sync --description "Auto-commit and push notes"
    set -l dir $argv[1]
    test -d $dir/.git; or return
    git -C $dir add -A 2>/dev/null
    git -C $dir diff --cached --quiet 2>/dev/null; and return
    git -C $dir commit --quiet -m "update notes" 2>/dev/null
    git -C $dir push --quiet 2>/dev/null &
    disown 2>/dev/null
end

function _note_open --description "Open note in editor with git sync"
    set -l file $argv[1]
    $EDITOR $file
    _note_git_sync (dirname $file)
end

function note --description "Quick notes with git sync"
    set -l notes_dir ~/notes
    mkdir -p $notes_dir

    # No args → open persistent scratch pad
    if test (count $argv) -eq 0
        set -l file $notes_dir/note.md
        if not test -f $file
            printf "# Notes\n\n" >$file
        end
        _note_open $file
        return
    end

    switch $argv[1]
        case ls list
            # Sort: default mtime desc, --name alphabetical, --old mtime asc
            set -l ls_args -t
            for arg in $argv[2..]
                switch $arg
                    case --name -n
                        set ls_args
                    case --old -o
                        set ls_args -tr
                end
            end

            set -l input (_note_list $ls_args)
            if test (count $input) -eq 0
                echo "No notes yet. Run 'note' to create one."
                return
            end

            set -l reload_cmd "_note_list $ls_args"

            printf '%s\n' $input | fzf \
                --reverse \
                --delimiter '\t' --with-nth 2 --nth 2,3 \
                --prompt '> ' \
                --bind 'start:disable-search+unbind(y,n)' \
                --bind 'j:down,k:up,g:first,G:last,q:abort' \
                --bind "x:transform~printf 'change-prompt(Delete %s? [y/N] )+unbind(j,k,g,G,q,x,/)+rebind(y,n)' {2}~" \
                --bind "y:execute-silent(rm {1})+reload($reload_cmd)+change-prompt(> )+rebind(j,k,g,G,q,x,/)+unbind(y,n)+disable-search" \
                --bind "n:change-prompt(> )+rebind(j,k,g,G,q,x,/)+unbind(y,n)" \
                --bind '/:unbind(j,k,g,G,q,x)+enable-search+change-prompt(/)' \
                --bind 'esc:rebind(j,k,g,G,q,x,/)+unbind(y,n)+disable-search+clear-query+change-prompt(> )' \
                --bind 'ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
                --preview 'bat --color=always --style=plain {1}' | read -l line
            and begin
                set -l selected (string split '\t' $line)[1]
                _note_open $selected
            end
            _note_git_sync $notes_dir
        case init
            if not test -d $notes_dir/.git
                git -C $notes_dir init --quiet
            end
            if git -C $notes_dir remote get-url origin >/dev/null 2>&1
                echo "Already configured."
                git -C $notes_dir remote -v
                return
            end
            git -C $notes_dir add -A 2>/dev/null
            git -C $notes_dir commit --quiet --allow-empty -m "init notes" 2>/dev/null
            gh repo create notes --private --source $notes_dir --push 2>/dev/null
            or begin
                # Repo already exists on GitHub — connect to it
                set -l url (gh repo view notes --json sshUrl -q .sshUrl 2>/dev/null)
                if test -n "$url"
                    git -C $notes_dir remote add origin $url
                    git -C $notes_dir push -u origin main
                else
                    echo "Failed to create repo. Check: gh auth status"
                    return 1
                end
            end
        case help
            echo "Usage: note [<title> | ls | init | help]"
            echo ""
            echo "  note                Open persistent scratch note"
            echo "  note <title>        Open/create a titled note"
            echo "  note ls             Browse notes (j/k, x delete, / search, q quit)"
            echo "  note ls --name      Sort alphabetically"
            echo "  note ls --old       Sort oldest first"
            echo "  note init           Set up git sync with GitHub"
        case '*'
            set -l slug (string join '-' $argv | string lower | string replace -ra '[^a-z0-9-]' '')
            set -l file $notes_dir/$slug.md
            if not test -f $file
                set -l title (string join ' ' $argv)
                printf "# %s\n\n" $title >$file
            end
            _note_open $file
    end
end
