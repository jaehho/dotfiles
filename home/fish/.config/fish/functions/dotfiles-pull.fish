# Fast-forward ~/dotfiles, restow this machine's packages (new files get
# linked, removed ones unlinked), and put nvim's plugins back on the
# lockfile when a pull changed it. Both machines commit and push; when
# both committed since the last pull, this fails and the next shell says
# so, to be fixed by hand (git pull --rebase).
#
# A machine's packages and stow ignores come from its own package
# (home/wonlab sets dotfiles_packages and dotfiles_stow_ignore); the
# default is every package but wonlab, with no ignores.
function dotfiles-pull --description 'Fast-forward ~/dotfiles and restow'
    set -l repo ~/dotfiles
    set -l lock home/nvim/.config/nvim/lazy-lock.json
    set -l packages $dotfiles_packages
    if not set -q packages[1]
        set packages (path basename $repo/home/*/ | string match -v wonlab)
    end
    set -l before (git -C $repo rev-parse HEAD); or return
    git -C $repo pull --ff-only --quiet; or return
    stow --no-folding --ignore=$dotfiles_stow_ignore -d $repo/home -t ~ \
        -R $packages; or return
    if not git -C $repo diff --quiet $before HEAD -- $lock
        nvim --headless '+Lazy! restore' +qa
    end
end
