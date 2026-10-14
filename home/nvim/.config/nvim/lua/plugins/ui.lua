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
  { -- VSCode-style code minimap. Split (not float): float wants wrap off,
    -- and <leader>uw / virt_wrap own wrapping. Config is vim.g.neominimap
    -- before load, not lazy.nvim opts.
    'Isrothy/neominimap.nvim',
    version = 'v3.x.x',
    lazy = false, -- maps belong to every window on startup
    keys = {
      -- <leader>um is render-markdown; uM is the minimap.
      { '<leader>uM', '<cmd>Neominimap Toggle<cr>', desc = 'Toggle Minimap' },
    },
    init = function()
      ---@type Neominimap.UserConfig
      vim.g.neominimap = {
        auto_enable = true,
        layout = 'split',
        split = {
          minimap_width = 12,
          direction = 'right',
          close_if_last_window = true,
        },
        -- Click jumps like VSCode; search hits light up the map.
        click = { enabled = true },
        search = { enabled = true },
      }
    end,
  },
}
