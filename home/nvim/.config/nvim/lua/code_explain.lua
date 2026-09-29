-- Visual select → optional question → explanation from raider's Ollama chat
-- model (qwen3.5:4b via wonlab raider-ollama). Surrounding lines ride along.
-- Answer is a snacks float; `q` closes. The wonlab logging proxy records the
-- request (~/.local/state/ollama/requests.jsonl), so nothing is logged here.

local M = {}

local ENDPOINT = 'http://100.64.0.3:11434/api/chat'
local MODEL = 'qwen3.5:4b'
local CONTEXT_LINES = 50
local NUM_PREDICT = 1024

local function visual_row_range()
  -- Prefer the live selection (still in visual when the xmap runs); fall
  -- back to the marks nvim sets when leaving visual.
  local v = vim.fn.getpos 'v'
  local c = vim.fn.getpos '.'
  if v[2] == 0 or c[2] == 0 then
    v = vim.fn.getpos "'<"
    c = vim.fn.getpos "'>"
  end
  local srow, erow = v[2], c[2]
  if srow > erow then
    srow, erow = erow, srow
  end
  return srow, erow
end

---Lines srow..erow plus CONTEXT_LINES of buffer on each side, marked up.
---@param srow integer
---@param erow integer
---@return string body, string selected
local function build_context(srow, erow)
  local last = vim.api.nvim_buf_line_count(0)
  local before_from = math.max(1, srow - CONTEXT_LINES)
  local after_to = math.min(last, erow + CONTEXT_LINES)
  local function lines(a, b)
    return table.concat(vim.api.nvim_buf_get_lines(0, a - 1, b, false), '\n')
  end
  local selected = lines(srow, erow)
  local before = lines(before_from, srow - 1)
  local after = lines(erow + 1, after_to)
  local path = vim.fn.expand '%:p'
  if path == '' then
    path = '[No Name]'
  end
  local ft = vim.bo.filetype ~= '' and vim.bo.filetype or 'text'
  local body = table.concat({
    ('file: %s (%s)'):format(path, ft),
    ('lines %d-%d of %d, with %d lines of surrounding context'):format(srow, erow, last, CONTEXT_LINES),
    '',
    '```',
    before,
    '<<< SELECTION',
    selected,
    'SELECTION >>>',
    after,
    '```',
  }, '\n')
  return body, selected
end

---@param text string
local function show(text)
  -- Bottom split, not a float: the selection stays visible while you read.
  Snacks.win {
    text = text,
    ft = 'markdown',
    position = 'bottom',
    height = 0.35,
    wo = { wrap = true, linebreak = true },
    keys = { q = 'close' },
  }
end

---@param question string
---@param body string
local function ask(question, body)
  local payload = {
    model = MODEL,
    stream = false,
    think = false,
    options = { num_predict = NUM_PREDICT },
    messages = {
      {
        role = 'system',
        content = table.concat({
          'Explain the marked region (between <<< SELECTION and SELECTION >>>).',
          'Use the surrounding context when it helps. Be concise and concrete.',
          'Reference names and line ranges when useful. Prefer short paragraphs or bullets over a long essay.',
        }, ' '),
      },
      {
        role = 'user',
        content = question .. '\n\n' .. body,
      },
    },
  }
  local encoded = vim.json.encode(payload)
  local tmp = vim.fn.tempname()
  vim.fn.writefile({ encoded }, tmp)

  vim.notify('Explaining selection…', vim.log.levels.INFO)
  vim.system({ 'curl', '-sS', '-m', '60', '-X', 'POST', ENDPOINT, '-H', 'Content-Type: application/json', '-d', '@' .. tmp }, { text = true }, function(res)
    vim.schedule(function()
      os.remove(tmp)
      if res.code ~= 0 then
        vim.notify('Explain failed: curl exit ' .. res.code, vim.log.levels.ERROR)
        return
      end
      local ok, data = pcall(vim.json.decode, res.stdout or '')
      if not ok or type(data) ~= 'table' then
        vim.notify('Explain failed: bad JSON from Ollama', vim.log.levels.ERROR)
        return
      end
      local msg = data.message or {}
      local content = msg.content or ''
      local thinking = msg.thinking or ''
      if content == '' and thinking ~= '' then
        content = thinking
      elseif content ~= '' and thinking ~= '' then
        content = thinking .. '\n\n---\n\n' .. content
      end
      if content == '' then
        vim.notify('Explain returned empty content', vim.log.levels.WARN)
        return
      end
      show(content)
    end)
  end)
end

function M.explain()
  local srow, erow = visual_row_range()
  if srow < 1 then
    vim.notify('Explain: no selection', vim.log.levels.WARN)
    return
  end
  local body = build_context(srow, erow)
  vim.ui.input({ prompt = 'Explain: ', default = 'Explain this code' }, function(input)
    if input == nil or input == '' then
      return
    end
    ask(input, body)
  end)
end

return M
