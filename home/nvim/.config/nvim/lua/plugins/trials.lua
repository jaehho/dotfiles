-- Trial of LazyVim extras against the live stack (see imports in
-- config/lazy.lua). Delete this file and those imports to end the trial.
return {
  -- Inline markdown: render-markdown (lang.markdown) replaces markview.
  -- Flip enabled to compare the other one.
  { 'OXY2DEV/markview.nvim', enabled = false },

  -- Browser preview: keep selimacerbas for <leader>tp / config.preview.
  -- iamcco shares the short name markdown-preview.nvim and would merge into
  -- the same lazy slot; preview.lua renames ours, this turns theirs off.
  { 'iamcco/markdown-preview.nvim', enabled = false },

  -- lang.markdown formats with prettier + markdownlint + toc. Prettier
  -- reflows prose; keep lint/toc only.
  {
    'stevearc/conform.nvim',
    optional = true,
    opts = {
      formatters_by_ft = {
        markdown = { 'markdownlint-cli2', 'markdown-toc' },
        ['markdown.mdx'] = { 'markdownlint-cli2', 'markdown-toc' },
      },
    },
  },
}
