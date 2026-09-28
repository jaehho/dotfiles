# Keymap inventory (2026-09-26)

Source: live `nvim` after `VimEnter`, every lazy plugin loaded. **175** global maps.
Buffer-local maps (LSP, DAP, typr buffers) are omitted.

## Legend

| Kind | Meaning |
|---|---|
| `changed` | stock map replaced or removed in `init.lua` |
| `added` | map you added (not a plugin default) |
| `plugin` | plugin default (lazy `keys=` or plugin setup) |
| `builtin` | Neovim or bundled runtime pack |

## Who owns what

| Owner | Kind | Total | n | x | o | s | i | t |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| nvim builtin | builtin | 62 | 44 | 10 | 0 | 3 | 5 | 0 |
| telescope.nvim | plugin | 16 | 14 | 1 | 0 | 1 | 0 | 0 |
| smart-splits.nvim | plugin | 14 | 10 | 2 | 2 | 0 | 0 | 0 |
| mini.ai | plugin | 13 | 0 | 6 | 7 | 0 | 0 | 0 |
| matchit (bundled) | builtin pack | 12 | 4 | 4 | 4 | 0 | 0 | 0 |
| mini.surround | plugin | 11 | 6 | 3 | 2 | 0 | 0 | 0 |
| nvim-dap | plugin | 10 | 10 | 0 | 0 | 0 | 0 | 0 |
| flash.nvim | plugin | 9 | 2 | 3 | 4 | 0 | 0 | 0 |
| nvim builtin / other | builtin | 7 | 2 | 2 | 0 | 2 | 0 | 1 |
| user/init.lua | added | 6 | 3 | 1 | 1 | 1 | 0 | 0 |
| user/init.lua (visual-line j/k) | changed | 6 | 2 | 2 | 0 | 2 | 0 | 0 |
| plugin (lazy keys=) | plugin | 4 | 4 | 0 | 0 | 0 | 0 | 0 |
| nvim builtin comment | builtin | 2 | 1 | 1 | 0 | 0 | 0 | 0 |
| user/init.lua (insert arrows) | added | 2 | 0 | 0 | 0 | 0 | 2 | 0 |
| user/init.lua (nohlsearch) | changed | 1 | 1 | 0 | 0 | 0 | 0 | 0 |

## Plugin claims and collisions

which-key reports **zero prefix overlaps** after today’s cleanup.
Remaining soft collisions are same-chord families or mode-scoped, not prefix nests.

| Plugin | Keys | What it claims | Collision notes |
|---|---|---|---|
| flash.nvim | `s` `S` `r` `R` | jump, treesitter select, remote, treesitter search | Used to share `s` with mini.surround. Surround moved to `gz*`. `r`/`R` only in operator-pending/visual, so normal-mode `r` (replace) is untouched. |
| mini.surround | `gza` `gzd` `gzf` `gzF` `gzh` `gzr` `gzn` | add / delete / find / find-left / highlight / replace / update-n_lines | Moved off `s`. Prev/next suffixes disabled so nothing nests under `gzf`/`gzF`. |
| mini.ai | `a` `i` `]a` `[a` `]i` `[i` `g[` `g]` | around/inside textobjects, next/last, goto edge | next/last are `]a`/`[a`/`]i`/`[i` instead of `an`/`al`/`in`/`il`. Treesitter `an`/`in` and matchit `a%` removed so `a`/`i` have no children. |
| nvim builtin comment | `gc` `gC` | comment operator / comment line | Stock `gcc` nested under `gc`. Line form is now `gC`. `gc` in operator-pending is the comment textobject. |
| matchit | `%` `g%` `[%` `]%` | extended `%` matching | Stock `a%` textobject removed (nested under `a`). The `%` family is fine (`%` is not a prefix of `g%`). |
| telescope.nvim | `<leader>s*` `<leader><leader>` `<leader>/` `<leader>gd` `<leader>gh` `<leader>gH` | pickers (files, grep, help, resume, git diff/history) | All under `<leader>`. `<leader>sd` is “diagnostics” here — easy to confuse with surround’s old `sd` (now `gzd`). |
| gitsigns.nvim | `<leader>gh` and hunk maps under `<leader>h*` | hunks, blame | Shares `<leader>gh` description space with telescope git-history (`<leader>gh` is telescope). Check `:nmap <leader>g` if one wins. |
| nvim-dap | `<leader>d*` | breakpoints, continue, step, REPL | Under `<leader>d`. No bare `<leader>d` map, so no prefix nest. |
| smart-splits.nvim | `<C-h/j/k/l>` + resize/swap | move/resize across splits | Takes over the usual `<C-w>` direction moves. Stock `<C-w>` chords still exist. |
| lazy.nvim | `<leader>l` | plugin manager UI | Under `<leader>l`. |
| user/init.lua | `<leader>q` `<leader>f` `<leader>tp` LSP `gd`/`gr`/… `gC` | diagnostics, format, preview, LSP, comment line | LSP maps are buffer-local when a client attaches. |

