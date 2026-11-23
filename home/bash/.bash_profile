# Login shell (bash; fish runs inside tmux). bash has already read
# /etc/profile. This starts the Hyprland session on tty1, with the
# environment every app and terminal inherits.

# ~/.config/environment.d, which systemd's user manager reads at login:
# plain KEY=VALUE lines only, as 00-environment-d.fish reads them. No
# secrets there: every process of the session inherits these.
for f in ~/.config/environment.d/*.conf; do
    [[ -r $f ]] || continue
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
        [[ $line == *=* ]] && export "${line%%=*}=${line#*=}"
    done <"$f"
done

# While fish was the login shell, the session got these from fish
# universals: fish_user_paths (config.fish's fish_add_path) and an
# exported NODE_OPTIONS. Kept for the whole session, in the same order.
for d in ~/.local/bin ~/.npm-global/bin ~/.cargo/bin; do
    [[ :$PATH: == *:$d:* ]] || PATH=$d:$PATH
done
export PATH
export NODE_OPTIONS=--dns-result-order=ipv4first

[[ -f ~/.bashrc ]] && . ~/.bashrc

if command -v Hyprland >/dev/null && [[ -z $DISPLAY && -z $WAYLAND_DISPLAY ]] \
    && [[ $(tty) == /dev/tty1 ]]; then
    exec /usr/bin/start-hyprland
fi
