-- Stock-delta paint model: whole +/- lines filled, words louder inside.
-- Line/emph backgrounds match delta --dark defaults (#002800/#006000,
-- #3f0001/#901011) so the buffer reads like `git diff` / lazygit.
local M = {}

-- delta --dark defaults (stable, not catppuccin).
local plus_line = '#002800'
local plus_emph = '#006000'
local minus_line = '#3f0001'
local minus_emph = '#901011'
-- No stock analog for in-place "change"; dark amber keeps the same weight.
local change_line = '#3a2a00'
local change_emph = '#806011'

function M.apply()
  local function hl(name, opts)
    vim.api.nvim_set_hl(0, name, opts)
  end

  -- Whole-line fills (gitsigns linehl / previews).
  hl('GitSignsAddLn', { bg = plus_line })
  hl('GitSignsDeleteLn', { bg = minus_line })
  hl('GitSignsChangeLn', { bg = change_line })
  hl('GitSignsAddPreview', { bg = plus_line })
  hl('GitSignsDeletePreview', { bg = minus_line })
  hl('GitSignsDeleteVirtLn', { bg = minus_line })
  hl('GitSignsVirtLnum', { fg = minus_emph })

  -- Word marks on top (gitsigns word_diff / inline previews).
  hl('GitSignsAddInline', { bg = plus_emph, bold = true })
  hl('GitSignsChangeInline', { bg = change_emph, bold = true })
  hl('GitSignsDeleteInline', { bg = minus_emph, bold = true })
  hl('GitSignsAddLnInline', { link = 'GitSignsAddInline' })
  hl('GitSignsChangeLnInline', { link = 'GitSignsChangeInline' })
  hl('GitSignsDeleteLnInline', { link = 'GitSignsDeleteInline' })
  hl('GitSignsDeleteVirtLnInLine', { link = 'GitSignsDeleteInline' })
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