## Stock maps you changed or removed

| Stock | Replacement | Why |
|---|---|---|
| `gcc` (comment line) | `gC` | `gcc` nested under `gc` |
| `an` `al` `in` `il` (treesitter select / mini.ai next-last) | `]a` `[a` `]i` `[i` (mini.ai only) | nested under `a`/`i` |
| `a%` (matchit textobject) | removed | nested under `a` |
| `j`/`k` | `gj`/`gk` expr | visual-line navigation |
| `s`/`sa`/`sd`/… (mini.surround defaults) | `gz*` | Flash owns `s` |

## Full chart by mode

### `n` — 103 maps

| Keys | Kind | Owner | Description |
|---|---|---|---|
| `  ` | plugin | telescope.nvim | [ ] Find existing buffers |
| ` /` | plugin | telescope.nvim | [/] Fuzzily search in current buffer |
| ` dB` | plugin | nvim-dap | Debug: Set Breakpoint Condition |
| ` dO` | plugin | nvim-dap | Debug: Step Out |
| ` db` | plugin | nvim-dap | Debug: Toggle Breakpoint |
| ` dc` | plugin | nvim-dap | Debug: Start/Continue |
| ` di` | plugin | nvim-dap | Debug: Step Into |
| ` do` | plugin | nvim-dap | Debug: Step Over |
| ` f` | added | user/init.lua | [F]ormat buffer |
| ` gH` | plugin | plugin (lazy keys=) | [G]it repo [H]istory |
| ` gd` | plugin | plugin (lazy keys=) | [G]it [D]iff view |
| ` gh` | plugin | plugin (lazy keys=) | [G]it file [H]istory |
| ` q` | changed | user/init.lua | Open diagnostic [Q]uickfix list |
| ` s.` | plugin | telescope.nvim | [S]earch Recent Files ("." for repeat) |
| ` s/` | plugin | telescope.nvim | [S]earch [/] in Open Files |
| ` sc` | plugin | telescope.nvim | [S]earch [C]ommands |
| ` sd` | plugin | telescope.nvim | [S]earch [D]iagnostics |
| ` sf` | plugin | telescope.nvim | [S]earch [F]iles |
| ` sg` | plugin | telescope.nvim | [S]earch by [G]rep |
| ` sh` | plugin | telescope.nvim | [S]earch [H]elp |
| ` sk` | plugin | telescope.nvim | [S]earch [K]eymaps |
| ` sn` | plugin | telescope.nvim | [S]earch [N]eovim files |
| ` sr` | plugin | telescope.nvim | [S]earch [R]esume |
| ` ss` | plugin | telescope.nvim | [S]earch [S]elect Telescope |
| ` sw` | plugin | telescope.nvim | [S]earch current [W]ord |
| ` tp` | plugin | plugin (lazy keys=) | [T]oggle [P]review |
| `%` | builtin pack | matchit (bundled) | — |
| `&` | builtin | nvim builtin | :help &-default |
| `<C-H>` | plugin | smart-splits.nvim | Move to left split |
| `<C-J>` | plugin | smart-splits.nvim | Move to below split |
| `<C-K>` | plugin | smart-splits.nvim | Move to above split |
| `<C-L>` | plugin | smart-splits.nvim | Move to right split |
| `<C-W><C-D>` | builtin | nvim builtin | Show diagnostics under the cursor |
| `<C-W>d` | builtin | nvim builtin | Show diagnostics under the cursor |
| `<C-W>h` | plugin | smart-splits.nvim | Resize left |
| `<C-W>j` | plugin | smart-splits.nvim | Resize down |
| `<C-W>k` | plugin | smart-splits.nvim | Resize up |
| `<C-W>l` | plugin | smart-splits.nvim | Resize right |
| `<Esc>` | changed | user/init.lua (nohlsearch) | — |
| `<F10>` | plugin | nvim-dap | Debug: Step Over |
| `<F11>` | plugin | nvim-dap | Debug: Step Into |
| `<F12>` | plugin | nvim-dap | Debug: Step Out |
| `<F5>` | plugin | nvim-dap | Debug: Start/Continue |
| `<M-j>` | builtin | nvim builtin / other | Move line down |
| `<M-k>` | builtin | nvim builtin / other | Move line up |
| `S` | plugin | flash.nvim | Flash Treesitter |
| `Y` | builtin | nvim builtin | :help Y-default |
| `[ ` | builtin | nvim builtin | Add empty line above cursor |
| `[%` | builtin pack | matchit (bundled) | — |
| `[<C-L>` | builtin | nvim builtin | :lpfile |
| `[<C-Q>` | builtin | nvim builtin | :cpfile |
| `[<C-T>` | builtin | nvim builtin | :ptprevious |
| `[A` | builtin | nvim builtin | :rewind |
| `[B` | builtin | nvim builtin | :brewind |
| `[D` | builtin | nvim builtin | Jump to the first diagnostic in the current buffer |
| `[L` | builtin | nvim builtin | :lrewind |
| `[Q` | builtin | nvim builtin | :crewind |
| `[T` | builtin | nvim builtin | :trewind |
| `[a` | builtin | nvim builtin | :previous |
| `[b` | builtin | nvim builtin | :bprevious |
| `[d` | builtin | nvim builtin | Jump to the previous diagnostic in the current buffer |
| `[l` | builtin | nvim builtin | :lprevious |
| `[q` | builtin | nvim builtin | :cprevious |
| `[t` | builtin | nvim builtin | :tprevious |
| `] ` | builtin | nvim builtin | Add empty line below cursor |
| `]%` | builtin pack | matchit (bundled) | — |
| `]<C-L>` | builtin | nvim builtin | :lnfile |
| `]<C-Q>` | builtin | nvim builtin | :cnfile |
| `]<C-T>` | builtin | nvim builtin | :ptnext |
| `]A` | builtin | nvim builtin | :last |
| `]B` | builtin | nvim builtin | :blast |
| `]D` | builtin | nvim builtin | Jump to the last diagnostic in the current buffer |
| `]L` | builtin | nvim builtin | :llast |
| `]Q` | builtin | nvim builtin | :clast |
| `]T` | builtin | nvim builtin | :tlast |
| `]a` | builtin | nvim builtin | :next |
| `]b` | builtin | nvim builtin | :bnext |
| `]d` | builtin | nvim builtin | Jump to the next diagnostic in the current buffer |
| `]l` | builtin | nvim builtin | :lnext |
| `]q` | builtin | nvim builtin | :cnext |
| `]t` | builtin | nvim builtin | :tnext |
| `g%` | builtin pack | matchit (bundled) | — |
| `gC` | changed | user/init.lua | Toggle comment line |
| `gO` | builtin | nvim builtin | vim.lsp.buf.document_symbol() |
| `g[` | plugin | smart-splits.nvim | Move to left "around" |
| `g]` | plugin | smart-splits.nvim | Move to right "around" |
| `gc` | builtin | nvim builtin comment | Toggle comment |
| `gra` | builtin | nvim builtin | vim.lsp.buf.code_action() |
| `gri` | builtin | nvim builtin | vim.lsp.buf.implementation() |
| `grn` | builtin | nvim builtin | vim.lsp.buf.rename() |
| `grr` | builtin | nvim builtin | vim.lsp.buf.references() |
| `grt` | builtin | nvim builtin | vim.lsp.buf.type_definition() |
| `grx` | builtin | nvim builtin | vim.lsp.codelens.run() |
| `gx` | builtin | nvim builtin | Opens filepath or URI under cursor with the system handler (file explorer, web browser, …) |
| `gzF` | plugin | mini.surround | Find left surrounding |
| `gza` | plugin | mini.surround | Add surrounding |
| `gzd` | plugin | mini.surround | Delete surrounding |
| `gzf` | plugin | mini.surround | Find right surrounding |
| `gzh` | plugin | mini.surround | Highlight surrounding |
| `gzr` | plugin | mini.surround | Replace surrounding |
| `j` | changed | user/init.lua (visual-line j/k) | — |
| `k` | changed | user/init.lua (visual-line j/k) | — |
| `s` | plugin | flash.nvim | Flash |

