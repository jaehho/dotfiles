-- Colorscheme: Everforest Dark Medium (sainnhe/everforest, the author's
-- own Vimscript port).
return {
  {
    'sainnhe/everforest',
    priority = 1000,
    init = function()
      vim.g.everforest_background = 'medium'
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
