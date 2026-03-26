function fish_prompt
    set -l last_status $status
    set -l duration $CMD_DURATION

    # Catppuccin Frappe palette
    set -l blue 8caaee
    set -l overlay a5adce
    set -l yellow e5c890
    set -l green a6d189
    set -l red e78284

    # ── Line 1: directory + git + duration ───────────────────────────────────

    # SSH: show user@host when remote
    if set -q SSH_CONNECTION
        set_color $yellow
        echo -n $USER@(prompt_hostname)" "
        set_color normal
    end

    set_color --bold $blue
    echo -n (prompt_pwd --full-length-dirs 1 -d 3)
    set_color normal

    # Git info (skip on FUSE/rclone mounts — git commands hang)
    if command -q git; and not mountpoint -q -- (pwd); and git rev-parse --is-inside-work-tree &>/dev/null
        set -l branch (git branch --show-current 2>/dev/null; or git rev-parse --short HEAD 2>/dev/null)
        set_color $overlay
        echo -n " on $branch"
        set_color normal

        # Status indicators
        set -l stat (git status --porcelain 2>/dev/null)
        if test -n "$stat"
            set -l staged (string match -r '^[MADRC]' $stat | count)
            set -l modified (string match -r '^ ?M' $stat | count)
            set -l untracked (string match -r '^\?\?' $stat | count)
            set -l indicators
            test $staged -gt 0; and set -a indicators "+"
            test $modified -gt 0; and set -a indicators "!"
            test $untracked -gt 0; and set -a indicators "?"
            if test (count $indicators) -gt 0
                set_color $yellow
                echo -n " "(string join "" $indicators)
                set_color normal
            end
        end

        # Ahead/behind
        set -l ab (git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
        if test $status -eq 0
            set -l ahead (string split \t $ab)[1]
            set -l behind (string split \t $ab)[2]
            set_color $yellow
            test "$ahead" -gt 0 2>/dev/null; and echo -n " ⇡"
            test "$behind" -gt 0 2>/dev/null; and echo -n " ⇣"
            set_color normal
        end
    end

    # Command duration (>2s)
    if test -n "$duration"; and test "$duration" -gt 2000 2>/dev/null
        set_color $overlay
        if test "$duration" -ge 60000
            set -l mins (math --scale=0 "$duration / 60000")
            set -l secs (math --scale=0 "$duration % 60000 / 1000")
            echo -n " "$mins"m"$secs"s"
        else
            set -l secs (math --scale=1 "$duration / 1000")
            echo -n " "$secs"s"
        end
        set_color normal
    end

    echo

    # ── Line 2: prompt character ─────────────────────────────────────────────
    if test $last_status -eq 0
        set_color $green
    else
        set_color $red
    end
    echo -n "❯ "
    set_color normal
end
