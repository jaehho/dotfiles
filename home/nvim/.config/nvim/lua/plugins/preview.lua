-- Browser markdown preview (GFM, mermaid, KaTeX). Pure Lua; no Node.
-- Commands match iamcco's start/stop/refresh names but there is no
-- Toggle; config/preview.lua tracks session state via the hooks below.
return {
  {
    'selimacerbas/markdown-preview.nvim',
    -- Distinct from iamcco/markdown-preview.nvim (lang.markdown); lazy keys
    -- by the trailing name and would otherwise merge the two.
    name = 'markdown-preview-selimacerbas',
    cmd = { 'MarkdownPreview', 'MarkdownPreviewRefresh', 'MarkdownPreviewStop' },
    ft = 'markdown',
    dependencies = { 'selimacerbas/live-server.nvim' },
    opts = {
      default_theme = 'dark',
      hooks = {
        on_start = function() vim.g.markdown_preview_on = true end,
        on_stop = function() vim.g.markdown_preview_on = false end,
      },
    },
  },
}
