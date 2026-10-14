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
        treesitter = { enabled = true },
        -- Click jumps like VSCode; search hits light up the map.
        click = { enabled = true },
        search = { enabled = true },
      }
    end,
    config = function()
      -- First paint can cache _Neominimap.* groups before catppuccin's @*
      -- fgs settle (Isrothy/neominimap.nvim#245). Rebuild after UI is up.
      local group =
        vim.api.nvim_create_augroup('neominimap-recolor', { clear = true })
      local function recolor()
        vim.schedule(function()
          local ok, ts = pcall(require, 'neominimap.map.treesitter')
          if ok and ts.clear_hl_cache then
            ts.clear_hl_cache()
          end
          pcall(function()
            require('neominimap.buffer.internal').refresh_all_minimap_buffers()
          end)
        end)
      end
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = group,
        callback = recolor,
      })
      vim.api.nvim_create_autocmd('User', {
        group = group,
        pattern = 'VeryLazy',
        callback = recolor,
      })
    end,
  },
}
