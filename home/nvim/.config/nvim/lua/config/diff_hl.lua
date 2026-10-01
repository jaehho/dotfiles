-- Word-diff previews: line fill quiet, actual add/change/delete words solid.
-- mini.base16 links GitSigns*Inline to the same fg as the whole line, so
-- without this a word-change preview is just "old line red, new line green".
local M = {}

function M.apply()
  local ok, p = pcall(require, 'theme_colors')
  if not ok then
    return
  end
  local function hl(name, opts)
    vim.api.nvim_set_hl(0, name, opts)
  end

  -- Solid word marks (read these).
  hl('GitSignsAddInline', { fg = p.base00, bg = p.base0B, bold = true })
  hl('GitSignsChangeInline', { fg = p.base00, bg = p.base0E, bold = true })
  hl('GitSignsDeleteInline', { fg = p.base00, bg = p.base08, bold = true })
  hl('GitSignsAddLnInline', { link = 'GitSignsAddInline' })
  hl('GitSignsChangeLnInline', { link = 'GitSignsChangeInline' })
  hl('GitSignsDeleteLnInline', { link = 'GitSignsDeleteInline' })
  hl('GitSignsDeleteVirtLnInLine', { link = 'GitSignsDeleteInline' })

  -- Quiet line fills (context, not the diff).
  hl('GitSignsAddPreview', { fg = p.base03, bg = p.base01 })
  hl('GitSignsDeletePreview', { fg = p.base03, bg = p.base01 })
  hl('GitSignsDeleteVirtLn', { fg = p.base03, bg = p.base01 })
  -- Keep the preview's lnum rail readable as "old side".
  hl('GitSignsVirtLnum', { fg = p.base08, bg = p.base01 })
end

--- Re-apply after every mini.base16.setup (theme-apply reloads that way).
function M.hook_base16()
  local base16 = require 'mini.base16'
  if base16.__diff_hl_hooked then
    M.apply()
    return
  end
  local orig = base16.setup
  base16.setup = function(opts)
    orig(opts)
    M.apply()
  end
  base16.__diff_hl_hooked = true
end

return M