### `x` — 35 maps

| Keys | Kind | Owner | Description |
|---|---|---|---|
| ` f` | added | user/init.lua | [F]ormat buffer |
| ` sw` | plugin | telescope.nvim | [S]earch current [W]ord |
| `#` | builtin | nvim builtin | :help v_#-default |
| `%` | builtin pack | matchit (bundled) | — |
| `*` | builtin | nvim builtin | :help v_star-default |
| `<M-j>` | builtin | nvim builtin / other | Move selection down |
| `<M-k>` | builtin | nvim builtin / other | Move selection up |
| `@` | builtin | nvim builtin | :help v_@-default |
| `Q` | builtin | nvim builtin | :help v_Q-default |
| `R` | plugin | flash.nvim | Treesitter Search |
| `S` | plugin | flash.nvim | Flash Treesitter |
| `[%` | builtin pack | matchit (bundled) | — |
| `[N` | builtin | nvim builtin | Select previous sibling node |
| `[a` | plugin | mini.ai | Around last textobject |
| `[i` | plugin | mini.ai | Inside last textobject |
| `[n` | builtin | nvim builtin | Select previous node |
| `]%` | builtin pack | matchit (bundled) | — |
| `]N` | builtin | nvim builtin | Select next sibling node |
| `]a` | plugin | mini.ai | Around next textobject |
| `]i` | plugin | mini.ai | Inside next textobject |
| `]n` | builtin | nvim builtin | Select next node |
| `a` | plugin | mini.ai | Around textobject |
| `g%` | builtin pack | matchit (bundled) | — |
| `g[` | plugin | smart-splits.nvim | Move to left "around" |
| `g]` | plugin | smart-splits.nvim | Move to right "around" |
| `gc` | builtin | nvim builtin comment | Toggle comment |
| `gra` | builtin | nvim builtin | vim.lsp.buf.code_action() |
| `gx` | builtin | nvim builtin | Opens filepath or URI under cursor with the system handler (file explorer, web browser, …) |
| `gzF` | plugin | mini.surround | Find left surrounding |
| `gza` | plugin | mini.surround | Add surrounding to selection |
| `gzf` | plugin | mini.surround | Find right surrounding |
| `i` | plugin | mini.ai | Inside textobject |
| `j` | changed | user/init.lua (visual-line j/k) | — |
| `k` | changed | user/init.lua (visual-line j/k) | — |
| `s` | plugin | flash.nvim | Flash |

