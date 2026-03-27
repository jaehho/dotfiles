function _note_list --description "List notes with content for fzf input"
    set -l notes_dir ~/notes
    for f in (command ls $argv $notes_dir/*.md 2>/dev/null)
        set -l content (string join ' ' < $f | string replace -ra '\s+' ' ' | string sub -l 1000)
        printf '%s\x1f%s\x1f%s\n' $f (basename $f) "$content"
    end
end
