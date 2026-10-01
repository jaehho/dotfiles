-- Unified preview toggle: dispatches by filetype (typst, tex, markdown, marimo, python, html).
-- Typst/TeX PDF-in-zathura is gone; typst-preview and vimtex own those.
local M = {}

local function is_marimo_notebook()
  local markers = {
    'import marimo',
    'from marimo',
    '__generated_with',
    'marimo.App',
    '@app.cell',
  }
  local lines = vim.api.nvim_buf_get_lines(0, 0, 200, false)
  for _, line in ipairs(lines) do
    for _, m in ipairs(markers) do
      if line:find(m, 1, true) then
        return true
      end
    end
  end
  return false
end

-- One uv pip install per interpreter so edit --watch has real file events.
local watchdog_checked = {}
local function ensure_watchdog(py)
  if watchdog_checked[py] then
    return
  end
  watchdog_checked[py] = true
  local probe = vim.system({
    py,
    '-c',
    "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('watchdog') else 1)",
  }):wait()
  if probe.code == 0 then
    return
  end
  local install = vim.system({ 'uv', 'pip', 'install', '--python', py, 'watchdog' }):wait()
  if install.code == 0 then
    vim.notify('watchdog installed for marimo --watch', vim.log.levels.INFO)
  else
    vim.notify('watchdog install failed; marimo --watch will poll', vim.log.levels.WARN)
  end
end

-- marimo discovery uses the local server registry
-- (~/.local/state/marimo/servers). marimo only registers servers started
-- with --no-token; that is also what keeps ?file= URLs free of a login
-- page. Open is not a toggle: each use reveals the notebook in an
-- existing window, or opens one.
local function marimo_servers_dir()
  local state = vim.env.XDG_STATE_HOME
  if state and state ~= '' then
    return state .. '/marimo/servers'
  end
  return vim.fn.expand '~/.local/state/marimo/servers'
end

