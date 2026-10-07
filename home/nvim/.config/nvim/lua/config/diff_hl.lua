-- Word-diff previews: line fill quiet, actual add/change/delete words solid.
-- gitsigns defaults link *Inline to TermCursor; mini.base16 used to collapse
-- word and line marks. Without a base16 palette we set the split directly.
local M = {}

function M.apply()
  local function hl(name, opts)
    vim.api.nvim_set_hl(0, name, opts)
  end

  -- Solid word marks (read these). Catppuccin Mocha, readable on a dark fill.
  hl('GitSignsAddInline', { fg = '#1e1e2e', bg = '#a6e3a1', bold = true })
  hl('GitSignsChangeInline', { fg = '#1e1e2e', bg = '#f9e2af', bold = true })
  hl('GitSignsDeleteInline', { fg = '#1e1e2e', bg = '#f38ba8', bold = true })
  hl('GitSignsAddLnInline', { link = 'GitSignsAddInline' })
  hl('GitSignsChangeLnInline', { link = 'GitSignsChangeInline' })
  hl('GitSignsDeleteLnInline', { link = 'GitSignsDeleteInline' })
  hl('GitSignsDeleteVirtLnInLine', { link = 'GitSignsDeleteInline' })

  -- Quiet line fills (context, not the diff).
  hl('GitSignsAddPreview', { fg = '#cdd6f4', bg = '#313244' })
  hl('GitSignsDeletePreview', { fg = '#cdd6f4', bg = '#313244' })
  hl('GitSignsDeleteVirtLn', { fg = '#cdd6f4', bg = '#313244' })
  hl('GitSignsVirtLnum', { fg = '#f38ba8', bg = '#313244' })
end

--- Re-apply after a colorscheme change (Colorscheme autocmd).
function M.hook()
  local group = vim.api.nvim_create_augroup('diff_hl', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = function()
      M.apply()
    end,
  })
  M.apply()
end

return M
