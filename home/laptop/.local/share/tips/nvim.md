# Neovim

This config is LazyVim plus personal extras. Roughly easiest-first: core
motions and operators before plugin binds. Leader is `<Space>`. Press
`<Space>` and wait -- which-key lists every leader bind, grouped.

## Which-key will tell you the rest

A menu of every leader bind appears after `<Space>`, `g`, `[`, `]`, `z`.
You never have to memorise a leader map -- just the first key.

## Search your own keymaps

`<leader>sk` fuzzy-searches every active keymap with its description.
When two plugins fight over a key, `:verbose nmap s` names the winner.

## Operator plus motion is the whole language

`d` delete, `c` change, `y` yank, `>` indent -- each takes any motion.
`dw`, `d$`, `d/foo<CR>`, `dG`. Learn motions once, every operator gets them.

## Text objects: inside and around

`ciw` changes the word under the cursor, `ci"` the string, `ci(` the
parens, `cit` an HTML tag. Swap `i` for `a` to include the delimiters.
mini.ai extends these to functions, arguments, and more.

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

## Flash is a two-character jump

Press `s`, type two characters you can see anywhere on screen, then the
label that appears. Faster than counting lines or searching.

## Surround with mini.surround

`gsa` adds a surrounding, `gsd` deletes one, `gsr` replaces one.
`gsaiw)` wraps the word in parens, `gsd'` deletes the surrounding quotes,
`gsr)'` replaces parens with quotes.

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

## Find files

`<leader><space>` or `<leader>ff` fuzzy-finds files in the project root.
`<leader>fb` switches between open buffers -- usually the faster one.
`<leader>fr` lists recent files, `<leader>fc` your Neovim config files.

## Grep the whole project

`<leader>sg` live-greps as you type. `<leader>sw` greps the word under the
cursor. `<leader>sr` is search-and-replace across the project.

## Fuzzy-find and help

`<leader>/` greps (same as `<leader>sg`).
`<leader>sh` fuzzy-searches the help tags. `:help` topics are excellent --
try `:help text-objects` and `:help ins-completion`.

## Go to definition and back

`grd` (or `gd`) goes to the definition, `<C-t>` (or `<C-o>`) comes back.
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

## Diagnostics

`]d`/`[d` step through them (a float opens so you can read the error),
`<leader>sd` fuzzy-finds them, `<leader>xx` opens the trouble list.

## Format on demand

`<leader>cf` formats the buffer with conform, falling back to the LSP.
Format-on-save is LazyVim's; formatters live in `lua/plugins/lsp.lua`.

## Toggle inlay hints

`<leader>uh` turns the LSP's inline type hints on and off.
Handy for a language you're still learning, noise once you aren't.

## Completion is control-y, not tab

blink.cmp uses the `default` preset: `<C-n>`/`<C-p>` to select,
`<C-y>` to accept, `<C-space>` for the menu and then the docs, `<C-e>` to
dismiss.

## Ghost text from minuet

Minuet offers a grey completion from raider's Ollama via wonlab's
`raider-ollama.service` (`http://100.64.0.3:11434`). No laptop-side tunnel.
`<A-A>` accepts it, `<A-a>` accepts the line, `<A-]>`/`<A-[>` cycle,
`<A-e>` dismisses.

## Explain a selection

Visual-select some lines and press `<leader>ce`. Type a question (default
"Explain this code") and the answer opens in a bottom split with ~50 lines
of surrounding context sent along. `q` closes the split.

Minuet and explain both go through wonlab's logging proxy. Every request
(prompt, response, latency) is in `~/.local/state/ollama/requests.jsonl` on
wonlab: `ssh wonlab 'tail -f ~/.local/state/ollama/requests.jsonl'`.

## Splits, and moving between them

`:vsplit`/`:split` (or `<C-w>v` / `<C-w>s`) split the window.
`<C-h/j/k/l>` move between splits here -- and across tmux panes, via
smart-splits. `<C-w>h/j/k/l` resize instead of moving.

## Git hunks without leaving the buffer

`<leader>ghs` stages the hunk under the cursor, `<leader>ghr` resets it,
`<leader>ghp` previews it inline, `<leader>ghb` blames the line.
`<leader>gs` is git status, `<leader>gl` the log.

## See the diff properly

`<leader>gv` opens diffview over the working tree.
`<leader>gH` is the current file's history, `<leader>gF` the repo's.

## One key previews whatever you're editing

`<leader>tp` dispatches on filetype: typst and LaTeX compile and open in
zathura, markdown opens the browser preview, marimo notebooks open in
Firefox (reuses a `marimo edit --watch --no-token` workspace when one is
registered; else starts `edit --watch --no-token --headless` in tmux and
installs `watchdog` into the project venv if missing), Python starts the
debugger.

## Debug from the editor

`<leader>db` toggles a breakpoint, `<leader>dc` starts or continues,
`<leader>dO`/`<leader>di`/`<leader>do` step over/into/out, `<leader>du`
toggles the UI. Python runs use the project `.venv` when present.

## Your TODO comments are searchable

todo-comments highlights `TODO`, `FIXME`, `HACK`, `NOTE`.
`<leader>st` lists every one in the project.

## Hardtime is watching

hardtime nudges you off repeated `hjkl` spam and other habits. If it
blocks a motion you meant, count first (`5j`) or disable it for that
buffer.

## Typing practice

`:Typr` is a typing drill. `:TyprStats` shows your history (closing stats
keeps Typr usable -- patched locally).

## Quickfix is a worklist

`:copen` opens it, `:cnext`/`:cprev` step through, `:cdo s/a/b/g | update`
runs a substitution on every entry.

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
`:LazyExtras` toggles LazyVim extras (mini-surround and dap.core are on).

## Count prefixes work everywhere

`3dw` deletes three words, `5>>` indents five lines, `2ci"` is still one
string. Relative line numbers are on, so `7dd` reads straight off the gutter.

## Do the tutorial, then reread it later

`:Tutor` takes half an hour and is worth redoing after a few months --
different things stick once you have real habits to hang them on.
