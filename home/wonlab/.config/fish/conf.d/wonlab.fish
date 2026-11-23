# wonlab's packages and stow ignores for dotfiles-pull (#95). arch.fish
# starts Hyprland; btop rewrites its config, which would dirty the
# checkout. Set for every fish, since dotfiles-pull runs in a
# non-interactive one.
set -g dotfiles_packages tmux nvim fish git theme wonlab
set -g dotfiles_stow_ignore 'arch\.fish' 'btop\.conf'
