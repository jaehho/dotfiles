-- Notes vault at ~/Obsidian (ZotLit/Templater/Dataview; synced by nextcloud-sync).
-- Link/tag completion goes through blink_cmp_obsidian (nvim-cmp sources adapted to blink).
return {
  {
    'epwalsh/obsidian.nvim',
    version = '*',
    lazy = true,
    ft = 'markdown',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      workspaces = {
        {
          name = 'vault',
          path = '~/Obsidian',
        },
      },
      -- Obsidian-native [[id]] / [[id|label]]; id is the filename stem (ZotLit citekeys).
      preferred_link_style = 'wiki',
      -- templates/ holds ZotLit liquid, not obsidian.nvim {{date}} templates.
      templates = { folder = vim.NIL },
      -- Link/tag completion goes through blink_cmp_obsidian, not nvim-cmp.
      completion = { nvim_cmp = false, min_chars = 2 },
      -- render-markdown already draws markdown; leave conceallevel alone.
      ui = { enable = false },
    },
  },

  {
    'saghen/blink.cmp',
    optional = true,
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.default = opts.sources.default or {}
      opts.sources.providers = opts.sources.providers or {}
      local add = {
        obsidian = { name = 'Obsidian', module = 'blink_cmp_obsidian', opts = { kind = 'refs' }, score_offset = 1 },
        obsidian_new = { name = 'ObsidianNew', module = 'blink_cmp_obsidian', opts = { kind = 'new' }, score_offset = -1 },
        obsidian_tags = { name = 'ObsidianTags', module = 'blink_cmp_obsidian', opts = { kind = 'tags' } },
      }
      for name, provider in pairs(add) do
        opts.sources.providers[name] = provider
        if not vim.tbl_contains(opts.sources.default, name) then
          table.insert(opts.sources.default, name)
        end
      end
    end,
  },
}
