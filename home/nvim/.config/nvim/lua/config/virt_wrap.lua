-- Word-wrap virtual text once, at nvim_buf_set_extmark, for every source.
--
-- Neovim draws inline virt_text with a hard column cut: spaces in the
-- decoration are not 'breakat' points, so 'linebreak' does not apply.
-- virt_lines never wrap at all ('virt_lines_overflow' is trunc/scroll on
-- 0.12). Both show up wherever plugins invent rows: gitsigns deleted-preview,
-- copilot ghost text, long inlay hints. Fix the display here instead of
-- once per plugin (replaces gitsigns_wrap.lua and inline_completion_wrap.lua).
--
-- Upstream: neovim/neovim#41369 (virt_lines wrap + linebreak),
-- neovim/neovim#42182 (inline virt_text + linebreak).
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

--- Drop trailing spaces (gitsigns pads virt_lines; they would wrap as blanks).
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

--- Split a chunk list into word-wrapped rows of at most max_cols.
--- Continuation rows are prefixed with indent spaces ('breakindent').
--- When lead is set, the first row is also a continuation and gets indent.
--- @param chunks table[]
--- @param max_cols integer
--- @param indent integer
--- @param lead boolean?
--- @return table[]
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
    if indent > 0 and (row_index > 1 or lead) then
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

--- Text width and wrap-indent for this buffer's window.
--- leftcol virt_lines (gitsigns) span the full window and indent by textoff.
local function win_metrics(bufnr, row, leftcol)
  local win = buf_win(bufnr)
  if not win then
    return 0, 0
  end
  local info = vim.fn.getwininfo(win)[1]
  if not info then
    return 0, 0
  end
  local textoff = info.textoff or 0
  if leftcol then
    return info.width, textoff
  end
  local indent = 0
  if vim.wo[win].breakindent then
    local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
    indent = vim.fn.strdisplaywidth(line:match '^[ \t]*' or '')
  end
  return math.max(0, info.width - textoff), indent
end

--- Display columns left on the screen row that holds the decoration start.
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

local function at_eol(bufnr, row, col)
  local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  return line:sub(col + 1):match '^%s*$' ~= nil
end

--- Rewrite extmark opts so long virtual rows word-wrap when 'wrap' is on.
--- @return table opts
local function rewrap(bufnr, row, col, opts)
  if bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  local win = buf_win(bufnr)
  if not win or not vim.wo[win].wrap then
    return opts
  end

  local out = opts
  local function touch()
    if out == opts then
      out = vim.deepcopy(opts)
      out.virt_lines = out.virt_lines or {}
    end
    return out
  end

  -- Plugin virt_lines (independent rows): wrap at the text area. Continuations
  -- indent like the row starts (textoff when leftcol, else flush left).
  if out.virt_lines and #out.virt_lines > 0 then
    local width, indent = win_metrics(bufnr, row, out.virt_lines_leftcol == true)
    if width > 0 then
      local wrapped = {}
      local dirty = false
      for _, vline in ipairs(out.virt_lines) do
        local rows = wrap_chunks(strip_trailing_spaces(vline), width, indent)
        if #rows ~= 1 or rows[1] ~= vline then
          dirty = true
        end
        vim.list_extend(wrapped, rows)
      end
      if dirty then
        touch().virt_lines = wrapped
      end
    end
  end

  local vtext = out.virt_text
  if not vtext or #vtext == 0 then
    return out
  end
  -- Overlay/right-align place the chunk in one cell region; only inline/eol
  -- participate in the line's wrap. Mid-line ghosts keep buffer text after
  -- them, so a virt_line tail would sit below the whole line and lie.
  local pos = out.virt_text_pos or 'eol'
  if pos ~= 'inline' and pos ~= 'eol' then
    return out
  end
  if not at_eol(bufnr, row, col) then
    return out
  end

  local head = strip_trailing_spaces(vtext)
  if #head == 0 then
    return out
  end

  local width, indent = win_metrics(bufnr, row, false)
  if width <= 0 then
    return out
  end

  local budget = first_row_budget(bufnr, row, col, width)
  local head_width = 0
  for _, chunk in ipairs(head) do
    head_width = head_width + dw(chunk[1])
  end
  if head_width <= budget then
    touch().virt_text = head
    return out
  end

  -- Word-fit the head onto the rest of its screen row; the tail becomes
  -- virt_lines and reads as wrap continuations of the buffer line.
  local first, rest = split_first_row(head, budget)
  local o = touch()
  o.virt_text = strip_trailing_spaces(first)
  local tail = {}
  if #rest > 0 then
    vim.list_extend(tail, wrap_chunks(rest, width, indent, true))
  end
  vim.list_extend(tail, o.virt_lines or {})
  o.virt_lines = tail
  return out
end

local patched = false
--- Original unsplit opts per (bufnr, mark id), for wrap toggle / resize.
local originals = {}

function M.patch()
  if patched then
    return
  end
  patched = true

  local orig_set_extmark = api.nvim_buf_set_extmark

  ---@diagnostic disable-next-line: duplicate-set-field
  function api.nvim_buf_set_extmark(bufnr, ns_id, row, col, opts)
    if not opts or (not opts.virt_text and not opts.virt_lines) or opts.ephemeral then
      return orig_set_extmark(bufnr, ns_id, row, col, opts)
    end
    local buf = bufnr == 0 and api.nvim_get_current_buf() or bufnr
    local raw = vim.deepcopy(opts)
    local wrapped = rewrap(buf, row, col, opts)
    local id = orig_set_extmark(bufnr, ns_id, row, col, wrapped)
    if wrapped ~= opts then
      originals[buf] = originals[buf] or {}
      originals[buf][id] = { ns = ns_id, row = row, col = col, opts = raw }
    end
    return id
  end

  local function refit(bufnr)
    local marks = originals[bufnr]
    if not marks then
      return
    end
    for id, saved in pairs(marks) do
      local live = api.nvim_buf_get_extmarks(bufnr, saved.ns, 0, -1, {})
      local found = false
      for _, m in ipairs(live) do
        if m[1] == id then
          found = true
          break
        end
      end
      if not found then
        marks[id] = nil
      else
        local opts = rewrap(bufnr, saved.row, saved.col, vim.deepcopy(saved.opts))
        opts.id = id
        orig_set_extmark(bufnr, saved.ns, saved.row, saved.col, opts)
      end
    end
    if next(marks) == nil then
      originals[bufnr] = nil
    end
  end

  -- Snacks <leader>uw uses nvim_set_option_value; OptionSet never fires.
  -- Hook the map after VeryLazy instead of a decoration provider (on_win is
  -- experimental and can stall startup / redraw).
  local function refit_all()
    for bufnr in pairs(originals) do
      refit(bufnr)
    end
  end

  api.nvim_create_autocmd('User', {
    pattern = 'VeryLazy',
    once = true,
    callback = function()
      local map = vim.fn.maparg('<leader>uw', 'n', false, true)
      if not map.callback then
        return
      end
      vim.keymap.set('n', '<leader>uw', function()
        map.callback()
        vim.schedule(refit_all)
      end, { desc = map.desc or 'Wrap', noremap = true })
    end,
  })

  local group = api.nvim_create_augroup('virt_wrap', { clear = true })
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
    end,
  })
end

return M
