-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.g.have_nerd_font = true

-- Provider configuration
vim.g.node_host_prog = vim.fn.expand('~/.npm-global/bin/neovim-node-host')
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- [[ Setting options ]]
-- See `:help vim.o`

-- Hybrid line numbers: relative for motions, absolute on cursor line
vim.o.number = true
vim.o.relativenumber = true

vim.o.mouse = 'a'
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  See `:help 'clipboard'`
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

vim.o.breakindent = true
vim.o.linebreak = true
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true

-- Show which line your cursor is on
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type
vim.o.inccommand = 'split'

vim.o.cursorline = true
vim.o.scrolloff = 10

-- Allow arrow keys to wrap across lines
vim.opt.whichwrap:append('<,>,[,]')

vim.o.confirm = true

-- Session options: include localoptions so filetype/highlighting restore correctly
vim.o.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize,winpos,localoptions'

-- [[ Basic Keymaps ]]

-- Navigate by visual lines (includes wrapped lines)
vim.keymap.set({ 'n', 'v' }, 'j', function() return vim.v.count == 0 and 'gj' or 'j' end, { expr = true })
vim.keymap.set({ 'n', 'v' }, 'k', function() return vim.v.count == 0 and 'gk' or 'k' end, { expr = true })
vim.keymap.set('i', '<Down>', '<C-o>gj')
vim.keymap.set('i', '<Up>', '<C-o>gk')

