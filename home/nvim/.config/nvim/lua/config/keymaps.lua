-- Keymaps load on VeryLazy. LazyVim defaults:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- Navigate by visual lines (includes wrapped lines)
vim.keymap.set({ 'n', 'v' }, 'j', function() return vim.v.count == 0 and 'gj' or 'j' end, { expr = true })
vim.keymap.set({ 'n', 'v' }, 'k', function() return vim.v.count == 0 and 'gk' or 'k' end, { expr = true })
vim.keymap.set('i', '<Down>', '<C-o>gj')
vim.keymap.set('i', '<Up>', '<C-o>gk')

-- Move lines up/down with Alt+j/k
vim.keymap.set('n', '<A-j>', ':m .+1<CR>==', { desc = 'Move line down' })
vim.keymap.set('n', '<A-k>', ':m .-2<CR>==', { desc = 'Move line up' })
vim.keymap.set('v', '<A-j>', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
vim.keymap.set('v', '<A-k>', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Builtin gcc is the line form of gc (prefix nest). Use gC instead.
vim.keymap.set('n', 'gC', function() return require('vim._comment').operator() .. '_' end, { expr = true, desc = 'Toggle comment line' })

-- LazyVim gco/gcO nest under gc and still call the deleted `gcc`. Keep the
-- behaviors on gB/gA (below/above) and use gC for the line toggle.
local function unmap(mode, lhs)
  if vim.fn.maparg(lhs, mode) ~= '' then
    vim.keymap.del(mode, lhs)
  end
end
unmap('n', 'gcc')
unmap('n', 'gco')
unmap('n', 'gcO')
vim.keymap.set('n', 'gB', 'o<esc>Vcx<esc><cmd>normal gC<cr>fxa<bs>', { desc = 'Add Comment Below' })
vim.keymap.set('n', 'gA', 'O<esc>Vcx<esc><cmd>normal gC<cr>fxa<bs>', { desc = 'Add Comment Above' })

-- Exit terminal mode with <Esc><Esc>
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Unified preview toggle (typst/tex/markdown/marimo/python/html)
vim.keymap.set('n', '<leader>tp', function() require('config.preview').toggle() end, { desc = '[T]oggle [P]review' })

-- Zotero annotation → markdown blockquote at cursor (stock local API :23119)
vim.keymap.set('n', '<leader>zq', function() require('zotero_quotes').pick() end, { desc = 'Zotero [Q]uote' })

-- Claude Code memory and CLAUDE.md files across projects (<c-x>/dd deletes)
vim.api.nvim_create_user_command('ClaudeMemory', function() require('claude_memory').pick() end, {})
vim.keymap.set('n', '<leader>fM', function() require('claude_memory').pick() end, { desc = 'Claude [M]emory' })
