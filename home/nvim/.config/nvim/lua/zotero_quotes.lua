-- Pick a Zotero PDF annotation and insert it as a markdown blockquote.
-- Reads Zotero's stock local API on :23119. citationKey/DOI on the parent
-- item come from the item payload (BBT injects the key). No Obsidian, no ZotLit.

local M = {}

local API = 'http://127.0.0.1:23119'
local PAGE = 100

---@param args string[]
---@return string? body, string? err
local function curl(args)
  local cmd = { 'curl', '-sS', '-m', '10' }
  vim.list_extend(cmd, args)
  local ok, proc = pcall(vim.system, cmd, { text = true })
  if not ok then
    return nil, tostring(proc)
  end
  local res = proc:wait()
  if res.code ~= 0 then
    return nil, res.stderr ~= '' and res.stderr or ('curl exit ' .. res.code)
  end
  return res.stdout, nil
end

---@param url string
---@return table? data, string? err
local function get_json(url)
  local body, err = curl { url }
  if not body then
    return nil, err
  end
  local ok, data = pcall(vim.json.decode, body)
  if not ok then
    return nil, 'bad JSON from ' .. url
  end
  return data, nil
end

---@param key string
---@return table? data, string? err
local function get_item(key)
  local data, err = get_json(('%s/api/users/0/items/%s?format=json'):format(API, key))
  if not data then
    return nil, err
  end
  return data.data or data, nil
end

---The local API ignores `itemKey=` multi-gets (it returns children instead of
---the listed items). Fire one GET per key in parallel instead.
---@param keys string[]
---@return table<string, table> items, string? err
local function get_items(keys)
  local procs = {}
  for _, key in ipairs(keys) do
    procs[key] = vim.system({ 'curl', '-sS', '-m', '10', ('%s/api/users/0/items/%s?format=json'):format(API, key) }, { text = true })
  end
  local items = {}
  for key, proc in pairs(procs) do
    local res = proc:wait()
    if res.code ~= 0 then
      return {}, res.stderr ~= '' and res.stderr or ('curl exit ' .. res.code .. ' for ' .. key)
    end
    local ok, data = pcall(vim.json.decode, res.stdout or '')
    if ok and data then
      items[key] = data.data or data
    end
  end
  return items, nil
end

