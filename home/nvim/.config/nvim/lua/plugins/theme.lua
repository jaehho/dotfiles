-- Colorscheme: official Catppuccin Mocha (catppuccin/nvim).
return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    opts = {
      flavour = 'mocha',
    },
  },
  {
    'LazyVim/LazyVim',
    opts = {
      colorscheme = 'catppuccin-mocha',
    },
    config = function(_, opts)
      -- A custom config replaces lazy.nvim's require('lazyvim').setup(opts).
      -- Without that call, clipboard stays empty after LazyVim's defer and
      -- config/keymaps.lua never loads. Call setup, then lock the word-diff split.
      require('lazyvim').setup(opts)
      require('config.diff_hl').hook()
    end,
  },
}
