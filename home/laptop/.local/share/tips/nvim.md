# Neovim

Roughly easiest-first: core motions and operators before this config's plugin
binds. Leader is `<Space>`. Anything with a leader was read out of
`home/nvim/.config/nvim/init.lua`, so it is what your config actually does.

## Which-key will tell you the rest

Press `<Space>` and wait. A menu of every leader bind appears, grouped.
Same for `g`, `[`, `]`, `z`, `"`. You never have to memorise a leader map --
just the first key.

## Search your own keymaps

`<leader>sk` fuzzy-searches every active keymap with its description.
When two plugins fight over a key, `:verbose nmap s` names the winner.

## Operator plus motion is the whole language

`d` delete, `c` change, `y` yank, `>` indent -- each takes any motion.
`dw`, `d$`, `d/foo<CR>`, `dG`. Learn motions once, every operator gets them.

## Text objects: inside and around

`ciw` changes the word under the cursor, `ci"` the string, `ci(` the
parens, `cit` an HTML tag. Swap `i` for `a` to include the delimiters.
This config's mini.ai extends these to functions and arguments.

## The dot is your macro

`.` repeats the last change. `ciw` a word, `n` to the next one, `.` to
repeat. Most refactors are that loop and nothing else.

## Undo is a tree, and it persists

`u` undo, `<C-r>` redo. `undofile` is on here, so undo history survives
closing the file. `:earlier 10m` rewinds the buffer ten minutes.

## Jump back to where you came from

`<C-o>` walks back through the jump list, `<C-i>` forward.
`` `` `` (backtick backtick) returns to the position before the last jump.
`` `. `` goes to your last edit, whatever file it was in.

## f and t move within the line

`fx` jumps forward to the next `x`, `tx` stops just before it.
`;` repeats, `,` reverses. `dt)` deletes up to the closing paren.

## % bounces between brackets

`%` jumps to the matching bracket. `d%` from an opening brace deletes the
whole block. Treesitter makes it reliable in real code here.

## Star searches the word under the cursor

`*` jumps to the next occurrence of the word you're on, `#` the previous.
No typing, no selection. `<leader>sw` does the same across the whole project.

## Escape clears the search highlight

This config maps `<Esc>` in normal mode to `:nohlsearch`.
No more leftover highlighting after a search.

## Search is smart about case

`ignorecase` + `smartcase` are on: `/error` matches Error, `/Error` does not.
Type a capital when you mean it.

## Substitutions preview live

`inccommand=split` is set, so `:%s/old/new/g` shows every match changing
in a split as you type it. You can see the mistake before you commit it.

## j and k move by screen line here

This config maps `j`/`k` to `gj`/`gk` when there's no count, so wrapped
lines behave. `5j` still moves five real lines.

## Move a line without cut and paste

`<A-j>` and `<A-k>` slide the current line down or up, reindenting as
they go. In visual mode they move the whole selection.

## s and S are flash, not substitute

flash.nvim owns `s` (jump to any label on screen) and `S` (treesitter
select). The builtin `s`/`S` are gone -- use `cl` and `cc` instead.
Note mini.surround also wants `s`; `:verbose nmap s` settles it.

## Flash is a two-character jump

Press `s`, type two characters you can see anywhere on screen, then the
label that appears. Faster than counting lines or searching.

## Surround with mini.surround

`saiw)` wraps the word in parens, `sd'` deletes the surrounding quotes,
`sr)'` replaces parens with quotes. Add, Delete, Replace.

## Registers are named clipboards

`"ayy` yanks into register a, `"ap` pastes it. `:reg` lists them all.
`"0` always holds your last yank even after you've deleted things.

## Yank goes to the system clipboard

`clipboard=unnamedplus` is set here, so `y` puts text on the system
clipboard and `p` pastes from it. No `"+` prefix needed.

## Record a macro when the dot isn't enough

`qa` starts recording into register a, `q` stops, `@a` replays, `@@`
repeats. `10@a` runs it ten times. Great for repetitive line edits.

## Visual block edits a column

`<C-v>` selects a rectangle. `I` inserts at the start of every line,
`A` appends at the end, `$` extends to each line's end first.

## Reselect what you just selected

`gv` reselects the last visual selection. `gi` puts you back in insert
mode exactly where you last left it.

## Increment the number under the cursor

`<C-a>` adds one, `<C-x>` subtracts. In visual mode `g<C-a>` turns a
column of zeros into an ascending sequence.

## Find files, not directories

`<leader>sf` fuzzy-finds files in the project.
`<leader><leader>` switches between open buffers -- usually the faster one.

## Grep the whole project

`<leader>sg` live-greps as you type. `<leader>sw` greps the word under the
cursor. `<leader>sr` resumes your last search with its results intact.

## Fuzzy-find inside the current file

`<leader>/` searches the current buffer. `<leader>s/` searches only the
files you have open. Both beat scrolling.

## Read the manual from inside the editor

