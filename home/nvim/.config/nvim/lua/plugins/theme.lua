-- Colorscheme: LazyVim default (tokyonight). theme-apply retired (issue #38);
-- no generated palette. config.diff_hl still splits word-diff preview colors.
return {
  {
    'LazyVim/LazyVim',
    opts = {
      colorscheme = 'tokyonight',
    },
    config = function()
      -- LazyVim applies opts.colorscheme; then lock the word-diff split.
      require('config.diff_hl').hook()
    end,
  },
}
