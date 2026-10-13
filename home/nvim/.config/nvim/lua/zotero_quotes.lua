-- Pick a Zotero PDF annotation and insert it as a markdown blockquote.
-- Reads Zotero's stock local API on :23119. citationKey/DOI on the parent
-- item come from the item payload (BBT injects the key). No Obsidian, no ZotLit.
--
-- Search is grep-like (literal substring, smartcase), not fuzzy. A short
-- fuzzy token matches almost every annotation; a quote lookup wants the text
-- as typed.
--   word        literal substring
--   a few words literal phrase (whitespace-normalized), the way a quote is typed
--   !word       exclude   ^word  prefix   word$  suffix
--   title:foo   field search (text, quote, title, author, ...)
-- O (normal) toggles open-reader-tabs vs the whole library. Not insert:
-- that would steal typing capital O in a query.

local M = {}

local API = 'http://127.0.0.1:23119'
-- One page covers a normal library; fewer round-trips than limit=100.
local PAGE = 500

-- Reopen is instant; open-tab flags are refreshed from the cheap path.
local ITEM_CACHE_TTL = 60
local item_cache = { items = nil, saved = 0 }

-- Collection-item GETs dominate a cold rebuild (~2s for 10 collections).
local COLMAP_TTL = 3600

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
---A stale map is served immediately; the rebuild is scheduled and paid later.
---@return table<string, string[]> map, string? err
local function rebuild_collection_map(cache_path)
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

local function fetch_collection_map()
  local cache_path = vim.fn.stdpath 'cache' .. '/zotero_collection_map.json'
  local cached = io.open(cache_path, 'r')
  local disk
  if cached then
    local body = cached:read '*a'
    cached:close()
    local ok, data = pcall(vim.json.decode, body)
    if ok and type(data) == 'table' and type(data.map) == 'table' then
      disk = data
    end
  end
  -- Serve any on-disk map; rebuild only when missing or past COLMAP_TTL. A
  -- scheduled rebuild after pick() would freeze the UI on proc:wait().
  if disk and (os.time() - (disk.saved or 0)) < COLMAP_TTL then
    return disk.map, nil
  end
  return rebuild_collection_map(cache_path)
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

