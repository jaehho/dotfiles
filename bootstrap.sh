#!/bin/bash
# Bootstrap dotfiles on a new machine.
# Idempotent — safe to re-run.
# Supports: Arch Linux, Ubuntu/Debian
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
COMMON_PACKAGES=(fish git tmux nvim claude rclone bin kitty ssh mime)

# ── Distro detection ──────────────────────────────────────────────────────────
DISTRO="$(. /etc/os-release 2>/dev/null && echo "${ID:-unknown}")"
echo "Detected distro: $DISTRO"

# ── Helpers ───────────────────────────────────────────────────────────────────
installed() { command -v "$1" >/dev/null 2>&1; }

symlink_tool() {
    local src="$1" dst="$LOCAL_BIN/$2"
    if installed "$2"; then
        echo "  $2: already available, skipping symlink"
        return
    fi
    if [ ! -f "$src" ]; then
        echo "  $2: source $src not found, skipping"
        return
    fi
    mkdir -p "$LOCAL_BIN"
    ln -sf "$src" "$dst"
    echo "  $2: symlinked $src -> $dst"
}

# Back up and remove any plain files that would conflict with stow,
# so stow can replace them with symlinks.
stow_with_backup() {
    local pkg="$1"
    local pkg_dir="$REPO_ROOT/$pkg"
    while IFS= read -r -d '' file; do
        local rel="${file#$pkg_dir/}"
        local target="$HOME/$rel"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo "  backing up $target -> ${target}.bak"
            mv "$target" "${target}.bak"
        fi
    done < <(find "$pkg_dir" -type f -print0)
    stow -d "$REPO_ROOT" -t ~ --no-folding "$pkg"
}

stow_common() {
    for pkg in "${COMMON_PACKAGES[@]}"; do
        echo "  stowing $pkg..."
        stow_with_backup "$pkg"
    done
}

set_default_shell_fish() {
    local fish_path
    fish_path="$(command -v fish)"
    if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$fish_path" ]; then
        echo "==> Setting fish as default shell..."
        grep -qxF "$fish_path" /etc/shells || echo "$fish_path" | sudo tee -a /etc/shells
        chsh -s "$fish_path"
        FISH_CHANGED=1
    else
        echo "  default shell: already fish, skipping"
        FISH_CHANGED=0
    fi
}

# ── Arch ──────────────────────────────────────────────────────────────────────
if [ "$DISTRO" = "arch" ]; then
    echo "==> Installing packages (Arch)..."
    sudo pacman -S --needed --noconfirm - < "$REPO_ROOT/packages/arch-snapshot.txt"

    echo "==> Stowing all packages..."
    stow_common

    echo "==> Running system-install..."
    make -C "$REPO_ROOT" system-install

    set_default_shell_fish

    if [ "$FISH_CHANGED" = "1" ]; then
        echo "==> Done. Log out and back in for fish to take effect."
    else
        echo "==> Done."
    fi
    exit 0
fi

# ── Ubuntu / Debian ───────────────────────────────────────────────────────────
if [ "$DISTRO" != "ubuntu" ] && [ "$DISTRO" != "debian" ]; then
    echo "Unsupported distro: $DISTRO"
    exit 1
fi

echo "==> Updating apt..."
sudo apt-get update -qq

echo "==> Installing minimum bootstrap deps..."
sudo apt-get install -y git curl stow make fish

echo "==> Installing packages from packages/ubuntu.txt..."
sudo apt-get install -y $(grep -v '^#' "$REPO_ROOT/packages/ubuntu.txt" | grep -v '^$')

# ── ~/.local/bin symlinks for renamed Ubuntu tools ────────────────────────────
echo "==> Setting up tool symlinks..."
mkdir -p "$LOCAL_BIN"
symlink_tool /usr/bin/batcat bat
symlink_tool /usr/bin/fdfind fd

# Make sure ~/.local/bin is in PATH for the rest of this script
export PATH="$LOCAL_BIN:$PATH"

# ── eza ───────────────────────────────────────────────────────────────────────
if installed eza; then
    echo "  eza: already installed, skipping"
else
    echo "  eza: installing..."
    if apt-cache show eza >/dev/null 2>&1; then
        sudo apt-get install -y eza
    elif installed cargo; then
        cargo install eza
    else
        echo "  eza: apt package unavailable and cargo not found — install manually"
        echo "       https://github.com/eza-community/eza/releases"
    fi
fi

# ── zoxide ────────────────────────────────────────────────────────────────────
if installed zoxide; then
    echo "  zoxide: already installed, skipping"
else
    echo "  zoxide: installing via installer script..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

# ── Kitty terminfo ────────────────────────────────────────────────────────────
# Install xterm-kitty terminfo so tmux/fish work correctly in kitty terminal
if ! infocmp xterm-kitty >/dev/null 2>&1; then
    echo "==> Installing kitty terminfo..."
    if installed kitty; then
        kitty +kitten ssh localhost true 2>/dev/null || \
            infocmp xterm-kitty 2>/dev/null | tic -x - 2>/dev/null || true
    else
        tmp_ti="$(mktemp)"
        curl -fsSL "https://raw.githubusercontent.com/kovidgoyal/kitty/master/terminfo/kitty.terminfo" \
            -o "$tmp_ti" && tic -x "$tmp_ti" && rm -f "$tmp_ti" \
            && echo "  kitty terminfo installed" \
            || echo "  kitty terminfo install failed — run: infocmp xterm-kitty | tic -x -"
    fi
else
    echo "  kitty terminfo: already installed, skipping"
fi

# ── Stow dotfiles ─────────────────────────────────────────────────────────────
echo "==> Stowing common packages..."
stow_common

# ── System configs ────────────────────────────────────────────────────────────
echo "==> Running system-install..."
make -C "$REPO_ROOT" system-install

set_default_shell_fish

echo ""
if [ "$FISH_CHANGED" = "1" ]; then
    echo "==> Bootstrap complete. Log out and back in for fish to take effect."
else
    echo "==> Bootstrap complete."
fi
