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

-- LazyVim wrap_spell turns wrap on for prose. Keep spell; wrap is a manual
-- toggle (<leader>uw). Code should be formatted so wrap is unnecessary.
local prose = { 'text', 'plaintex', 'typst', 'gitcommit', 'markdown' }
local wrap_group = vim.api.nvim_create_augroup('lazyvim_wrap_spell', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = wrap_group,
  pattern = prose,
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.spell = true
  end,
})
for _, win in ipairs(vim.api.nvim_list_wins()) do
  if vim.tbl_contains(prose, vim.bo[vim.api.nvim_win_get_buf(win)].filetype) then
    vim.wo[win].wrap = false
  end
end
