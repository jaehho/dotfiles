# Import ~/.config/environment.d, which systemd's user manager reads at login,
# so the Hyprland session (exec'd from arch.fish on tty1, hence the 00- prefix)
# and every terminal see the same variables. Plain KEY=VALUE lines only; no
# ${VAR} expansion or quoting.
for f in ~/.config/environment.d/*.conf
    for line in (string match -rv '^\s*(#|$)' <$f)
        set -l kv (string split -m1 = -- $line)
        test (count $kv) = 2; and set -gx $kv[1] $kv[2]
    end
end
