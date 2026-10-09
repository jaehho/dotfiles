-- Options load before lazy.nvim. LazyVim defaults:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

-- LazyVim's lang.python extra runs this server (default: pyright).
vim.g.lazyvim_python_lsp = 'ty'

-- Provider configuration
vim.g.node_host_prog = vim.fn.expand '~/.npm-global/bin/neovim-node-host'
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- nvim-lspconfig's marksman advertises the compound filetype markdown.mdx
vim.filetype.add { extension = { mdx = 'markdown.mdx' } }

vim.opt.breakindent = true
vim.opt.linebreak = true
vim.opt.whichwrap:append '<,>,[,]'
vim.opt.confirm = true

-- Show which line your cursor is on
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Substitutions preview live, as you type
vim.opt.inccommand = 'split'

-- Session options: include localoptions so filetype/highlighting restore correctly
vim.opt.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize,winpos,localoptions'

-- scripts/server.sh installs treesitter parsers from this list
vim.g.ts_parsers = {
  'bash', 'c', 'css', 'diff', 'html', 'javascript', 'json', 'lua', 'luadoc',
  'markdown', 'markdown_inline', 'python', 'query', 'regex', 'rust', 'toml',
  'typescript', 'typst', 'vim', 'vimdoc', 'yaml',
}

-- Auto open the float when jumping with [d / ]d
vim.diagnostic.config {
  jump = { on_jump = vim.diagnostic.open_float },
}

-- Wrap toggle. LazyVim maps <leader>uw on VeryLazy via Snacks; map it here so
-- it exists even when VeryLazy has not run yet. virt_wrap.refit_all reapplies
-- word-wrap to visible virtual text after the toggle.
vim.keymap.set('n', '<leader>uw', function()
  vim.wo.wrap = not vim.wo.wrap
  local ok, vw = pcall(require, 'config.virt_wrap')
  if ok and vw.refit_all then
    vw.refit_all()
  end
end, { desc = 'Wrap' })
