-- Word-diff previews: line fill quiet, actual add/change/delete words solid.
-- gitsigns defaults link *Inline to TermCursor; mini.base16 used to collapse
-- word and line marks. Without a base16 palette we set the split directly.
local M = {}

function M.apply()
  local function hl(name, opts)
    vim.api.nvim_set_hl(0, name, opts)
  end

  -- Solid word marks (read these). tokyonight-ish, readable on a dark fill.
  hl('GitSignsAddInline', { fg = '#000000', bg = '#9ece6a', bold = true })
  hl('GitSignsChangeInline', { fg = '#000000', bg = '#e0af68', bold = true })
  hl('GitSignsDeleteInline', { fg = '#000000', bg = '#f7768e', bold = true })
  hl('GitSignsAddLnInline', { link = 'GitSignsAddInline' })
  hl('GitSignsChangeLnInline', { link = 'GitSignsChangeInline' })
  hl('GitSignsDeleteLnInline', { link = 'GitSignsDeleteInline' })
  hl('GitSignsDeleteVirtLnInLine', { link = 'GitSignsDeleteInline' })

  -- Quiet line fills (context, not the diff).
  hl('GitSignsAddPreview', { fg = '#a9b1d6', bg = '#292e42' })
  hl('GitSignsDeletePreview', { fg = '#a9b1d6', bg = '#292e42' })
  hl('GitSignsDeleteVirtLn', { fg = '#a9b1d6', bg = '#292e42' })
  hl('GitSignsVirtLnum', { fg = '#f7768e', bg = '#292e42' })
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
