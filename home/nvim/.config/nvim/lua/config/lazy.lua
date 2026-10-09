local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup {
  spec = {
    { 'LazyVim/LazyVim', import = 'lazyvim.plugins' },
    -- Snippet engine. friendly-snippets via LuaSnip's vscode loader; blink
    -- gets snippets.preset = 'luasnip'. No personal snippets yet.
    { import = 'lazyvim.plugins.extras.coding.luasnip' },
    { import = 'lazyvim.plugins.extras.coding.mini-surround' },
    { import = 'lazyvim.plugins.extras.dap.core' },
    { import = 'lazyvim.plugins.extras.lang.python' },
    { import = 'lazyvim.plugins.extras.util.mini-hipatterns' },

    -- Config formats in this repo: SchemaStore + yamlls / jsonls / taplo
    { import = 'lazyvim.plugins.extras.lang.json' },
    { import = 'lazyvim.plugins.extras.lang.yaml' },
    { import = 'lazyvim.plugins.extras.lang.toml' },

    -- Editing: yank ring, smart increment
    { import = 'lazyvim.plugins.extras.coding.yanky' },
    { import = 'lazyvim.plugins.extras.editor.dial' },

    -- render-markdown, typst-preview, vimtex, octo, Claude Code bridge
    { import = 'lazyvim.plugins.extras.lang.markdown' },
    { import = 'lazyvim.plugins.extras.lang.typst' },
    { import = 'lazyvim.plugins.extras.lang.tex' },
    { import = 'lazyvim.plugins.extras.util.octo' },
    { import = 'lazyvim.plugins.extras.ai.claudecode' },
    { import = 'lazyvim.plugins.extras.ai.copilot-native' },

    { import = 'plugins' },
  },
  defaults = {
    lazy = false,
    version = false,
  },
  install = { colorscheme = { 'habamax' } },
  checker = {
    enabled = true,
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip',
        'tarPlugin',
        'tohtml',
        'tutor',
        'zipPlugin',
      },
    },
  },
}
