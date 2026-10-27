-- Colorscheme: official Catppuccin Mocha (catppuccin/nvim).
return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    opts = {
      flavour = 'mocha',
      custom_highlights = function(colors)
        -- Catppuccin dims GitSignsChangeInline to 14% blue, so replaced words
        -- in <leader>ghp barely show next to the 36% green of added words.
        -- Replaced words sit on the green added line; match the add strength.
        local darken = require('catppuccin.utils.colors').darken
        return {
          GitSignsChangeInline = {
            bg = darken(colors.green, 0.36, colors.base),
          },
        }
      end,
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
      -- config/keymaps.lua never loads.
      require('lazyvim').setup(opts)
    end,
  },
}
