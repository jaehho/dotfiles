-- UI extras beyond LazyVim's lualine/bufferline/snacks.indent.
return {
  { -- Render markdown inline in Neovim
    'OXY2DEV/markview.nvim',
    lazy = false,
    opts = {
      preview = {
        hybrid_modes = { 'n', 'i' },
        filetypes = { 'markdown', 'quarto', 'rmd' },
      },
    },
  },
}
