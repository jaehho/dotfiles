function fish_prompt
    set -l last_status $status

    # Catppuccin Frappe palette
    set -l blue 8caaee
    set -l overlay a5adce
    set -l yellow e5c890
    set -l green a6d189
    set -l red e78284

    # Line 1: directory + git
    set_color --bold $blue
    echo -n (prompt_pwd --full-length-dirs 1 -d 3)
    set_color normal

    # Git info
    if command -q git; and git rev-parse --is-inside-work-tree &>/dev/null
        set -l branch (git branch --show-current 2>/dev/null)
        set_color $overlay
        echo -n " on $branch"
        set_color normal

        # Status indicators
        set -l stat (git status --porcelain 2>/dev/null)
        if test -n "$stat"
            set -l modified (string match -r '^ ?M' $stat | count)
            set -l untracked (string match -r '^\?\?' $stat | count)
            set -l staged (string match -r '^[MADRC]' $stat | count)
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
        set -l ahead_behind (git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
        if test $status -eq 0
            set -l ahead (string split \t $ahead_behind)[1]
            set -l behind (string split \t $ahead_behind)[2]
            set_color $yellow
            test "$ahead" -gt 0 2>/dev/null; and echo -n " ⇡"
            test "$behind" -gt 0 2>/dev/null; and echo -n " ⇣"
            set_color normal
        end
    end

    echo

    # Line 2: prompt character
    if test $last_status -eq 0
        set_color $green
    else
        set_color $red
    end
    echo -n "❯ "
    set_color normal
end
