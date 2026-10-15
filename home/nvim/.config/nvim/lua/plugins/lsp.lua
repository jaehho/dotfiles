-- LSP / format / treesitter / completion overrides on top of LazyVim.
return {
  {
    'neovim/nvim-lspconfig',
    opts = {
      -- Ghosts on their own rows instead of eol virtual_text (which
      -- hard-cuts at the window edge). Stock virt_lines also trunc at the
      -- window edge (no wrap until neovim#41369), so wrap in format and
      -- let the handler split on \n.
      diagnostics = {
        virtual_text = false,
        virtual_lines = {
          format = function(diagnostic)
            local width = math.max(20, vim.api.nvim_win_get_width(0) - 12)
            local lines, cur = {}, ''
            for word in diagnostic.message:gmatch '%S+' do
              if cur == '' then
                cur = word
              elseif #cur + 1 + #word <= width then
                cur = cur .. ' ' .. word
              else
                lines[#lines + 1] = cur
                cur = word
              end
            end
            if cur ~= '' then
              lines[#lines + 1] = cur
            end
            return table.concat(lines, '\n')
          end,
        },
      },
      servers = {
        bashls = {},
        marksman = {},
        rust_analyzer = {},
        tinymist = {},
        ty = {},
      },
    },
  },

  {
    'stevearc/conform.nvim',
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      -- markdown formatters stay LazyVim lang.markdown stock
      -- (prettier + markdownlint-cli2 + markdown-toc).
      -- markdownlint config is per project (.markdownlint.yaml).
      opts.formatters_by_ft.lua = { 'stylua' }
      opts.formatters_by_ft.python = { 'ruff_organize_imports', 'ruff_format' }
      opts.formatters_by_ft.sh = { 'shfmt' }
      opts.formatters_by_ft.bash = { 'shfmt' }
      opts.formatters_by_ft.typst = { 'typstyle' }
    end,
  },

  {
    'saghen/blink.cmp',
    optional = true,
    opts = {
      keymap = {
        -- 'default' preset: <c-y> accept, <c-n>/<c-p> select, <c-space> docs
        preset = 'default',
      },
      appearance = {
        nerd_font_variant = 'mono',
      },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
      signature = {
        enabled = true,
        window = { show_documentation = false },
      },
    },
  },

  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, vim.g.ts_parsers or {})
    end,
  },

  { -- Install or update with :MasonToolsUpdateSync.
    -- run_on_start off: a startup install would run on every nvim launch,
    -- headless `+qa` included.
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'mason-org/mason.nvim' },
    opts = {
      run_on_start = false,
      ensure_installed = {
        'bash-language-server',
        'copilot-language-server',
        'lua-language-server',
        'marksman',
        'ty',
        'rust-analyzer',
        'tinymist',
        'debugpy',
        'ruff',
        'stylua',
        'shfmt',
        'typstyle',
      },
    },
  },

  { -- Debug adapter protocol (Python) — maps come from extras.dap.core
    'mfussenegger/nvim-dap-python',
    dependencies = {
      'mfussenegger/nvim-dap',
      {
        -- debugpy is in mason-tool-installer; do not start a second install here.
        'jay-babu/mason-nvim-dap.nvim',
        opts = { ensure_installed = { 'debugpy' }, automatic_installation = false },
      },
    },
    config = function()
      local mason_debugpy = vim.fn.stdpath 'data' .. '/mason/packages/debugpy/venv/bin/python'
      local dap_python = require 'dap-python'
      dap_python.setup(mason_debugpy)
      dap_python.resolve_python = function()
        local root = vim.fs.root(0, { 'pyproject.toml', '.venv' })
        if root and vim.uv.fs_stat(root .. '/.venv/bin/python') then
          return root .. '/.venv/bin/python'
        end
        return vim.fn.exepath 'python3'
      end
    end,
  },
}
