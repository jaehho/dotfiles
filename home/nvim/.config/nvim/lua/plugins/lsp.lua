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
    opts = {
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'ruff_organize_imports', 'ruff_format' },
        sh = { 'shfmt' },
        bash = { 'shfmt' },
        typst = { 'typstyle' },
        -- lang.markdown wants prettier too; it reflows prose. lint/toc only.
        markdown = { 'markdownlint-cli2', 'markdown-toc' },
        ['markdown.mdx'] = { 'markdownlint-cli2', 'markdown-toc' },
      },
    },
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

  { -- scripts/server.sh runs :MasonToolsUpdateSync from this plugin
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'mason-org/mason.nvim' },
    opts = {
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
        'jay-babu/mason-nvim-dap.nvim',
        opts = { ensure_installed = { 'debugpy' } },
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
