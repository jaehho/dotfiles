-- Autocmds load on VeryLazy. Default groups use the `lazyvim_` prefix.

-- LazyVim checktimes only on FocusGained/TermClose/TermLeave. An external
-- write (Claude, git checkout, a formatter) then leaves the buffer stale, and
-- gitsigns diffs that buffer — not the file — so the sign column treats the
-- stale view as the working tree until a tmux focus round-trip. Idle
-- checktime reloads clean buffers without leaving nvim. autoread is on by
-- default, so a clean buffer reloads silently; a dirty one still prompts.
vim.api.nvim_create_autocmd('CursorHold', {
  group = vim.api.nvim_create_augroup('lazyvim_checktime_idle', { clear = true }),
  desc = 'Reload buffers changed outside Vim without a focus round-trip',
  callback = function()
    if vim.bo.buftype ~= 'nofile' then
      -- :checktime from an autocmd is postponed to a "harmless" moment and
      -- can sit there; schedule the call so it runs outside the autocmd.
      vim.schedule(function()
        vim.cmd('checktime')
      end)
    end
  end,
})

-- Treesitter select parent/child and matchit a% nest under mini.ai's a/i.
-- Drop them; [n/]n/[N/]N still grow/shrink the treesitter selection.
-- (an/in also come from mini.ai's around_next/inside_next — those are
-- disabled in plugins/coding.lua. This catches treesitter-textobjects.)
local function unmap(mode, lhs)
  if vim.fn.maparg(lhs, mode) ~= '' then
    vim.keymap.del(mode, lhs)
  end
end

for _, mode in ipairs { 'x', 'o' } do
  unmap(mode, 'an')
  unmap(mode, 'in')
end

-- This file loads on VeryLazy (after VimEnter) for a bare `nvim`, but before
-- plugin/ scripts when a file is passed, so matchit may not be loaded yet.
local function drop_matchit_a()
  for _, mode in ipairs { 'x', 'o' } do
    unmap(mode, 'a%')
  end
end
if vim.v.vim_did_enter == 1 then
  drop_matchit_a()
else
  vim.api.nvim_create_autocmd('VimEnter', { desc = 'Drop matchit a% so it does not nest under mini.ai a', callback = drop_matchit_a })
end
