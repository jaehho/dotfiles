-- LSP / format / treesitter / completion overrides on top of LazyVim.
return {
  {
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        bashls = {},
        marksman = {},
        rust_analyzer = {},
        tinymist = {},
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
      },
    },
  },

  {
    'stevearc/conform.nvim',
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      -- lang.markdown wants prettier + markdownlint-cli2 as well. Prettier
      -- reflows prose; markdownlint is the inline noise. Keep toc only.
      opts.formatters_by_ft.markdown = { 'markdown-toc' }
      opts.formatters_by_ft['markdown.mdx'] = { 'markdown-toc' }
      opts.formatters_by_ft.lua = { 'stylua' }
      opts.formatters_by_ft.python = { 'ruff_organize_imports', 'ruff_format' }
      opts.formatters_by_ft.sh = { 'shfmt' }
      opts.formatters_by_ft.bash = { 'shfmt' }
      opts.formatters_by_ft.typst = { 'typstyle' }
    end,
  },

  { -- lang.markdown lints markdown with markdownlint-cli2 (nvim-lint). Those
    -- diagnostics are the inline errors in notes. Off; do not reinstall.
    'mfussenegger/nvim-lint',
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = {}
    end,
  },

  {
    'mason-org/mason.nvim',
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return tool ~= 'markdownlint-cli2'
      end, opts.ensure_installed or {})
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

  { -- scripts/server.sh runs :MasonToolsUpdateSync from this plugin.
    -- run_on_start off: headless `+qa` in that script would otherwise abort
    -- whatever the startup install had open, and the log grep reads as failure.
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'mason-org/mason.nvim' },
    opts = {
      run_on_start = false,
      ensure_installed = {
        'bash-language-server',
        'copilot-language-server',
        'lua-language-server',
        'marksman',
        'pyright',
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
