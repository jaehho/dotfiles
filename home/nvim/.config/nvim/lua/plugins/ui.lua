-- UI extras beyond LazyVim's lualine/bufferline/snacks.indent.
return {
  { -- Inline markdown via lang.markdown's render-markdown. The extra mutes
    -- checkboxes and heading icons; put those back.
    'MeanderingProgrammer/render-markdown.nvim',
    opts = {
      heading = {
        sign = false,
        icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
      },
      checkbox = { enabled = true },
    },
  },

  { -- Kitty graphics: open image files, inline images in markdown/typst.
    -- LazyVim ships snacks.image but leaves it off. tmux allow-passthrough
    -- is on in .tmux.conf; magick is on PATH. `:checkhealth snacks` if a
    -- format fails. See issue #35 for the XTVERSION probe under tmux.
    'folke/snacks.nvim',
    optional = true,
    opts = {
      image = {
        enabled = true,
      },
    },
  },
}
