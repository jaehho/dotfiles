" Keymaps for marimo's vim preset, matching LazyVim where marimo's
" parser can express them. marimo.toml points to this file by absolute
" path ([keymap] vimrc): "~" is not expanded.
" Only map-family commands load, and an rhs is one token without
" spaces, so <leader>, expression maps, and :move are out.
" Left out after trying them in marimo 0.25.1:
"   j and k to gj and gk: they break j and k crossing cells.
"   <Esc> to :nohlsearch: <Esc> already clears the search highlight.
"   <A-j> and <A-k> as ddp and ddkP: dd on the last line of a cell
"   leaves blank lines.

" Keep the selection after indenting.
vnoremap < <gv
vnoremap > >gv