`<leader>sh` fuzzy-searches the help tags. `:help` topics are excellent --
try `:help text-objects` and `:help ins-completion`.

## Recent files and the config

`<leader>s.` lists recently opened files.
`<leader>sn` jumps straight into your Neovim config directory.

## Go to definition and back

`grd` goes to the definition, `<C-t>` (or `<C-o>`) comes back.
`grr` lists references, `gri` implementations, `grt` the type definition.

## Rename a symbol everywhere

`grn` renames via the LSP -- every reference across the project, correctly.
Never do this with `:%s` again.

## Code actions fix things for you

`gra` offers the LSP's fixes for whatever is under the cursor: import the
missing name, add the type, remove the unused variable.

## Navigate a file by its symbols

`gO` lists the symbols in the current buffer, `gW` across the workspace.
Faster than scrolling for the function you half-remember.

## Diagnostics, three ways

`]d`/`[d` step through them with the float opening automatically,
`<leader>q` dumps them to the location list, `<leader>sd` fuzzy-finds them.

## Format on demand

`<leader>f` formats the buffer with conform, falling back to the LSP.
Format-on-save is configured per filetype in `init.lua`.

## Toggle inlay hints

`<leader>th` turns the LSP's inline type hints on and off.
Handy for a language you're still learning, noise once you aren't.

## Completion is control-y, not tab

blink.cmp uses the `default` preset: `<C-n>`/`<C-p>` to select,
`<C-y>` to accept, `<C-space>` for the menu and then the docs, `<C-e>` to
dismiss.

## Splits, and moving between them

`:vsplit`/`:split` (or `<C-w>v` / `<C-w>s`) split the window.
`<C-h/j/k/l>` move between splits here -- and across tmux panes, via
smart-splits. `<C-w>h/j/k/l` resize instead of moving.

## Stage a hunk without leaving the buffer

`<leader>hs` stages the hunk under the cursor, `<leader>hr` resets it,
`<leader>hp` previews it. In visual mode they act on the selected lines.

## Walk the changed hunks

`]c` and `[c` jump to the next and previous git hunk in the file.
`<leader>hb` blames the current line in full.

## See the diff properly

`<leader>gd` opens diffview over the working tree.
`<leader>gh` is the current file's history, `<leader>gH` the repo's.

## Toggle inline blame

`<leader>tb` shows the commit that last touched each line, as virtual text.
`<leader>tw` switches the diff to word granularity.

## One key previews whatever you're editing

`<leader>tp` dispatches on filetype: typst and LaTeX compile and open in
zathura, markdown opens the browser preview, marimo notebooks open a
tmux pane, Python starts the debugger.

## Debug from the editor

`<leader>db` toggles a breakpoint, `<leader>dc` starts or continues,
`<leader>do`/`<leader>di`/`<leader>dO` step over/into/out, `<leader>du`
toggles the UI. `<F5>` and `<F10>`-`<F12>` mirror the step keys.

## Your TODO comments are searchable

todo-comments highlights `TODO`, `FIXME`, `HACK`, `NOTE`.
`:TodoTelescope` lists every one in the project.

## Quickfix is a worklist

`:copen` opens it, `:cnext`/`:cprev` step through, `:cdo s/a/b/g | update`
runs a substitution on every entry. Telescope sends results there with
`<C-q>` from inside the picker.

## Marks span files

`ma` sets mark a in this buffer; `mA` sets a global mark you can jump to
from any file with `` `A ``. `:marks` lists them.

## Open a terminal inside nvim

`:terminal` opens a shell in a buffer. `<Esc><Esc>` leaves terminal mode
(this config's map for `<C-\><C-n>`). `:h terminal` for the rest.

## Read command output into the buffer

`:r !date` inserts the output of a command. `:%!sort` pipes the whole
buffer through a filter and replaces it. `!ip` sorts one paragraph.

## Fix indentation mechanically

`=` is an operator like any other: `=ap` reindents the paragraph,
`gg=G` the whole file. `guess-indent` already matched the file's style.

## Case and formatting operators

`gU` uppercases, `gu` lowercases, `g~` toggles -- all take motions.
`gq` rewraps a motion to `textwidth`; `gqip` tidies a paragraph.

## Diff two buffers on the spot

`:diffthis` in each of two windows starts a diff. `]c`/`[c` walk the
changes, `do` pulls a change in, `dp` pushes one out.

## Sudo isn't needed to see who owns a mapping

`:verbose map <key>` prints the mapping and the file that set it.
The single best tool for "why does this key do that".

## Check the config's health

`:checkhealth` reports on providers, LSPs, treesitter, and each plugin.
`:Lazy` manages plugins, `:Mason` manages LSPs and formatters.

## Count prefixes work everywhere

`3dw` deletes three words, `5>>` indents five lines, `2ci"` is still one
string. Relative line numbers are on, so `7dd` reads straight off the gutter.

## Do the tutorial, then reread it later

`:Tutor` takes half an hour and is worth redoing after a few months --
different things stick once you have real habits to hang them on.
