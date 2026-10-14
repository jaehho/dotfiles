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
}
