-- vim.lsp.inline_completion draws the first suggestion line as inline virt_text
-- and the rest as virt_lines. Neovim's 'linebreak' does not treat spaces in
-- virt_text as break points, so ghost text hard-wraps mid-word even with wrap
-- on. virt_lines never wrap (see gitsigns_wrap.lua). Word-wrap the suggestion
-- ourselves: keep a word-fitted head on the ghost's screen row and put the
-- tail in virt_lines, which look like wrap continuations when the ghost sits
-- at end-of-line.
local api = vim.api

local M = {}

local function dw(text, col)
  return vim.fn.strdisplaywidth(text, col or 0)
end

--- Longest character-aligned prefix of text that fits max_cols display cells.
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

local function first_char(text)
  local positions = vim.str_utf_pos(text)
  local b = positions[1]
  local next_b = positions[2] or (#text + 1)
  return text:sub(b, next_b - 1)
end

--- Longest word-aware fit: stop before a split word when possible.
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
  local cut = piece:find '%s[^%s]*$'
  if cut and cut > 1 then
    return piece:sub(1, cut - 1), true
  end
  return piece, true
end

--- Split a chunk list into word-wrapped rows of at most max_cols.
--- Continuation rows are prefixed with indent spaces ('breakindent').
--- When lead is set, the first row is also a continuation and gets indent.
--- @param chunks [string, string|string[]][]
--- @param max_cols integer
--- @param indent integer
--- @param lead boolean?
--- @return [string, string|string[]][][]
local function wrap_chunks(chunks, max_cols, indent, lead)
  if max_cols <= 0 then
    return { chunks }
  end

  local total = 0
  for _, chunk in ipairs(chunks) do
    total = total + dw(chunk[1])
  end
  if total + (lead and indent or 0) <= max_cols then
    local row = {}
    if lead and indent > 0 then
      row[1] = { string.rep(' ', indent), 'Normal' }
    end
    for _, chunk in ipairs(chunks) do
      row[#row + 1] = { chunk[1], chunk[2] }
    end
    return { row }
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
    local need_indent = indent > 0 and (row_index > 1 or lead)
    if need_indent then
      current[1] = { string.rep(' ', indent), 'Normal' }
      col = indent
    end
  end

  local function strip_leading(s)
    return (s:gsub('^%s+', '', 1))
  end

  new_row()
  for _, chunk in ipairs(chunks) do
    local text, hl = chunk[1], chunk[2]
    while text ~= '' do
      local is_cont = row_index > 1 or lead
      local prefix = (indent > 0 and is_cont) and indent or 0
      -- Drop the wrap-point space on continuations; keep a line's own indent.
      if is_cont and col == prefix then
        text = strip_leading(text)
        if text == '' then
          break
        end
      end
      local avail = max_cols - col
      if avail <= 0 then
        new_row()
        text = strip_leading(text)
        if text == '' then
          break
        end
        avail = max_cols - col
      end
      local piece, flush = word_fit(text, avail, col)
      if piece == '' then
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

local function buf_win(bufnr)
  if bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  local win = api.nvim_get_current_win()
  if api.nvim_win_get_buf(win) ~= bufnr then
    win = vim.fn.bufwinid(bufnr)
  end
  if win == -1 or not api.nvim_win_is_valid(win) then
    return nil
  end
  return win
end

--- Window text width and breakindent indent for the ghost's line.
--- @return integer width
--- @return integer indent
local function win_metrics(bufnr, row)
  local win = buf_win(bufnr)
  if not win then
    return 0, 0
  end
  local info = vim.fn.getwininfo(win)[1]
  if not info then
    return 0, 0
  end
  local width = math.max(0, info.width - (info.textoff or 0))
  local indent = 0
  if vim.wo[win].breakindent then
    local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
    indent = vim.fn.strdisplaywidth(line:match '^[ \t]*' or '')
  end
  return width, indent
end

--- Display columns left on the screen row that holds the ghost start.
local function first_row_budget(bufnr, row, col, width)
  local win = buf_win(bufnr)
  if not win then
    return width
  end
  local pos = vim.fn.screenpos(win, row + 1, col + 1)
  if pos.row == 0 then
    return width
  end
  local info = vim.fn.getwininfo(win)[1]
  local textoff = info and info.textoff or 0
  local used = pos.col - textoff - 1
  return math.max(0, width - used)
end

--- Drop trailing spaces so a full first row does not wrap to a blank row.
local function strip_trailing_spaces(chunks)
  local out = {}
  for i, chunk in ipairs(chunks) do
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

--- True when nothing but whitespace follows the ghost on its buffer line.
local function at_eol(bufnr, row, col)
  local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  return line:sub(col + 1):match '^%s*$' ~= nil
end

--- Split chunks into a first row that fits max_cols and the unwrapped rest.
--- @return table first
--- @return table rest
local function split_first_row(chunks, max_cols)
  local first, rest = {}, {}
  local col = 0
  local splitting = false

  local function push_rest(text, hl)
    text = text:gsub('^%s+', '', 1)
    if text ~= '' then
      rest[#rest + 1] = { text, hl }
    end
  end

  for _, chunk in ipairs(chunks) do
    local text, hl = chunk[1], chunk[2]
    if splitting then
      push_rest(text, hl)
    else
      while text ~= '' do
        local avail = max_cols - col
        if avail <= 0 then
          splitting = true
          break
        end
        local piece, flush = word_fit(text, avail, col)
        if piece == '' then
          piece = first_char(text)
          flush = false
        end
        first[#first + 1] = { piece, hl }
        col = col + dw(piece, col)
        text = text:sub(#piece + 1)
        if flush and text ~= '' then
          splitting = true
          break
        end
      end
      if splitting then
        push_rest(text, hl)
      end
    end
  end
  return first, rest
end

--- Rewrite inline-completion extmark opts for wrap + linebreak.
--- @param bufnr integer
--- @param row integer
--- @param col integer
--- @param opts table
--- @return table opts
local function rewrap(bufnr, row, col, opts)
  if bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  local win = buf_win(bufnr)
  if not win or not vim.wo[win].wrap or not opts.virt_text then
    return opts
  end

  local width, indent = win_metrics(bufnr, row)
  if width <= 0 then
    return opts
  end

  local out = vim.deepcopy(opts)
  out.virt_lines = out.virt_lines or {}

  -- Multi-line suggestion tails: virt_lines never wrap.
  local wrapped = {}
  for _, vline in ipairs(out.virt_lines) do
    vim.list_extend(wrapped, wrap_chunks(vline, width, indent))
  end
  out.virt_lines = wrapped

  -- Overlay replaces text in place; leave the head alone.
  if out.virt_text_pos == 'overlay' then
    return out
  end

  -- Mid-line ghosts have buffer text after them; virt_lines sit below the
  -- whole line and cannot continue the wrap. Only split at end-of-line.
  if not at_eol(bufnr, row, col) then
    return out
  end

  local head = strip_trailing_spaces(out.virt_text)
  if #head == 0 then
    return out
  end

  local budget = first_row_budget(bufnr, row, col, width)
  local head_width = 0
  for _, chunk in ipairs(head) do
    head_width = head_width + dw(chunk[1])
  end
  if head_width <= budget then
    out.virt_text = head
    return out
  end

  -- Word-fit the head onto the remaining part of its screen row; the tail
  -- becomes virt_lines and reads as wrap continuations of the buffer line.
  local first, rest = split_first_row(head, budget)
  out.virt_text = strip_trailing_spaces(first)
  local tail = {}
  if #rest > 0 then
    vim.list_extend(tail, wrap_chunks(rest, width, indent, true))
  end
  vim.list_extend(tail, out.virt_lines)
  out.virt_lines = tail
  return out
end

local patched = false
--- Original unsplit opts, keyed by bufnr, so wrap toggle / resize can re-fit.
local originals = {}

function M.patch()
  if patched then
    return
  end
  patched = true

  local ns = api.nvim_create_namespace 'nvim.lsp.inline_completion'
  local orig_set_extmark = api.nvim_buf_set_extmark
  -- Last wrap state per buffer, so redraw can detect Snacks' <leader>uw
  -- (OptionSet does not fire for nvim_set_option_value).
  local shown = {}

  ---@diagnostic disable-next-line: duplicate-set-field
  function api.nvim_buf_set_extmark(bufnr, ns_id, row, col, opts)
    if ns_id == ns and opts and opts.virt_text then
      local buf = bufnr == 0 and api.nvim_get_current_buf() or bufnr
      local raw = vim.deepcopy(opts)
      local id = orig_set_extmark(bufnr, ns_id, row, col, rewrap(buf, row, col, opts))
      originals[buf] = { id = id, row = row, col = col, opts = raw }
      local win = buf_win(buf)
      shown[buf] = win and vim.wo[win].wrap or nil
      return id
    end
    return orig_set_extmark(bufnr, ns_id, row, col, opts)
  end

  local group = api.nvim_create_augroup('inline_completion_wrap', { clear = true })

  local function refit(bufnr)
    local saved = originals[bufnr]
    if not saved then
      return
    end
    local marks = api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
    if #marks == 0 then
      originals[bufnr] = nil
      shown[bufnr] = nil
      return
    end
    local opts = rewrap(bufnr, saved.row, saved.col, vim.deepcopy(saved.opts))
    opts.id = saved.id
    orig_set_extmark(bufnr, ns, saved.row, saved.col, opts)
  end

  local function watch(win, buf)
    if not originals[buf] then
      return
    end
    local wrap = vim.wo[win].wrap
    if shown[buf] ~= wrap then
      shown[buf] = wrap
      vim.schedule(function()
        if originals[buf] then
          refit(buf)
        end
      end)
    end
  end

  api.nvim_set_decoration_provider(api.nvim_create_namespace 'inline_completion_wrap', {
    on_win = function(_, win, buf)
      watch(win, buf)
      return false
    end,
  })

  api.nvim_create_autocmd({ 'WinResized', 'WinScrolled' }, {
    group = group,
    callback = function()
      for bufnr in pairs(originals) do
        refit(bufnr)
      end
    end,
  })
  api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = group,
    callback = function(ev)
      originals[ev.buf] = nil
      shown[ev.buf] = nil
    end,
  })
end

return M