### `o` — 20 maps

| Keys | Kind | Owner | Description |
|---|---|---|---|
| ` f` | added | user/init.lua | [F]ormat buffer |
| `%` | builtin pack | matchit (bundled) | — |
| `R` | plugin | flash.nvim | Treesitter Search |
| `S` | plugin | flash.nvim | Flash Treesitter |
| `[%` | builtin pack | matchit (bundled) | — |
| `[a` | plugin | mini.ai | Around last textobject |
| `[i` | plugin | mini.ai | Inside last textobject |
| `]%` | builtin pack | matchit (bundled) | — |
| `]a` | plugin | mini.ai | Around next textobject |
| `]i` | plugin | mini.ai | Inside next textobject |
| `a` | plugin | mini.ai | Around textobject |
| `g%` | builtin pack | matchit (bundled) | — |
| `g[` | plugin | smart-splits.nvim | Move to left "around" |
| `g]` | plugin | smart-splits.nvim | Move to right "around" |
| `gc` | plugin | mini.ai | Comment textobject |
| `gzF` | plugin | mini.surround | Find left surrounding |
| `gzf` | plugin | mini.surround | Find right surrounding |
| `i` | plugin | mini.ai | Inside textobject |
| `r` | plugin | flash.nvim | Remote Flash |
| `s` | plugin | flash.nvim | Flash |

### `s` — 9 maps

| Keys | Kind | Owner | Description |
|---|---|---|---|
| ` f` | added | user/init.lua | [F]ormat buffer |
| ` sw` | plugin | telescope.nvim | [S]earch current [W]ord |
| `<C-S>` | builtin | nvim builtin | vim.lsp.buf.signature_help() |
| `<M-j>` | builtin | nvim builtin / other | Move selection down |
| `<M-k>` | builtin | nvim builtin / other | Move selection up |
| `<S-Tab>` | builtin | nvim builtin | vim.snippet.jump if active, otherwise <S-Tab> |
| `<Tab>` | builtin | nvim builtin | vim.snippet.jump if active, otherwise <Tab> |
| `j` | changed | user/init.lua (visual-line j/k) | — |
| `k` | changed | user/init.lua (visual-line j/k) | — |

### `i` — 7 maps

| Keys | Kind | Owner | Description |
|---|---|---|---|
| `<C-S>` | builtin | nvim builtin | vim.lsp.buf.signature_help() |
| `<C-U>` | builtin | nvim builtin | :help i_CTRL-U-default |
| `<C-W>` | builtin | nvim builtin | :help i_CTRL-W-default |
| `<Down>` | added | user/init.lua (insert arrows) | — |
| `<S-Tab>` | builtin | nvim builtin | vim.snippet.jump if active, otherwise <S-Tab> |
| `<Tab>` | builtin | nvim builtin | vim.snippet.jump if active, otherwise <Tab> |
| `<Up>` | added | user/init.lua (insert arrows) | — |

### `t` — 1 maps

| Keys | Kind | Owner | Description |
|---|---|---|---|
| `<Esc><Esc>` | builtin | nvim builtin / other | Exit terminal mode |

