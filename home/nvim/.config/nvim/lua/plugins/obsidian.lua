-- Notes via obsidian-nvim (community fork of epwalsh/obsidian.nvim). It runs
-- an in-process LSP, so blink.cmp completes [[links]] and #tags through its
-- `lsp` source with no adapter. Point a workspace at a real path: files
-- behind a symlink inside a workspace are not searched.
return {
  {
    'obsidian-nvim/obsidian.nvim',
    version = '*',
    lazy = true,
    ft = 'markdown',
    ---@module 'obsidian'
    ---@type obsidian.config
    opts = {
      legacy_commands = false,
      workspaces = {
        { name = 'lab', path = '~/projects/lab/notes' },
        { name = 'vault', path = '~/Obsidian' },
      },
      -- Obsidian-native [[id]] / [[id|label]]; id is the filename stem (ZotLit citekeys).
      link = { style = 'wiki' },
      -- templates/ holds ZotLit liquid, not obsidian.nvim {{date}} templates.
      templates = { enabled = false },
      completion = { min_chars = 2 },
      -- render-markdown already draws markdown; leave conceallevel alone.
      ui = { enable = false },
      -- No {{properties}}: Note.status counts the always-present id/aliases/tags
      -- keys, so it reads 3 even for a file with no front matter.
      footer = {
        format = '{{backlinks}} backlinks  {{words}} words  {{chars}} chars',
      },
    },
  },
}
