status is-interactive; or return

function fish_user_key_bindings
    # Ctrl+Z to resume last background job (toggle suspend/resume)
    bind \cz 'fg 2>/dev/null; commandline -f repaint'

    # Shift+Enter to insert newline (multi-line editing)
    bind shift-enter 'commandline -i \n'
    bind \e\[13\;2u 'commandline -i \n'
end
