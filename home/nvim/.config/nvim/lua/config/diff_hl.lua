-- Word-diff previews: line fill quiet, actual add/change/delete words solid.
-- Colors come from the catppuccin.nvim palette (official port), not literals.
local M = {}

local function mocha()
  local ok, pal = pcall(require, 'catppuccin.palettes')
  if ok and pal.get_palette then
    return pal.get_palette('mocha')
  end
  return nil
end

function M.apply()
  local p = mocha()
  if not p then
    return
  end
  local function hl(name, opts)
    vim.api.nvim_set_hl(0, name, opts)
  end

  -- Solid word marks (read these).
  hl('GitSignsAddInline', { fg = p.base, bg = p.green, bold = true })
  hl('GitSignsChangeInline', { fg = p.base, bg = p.yellow, bold = true })
  hl('GitSignsDeleteInline', { fg = p.base, bg = p.red, bold = true })
  hl('GitSignsAddLnInline', { link = 'GitSignsAddInline' })
  hl('GitSignsChangeLnInline', { link = 'GitSignsChangeInline' })
  hl('GitSignsDeleteLnInline', { link = 'GitSignsDeleteInline' })
  hl('GitSignsDeleteVirtLnInLine', { link = 'GitSignsDeleteInline' })

  -- Quiet line fills (context, not the diff).
  hl('GitSignsAddPreview', { fg = p.text, bg = p.surface0 })
  hl('GitSignsDeletePreview', { fg = p.text, bg = p.surface0 })
  hl('GitSignsDeleteVirtLn', { fg = p.text, bg = p.surface0 })
  hl('GitSignsVirtLnum', { fg = p.red, bg = p.surface0 })
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
