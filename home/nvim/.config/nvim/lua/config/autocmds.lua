-- Autocmds load on VeryLazy. Default groups use the `lazyvim_` prefix.

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