local function marimo_registry()
  local entries = {}
  for name, kind in vim.fs.dir(marimo_servers_dir()) do
    if kind == 'file' and name:match '%.json$' then
      local path = marimo_servers_dir() .. '/' .. name
      local lines = vim.fn.readfile(path)
      local ok, data = pcall(vim.json.decode, table.concat(lines, '\n'))
      if ok and type(data) == 'table' and type(data.port) == 'number' and type(data.pid) == 'number' then
        if vim.uv.kill(data.pid, 0) == 0 then
          entries[#entries + 1] = data
        end
      end
    end
  end
  return entries
end

local function marimo_url_host(host)
  if not host or host == '*' or host == '0.0.0.0' or host == '::' or host == '' then
    return '127.0.0.1'
  end
  if host:find ':' and not host:find '^%[' then
    return '[' .. host .. ']'
  end
  return host
end

-- What the server serves, from the registered pid: directory operand of
-- `marimo edit [NAME]`, or the single file. Registry entries do not carry
-- a root, and the workspace_files API wants a skew-protection token.
local function marimo_workspace_root(server)
  local proc = '/proc/' .. server.pid
  local fd = vim.uv.fs_open(proc .. '/cmdline', 'r', 0)
  if not fd then
    return nil
  end
  -- /proc files report size 0; read a fixed cap.
  local data = vim.uv.fs_read(fd, 65536, 0) or ''
  vim.uv.fs_close(fd)
  local tokens = vim.split((data:gsub('%z', ' ')), '%s+', { trimempty = true })
  local cwd = vim.uv.fs_realpath(proc .. '/cwd') or ''

  local name
  for i, t in ipairs(tokens) do
    if t == 'edit' then
      local j = i + 1
      while j <= #tokens do
        local a = tokens[j]
        if a:sub(1, 1) ~= '-' then
          name = a
          break
        end
        if not a:match '^%-%-%w+=' then
          local takes_value = a == '-p'
            or a == '--port'
            or a == '--host'
            or a == '--proxy'
            or a == '--base-url'
            or a == '--token-password'
            or a == '--token-password-file'
            or a == '--allow-origins'
          if takes_value then
            j = j + 1
          end
        end
        j = j + 1
      end
      break
    end
  end

  if not name then
    return cwd, nil
  end
  local abs = name:sub(1, 1) == '/' and vim.fs.normalize(name) or vim.fs.normalize(cwd .. '/' .. name)
  local st = vim.uv.fs_stat(abs)
  if st and st.type == 'directory' then
    return abs, nil
  end
  return nil, abs
end

-- A registered marimo server that covers src, deepest root first.
local function find_marimo_workspace(src)
  src = vim.fs.normalize(src)
  local best, best_score = nil, -1
  for _, server in ipairs(marimo_registry()) do
    local root, only_file = marimo_workspace_root(server)
    local score = -1
    local file_key = src
    if only_file then
      if only_file == src then
        score = 1
      end
    elseif root and (src == root or vim.startswith(src, root .. '/')) then
      score = #root
      file_key = src:sub(#root + 2)
      if file_key == '' then
        file_key = src
      end
    end
    if score > best_score then
      best_score = score
      best = {
        host = server.host,
        port = server.port,
        base_url = server.base_url or '',
        root = root or '',
        file_key = file_key,
      }
    end
  end
  return best
end

-- Firefox is the render surface (WebKitGTK upsampled marimo's PNG figures).
-- One window per notebook; raise by title so a second <leader>tp does not
-- spawn another tab. marimo-view (home/laptop) is an unused WebKit experiment.
local function title_has_basename(title, basename)
  local init = 1
  while true do
    local s, e = title:find(basename, init, true)
    if not s then
      return false
    end
    local before = s == 1 or not title:sub(s - 1, s - 1):match '[%w_]'
    local after = e >= #title or not title:sub(e + 1, e + 1):match '[%w_]'
    if before and after then
      return true
    end
    init = s + 1
  end
end

local function focus_marimo_window(title_fragment)
  local out = vim.system({ 'hyprctl', 'clients', '-j' }, { text = true }):wait()
  local ok, clients = pcall(vim.json.decode, out.stdout or '')
  if not ok or type(clients) ~= 'table' then
    return false
  end
  for _, c in ipairs(clients) do
    local title = type(c) == 'table' and c.title or ''
    if type(title) == 'string' and title_has_basename(title, title_fragment) and c.address then
      vim.system({
        'hyprctl',
        'dispatch',
        ('hl.dsp.focus({ window = "address:%s" })'):format(c.address),
      }, { text = true })
      return true
    end
  end
  return false
end

local function firefox_bin()
  for _, bin in ipairs { 'firefox-developer-edition', 'firefox' } do
    if vim.fn.executable(bin) == 1 then
      return bin
    end
  end
end

local function show_marimo(server, src)
  local host = marimo_url_host(server.host)
  local file = server.file_key or src
  local url = ('http://%s:%d%s/?file=%s'):format(host, server.port, server.base_url or '', vim.uri_encode(file, true))
  if focus_marimo_window(vim.fs.basename(src)) then
    return url
  end
  local bin = firefox_bin()
  if bin then
    vim.fn.jobstart({ bin, '--new-window', url }, { detach = true })
  else
    vim.fn.jobstart({ 'xdg-open', url }, { detach = true })
  end
  return url
end

function M.toggle()
  local ft = vim.bo.filetype

  if ft == 'typst' then
    vim.cmd 'TypstPreviewToggle'
  elseif ft == 'tex' then
    -- vimtex continuous compile; <localLeader>lv opens the PDF viewer
    vim.cmd 'VimtexCompile'
  elseif ft == 'markdown' then
    -- selimacerbas has start/stop, not Toggle; hooks set markdown_preview_on.
    if vim.g.markdown_preview_on then
      vim.cmd 'MarkdownPreviewStop'
    else
      vim.cmd 'MarkdownPreview'
    end
  elseif ft == 'python' then
    if is_marimo_notebook() then
      local src = vim.api.nvim_buf_get_name(0)
      local bufnr = vim.api.nvim_get_current_buf()

      -- A pane we spawned is ours to toggle off.
      if vim.b.marimo_pane then
        vim.system { 'tmux', 'kill-pane', '-t', vim.b.marimo_pane }
        vim.b.marimo_pane = nil
        vim.notify('Preview stopped', vim.log.levels.INFO)
        return
      end

      -- Live workspace: reveal/switch, never stop.
      local server = find_marimo_workspace(src)
      if server then
        show_marimo(server, src)
        vim.notify(('Opened in marimo workspace :%d'):format(server.port), vim.log.levels.INFO)
        return
      end

      local root = vim.fs.root(0, { 'pyproject.toml', '.venv' }) or vim.fn.fnamemodify(src, ':h')
      local venv_marimo = root .. '/.venv/bin/marimo'
      local marimo_bin = vim.uv.fs_stat(venv_marimo) and venv_marimo or 'marimo'
      local venv_python = root .. '/.venv/bin/python'
      local py = vim.uv.fs_stat(venv_python) and venv_python or 'python3'
      ensure_watchdog(py)
      -- edit --watch: notebook UI + reload on nvim saves. --no-token registers
      -- the server; --headless leaves the window to Firefox.
      local cmd = vim.fn.shellescape(marimo_bin)
        .. ' edit --watch --no-token --headless '
        .. vim.fn.shellescape(src)
      local result = vim.system {
        'tmux', 'split-window', '-v', '-d', '-l', '10', '-P', '-F', '#{pane_id}',
        cmd,
      }:wait()
      vim.b.marimo_pane = vim.trim(result.stdout or '')
      vim.api.nvim_create_autocmd({ 'BufDelete', 'VimLeavePre' }, {
        buffer = bufnr,
        once = true,
        callback = function()
          if vim.b[bufnr].marimo_pane then
            vim.system { 'tmux', 'kill-pane', '-t', vim.b[bufnr].marimo_pane }
          end
        end,
      })
      for _ = 1, 20 do
        vim.wait(100)
        server = find_marimo_workspace(src)
        if server then
          show_marimo(server, src)
          return
        end
      end
      vim.notify('marimo started in tmux; no registry entry yet', vim.log.levels.WARN)
    else
      local dap = require 'dap'
      if dap.session() then
        dap.terminate()
        require('dapui').close()
        vim.notify('Debug stopped', vim.log.levels.INFO)
        return
      end
      dap.run {
        type = 'python',
        request = 'launch',
        name = 'tp: Launch file',
        program = '${file}',
        console = 'integratedTerminal',
      }
    end
  elseif ft == 'html' then
    local src = vim.api.nvim_buf_get_name(0)
    vim.fn.jobstart({ 'xdg-open', src }, { detach = true })
  else
    vim.notify('No preview for filetype: ' .. ft, vim.log.levels.WARN)
  end
end

return M
