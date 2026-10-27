-- Editor extras: tmux-aware splits, git diff viewer, gitsigns base toggle,
-- activity watcher.
local vs_last_change = false

-- Parent of the last commit that touched the buffer's file, so the signs
-- show that file's most recent change even on a clean tree. Nil (the index)
-- for untracked files and for files whose last commit is the root commit.
local function parent_of_last_change(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  local out = vim
    .system(
      { 'git', 'log', '-1', '--format=%P', '--', file },
      { cwd = vim.fs.dirname(file), text = true }
    )
    :wait()
  local parent = vim.split(vim.trim(out.stdout or ''), '%s+')[1]
  if out.code ~= 0 or parent == '' then return nil end
  return parent
end

local function apply_last_change_base(bufnr)
  vim.api.nvim_buf_call(bufnr, function()
    require('gitsigns').change_base(parent_of_last_change(bufnr))
  end)
end

return {
  { -- Smart split navigation + directional resizing (works across tmux panes)
    -- v3 core has no multiplexer code. backend-tmux sets tmux's @pane-is-vim
    -- and walks panes past the last Neovim split. Do not lazy load: until the
    -- plugin runs, tmux treats the pane as a shell and swallows C-hjkl.
    'mrjones2014/smart-splits.nvim',
    lazy = false,
    dependencies = {
      { 'smart-splits-nvim/backend-tmux', main = 'smart-splits-backend-tmux' },
    },
    opts = {
      mux = { backend = 'smart-splits-backend-tmux' },
    },
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

  { -- Gitsigns against the parent of each file's last commit
    -- LazyVim's gitsigns spec owns the signs and <leader>gh*. The base is per
    -- file, so it is applied on attach and on BufEnter while the toggle is on.
    'lewis6991/gitsigns.nvim',
    opts = function(_, opts)
      local on_attach = opts.on_attach
      opts.on_attach = function(bufnr)
        if on_attach and on_attach(bufnr) == false then return false end
        if vs_last_change then apply_last_change_base(bufnr) end
      end
      vim.api.nvim_create_autocmd('BufEnter', {
        callback = function(args)
          if vs_last_change and require('gitsigns.cache').cache[args.buf] then
            apply_last_change_base(args.buf)
          end
        end,
      })
      Snacks.toggle({
        name = 'Gitsigns vs last change',
        get = function() return vs_last_change end,
        set = function(state)
          vs_last_change = state
          if state then
            apply_last_change_base(vim.api.nvim_get_current_buf())
          else
            require('gitsigns').change_base(nil, true)
          end
        end,
      }):map('<leader>g~')
    end,
  },

  { -- ActivityWatch: file, language, git branch, project → aw-server :5600
    -- Record every buffer as-is (including Claude temps). Classification
    -- belongs in awq, not a drop at the watcher.
    'lowitea/aw-watcher.nvim',
    event = 'VeryLazy',
    opts = {},
  },
}