-- Move lines up/down with Alt+j/k
vim.keymap.set('n', '<A-j>', ':m .+1<CR>==', { desc = 'Move line down' })
vim.keymap.set('n', '<A-k>', ':m .-2<CR>==', { desc = 'Move line up' })
vim.keymap.set('v', '<A-j>', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
vim.keymap.set('v', '<A-k>', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic Config & Keymaps
-- See :help vim.diagnostic.Opts
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },
  virtual_text = true,
  virtual_lines = false,
  -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
  jump = { on_jump = vim.diagnostic.open_float },
}

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Unified preview toggle: dispatches by filetype (typst, tex, markdown, marimo)
do
  local function stop_pdf_preview(bufnr)
    local ok, preview = pcall(function() return vim.b[bufnr].pdf_preview end)
    if not ok or not preview then return end
    if preview.pane_id and preview.pane_id ~= '' then
      vim.system({ 'tmux', 'kill-pane', '-t', preview.pane_id })
    end
    if preview.zathura_id then
      pcall(vim.fn.jobstop, preview.zathura_id)
    end
    pcall(function() vim.b[bufnr].pdf_preview = nil end)
    pcall(vim.api.nvim_del_augroup_by_name, 'PdfPreview' .. bufnr)
  end

  local function start_pdf_preview(compile_cmd, watch_cmd, src, pdf)
    local bufnr = vim.api.nvim_get_current_buf()

    if vim.b.pdf_preview then
      stop_pdf_preview(bufnr)
      vim.notify('Preview stopped', vim.log.levels.INFO)
      return
    end

    vim.system(compile_cmd):wait()
    local result = vim.system({
      'tmux', 'split-window', '-v', '-d', '-l', '6', '-P', '-F', '#{pane_id}',
      watch_cmd,
    }):wait()
    local pane_id = vim.trim(result.stdout or '')
    local zathura_id = vim.fn.jobstart({ 'zathura', pdf }, {
      on_exit = function()
        vim.schedule(function() stop_pdf_preview(bufnr) end)
      end,
    })
    vim.b.pdf_preview = { pane_id = pane_id, zathura_id = zathura_id }
    local augroup = vim.api.nvim_create_augroup('PdfPreview' .. bufnr, { clear = true })
    vim.api.nvim_create_autocmd({ 'BufDelete', 'VimLeavePre' }, {
      group = augroup,
      buffer = bufnr,
      callback = function() stop_pdf_preview(bufnr) end,
    })
  end

  vim.keymap.set('n', '<leader>tp', function()
    local ft = vim.bo.filetype

    if ft == 'typst' then
      local src = vim.api.nvim_buf_get_name(0)
      local root = vim.fs.root(0, '.git') or vim.fn.fnamemodify(src, ':h')
      local pdf = src:gsub('%.typ$', '.pdf')
      start_pdf_preview(
        { 'typst', 'compile', '--root', root, src, pdf },
        'typst watch --root ' .. vim.fn.shellescape(root) .. ' ' .. vim.fn.shellescape(src) .. ' ' .. vim.fn.shellescape(pdf),
        src, pdf
      )
    elseif ft == 'tex' then
      local src = vim.api.nvim_buf_get_name(0)
      local build_dir = vim.fn.fnamemodify(src, ':h') .. '/build'
      vim.fn.mkdir(build_dir, 'p')
      local pdf = build_dir .. '/' .. vim.fn.fnamemodify(src, ':t'):gsub('%.tex$', '.pdf')
      start_pdf_preview(
        { 'latexmk', '-pdf', '-g', '-interaction=nonstopmode', '-output-directory=' .. build_dir, src },
        'latexmk -pdf -pvc -g -interaction=nonstopmode -output-directory=' .. vim.fn.shellescape(build_dir) .. ' ' .. vim.fn.shellescape(src),
        src, pdf
      )
    elseif ft == 'markdown' then
      vim.cmd 'MarkdownPreviewToggle'
    elseif ft == 'python' then
      local lines = vim.api.nvim_buf_get_lines(0, 0, 50, false)
      local is_marimo = false
      for _, line in ipairs(lines) do
        if line:match('^import marimo') then
          is_marimo = true
          break
        end
      end
      if is_marimo then
        local src = vim.api.nvim_buf_get_name(0)
        local bufnr = vim.api.nvim_get_current_buf()

        if vim.b.marimo_pane then
          vim.system({ 'tmux', 'kill-pane', '-t', vim.b.marimo_pane })
          vim.b.marimo_pane = nil
          vim.notify('Preview stopped', vim.log.levels.INFO)
          return
        end

        local root = vim.fs.root(0, { 'pyproject.toml', '.venv' }) or vim.fn.fnamemodify(src, ':h')
        local venv_marimo = root .. '/.venv/bin/marimo'
        local marimo_bin = vim.uv.fs_stat(venv_marimo) and venv_marimo or 'marimo'
        local cmd = vim.fn.shellescape(marimo_bin) .. ' edit --watch ' .. vim.fn.shellescape(src)
        local result = vim.system({
          'tmux', 'split-window', '-v', '-d', '-l', '10', '-P', '-F', '#{pane_id}',
          cmd,
        }):wait()
        vim.b.marimo_pane = vim.trim(result.stdout or '')
        vim.api.nvim_create_autocmd({ 'BufDelete', 'VimLeavePre' }, {
          buffer = bufnr,
          once = true,
          callback = function()
            if vim.b[bufnr].marimo_pane then
              vim.system({ 'tmux', 'kill-pane', '-t', vim.b[bufnr].marimo_pane })
            end
          end,
        })
      else
        local dap = require 'dap'
        if dap.session() then
          dap.terminate()
          require('dapui').close()
          vim.notify('Debug stopped', vim.log.levels.INFO)
          return
        end
        dap.run {
          type = 'python',
          request = 'launch',
          name = 'tp: Launch file',
          program = '${file}',
          console = 'integratedTerminal',
        }
      end
    elseif ft == 'html' then
      local src = vim.api.nvim_buf_get_name(0)
      vim.fn.jobstart({ 'xdg-open', src }, { detach = true })
    else
      vim.notify('No preview for filetype: ' .. ft, vim.log.levels.WARN)
    end
  end, { desc = '[T]oggle [P]review' })
end

-- Exit terminal mode with <Esc><Esc> (easier than <C-\><C-n>)
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- [[ Basic Autocommands ]]

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then error('Error cloning lazy.nvim:\n' .. out) end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- asst (~/projects/asst) installs its Neovim plugin itself: `make install`
-- there, or the asst-git package.
local asst_nvim = vim.iter({ vim.fn.expand '~/.local/share/asst/nvim', '/usr/share/asst/nvim' }):find(
  function(dir) return vim.fn.isdirectory(dir) == 1 end
)

