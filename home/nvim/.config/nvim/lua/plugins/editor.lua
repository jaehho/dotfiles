-- Editor extras: tmux-aware splits, git diff viewer, activity watcher.
return {
  { -- Smart split navigation + directional resizing (works across tmux panes)
    'mrjones2014/smart-splits.nvim',
    lazy = false,
    opts = {},
    keys = {
      { '<C-h>', function() require('smart-splits').move_cursor_left() end, desc = 'Move to left split' },
      { '<C-j>', function() require('smart-splits').move_cursor_down() end, desc = 'Move to below split' },
      { '<C-k>', function() require('smart-splits').move_cursor_up() end, desc = 'Move to above split' },
      { '<C-l>', function() require('smart-splits').move_cursor_right() end, desc = 'Move to right split' },
      { '<C-w>h', function() require('smart-splits').resize_left() end, desc = 'Resize left' },
      { '<C-w>j', function() require('smart-splits').resize_down() end, desc = 'Resize down' },
      { '<C-w>k', function() require('smart-splits').resize_up() end, desc = 'Resize up' },
      { '<C-w>l', function() require('smart-splits').resize_right() end, desc = 'Resize right' },
    },
  },

  { -- Diff viewer with word-level highlights
    -- Maps avoid snacks git_diff's <leader>gd / <leader>gD
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory' },
    keys = {
      { '<leader>gv', '<cmd>DiffviewOpen<cr>', desc = '[G]it diff [V]iew' },
      { '<leader>gH', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it file [H]istory' },
      { '<leader>gF', '<cmd>DiffviewFileHistory<cr>', desc = '[G]it repo history ([F]ull)' },
    },
    opts = {},
  },

  { -- ActivityWatch: file, language, git branch, project → aw-server :5600
    'lowitea/aw-watcher.nvim',
    event = 'VeryLazy',
    opts = {},
    config = function(_, opts)
      -- Skip Claude temp dumps and empty/help buffers so they do not land in
      -- the project bucket (they were showing up as champalimaud "coding").
      local function polluted()
        local f = vim.fn.expand('%p')
        if f == '' or vim.bo.buftype ~= '' then
          return true
        end
        return f:find('/tmp/claude-', 1, true) ~= nil
          or f:find('/tmp/claude-1000/', 1, true) ~= nil
          or vim.startswith(f, 'health://')
      end
      local aw = require('aw_watcher')
      local orig = aw.heartbeat
      aw.heartbeat = function()
        if polluted() then
          return
        end
        orig()
      end
      aw.setup(opts)
    end,
  },
}
