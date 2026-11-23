# wonlab only. Fast-forward ~/dotfiles, restow the packages this host
# uses (new files get linked, removed ones unlinked), and put nvim's
# plugins back on the lockfile when a pull changed it. The checkout only
# pulls: edit dotfiles on the laptop.
function dotfiles-pull --description 'Fast-forward ~/dotfiles and restow wonlab packages'
    set -l repo ~/dotfiles
    set -l lock home/nvim/.config/nvim/lazy-lock.json
    set -l before (git -C $repo rev-parse HEAD); or return
    git -C $repo pull --ff-only --quiet; or return
    stow --no-folding --ignore='arch\.fish' --ignore='btop\.conf' \
        -d $repo/home -t ~ -R tmux nvim fish git theme wonlab; or return
    if not git -C $repo diff --quiet $before HEAD -- $lock
        nvim --headless '+Lazy! restore' +qa
    end
end
