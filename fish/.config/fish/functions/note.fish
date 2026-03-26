function note --description "Quick notes with Notion sync"
    set -l notes_dir ~/notes
    mkdir -p $notes_dir

    # No args → timestamped scratch note
    if test (count $argv) -eq 0
        set -l timestamp (date +%Y-%m-%d-%H%M%S)
        set -l file $notes_dir/$timestamp.md
        printf "# %s\n\n" (date +"%Y-%m-%d %H:%M:%S") >$file
        $EDITOR $file
        return
    end

    switch $argv[1]
        case sync
            note-sync $argv[2..]
        case ls list
            set -l synced_file $notes_dir/.synced
            set -l has_notes 0
            for f in $notes_dir/*.md
                test -f $f; or continue
                set has_notes 1
                set -l name (basename $f)
                set -l lines (wc -l <$f | string trim)
                set -l status ""
                if test -f $synced_file; and grep -qxF $name $synced_file
                    set status " [synced]"
                end
                printf "  %s  (%s lines)%s\n" $name $lines $status
            end
            if test $has_notes -eq 0
                echo "No notes yet. Run 'note' to create one."
            end
        case setup
            note-sync --setup
        case help
            echo "Usage: note [<title> | sync | ls | setup]"
            echo ""
            echo "  note              Open a new timestamped note"
            echo "  note <title>      Open a new titled note"
            echo "  note ls           List all notes with sync status"
            echo "  note sync         Sync unsynced notes to Notion"
            echo "  note sync --all   Re-sync all notes"
            echo "  note setup        Configure Notion integration"
        case '*'
            set -l slug (string join '-' $argv | string lower | string replace -ra '[^a-z0-9-]' '')
            set -l file $notes_dir/$slug.md
            if not test -f $file
                set -l title (string join ' ' $argv)
                printf "# %s\n\n" $title >$file
            end
            $EDITOR $file
    end
end
