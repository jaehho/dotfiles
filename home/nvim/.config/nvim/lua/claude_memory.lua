-- Browse, edit, and delete Claude Code memory and CLAUDE.md files across all
-- projects. Projects come from ~/.claude.json; memory dirs are matched back to
-- their project by Claude's path slug (every non-alphanumeric char -> '-').

local M = {}

local HOME = vim.env.HOME
local CLAUDE = HOME .. '/.claude'

local function read(path)
  local f = io.open(path, 'r')
  if not f then
    return nil
  end
  local s = f:read('*a')
  f:close()
  return s
end

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function slug(path)
  return (path:gsub('[^%w]', '-'))
end

local function short(path)
  return (path:gsub('^' .. vim.pesc(HOME), '~'))
end

-- Frontmatter name/description/type, else the first heading.
local function describe(path)
  local text = read(path) or ''
  local meta = {}
  local fm = text:match('^%-%-%-\n(.-)\n%-%-%-')
  if fm then
    for line in fm:gmatch('[^\n]+') do
      local k, v = line:match('^%s*(%w+):%s*(.-)%s*$')
      if k and v ~= '' then
        meta[k] = v
      end
    end
  end
  meta.heading = text:match('\n?#+%s+([^\n]+)')
  return meta
end

local function project_paths()
  local paths = {}
  local ok, data = pcall(vim.json.decode, read(HOME .. '/.claude.json') or '{}')
  if ok and type(data.projects) == 'table' then
    for p in pairs(data.projects) do
      paths[#paths + 1] = p
    end
  end
  return paths
end

local function collect()
  local items = {}
  local by_slug = {}
  local seen = {}

  local function add(file, project, kind)
    file = vim.uv.fs_realpath(file) or file
    if seen[file] then
      return
    end
    seen[file] = true
    local meta = describe(file)
    local label = meta.name or vim.fn.fnamemodify(file, ':t')
    local desc = meta.description or meta.heading or ''
    items[#items + 1] = {
      file = file,
      project = project,
      kind = kind,
      rank = kind:find('CLAUDE') and 1 or kind == 'index' and 2 or 3,
      label = label,
      desc = desc,
      text = table.concat({ project, kind, label, desc }, ' '),
    }
  end

  local global = vim.uv.fs_realpath(CLAUDE .. '/CLAUDE.md')
  if global then
    add(global, 'global', 'CLAUDE.md')
  end

  for _, p in ipairs(project_paths()) do
    by_slug[slug(p)] = p
    for _, rel in ipairs { 'CLAUDE.md', 'CLAUDE.local.md', '.claude/CLAUDE.md' } do
      local f = p .. '/' .. rel
      if exists(f) then
        add(f, short(p), rel)
      end
    end
  end

  for _, dir in ipairs(vim.fn.glob(CLAUDE .. '/projects/*/memory', false, true)) do
    local s = vim.fn.fnamemodify(dir, ':h:t')
    local project = by_slug[s] and short(by_slug[s]) or s
    for _, f in ipairs(vim.fn.glob(dir .. '/*.md', false, true)) do
      local kind = vim.fn.fnamemodify(f, ':t') == 'MEMORY.md' and 'index' or (describe(f).type or 'memory')
      add(f, project, kind)
    end
  end

  table.sort(items, function(a, b)
    local ga, gb = a.project == 'global', b.project == 'global'
    if ga ~= gb then
      return ga
    end
    if a.project ~= b.project then
      return a.project < b.project
    end
    if a.rank ~= b.rank then
      return a.rank < b.rank
    end
    return a.file < b.file
  end)
  return items
end

-- Remove the file and its line in the sibling MEMORY.md index.
local function delete_file(file)
  local ok, err = os.remove(file)
  if not ok then
    vim.notify('Delete failed: ' .. err, vim.log.levels.ERROR)
    return
  end
  local buf = vim.fn.bufnr(file)
  if buf ~= -1 then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
  local index = vim.fn.fnamemodify(file, ':h') .. '/MEMORY.md'
  local name = vim.fn.fnamemodify(file, ':t')
  if name ~= 'MEMORY.md' and exists(index) then
    local lines = vim.fn.readfile(index)
    local kept = vim.tbl_filter(function(l)
      return not l:find('(' .. name .. ')', 1, true)
    end, lines)
    if #kept ~= #lines then
      vim.fn.writefile(kept, index)
    end
  end
end

function M.pick()
  local ok, picker = pcall(require, 'snacks.picker')
  if not ok then
    vim.notify('Claude memory: snacks.picker unavailable', vim.log.levels.ERROR)
    return
  end
  picker.pick {
    title = 'Claude memory',
    finder = collect,
    sort = false,
    format = function(item)
      return {
        { ('%-28s'):format(item.project), 'Directory' },
        { ('%-10s'):format(item.kind), 'Type' },
        { item.label, 'Title' },
        { '  ' .. item.desc, 'Comment' },
      }
    end,
    confirm = function(p, item)
      p:close()
      if item then
        vim.cmd.edit(vim.fn.fnameescape(item.file))
      end
    end,
    actions = {
      memory_delete = function(p)
        local sel = p:selected { fallback = true }
        if #sel == 0 then
          return
        end
        local names = vim.tbl_map(function(i)
          return '  ' .. short(i.file)
        end, sel)
        local msg = 'Delete ' .. #sel .. ' file(s)?\n' .. table.concat(names, '\n')
        if vim.fn.confirm(msg, '&Yes\n&No', 2) ~= 1 then
          return
        end
        for _, i in ipairs(sel) do
          delete_file(i.file)
        end
        p.list:set_selected()
        p:find()
      end,
    },
    win = {
      preview = { wo = { wrap = true, linebreak = true } },
      input = { keys = { ['<c-x>'] = { 'memory_delete', mode = { 'n', 'i' } } } },
      list = { keys = { ['dd'] = 'memory_delete' } },
    },
  }
end

return M
