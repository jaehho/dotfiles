# Tridactyl

Roughly easiest-first. `tip` draws unseen tips in file order, so new material
arrives in this sequence. Verified against Tridactyl's default binds and
`home/tridactyl/.config/tridactyl/tridactylrc` in this repo.

## Follow any link without the mouse

`f` paints a letter hint on every link; type the letters to click it.
`F` does the same but opens in a background tab.
This one bind replaces most of what you use a mouse for.

## Escape gets you out of everything

`<Esc>` leaves insert mode, hint mode, visual mode, and the command line.
If a page steals your keys, `<S-Insert>` toggles ignore mode off and on.

## Open a URL three ways

`o` opens in this tab, `t` in a new tab, `w` in a new window.
Capitalised (`O` `T` `W`) they prefill the current URL so you can edit it.
`T` is the fast way to fork the page you're on.

## Back and forward are H and L

`H` goes back, `L` goes forward. Same hand position as `h`/`l` scrolling.
Much faster than reaching for Alt-Left.

## Switch tabs with J and K

Your `tridactylrc` swaps these from the default: `J` is next, `K` is previous.
`gt`/`gT` also work, and `g0`/`g$` jump to the first/last tab.

## Close a tab and take it back

`d` closes the current tab, `u` reopens the last one you closed.
`u` is the single most reassuring bind in Tridactyl -- close freely.

## Find a tab by name instead of by position

`b` opens a fuzzy tab switcher over the current window; `B` searches every
window. Once you have thirty tabs this beats cycling with `J` forever.

## Yank the current URL

`yy` copies the URL. `yt` copies the title, `ym` copies a markdown link,
`yc` copies the canonical URL. `yq` renders it as a QR code for your phone.

## Paste a URL from the clipboard

`p` opens whatever URL is in your clipboard in this tab, `P` in a new tab.
Copy a link out of a terminal, hit `P`, done.

## Yank a link without visiting it

`;y` hints every link and copies the one you pick.
`;p` copies the link's *text* instead of its URL.

## Jump into the page's search box

`gi` focuses the first text input on the page.
`;i` hints every input so you can pick a specific one.
`gI` is the same as `;i` but skips the mode change.

## The command line is `:`

`:` opens Tridactyl's ex command line. Tab completes, `<C-f>` forces
completion. Everything Tridactyl can do is an ex command.

## Ask Tridactyl about itself

`:help` opens the manual. `:help <bind-or-command>` jumps straight to the
entry. `<F1>` is bound to `help` too.

## Do the tutorial once

`:tutor` walks through hinting, tabs, and modes in about ten minutes.
It is the fastest way to stop guessing.

## Scroll like a pager

`<C-d>`/`<C-u>` half a page, `<C-f>`/`<C-b>` a full page,
`gg`/`G` to top/bottom. `j`/`k` scroll ten lines.

## Repeat the last command

`.` repeats your last Tridactyl action, exactly like Vim.
Prefix a count: `3.` runs it three times.

## Walk paginated sites with ]] and [[

`]]` follows the "next" link, `[[` follows "previous". Tridactyl guesses
which link that is from its text. Works on search results and forums.

## Edit the URL's number in place

`<C-a>` increments the first number in the URL, `<C-x>` decrements it.
Gallery and paginated URLs become one keystroke to walk.

## Climb the URL tree

`gu` strips one path segment off the URL, `gU` goes to the site root.
`gu` repeatedly is how you find the index page of anything.

## Zoom without the mouse

`zi` zooms in, `zo` out, `zz` resets to 100%. `zm`/`zr` step by a larger
amount. Per-site, so it sticks for that domain.

## Jump back to where you were on the page

`<C-o>` goes back in the jump list, `<C-i>` forward. This includes
scroll positions, not just pages -- useful after clicking a footnote.

## Mark a spot on a long page

`m` then a letter sets a mark, `` ` `` then that letter jumps to it.
`M` then a letter sets a *quickmark* to the whole URL, usable from any page.

## Bookmark from the keyboard

`a` bookmarks the current page silently. `A` opens the bookmark dialog
so you can set a folder and tags.

## Let one keystroke through to the page

`<C-v>` passes the very next key to the page instead of Tridactyl.
Use it when a webapp wants a key that Tridactyl has bound.

## Ignore mode for webapps

`<S-Insert>` drops Tridactyl into ignore mode, where it passes everything
through. Press it again to come back. Essential in Gmail or a web IDE.

## Blacklist a site permanently

`:blacklistadd example.com` disables Tridactyl there for good.
This repo's `tridactylrc` already does it for `cvat.jaehho.com`.

## Reader mode

`gr` strips a page to Firefox's reader view. `;r` hints links and opens
the one you pick directly in reader mode.

## Find the tab that is making noise

`ga` jumps to whichever tab is playing audio. `<A-m>` mutes the current
tab, `<A-p>` pins it.

## Move a tab along the bar

`<<` moves the current tab left, `>>` moves it right.
`:tabmove 0` sends it to the front.

## Close a swathe of tabs

`gx0` closes every tab to the left, `gx$` every tab to the right.
`D` closes the current tab and moves left instead of right.

## Select text with the keyboard

`v` hints an element and enters visual mode there. Then `w`/`b`/`e` extend
by word, `j`/`k` by line, and `y` copies the selection.

## Search from the keybar

`s` opens the command line prefilled with `open search`, `S` with
`tabopen search`. Type the query and hit enter.

## Teach it your own search engines

`:set searchurls.gh https://github.com/search?q=%s` then `t gh tridactyl`
searches GitHub in a new tab. `%s` is where the query lands.

## Rebind anything

`:bind J tabnext` changes a bind for this session; put the same line in
`tridactylrc` to make it stick. `:unbind <key>` removes one.

## Reload your rc file

`:source` re-reads `~/.config/tridactyl/tridactylrc` without restarting
Firefox. Edit, `:source`, test -- that's the whole config loop.

## See what your config actually is

`:viewconfig` dumps the live config as JSON. `:viewconfig nmaps` shows
just the normal-mode binds, including everything you overrode.

## Edit any text box in Neovim

In a text field, `<C-i>` opens the contents in your `$EDITOR` in a real
terminal. Write and quit, and the text lands back in the browser.
This is the feature that justifies the whole extension.

## Chain commands with composite

`:composite tabprev; tabclose #` runs two ex commands in order.
Bind a composite to build actions Tridactyl doesn't ship.

## Hint by category, not just links

`;b` background tab, `;t` new tab, `;s` save, `;a` save-as, `;#` yank the
element's anchor, `;;` hints *every* element regardless of type.

## Hints for images

`;Y` yanks an image's URL, `;m`/`;M` reverse-image-search it with Google
Lens in this tab or a new one.

## Keep hinting after the first pick

Any `;g<flag>` variant stays in hint mode after you pick, so `;gb` opens
link after link in background tabs without re-entering hint mode.

## Open a hint in a container

`:hint -W tabopen -c work` hints links and opens the pick in the "work"
container. `:tabopen -c <container>` works on its own too.

## Detach a tab into its own window

`<Space>d` -- a bind from this repo's `tridactylrc` -- pulls the current
tab out into a new window.

## Hide Firefox's tab bar

`:guiset tabs none` and `:guiset navbar autohide` reclaim the top of the
screen. `:guiset gui full` hides everything. Needs a restart.

## Clear browsing data

`:sanitize history cookies` wipes those categories.
`:sanitize -t 1h all` limits it to the last hour.

## Quit everything

`ZZ` closes the browser. Same muscle memory as Vim.