-- [[ Configure and install plugins ]]
require('lazy').setup({
  { -- Smart split navigation + directional resizing (works across tmux panes)
    'mrjones2014/smart-splits.nvim',
    lazy = false,
    opts = {},
    keys = {
      -- Navigation (Ctrl+hjkl) — replaces vim-tmux-navigator
      { '<C-h>', function() require('smart-splits').move_cursor_left() end, desc = 'Move to left split' },
      { '<C-j>', function() require('smart-splits').move_cursor_down() end, desc = 'Move to below split' },
      { '<C-k>', function() require('smart-splits').move_cursor_up() end, desc = 'Move to above split' },
      { '<C-l>', function() require('smart-splits').move_cursor_right() end, desc = 'Move to right split' },
      -- Resizing (Ctrl-w + hjkl) — directional border movement like tmux/Hyprland
      { '<C-w>h', function() require('smart-splits').resize_left() end, desc = 'Resize left' },
      { '<C-w>j', function() require('smart-splits').resize_down() end, desc = 'Resize down' },
      { '<C-w>k', function() require('smart-splits').resize_up() end, desc = 'Resize up' },
      { '<C-w>l', function() require('smart-splits').resize_right() end, desc = 'Resize right' },
    },
  },
  { 'NMAC427/guess-indent.nvim', opts = {} },

  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    ---@module 'gitsigns'
    ---@type Gitsigns.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      signs = {
        add = { text = '+' }, ---@diagnostic disable-line: missing-fields
        change = { text = '~' }, ---@diagnostic disable-line: missing-fields
        delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
        topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
        changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
      },
      on_attach = function(bufnr)
        local gs = require 'gitsigns'
        local map = function(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gs.nav_hunk 'next'
          end
        end, 'Next [C]hange hunk')
        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gs.nav_hunk 'prev'
          end
        end, 'Prev [C]hange hunk')

        -- Actions
        map('n', '<leader>hs', gs.stage_hunk, '[H]unk [S]tage')
        map('n', '<leader>hr', gs.reset_hunk, '[H]unk [R]eset')
        map('v', '<leader>hs', function() gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, '[H]unk [S]tage')
        map('v', '<leader>hr', function() gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, '[H]unk [R]eset')
        map('n', '<leader>hS', gs.stage_buffer, '[H]unk [S]tage buffer')
        map('n', '<leader>hR', gs.reset_buffer, '[H]unk [R]eset buffer')
        map('n', '<leader>hu', gs.undo_stage_hunk, '[H]unk [U]ndo stage')
        map('n', '<leader>hp', gs.preview_hunk, '[H]unk [P]review')
        map('n', '<leader>hi', gs.preview_hunk_inline, '[H]unk [I]nline preview')
        map('n', '<leader>hb', function() gs.blame_line { full = true } end, '[H]unk [B]lame line')
        map('n', '<leader>hd', gs.diffthis, '[H]unk [D]iff')
        map('n', '<leader>hD', function() gs.diffthis '~' end, '[H]unk [D]iff ~HEAD')

        -- Toggles
        map('n', '<leader>tb', gs.toggle_current_line_blame, '[T]oggle [B]lame line')
        map('n', '<leader>tw', gs.toggle_word_diff, '[T]oggle [W]ord diff')

        -- Text object
        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', 'inner hunk')
      end,
    },
  },

  { -- Diff viewer with word-level highlights
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory' },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = '[G]it [D]iff view' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it file [H]istory' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = '[G]it repo [H]istory' },
    },
    opts = {},
  },

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter',
    ---@module 'which-key'
    ---@type wk.Opts
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      delay = 0,
      icons = { mappings = vim.g.have_nerd_font },

      -- Document existing key chains
      spec = {
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { '<leader>d', group = '[D]ebug' },
        { '<leader>m', group = '[M]arkdown' },
        { 'gr', group = 'LSP Actions', mode = { 'n' } },
      },
    },
  },

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function() return vim.fn.executable 'make' == 1 end,
      },
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      require('telescope').setup {}

      pcall(require('telescope').load_extension, 'fzf')

      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
        callback = function(event)
          local buf = event.buf

          vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
          vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })
          vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })
          vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })
          vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })
          vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
        end,
      })

      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      vim.keymap.set(
        'n',
        '<leader>s/',
        function()
          builtin.live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end,
        { desc = '[S]earch [/] in Open Files' }
      )

      vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- LSP Plugins
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      {
        'mason-org/mason.nvim',
        ---@module 'mason.settings'
        ---@type MasonSettings
        ---@diagnostic disable-next-line: missing-fields
        opts = {},
      },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },
    config = function()
      -- This function gets run when an LSP attaches to a particular buffer.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
          -- WARN: this is Goto Declaration, not Goto Definition
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- Highlight references of the word under the cursor when it rests there
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Language servers (auto-installed via mason-tool-installer)
      ---@type table<string, vim.lsp.Config>
      local servers = {
        bashls = {},
        marksman = {},
        pyright = {
          root_markers = { 'pyproject.toml', 'pyrightconfig.json', 'setup.py', 'setup.cfg' },
          on_init = function(client)
            local root = client.workspace_folders and client.workspace_folders[1] and client.workspace_folders[1].name
            if root then
              local venv_python = root .. '/.venv/bin/python'
              if vim.uv.fs_stat(venv_python) then
                client.config.settings.python = { pythonPath = venv_python }
                client:notify('workspace/didChangeConfiguration', { settings = client.config.settings })
              end
            end
          end,
          settings = { python = {} },
        },
        rust_analyzer = {},
        tinymist = {},

        -- Special Lua config for editing this Neovim config
        lua_ls = {
          on_init = function(client)
            if client.workspace_folders then
              local path = client.workspace_folders[1].name
              if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
            end

            client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
              runtime = {
                version = 'LuaJIT',
                path = { 'lua/?.lua', 'lua/?/init.lua' },
              },
              workspace = {
                checkThirdParty = false,
                library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
                  '${3rd}/luv/library',
                  '${3rd}/busted/library',
                }),
              },
            })
          end,
          settings = {
            Lua = {},
          },
        },
      }

      -- Mason package names (not always identical to LSP config names)
      local ensure_installed = {
        'bash-language-server',
        'lua-language-server',
        'marksman',
        'pyright',
        'rust-analyzer',
        'tinymist',
        'ruff',
        'stylua',
        'shfmt',
        'typstyle',
      }
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      for name, server in pairs(servers) do
        vim.lsp.config(name, server)
        vim.lsp.enable(name)
      end
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function() require('conform').format { async = true, lsp_format = 'fallback' } end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    ---@module 'conform'
    ---@type conform.setupOpts
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable format-on-save for languages without a well standardized style
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'ruff_organize_imports', 'ruff_format' },
        sh = { 'shfmt' },
        bash = { 'shfmt' },
        typst = { 'typstyle' },
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        -- 'default' preset: <c-y> accept, <c-n>/<c-p> select, <c-space> docs
        -- See :h ins-completion
        preset = 'default',
      },

      appearance = {
        nerd_font_variant = 'mono',
      },

      completion = {
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets' },
      },

      -- Rust fuzzy matcher: downloads a prebuilt binary, falls back to Lua
      fuzzy = { implementation = 'prefer_rust_with_warning' },

      signature = {
        enabled = true,
        window = { show_documentation = false },
      },
    },
  },

  -- Highlight todo, notes, etc in comments
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    ---@module 'todo-comments'
    ---@type TodoOptions
    ---@diagnostic disable-next-line: missing-fields
    opts = { signs = false },
  },

  { -- Collection of various small independent plugins/modules
    'nvim-mini/mini.nvim',
    priority = 1000, -- carries the colorscheme; load before other start plugins
    config = function()
      -- Colorscheme: mini.base16 fed the generated Solarized palette (base16 form).
      -- theme_colors.lua is regenerated by theme-apply.
      require('mini.base16').setup {
        palette = require 'theme_colors',
        use_cterm = true,
      }

      -- Better Around/Inside textobjects
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      require('mini.surround').setup()

      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }
      statusline.section_location = function() return '%2l:%-2v' end
    end,
  },

  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    branch = 'main',
    config = function()
      local parsers = {
        'bash', 'c', 'css', 'diff', 'html', 'javascript', 'json', 'lua', 'luadoc',
        'markdown', 'markdown_inline', 'python', 'query', 'rust', 'toml',
        'typescript', 'typst', 'vim', 'vimdoc', 'yaml',
      }
      require('nvim-treesitter').install(parsers)
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          local buf, filetype = args.buf, args.match

          local language = vim.treesitter.language.get_lang(filetype)
          if not language then return end

          if not vim.treesitter.language.add(language) then return end
          vim.treesitter.start(buf, language)

          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },

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

  { -- Jump anywhere on screen with labeled targets
    'folke/flash.nvim',
    event = 'VeryLazy',
    ---@type Flash.Config
    opts = {},
    keys = {
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash' },
      { 'S', mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter' },
      { 'r', mode = 'o', function() require('flash').remote() end, desc = 'Remote Flash' },
      { 'R', mode = { 'o', 'x' }, function() require('flash').treesitter_search() end, desc = 'Treesitter Search' },
    },
  },

  { -- Autosave buffers
    'okuuva/auto-save.nvim',
    event = 'VimEnter',
    opts = {
      noautocmd = true,
    },
  },

  { -- Debug adapter protocol (Python)
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui',
      'nvim-neotest/nvim-nio',
      'jay-babu/mason-nvim-dap.nvim',
      'mfussenegger/nvim-dap-python',
    },
    keys = {
      { '<leader>dc', function() require('dap').continue() end, desc = 'Debug: Start/Continue' },
      { '<leader>di', function() require('dap').step_into() end, desc = 'Debug: Step Into' },
      { '<leader>do', function() require('dap').step_over() end, desc = 'Debug: Step Over' },
      { '<leader>dO', function() require('dap').step_out() end, desc = 'Debug: Step Out' },
      { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Debug: Toggle Breakpoint' },
      { '<leader>dB', function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, desc = 'Debug: Set Breakpoint Condition' },
      { '<F5>', function() require('dap').continue() end, desc = 'Debug: Start/Continue' },
      { '<F10>', function() require('dap').step_over() end, desc = 'Debug: Step Over' },
      { '<F11>', function() require('dap').step_into() end, desc = 'Debug: Step Into' },
      { '<F12>', function() require('dap').step_out() end, desc = 'Debug: Step Out' },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      require('mason-nvim-dap').setup {
        automatic_installation = true,
        handlers = {},
        ensure_installed = { 'debugpy' },
      }

      local mason_debugpy = vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/bin/python'
      require('dap-python').setup(mason_debugpy)
      require('dap-python').resolve_python = function()
        local root = vim.fs.root(0, { 'pyproject.toml', '.venv' })
        if root and vim.uv.fs_stat(root .. '/.venv/bin/python') then
          return root .. '/.venv/bin/python'
        end
        return vim.fn.exepath 'python3'
      end

      dapui.setup()
      dap.listeners.after.event_initialized['dapui_config'] = dapui.open
      dap.listeners.before.event_terminated['dapui_config'] = dapui.close
      dap.listeners.before.event_exited['dapui_config'] = dapui.close

      vim.keymap.set('n', '<leader>du', dapui.toggle, { desc = 'Debug: Toggle UI' })
    end,
  },

  { -- Better UI for messages, cmdline, and notifications
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = {
      'MunifTanjim/nui.nvim',
      'rcarriga/nvim-notify',
    },
    opts = {
      lsp = {
        progress = { enabled = true },
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
        },
      },
      presets = {
        bottom_search = true,
        long_message_to_split = true,
        lsp_doc_border = true,
      },
    },
  },

  { -- Indent guides
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      indent = { char = '│' },
      scope = { enabled = true },
    },
  },

  { -- Markdown preview in browser (GFM-ish, mermaid, katex)
    'iamcco/markdown-preview.nvim',
    cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
    ft = 'markdown',
    build = 'cd app && npx --yes yarn install',
    init = function()
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_theme = 'dark'
    end,
  },

  { -- asst: tasks linked to the note being edited
    name = 'asst',
    dir = asst_nvim or vim.fn.expand '~/.local/share/asst/nvim',
    enabled = asst_nvim ~= nil,
    cmd = { 'AsstTask', 'AsstAttach', 'AsstTasks' },
    keys = {
      { '<leader>mt', '<cmd>AsstTask<cr>', ft = 'markdown', desc = '[M]arkdown: new linked [T]ask' },
      { '<leader>ma', '<cmd>AsstAttach<cr>', ft = 'markdown', desc = '[M]arkdown: [A]ttach to a task' },
      { '<leader>ml', '<cmd>AsstTasks<cr>', ft = 'markdown', desc = '[M]arkdown: [L]inked tasks' },
    },
  },
}, { ---@diagnostic disable-line: missing-fields
  rocks = { enabled = false },
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
