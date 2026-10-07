-- Coding extras not covered by LazyVim defaults (mini.pairs / ts-comments are core).
return {
  { -- Discourage repeated hjkl and other bad habits
    'm4xshen/hardtime.nvim',
    lazy = false,
    dependencies = { 'MunifTanjim/nui.nvim' },
    opts = {
      disabled_filetypes = {
        typr = true,
      },
    },
  },

  { -- Autosave buffers
    'okuuva/auto-save.nvim',
    event = 'VeryLazy',
    opts = {
      noautocmd = true,
    },
  },

  { 'NMAC427/guess-indent.nvim', opts = {} },

  { -- Drop al/an/il/in. They nest under mini.ai's a/i and which-key reports
    -- overlaps. '' disables a mapping in mini.ai. ai_whichkey is replaced
    -- because the LazyVim helper force-includes those prefixes and then
    -- registers every object 4× (which-key "Duplicates").
    'nvim-mini/mini.ai',
    optional = true,
    opts = function(_, opts)
      opts.mappings = vim.tbl_deep_extend('force', opts.mappings or {}, {
        around_last = '',
        inside_last = '',
        around_next = '',
        inside_next = '',
      })
      if LazyVim and LazyVim.mini and not LazyVim.mini.__ai_whichkey_ours then
        ---@diagnostic disable-next-line: duplicate-set-field
        LazyVim.mini.ai_whichkey = function()
          local objects = {
            { ' ', desc = 'whitespace' },
            { '"', desc = '" string' },
            { "'", desc = "' string" },
            { '(', desc = '() block' },
            { ')', desc = '() block with ws' },
            { '<', desc = '<> block' },
            { '>', desc = '<> block with ws' },
            { '?', desc = 'user prompt' },
            { 'U', desc = 'use/call without dot' },
            { '[', desc = '[] block' },
            { ']', desc = '[] block with ws' },
            { '_', desc = 'underscore' },
            { '`', desc = '` string' },
            { 'a', desc = 'argument' },
            { 'b', desc = ')]} block' },
            { 'c', desc = 'class' },
            { 'd', desc = 'digit(s)' },
            { 'e', desc = 'CamelCase / snake_case' },
            { 'f', desc = 'function' },
            { 'g', desc = 'entire file' },
            { 'i', desc = 'indent' },
            { 'o', desc = 'block, conditional, loop' },
            { 'q', desc = "quote `\"'" },
            { 't', desc = 'tag' },
            { 'u', desc = 'use/call' },
            { '{', desc = '{} block' },
            { '}', desc = '{} with ws' },
          }
          local ret = { mode = { 'o', 'x' } }
          for _, prefix in ipairs { 'a', 'i' } do
            ret[#ret + 1] = { prefix, group = prefix == 'a' and 'around' or 'inside' }
            for _, obj in ipairs(objects) do
              local desc = obj.desc
              if prefix == 'i' then
                desc = desc:gsub(' with ws', '')
              end
              ret[#ret + 1] = { prefix .. obj[1], desc = desc }
            end
          end
          require('which-key').add(ret, { notify = false })
        end
        LazyVim.mini.__ai_whichkey_ours = true
      end
      return opts
    end,
  },

  { -- Drop ai/ii (scope textobjects) for the same a/i nest. Jumps [i/]i stay.
    -- Scroll animation off: races noice's search_count virt_text (folke/noice.nvim#395)
    -- and the first C-d/u often skips the tween entirely.
    'folke/snacks.nvim',
    optional = true,
    opts = {
      scroll = { enabled = false },
      scope = {
        keys = {
          textobject = {
            ai = false,
            ii = false,
          },
        },
      },
    },
  },

  { -- Typing practice dashboard
    'nvzone/typr',
    dependencies = 'nvzone/volt',
    cmd = { 'Typr', 'TyprStats' },
    opts = {},
    config = function(_, opts)
      require('typr').setup(opts)
      -- Upstream: :TyprStats assigns state.win to its own float, so Typr's
      -- <C-r>/i mappings hit a stale window id after stats closes.
      local state = require 'typr.state'
      local stats = require 'typr.stats'
      local orig_open = stats.open
      stats.open = function()
        local typr_win = state.buf and vim.fn.bufwinid(state.buf) or nil
        orig_open()
        if typr_win and typr_win ~= -1 and vim.api.nvim_win_is_valid(typr_win) then
          state.win = typr_win
        end
      end
    end,
  },

  { -- Off: qwen2.5-coder:7b on raider is too weak. copilot-native owns ghost
    -- text. Endpoint notes if revived: wonlab:11434 (raider-ollama.service);
    -- accept <A-A>, line <A-a>, cycle <A-]>/<A-[>, dismiss <A-e>.
    'milanglacier/minuet-ai.nvim',
    enabled = false,
    event = 'InsertEnter',
    config = function()
      require('minuet').setup {
        provider = 'openai_fim_compatible',
        n_completions = 1,
        context_window = 2048,
        virtualtext = {
          auto_trigger_ft = { '*' },
          keymap = {
            accept = '<A-A>',
            accept_line = '<A-a>',
            accept_n_lines = '<A-z>',
            next = '<A-]>',
            prev = '<A-[>',
            dismiss = '<A-e>',
          },
        },
        provider_options = {
          openai_fim_compatible = {
            api_key = 'TERM', -- Ollama ignores it; minuet wants non-null
            name = 'Ollama raider via wonlab',
            end_point = 'http://100.64.0.3:11434/v1/completions',
            model = 'qwen2.5-coder:7b',
          },
        },
      }
    end,
  },
}
