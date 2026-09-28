-- Blink.cmp adapter for obsidian.nvim's nvim-cmp sources (cmp_obsidian*).
-- Request shape is the nvim-cmp Context those sources expect.
local M = {}

local MODULES = {
  refs = 'cmp_obsidian',
  new = 'cmp_obsidian_new',
  tags = 'cmp_obsidian_tags',
}

function M.new(opts)
  return setmetatable({
    kind = (opts and opts.kind) or 'refs',
    src = nil,
  }, { __index = M })
end

function M:get_source()
  if not self.src then
    self.src = require(MODULES[self.kind]).new()
  end
  return self.src
end

function M:enabled()
  local ok, client = pcall(function() return require('obsidian').get_client() end)
  if not ok or not client or not client.dir then
    return false
  end
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' then
    return false
  end
  return vim.startswith(path, tostring(client.dir))
end

function M:get_trigger_characters()
  return self.kind == 'tags' and { '#' } or { '[' }
end

---Build the nvim-cmp-shaped request obsidian.nvim's sources expect.
---@param ctx table blink.cmp.Context (cursor={row,col0}, line, bufnr)
local function to_cmp_request(ctx)
  local col0 = ctx.cursor[2]
  local row1 = ctx.cursor[1]
  return {
    context = {
      bufnr = ctx.bufnr,
      cursor_before_line = ctx.line:sub(1, col0),
      cursor_after_line = ctx.line:sub(col0 + 1),
      cursor = {
        row = row1,
        -- nvim-cmp col is 1-based, exclusive at the insert cursor.
        col = col0 + 1,
        -- nvim-cmp line is 0-based (used with nvim_buf_get_lines).
        line = row1 - 1,
      },
    },
  }
end

function M:get_completions(ctx, callback)
  self:get_source():complete(to_cmp_request(ctx), function(response)
    response = response or {}
    local items = {}
    for _, item in ipairs(response.items or {}) do
      -- Blink fuzzy-matches filterText against its own query (no '[[' prefix).
      item.filterText = item.sortText or item.label
      items[#items + 1] = item
    end
    callback {
      items = items,
      is_incomplete_forward = response.isIncomplete and true or false,
    }
  end)
end

function M:execute(_, item, callback, default_implementation)
  local src = self:get_source()
  if src.execute then
    src:execute(item, function() callback() end)
  else
    default_implementation()
  end
end

return M
