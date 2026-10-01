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
    -- Record every buffer as-is (including Claude temps). Classification
    -- belongs in awq, not a drop at the watcher.
    'lowitea/aw-watcher.nvim',
    event = 'VeryLazy',
    opts = {},
  },
}
