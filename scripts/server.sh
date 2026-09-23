#!/usr/bin/env bash
# server.sh: user-level dotfiles on a Debian/Ubuntu server, nothing as root.
#
#   dotfiles server [host]          from the laptop (default host: wonlab)
#   ~/dotfiles/scripts/server.sh    on the server itself
#
# First run sets up, every run updates: pulls the repo, links fish, tmux, nvim,
# claude and theme with stow, keeps Neovim and the tree-sitter CLI at their latest
# upstream release in ~/.local (Ubuntu's are too old for the nvim config), and
# brings plugins to the laptop's lazy-lock.json. sudo only when an apt package
# is missing. No timers: the server changes only when someone runs this. See
# README "Server (wonlab)".

set -euo pipefail

DOTFILES="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)"

[ "$(id -u)" != 0 ] || { echo "run as your user, not root" >&2; exit 1; }
command -v apt-get >/dev/null || { echo "server.sh is for Debian/Ubuntu" >&2; exit 1; }

# Pull, then run the pulled copy: bash reads a script as it goes, so it must
# not keep executing a file that the pull just rewrote.
if [ -z "${SERVER_PULLED:-}" ]; then
  git -C "$DOTFILES" pull -q --ff-only
  SERVER_PULLED=1 exec bash "$DOTFILES/scripts/server.sh" "$@"
fi

STOW_DIR="$DOTFILES/home"
PKGS=(fish tmux nvim claude theme)   # theme: tmux's @thm_* status-bar colors
APT=(fish stow tmux git curl jq ripgrep fd-find fzf unzip gcc make)
OPT="$HOME/.local/opt" BIN="$HOME/.local/bin"
LOG="$HOME/.local/state/dotfiles-server"
mkdir -p "$OPT" "$BIN" "$LOG"
export PATH="$BIN:$PATH"

say() { echo "==> $*"; }

case "$(uname -m)" in
  x86_64)  NVIM_ARCH=x86_64 TS_ARCH=x64 ;;
  aarch64) NVIM_ARCH=arm64  TS_ARCH=arm64 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

# The tag GitHub's /releases/latest redirects to, e.g. v0.12.5.
latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's|.*/||'
}

# --- apt ----------------------------------------------------------------------

missing=()
for p in "${APT[@]}"; do
  dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'ok installed' || missing+=("$p")
done
if [ ${#missing[@]} -gt 0 ]; then
  say "apt install ${missing[*]} (sudo)"
  sudo apt-get install -y "${missing[@]}"
fi

# --- Neovim and tree-sitter, upstream -----------------------------------------

tag=$(latest_tag neovim/neovim)
if [ "$("$BIN/nvim" --version 2>/dev/null | awk 'NR==1 {print $2}')" != "$tag" ]; then
  say "neovim $tag"
  tmp=$(mktemp -d)
  curl -fsSL "https://github.com/neovim/neovim/releases/download/$tag/nvim-linux-$NVIM_ARCH.tar.gz" | tar -xz -C "$tmp"
  rm -rf "$OPT/nvim"
  mv "$tmp/nvim-linux-$NVIM_ARCH" "$OPT/nvim"
  rm -rf "$tmp"
  ln -sfn "$OPT/nvim/bin/nvim" "$BIN/nvim"
fi

tag=$(latest_tag tree-sitter/tree-sitter)
if [ "v$("$BIN/tree-sitter" --version 2>/dev/null | awk '{print $2}')" != "$tag" ]; then
  say "tree-sitter $tag"
  curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/download/$tag/tree-sitter-linux-$TS_ARCH.gz" |
    gunzip > "$BIN/tree-sitter.new"
  chmod +x "$BIN/tree-sitter.new"
  mv -f "$BIN/tree-sitter.new" "$BIN/tree-sitter"
fi

# Claude Code updates itself once installed.
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash

# --- stow -----------------------------------------------------------------------

# stow refuses to replace a file it does not own. Move each one it names aside
# (settings.json the first time), exactly as converge does on the laptop.
{ stow -n -d "$STOW_DIR" -t "$HOME" --no-folding -R "${PKGS[@]}" 2>&1 || true; } |
  sed -n 's/.*existing target is [^:]*: //p' | sort -u | while IFS= read -r rel; do
    mv "$HOME/$rel" "$HOME/$rel.bak"
    echo "  backed up ~/$rel -> ~/$rel.bak"
  done
stow -d "$STOW_DIR" -t "$HOME" --no-folding -R "${PKGS[@]}"

# --- plugins --------------------------------------------------------------------

say "tmux plugins"
[ -d "$HOME/.tmux/plugins/tpm" ] || git clone -q https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
"$HOME/.tmux/plugins/tpm/bin/install_plugins" >"$LOG/tpm.log" 2>&1
"$HOME/.tmux/plugins/tpm/bin/update_plugins" all >>"$LOG/tpm.log" 2>&1

# Plugins to the laptop's lockfile, then parsers to match them (nvim-treesitter
# requires a parser update after a plugin update), then mason's tools. The
# config starts the parser install asynchronously; waiting on the same list
# joins it rather than racing it.
say "neovim plugins, parsers, language servers"
{
  nvim --headless '+Lazy! restore' +qa
  nvim --headless "+lua require('nvim-treesitter').update():wait(600000)" \
    "+lua require('nvim-treesitter').install(vim.g.ts_parsers):wait(600000)" +qa
  nvim --headless '+MasonToolsUpdateSync' +qa
} >"$LOG/nvim.log" 2>&1
grep -iE 'error|fail' "$LOG/nvim.log" | sed 's/^/  /' | head -10 || true
command -v npm >/dev/null ||
  echo "  npm not found: mason's npm-based servers (pyright, bash-language-server) are skipped"

say "done: nvim $("$BIN/nvim" --version | awk 'NR==1 {print $2}'), tree-sitter $("$BIN/tree-sitter" --version | awk '{print $2}'). Logs in ${LOG/#$HOME/\~}"