---Collapse whitespace so a typed phrase matches across line breaks in the PDF.
---@param s string?
---@return string
local function flatten(s)
  return (clean(s):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', ''))
end

---Inserted lines stay within PEP 8 docstring limits (ruff W505, 72 cols)
---so a paste into a Python comment or markdown cell lints clean.
local WIDTH = 72

---Greedy word-wrap so each result is `#prefix + text` <= WIDTH.
---A single long token (a URL) is left whole; ruff exempts those lines.
---@param text string
---@param prefix string
---@return string[]
local function wrap_prefix(text, prefix)
  local out = {}
  if text == '' then
    out[1] = prefix
    return out
  end
  local limit = math.max(WIDTH - #prefix, 1)
  local cur ---@type string?
  for word in text:gmatch '%S+' do
    if not cur then
      cur = word
    elseif #cur + 1 + #word <= limit then
      cur = cur .. ' ' .. word
    else
      out[#out + 1] = prefix .. cur
      cur = word
    end
  end
  if cur then
    out[#out + 1] = prefix .. cur
  end
  return out
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
    vim.list_extend(lines, wrap_prefix(line, '> '))
  end
  return lines
end

---Stable attribution: author-year-page, then one citation link per line.
---Each link sits on its own `> · …` line so ruff's URL line-length exemption
---covers it when this block is pasted into a docstring or markdown cell.
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
  lines[#lines + 1] = '> ' .. base
  for _, link in ipairs(links) do
    lines[#lines + 1] = '> · ' .. link
  end

  -- User's own comment stays outside the quotation, same width limit.
  if a.annotationText ~= '' and (a.annotationComment or '') ~= '' then
    lines[#lines + 1] = ''
    for line in (a.annotationComment .. '\n'):gmatch '(.-)\n' do
      vim.list_extend(lines, wrap_prefix(line, ''))
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
  local now = os.time()
  if item_cache.items and (now - item_cache.saved) < ITEM_CACHE_TTL then
    local open = open_reader_attachment_keys()
    for _, it in ipairs(item_cache.items) do
      it.open = open[it.attachmentKey] or false
    end
    return item_cache.items, nil
  end

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
    local quote = flatten(text ~= '' and text or comment)
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
      -- Whitespace-flattened so a typed phrase matches across PDF line breaks.
      text = table.concat({
        page and ('p' .. page) or 'p?',
        quote,
        author,
        year,
        title,
        publication,
        table.concat(cols, ' '),
        doi or '',
      }, ' '),
      -- Field search targets (quote:left lamina, title:..., author:...)
      quote = quote,
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
  item_cache.items, item_cache.saved = items, os.time()
  return items, nil
end

M.load_items = load_items

---True when the query is plain words (no fzf modifiers). Those are treated as
---an exact phrase so a direct quote does not fuzzy-match half the library.
---@param pattern string
---@return boolean
local function is_plain_phrase(pattern)
  pattern = vim.trim(pattern)
  return pattern:find '%s' ~= nil
    and pattern:match '^%w' ~= nil
    and pattern:match "[\'!^$|:%\"%*]" == nil
end

---@param opts { open_only?: boolean }?
function M.pick(opts)
  opts = opts or {}
  if vim.bo.buftype ~= '' then
    vim.notify('Zotero quotes: not a normal buffer', vim.log.levels.WARN)
    return
  end

  local ok, picker = pcall(require, 'snacks.picker')
  if not ok then
    vim.notify('Zotero quotes: snacks.picker unavailable', vim.log.levels.ERROR)
    return
  end

  -- Open-tabs default is resolved from the first load (cheap path is wrong:
  -- a reader tab can be open with no annotations). Finder paints the window
  -- first; no pre-open spinner (snacks fills the list instead).
  local auto_open = opts.open_only == nil

  picker.pick {
    title = 'Zotero quotes',
    -- item.preview table, not the file previewer (avoids "Item has no `file`")
    preview = 'preview',
    open_only = opts.open_only or false,
    -- Snacks title chip: `o` while open-tabs mode is on (key is `O`, like `H`/`h`).
    toggles = {
      open_only = 'o',
    },
    -- Grep-like: literal substring, not fuzzy. Multi-word plain queries become
    -- one literal phrase (see is_plain_phrase).
    matcher = { fuzzy = false },
    filter = {
      transform = function(p, filter)
        local pattern = filter.pattern
        if is_plain_phrase(pattern) then
          p.matcher.opts.regex = true
          -- \V = very nomagic (literal), \c = ignorecase when the query is lowercase
          filter.pattern = (pattern:lower() == pattern and '\\c\\V' or '\\V') .. pattern:gsub('\\', '\\\\')
        else
          p.matcher.opts.regex = false
        end
        return false
      end,
    },
    ---@async
    finder = function(fopts, ctx)
      return function(cb)
        -- load_items uses vim.system:wait → vim.wait, which is illegal in
        -- snacks' fast-event async task. schedule() hops to the main loop.
        local loaded, err = ctx.async:schedule(load_items)
        if err then
          Snacks.notify.error('Zotero quotes: ' .. err)
          return
        end
        if #loaded == 0 then
          Snacks.notify.warn('Zotero quotes: no annotations (is Zotero running?)')
          return
        end
        if auto_open then
          auto_open = false
          local has_open = false
          for _, it in ipairs(loaded) do
            if it.open then
              has_open = true
              break
            end
          end
          ctx.picker.opts.open_only = has_open
          fopts.open_only = has_open
          ctx.picker:update_titles()
        end
        for _, item in ipairs(loaded) do
          if not fopts.open_only or item.open then
            -- Cached tables keep match_tick/score from the last matcher pass.
            -- On O re-find the tick is unchanged, so a stale match_tick makes
            -- the matcher skip every item (empty list, stale totals).
            item.match_tick, item.match_topk = nil, nil
            item.score = nil
            cb(item)
          end
        end
      end
    end,
    -- Rank by match score. Empty query keeps load_items order (paper, page).
    sort = { fields = { 'score:desc', 'idx' } },
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
          -- Normal only: insert `O` must type in a query. Matches snacks `H`.
          ['O'] = { 'toggle_open_only', desc = 'Toggle open tabs / all' },
        },
      },
      list = {
        keys = {
          ['O'] = { 'toggle_open_only', desc = 'Toggle open tabs / all' },
        },
      },
    },
  }
end

return M