---@return table[] annotations, string? err
local function fetch_annotations()
  local out = {}
  local start = 0
  while true do
    local page, err = get_json(('%s/api/users/0/items?itemType=annotation&format=json&limit=%d&start=%d'):format(API, PAGE, start))
    if not page then
      return {}, err
    end
    for _, item in ipairs(page) do
      out[#out + 1] = item.data or item
    end
    if #page < PAGE then
      break
    end
    start = start + PAGE
  end
  return out, nil
end

---Collection names by item key (parents and attachments). Cached on disk —
---collection-item endpoints are ~0.5s each and dominate load time.
---@return table<string, string[]> map, string? err
local function fetch_collection_map()
  local cache_path = vim.fn.stdpath 'cache' .. '/zotero_collection_map.json'
  local cached = io.open(cache_path, 'r')
  if cached then
    local body = cached:read '*a'
    cached:close()
    local ok, data = pcall(vim.json.decode, body)
    if ok and type(data) == 'table' and data.saved and (os.time() - data.saved) < 300 then
      return data.map or {}, nil
    end
  end

  local cols, err = get_json(('%s/api/users/0/collections?format=json&limit=100'):format(API))
  if not cols then
    return {}, err
  end
  local name, parent = {}, {}
  for _, c in ipairs(cols) do
    local d = c.data or c
    name[d.key] = d.name
    parent[d.key] = d.parentCollection
  end
  local function path_of(key)
    local parts, seen = {}, {}
    while key and name[key] and not seen[key] do
      seen[key] = true
      table.insert(parts, 1, name[key])
      key = parent[key]
    end
    return table.concat(parts, ' > ')
  end

  -- Parallel GET per collection; Zotero serializes some of this but it still wins.
  local procs = {}
  for key in pairs(name) do
    procs[key] = {
      label = path_of(key),
      proc = vim.system({ 'curl', '-sS', '-m', '20', ('%s/api/users/0/collections/%s/items?format=json&limit=100'):format(API, key) }, { text = true }),
    }
  end

  local map = {}
  for _, entry in pairs(procs) do
    local res = entry.proc:wait()
    if res.code == 0 and res.stdout then
      local ok, items = pcall(vim.json.decode, res.stdout)
      if ok and type(items) == 'table' then
        for _, it in ipairs(items) do
          local ik = (it.data or it).key
          if ik then
            map[ik] = map[ik] or {}
            if not vim.tbl_contains(map[ik], entry.label) then
              table.insert(map[ik], entry.label)
            end
          end
        end
      end
    end
  end

  vim.fn.mkdir(vim.fn.stdpath 'cache', 'p')
  local f = io.open(cache_path, 'w')
  if f then
    f:write(vim.json.encode { saved = os.time(), map = map })
    f:close()
  end
  return map, nil
end

---Attachment keys currently open in Zotero reader tabs (last saved session).
---@return table<string, boolean> keys
local function open_reader_attachment_keys()
  local keys = {}
  local sessions = vim.fn.glob(vim.fn.expand '~/.zotero/zotero/*/session.json', false, true)
  local session_path
  for _, p in ipairs(sessions) do
    session_path = p
    break
  end
  if not session_path then
    return keys
  end
  local f = io.open(session_path, 'r')
  if not f then
    return keys
  end
  local body = f:read '*a'
  f:close()
  local ok, session = pcall(vim.json.decode, body)
  if not ok or type(session) ~= 'table' then
    return keys
  end

  local item_ids = {}
  for _, win in ipairs(session.windows or {}) do
    for _, tab in ipairs(win.tabs or {}) do
      if tab.type == 'reader' and tab.data and tab.data.itemID then
        item_ids[tostring(tab.data.itemID)] = tab.selected and 2 or 1
      end
    end
  end
  if not next(item_ids) then
    return keys
  end

  -- Map internal itemIDs to API keys. immutable=1 skips the locked-DB copy.
  local db = vim.fn.expand '~/Zotero/zotero.sqlite'
  if vim.fn.filereadable(db) ~= 1 then
    return keys
  end
  local id_list = {}
  for id in pairs(item_ids) do
    id_list[#id_list + 1] = id
  end
  local out = vim.system({
    'sqlite3',
    '-batch',
    ('file:%s?immutable=1'):format(db),
    ('SELECT itemID, key FROM items WHERE itemID IN (%s);'):format(table.concat(id_list, ',')),
  }, { text = true }):wait()
  if out.code == 0 then
    for line in (out.stdout or ''):gmatch '[^\n]+' do
      local id, key = line:match '^(%d+)|(%w+)$'
      if id and key then
        keys[key] = true
      end
    end
  end
  return keys
end

---@param creators table[]?
---@return string
local function authors_short(creators)
  if not creators or #creators == 0 then
    return 'Anon'
  end
  local c = creators[1]
  local last = c.lastName or c.name or '?'
  return #creators > 1 and (last .. ' et al.') or last
end

---@param date string?
---@return string
local function year_of(date)
  return (date and date:match '(%d%d%d%d)') or 'n.d.'
end

---@param page string?
---@return number
local function page_num(page)
  return tonumber(page and page:match '(%d+)') or 1e9
end

---@param s string?
---@return string
local function clean(s)
  if not s then
    return ''
  end
  -- Drop C0 controls (except \n \t) and C1; keeps preview/list out of binary territory.
  return (s:gsub('[%z\1-\8\11\12\14-\31\127-\255]', ''))
end

---@param s string?
---@return string[]
local function wrap_quote(s)
  local text = clean(s):gsub('%s+$', '')
  if text == '' then
    return { '> *empty annotation*' }
  end
  local lines = {}
  for line in (text .. '\n'):gmatch '(.-)\n' do
    lines[#lines + 1] = line == '' and '>' or ('> ' .. line)
  end
  return lines
end

---Stable attribution: author-year-page plus two links when possible.
---Citekeys are omitted on purpose — Better BibTeX can rewrite them.
---1. Zotero deep link to *this annotation* (jumps to the highlight)
---2. DOI (or item URL) as a paper-level backup that outlives deletion
---@param a table enriched annotation
---@return string[]
function M.format_markdown(a)
  local lines = wrap_quote(a.annotationText ~= '' and a.annotationText or a.annotationComment)
  local page = a.annotationPageLabel
  local base
  if page then
    base = ('— %s %s, p. %s'):format(a.author, a.year, page)
  else
    base = ('— %s %s'):format(a.author, a.year)
  end

  local links = {}
  if a.attachmentKey and a.annotationKey then
    local q = {}
    if page then
      q[#q + 1] = 'page=' .. page
    end
    q[#q + 1] = 'annotation=' .. a.annotationKey
    links[#links + 1] = ('[PDF p. %s](zotero://open-pdf/library/items/%s?%s)'):format(
      page or '?',
      a.attachmentKey,
      table.concat(q, '&')
    )
  end
  -- Paper-level backup: survives annotation deletion. DOI if present, else URL.
  if a.doi then
    links[#links + 1] = ('[%s](https://doi.org/%s)'):format(a.doi, a.doi)
  elseif a.url and a.url ~= '' then
    local host = a.url:match '^https?://([^/]+)' or 'link'
    local label = (a.publication ~= '' and a.publication or host):gsub('%s+', ' ')
    links[#links + 1] = ('[%s](%s)'):format(label, a.url)
  end
  lines[#lines + 1] = '>'
  lines[#lines + 1] = #links > 0 and ('> %s · %s'):format(base, table.concat(links, ' · ')) or ('> ' .. base)

  -- User's own comment stays outside the quotation.
  if a.annotationText ~= '' and (a.annotationComment or '') ~= '' then
    lines[#lines + 1] = ''
    for line in (a.annotationComment .. '\n'):gmatch '(.-)\n' do
      lines[#lines + 1] = line
    end
  end
  return lines
end

---@param lines string[]
local function insert_lines(lines)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, lines)
  vim.api.nvim_win_set_cursor(0, { row + #lines, 0 })
end

---@return table[] items, string? err
local function load_items()
  local annots, err = fetch_annotations()
  if err then
    return {}, err
  end
  if #annots == 0 then
    return {}, nil
  end

  local attach_keys, parent_keys = {}, {}
  local seen_a, seen_p = {}, {}
  for _, a in ipairs(annots) do
    if a.parentItem and not seen_a[a.parentItem] then
      seen_a[a.parentItem] = true
      attach_keys[#attach_keys + 1] = a.parentItem
    end
  end

  local attachments, aerr = get_items(attach_keys)
  if aerr then
    return {}, aerr
  end
  for _, att in pairs(attachments) do
    local p = att.parentItem
    if p and not seen_p[p] then
      seen_p[p] = true
      parent_keys[#parent_keys + 1] = p
    end
  end

  local parents, perr = get_items(parent_keys)
  if perr then
    return {}, perr
  end

  local colmap = fetch_collection_map()
  local open = open_reader_attachment_keys()

  local items = {}
  for _, a in ipairs(annots) do
    local att = a.parentItem and attachments[a.parentItem] or nil
    local parent = att and att.parentItem and parents[att.parentItem] or nil
    local text = clean(a.annotationText)
    local comment = clean(a.annotationComment)
    local author = parent and authors_short(parent.creators) or 'Anon'
    local year = parent and year_of(parent.date) or 'n.d.'
    local title = parent and parent.title or (att and att.title) or '?'
    local doi = parent and parent.DOI or nil
    if doi then
      doi = doi:gsub('^https?://doi%.org/', '')
    end
    local url = parent and parent.url or nil
    if url and url:find('doi%.org/', 1, true) then
      local extracted = url:match 'doi%.org/(.+)$'
      if extracted and not doi then
        doi = extracted
      end
      url = nil
    end
    local publication = parent and parent.publicationTitle or parent and parent.bookTitle or ''
    local attachmentKey = a.parentItem
    local cols = {}
    for _, key in ipairs { attachmentKey, parent and parent.key or nil } do
      for _, c in ipairs(colmap[key] or {}) do
        if not vim.tbl_contains(cols, c) then
          cols[#cols + 1] = c
        end
      end
    end
    local page = a.annotationPageLabel
    items[#items + 1] = {
      -- Fuzzy-matched haystack: quote, comment, paper, people, collections.
      text = table.concat({
        page and ('p' .. page) or 'p?',
        text ~= '' and text or comment,
        author,
        year,
        title,
        publication,
        table.concat(cols, ' '),
        doi or '',
      }, ' '),
      preview = {
        text = table.concat(M.format_markdown {
          annotationText = text,
          annotationComment = comment,
          annotationPageLabel = page,
          doi = doi,
          url = url,
          publication = publication,
          attachmentKey = attachmentKey,
          annotationKey = a.key,
          author = author,
          year = year,
        }, '\n'),
        -- No markdown ft: snacks.image attaches to markdown and probes the
        -- terminal (kitty graphics), and that reply leaks into the picker input.
        ft = 'text',
        loc = false,
      },
      -- Insert payload
      annotationText = text,
      annotationComment = comment,
      annotationPageLabel = page,
      doi = doi,
      url = url,
      publication = publication,
      attachmentKey = attachmentKey,
      annotationKey = a.key,
      author = author,
      year = year,
      title = title,
      collections = cols,
      -- Sort / filter helpers
      paper = ('%s %s %s'):format(author, year, title),
      page_n = page_num(page),
      open = open[attachmentKey] or false,
    }
  end

  table.sort(items, function(a, b)
    if a.paper ~= b.paper then
      return a.paper < b.paper
    end
    if a.page_n ~= b.page_n then
      return a.page_n < b.page_n
    end
    return (a.annotationText or '') < (b.annotationText or '')
  end)
  return items, nil
end

M.load_items = load_items

---@param opts { open_only?: boolean }?
function M.pick(opts)
  opts = opts or {}
  if vim.bo.buftype ~= '' then
    vim.notify('Zotero quotes: not a normal buffer', vim.log.levels.WARN)
    return
  end
  local items, err = load_items()
  if err then
    vim.notify('Zotero quotes: ' .. err, vim.log.levels.ERROR)
    return
  end
  if #items == 0 then
    vim.notify('Zotero quotes: no annotations (is Zotero running?)', vim.log.levels.WARN)
    return
  end

  local ok, picker = pcall(require, 'snacks.picker')
  if not ok then
    vim.notify('Zotero quotes: snacks.picker unavailable', vim.log.levels.ERROR)
    return
  end

  local has_open = false
  for _, it in ipairs(items) do
    if it.open then
      has_open = true
      break
    end
  end
  -- Default to open-tabs mode when any reader tab has annotations.
  local open_only = opts.open_only
  if open_only == nil then
    open_only = has_open
  end

  picker.pick {
    title = 'Zotero quotes',
    items = items,
    -- item.preview table, not the file previewer (avoids "Item has no `file`")
    preview = 'preview',
    open_only = open_only,
    -- Title flag when open-tabs mode is on (snacks `{flags}` in the input bar).
    toggles = {
      open_only = { icon = 'open', value = true },
    },
    finder = function(fopts, ctx)
      local list = items
      if fopts.open_only then
        list = vim.tbl_filter(function(i)
          return i.open
        end, items)
      end
      return ctx.filter:filter(list)
    end,
    sort = function(a, b)
      return a.paper < b.paper or (a.paper == b.paper and a.page_n < b.page_n)
    end,
    format = function(item)
      local excerpt = (item.annotationText ~= '' and item.annotationText or item.annotationComment):gsub('%s+', ' ')
      if #excerpt > 60 then
        excerpt = excerpt:sub(1, 57) .. '…'
      end
      return {
        { item.annotationPageLabel and ('p.' .. item.annotationPageLabel) or 'p.?', 'Number' },
        { ' ' },
        { excerpt, 'String' },
        { '  ', 'Comment' },
        { item.author .. ' ' .. item.year, 'Comment' },
        { #item.collections > 0 and ('  ' .. item.collections[1]) or '', 'Title' },
      }
    end,
    confirm = function(p, item)
      p:close()
      if not item then
        return
      end
      vim.schedule(function()
        insert_lines(M.format_markdown(item))
      end)
    end,
    win = {
      preview = {
        wo = {
          wrap = true,
          linebreak = true,
          breakindent = true,
          number = false,
          relativenumber = false,
          signcolumn = 'no',
        },
      },
      input = {
        keys = {
          ['<c-o>'] = { 'toggle_open_only', mode = { 'n', 'i' } },
        },
      },
      list = {
        keys = {
          ['<c-o>'] = 'toggle_open_only',
        },
      },
    },
  }
end

return M
