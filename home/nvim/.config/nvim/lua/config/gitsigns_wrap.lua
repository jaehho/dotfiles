-- gitsigns inline preview uses extmark virt_lines for the old side of a hunk.
-- Neovim ignores 'wrap' for virt_lines; with wrap on, gitsigns' overflow=scroll
-- truncates. Split those lines to the window width so the preview wraps.
local api = vim.api

local M = {}

local function dw(text, col)
  return vim.fn.strdisplaywidth(text, col or 0)
end

--- Longest character-aligned prefix of text that fits max_cols display cells.
--- start_col is only for tab expansion; max_cols is a width budget, not a column.
local function fit_bytes(text, max_cols, start_col)
  if text == '' or max_cols <= 0 then
    return ''
  end
  local positions = vim.str_utf_pos(text)
  local last_fit = 0
  local used = 0
  for i = 1, #positions do
    local b = positions[i]
    local next_b = positions[i + 1] or (#text + 1)
    local ch = text:sub(b, next_b - 1)
    local w = dw(ch, start_col + used)
    if used + w > max_cols then
      break
    end
    used = used + w
    last_fit = next_b - 1
  end
  return text:sub(1, last_fit)
end

--- First character of text (character-aligned).
local function first_char(text)
  local positions = vim.str_utf_pos(text)
  local b = positions[1]
  local next_b = positions[2] or (#text + 1)
  return text:sub(b, next_b - 1)
end

--- Longest word-aware fit: stop before a split word when possible.
--- Returns the piece and whether the row should end (word break).
--- @return string piece
--- @return boolean flush
local function word_fit(text, max_cols, start_col)
  local piece = fit_bytes(text, max_cols, start_col)
  if piece == '' then
    return '', false
  end
  if #piece >= #text then
    return piece, false
  end
  local rest = text:sub(#piece + 1)
  if piece:match '%s$' or rest:match '^%s' then
    return piece, false
  end
  -- Mid-word. Retreat to the last space so the word moves to the next row.
  local cut = piece:find '%s[^%s]*$'
  if cut and cut > 1 then
    return piece:sub(1, cut - 1), true
  end
  -- Word longer than the row: hard break and end the row.
  return piece, true
end

--- Drop gitsigns pad_width (300) trailing spaces so they do not wrap.
local function strip_trailing_spaces(vline)
  local out = {}
  for i, chunk in ipairs(vline) do
    out[i] = { chunk[1], chunk[2] }
  end
  while #out > 0 do
    local last = out[#out]
    local trimmed = last[1]:gsub('%s+$', '')
    if trimmed == '' then
      table.remove(out)
    else
      if trimmed ~= last[1] then
        last[1] = trimmed
      end
      break
    end
  end
  return out
end

--- Split one virt_line into rows of at most `width` display columns.
--- Continuation rows indent to `indent` (matches the buffer's breakindent).
local function wrap_virt_line(vline, width, indent)
  vline = strip_trailing_spaces(vline)
  if width <= 0 then
    return { vline }
  end

  local total = 0
  for _, chunk in ipairs(vline) do
    total = total + dw(chunk[1])
  end
  if total <= width then
    return { vline }
  end

  local rows = {}
  local current = {}
  local col = 0
  local row_index = 0

  local function new_row()
    if #current > 0 then
      rows[#rows + 1] = current
    end
    row_index = row_index + 1
    current = {}
    col = 0
    if row_index > 1 and indent > 0 then
      current[1] = { string.rep(' ', indent), 'Normal' }
      col = indent
    end
  end

  new_row()

  local function strip_leading(s)
    return (s:gsub('^%s+', '', 1))
  end

  for _, chunk in ipairs(vline) do
    local text, hl = chunk[1], chunk[2]
    while text ~= '' do
      -- Continuation row still only holds breakindent spaces: drop leading blanks.
      if row_index > 1 and col == indent then
        text = strip_leading(text)
        if text == '' then
          break
        end
      end

      local avail = width - col
      if avail <= 0 then
        new_row()
        text = strip_leading(text)
        if text == '' then
          break
        end
        avail = width - col
      end

      local piece, flush = word_fit(text, avail, col)
      if piece == '' then
        -- Row too narrow for the next cell (wide char / tab); force one char.
        piece = first_char(text)
        flush = false
      end
      current[#current + 1] = { piece, hl }
      col = col + dw(piece, col)
      text = text:sub(#piece + 1)
      if flush and text ~= '' then
        new_row()
      end
    end
  end

  rows[#rows + 1] = current
  return rows
end

--- @param vlines table[][]
--- @param win integer
--- @param leftcol boolean?
--- @return table[][]
function M.wrap_virt_lines(vlines, win, leftcol)
  if not api.nvim_win_is_valid(win) then
    return vlines
  end
  local info = vim.fn.getwininfo(win)[1]
  if not info then
    return vlines
  end
  local win_width = info.width
  local textoff = info.textoff or 0
  local width, indent
  if leftcol then
    width = win_width
    indent = textoff
  else
    width = win_width - textoff
    indent = 0
  end

  local out = {}
  for _, vline in ipairs(vlines) do
    vim.list_extend(out, wrap_virt_line(vline, width, indent))
  end
  return out
end

--- Re-wrap the extmark just placed by place_inline_preview_lines.
local function rewrap_mark(bufnr, ns, markid, win, leftcol)
  local marks = api.nvim_buf_get_extmarks(bufnr, ns, markid, markid, { details = true })
  local mark = marks[1]
  if not mark then
    return
  end
  local row, col, details = mark[2], mark[3], mark[4]
  local vlines = details and details.virt_lines
  if not vlines or #vlines == 0 then
    return
  end
  api.nvim_buf_set_extmark(bufnr, ns, row, col, {
    id = markid,
    virt_lines = M.wrap_virt_lines(vlines, win, leftcol),
    virt_lines_above = details.virt_lines_above,
    virt_lines_leftcol = details.virt_lines_leftcol,
    virt_lines_overflow = 'trunc',
  })
end

local patched = false

function M.patch()
  if patched then
    return
  end
  local ok, DeletedPreview = pcall(require, 'gitsigns.deleted_preview')
  if not ok then
    return
  end
  patched = true

  local orig = DeletedPreview.place_inline_preview_lines
  --- @diagnostic disable-next-line: duplicate-set-field
  function DeletedPreview.place_inline_preview_lines(bufnr, ns, hunk, staged, opts)
    opts = opts or {}
    local markid = orig(bufnr, ns, hunk, staged, opts)
    if markid then
      local win = opts.win or api.nvim_get_current_win()
      rewrap_mark(bufnr, ns, markid, win, opts.leftcol == true)
    end
    return markid
  end
end

return M
