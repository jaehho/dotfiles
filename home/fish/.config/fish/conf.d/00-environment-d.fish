# Import ~/.config/environment.d, which systemd's user manager reads at login,
# so every fish sees an edit there without a new login. The login shell
# (bash, ~/.bash_profile) imports the same files for the Hyprland session. Plain KEY=VALUE lines only; no
# ${VAR} expansion or quoting.
#
# No secrets here: every process of the session inherits these, and
# agents print environments while debugging. A secret goes to its one
# consumer instead (gog: ~/.config/gogcli/keyring-password through
# ~/.local/bin/gog; zotero-mcp: client_env in its config.json).
for f in ~/.config/environment.d/*.conf
    for line in (string match -rv '^\s*(#|$)' <$f)
        set -l kv (string split -m1 = -- $line)
        test (count $kv) = 2; and set -gx $kv[1] $kv[2]
    end
end
