-- Colorscheme: Everforest Dark Medium (sainnhe/everforest, the author's
-- own Vimscript port).
return {
  {
    'sainnhe/everforest',
    priority = 1000,
    init = function()
      vim.g.everforest_background = 'medium'
      -- Warm-gray backgrounds, same values as the foliage palette
      -- (hypr/themes/foliage.lua); accents stay stock Everforest.
      vim.g.everforest_colors_override = {
        bg_dim = { '#292927', '233' },
        bg0 = { '#343431', '235' },
        bg1 = { '#3d3d3a', '236' },
        bg2 = { '#464642', '237' },
        bg3 = { '#50504c', '238' },
        bg4 = { '#575752', '239' },
        bg5 = { '#60605b', '240' },
      }
    end,
    -- No GitSignsChangeInline override (the Catppuccin one lifted replaced
    -- words to the strength of added words in <leader>ghp). Everforest
    -- leaves all GitSigns*Inline groups on gitsigns' TermCursor fallback,
    -- so replaced and added words already render alike.
  },
  {
    'LazyVim/LazyVim',
    opts = {
      colorscheme = 'everforest',
    },
    config = function(_, opts)
      -- A custom config replaces lazy.nvim's require('lazyvim').setup(opts).
      -- Without that call, clipboard stays empty after LazyVim's defer and
      -- config/keymaps.lua never loads.
      require('lazyvim').setup(opts)
    end,
  },
}
