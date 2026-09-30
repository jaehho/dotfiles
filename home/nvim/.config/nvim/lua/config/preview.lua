-- Unified preview toggle: dispatches by filetype (typst, tex, markdown, marimo, python, html)
local M = {}

local function stop_pdf_preview(bufnr)
  local ok, preview = pcall(function() return vim.b[bufnr].pdf_preview end)
  if not ok or not preview then return end
  if preview.pane_id and preview.pane_id ~= '' then
    vim.system { 'tmux', 'kill-pane', '-t', preview.pane_id }
  end
  if preview.zathura_id then
    pcall(vim.fn.jobstop, preview.zathura_id)
  end
  pcall(function() vim.b[bufnr].pdf_preview = nil end)
  pcall(vim.api.nvim_del_augroup_by_name, 'PdfPreview' .. bufnr)
end

local function start_pdf_preview(compile_cmd, watch_cmd, src, pdf)
  local bufnr = vim.api.nvim_get_current_buf()

  if vim.b.pdf_preview then
    stop_pdf_preview(bufnr)
    vim.notify('Preview stopped', vim.log.levels.INFO)
    return
  end

  vim.system(compile_cmd):wait()
  local result = vim.system {
    'tmux', 'split-window', '-v', '-d', '-l', '6', '-P', '-F', '#{pane_id}',
    watch_cmd,
  }:wait()
  local pane_id = vim.trim(result.stdout or '')
  local zathura_id = vim.fn.jobstart({ 'zathura', pdf }, {
    on_exit = function()
      vim.schedule(function() stop_pdf_preview(bufnr) end)
    end,
  })
  vim.b.pdf_preview = { pane_id = pane_id, zathura_id = zathura_id }
  local augroup = vim.api.nvim_create_augroup('PdfPreview' .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd({ 'BufDelete', 'VimLeavePre' }, {
    group = augroup,
    buffer = bufnr,
    callback = function() stop_pdf_preview(bufnr) end,
  })
end

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

-- Returns has_edit, name: the `edit` token is present, and the path operand
-- after it (nil for a bare `edit`, which serves cwd).
local function marimo_edit_name(cmd)
  local tokens = vim.split(cmd, '%s+', { trimempty = true })
  for i, t in ipairs(tokens) do
    if t == 'edit' then
      local j = i + 1
      while j <= #tokens do
        local a = tokens[j]
        if a:sub(1, 1) ~= '-' then
          return true, a
        end
        if a:match '^%-%-%w+=' then
          j = j + 1
        elseif a == '-p' or a == '--port' or a == '--host' or a == '--proxy' or a == '--base-url'
          or a == '--token-password' or a == '--token-password-file' or a == '--allow-origins'
        then
          j = j + 2
        else
          j = j + 1
        end
      end
      return true, nil
    end
  end
  return false, nil
end

-- Listening TCP port for pid, preferring 127.0.0.1.
local function marimo_listen_port(pid)
  local out = vim.system({ 'ss', '-ltnp' }, { text = true }):wait()
  local fallback
  for line in (out.stdout or ''):gmatch '[^\r\n]+' do
    if line:find('pid=' .. pid .. ',', 1, true) then
      local addr = line:match '^%S+%s+%d+%s+%d+%s+(%S+)'
      local host, port
      if addr then
        host, port = addr:match '^(.+):(%d+)$'
      end
      if port then
        if host == '*' or host == '0.0.0.0' or host == '127.0.0.1' then
          return '127.0.0.1', tonumber(port)
        end
        fallback = { host = host, port = tonumber(port) }
      end
    end
  end
  if fallback then
    return fallback.host, fallback.port
  end
end

-- A live `marimo edit` whose workspace contains src.
-- Directory workspaces (`edit --watch notebooks/`) beat single-file servers.
local function find_marimo_workspace(src)
  src = vim.fs.normalize(src)
  local out = vim.system({ 'pgrep', '-af', 'marimo' }, { text = true }):wait()
  local best, best_score = nil, -1

  for line in (out.stdout or ''):gmatch '[^\r\n]+' do
    local pid, cmd = line:match '^(%d+) (.+)$'
    local has_edit, name = false, nil
    if pid then
      has_edit, name = marimo_edit_name(cmd)
    end
    -- uv wrapper is fine; it carries the same argv. A listen port picks the
    -- real server over the wrapper.
    if has_edit then
      local host, port = marimo_listen_port(tonumber(pid))
      if port then
        local cwd = vim.uv.fs_realpath('/proc/' .. pid .. '/cwd') or ''
        local workspace_dir, file_arg
        if name and name ~= '' then
          local abs = name:sub(1, 1) == '/' and vim.fs.normalize(name) or vim.fs.normalize(cwd .. '/' .. name)
          local st = vim.uv.fs_stat(abs)
          if st and st.type == 'directory' then
            workspace_dir = abs
          else
            file_arg = abs
          end
        else
          workspace_dir = cwd
        end

        local score = -1
        if file_arg and file_arg == src then
          score = 100
        elseif workspace_dir and (src == workspace_dir or vim.startswith(src, workspace_dir .. '/')) then
          score = #workspace_dir
        end
        if score > best_score then
          best_score = score
          best = { host = host, port = port, dir = workspace_dir }
        end
      end
    end
  end
  return best
end

local function open_marimo_workspace(server, src)
  -- Directory workspaces list files relative to the served dir; the
  -- server also accepts absolute paths inside that dir.
  local file = src
  if server.dir and vim.startswith(src, server.dir .. '/') then
    file = src:sub(#server.dir + 2)
  end
  local host = server.host
  if host:find ':' and not host:find '^%[' then
    host = '[' .. host .. ']'
  end
  local url = ('http://%s:%d/?file=%s'):format(host, server.port, vim.uri_encode(file, true))
  vim.fn.jobstart({ 'xdg-open', url }, { detach = true })
  return url
end

function M.toggle()
  local ft = vim.bo.filetype

  if ft == 'typst' then
    local src = vim.api.nvim_buf_get_name(0)
    local root = vim.fs.root(0, '.git') or vim.fn.fnamemodify(src, ':h')
    local pdf = src:gsub('%.typ$', '.pdf')
    start_pdf_preview(
      { 'typst', 'compile', '--root', root, src, pdf },
      'typst watch --root ' .. vim.fn.shellescape(root) .. ' ' .. vim.fn.shellescape(src) .. ' ' .. vim.fn.shellescape(pdf),
      src,
      pdf
    )
  elseif ft == 'tex' then
    local src = vim.api.nvim_buf_get_name(0)
    local build_dir = vim.fn.fnamemodify(src, ':h') .. '/build'
    vim.fn.mkdir(build_dir, 'p')
    local pdf = build_dir .. '/' .. vim.fn.fnamemodify(src, ':t'):gsub('%.tex$', '.pdf')
    start_pdf_preview(
      { 'latexmk', '-pdf', '-g', '-interaction=nonstopmode', '-output-directory=' .. build_dir, src },
      'latexmk -pdf -pvc -g -interaction=nonstopmode -output-directory=' .. vim.fn.shellescape(build_dir) .. ' ' .. vim.fn.shellescape(src),
      src,
      pdf
    )
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

      if vim.b.marimo_pane then
        vim.system { 'tmux', 'kill-pane', '-t', vim.b.marimo_pane }
        vim.b.marimo_pane = nil
        vim.notify('Preview stopped', vim.log.levels.INFO)
        return
      end

      -- Attach to a live `marimo edit` workspace (e.g. `uv run marimo edit
      -- --watch notebooks/`) instead of starting another server on a new port.
      if vim.b.marimo_attached then
        vim.b.marimo_attached = nil
        vim.notify('Preview stopped (existing marimo workspace left running)', vim.log.levels.INFO)
        return
      end
      local server = find_marimo_workspace(src)
      if server then
        vim.b.marimo_attached = open_marimo_workspace(server, src)
        vim.notify(('Using marimo workspace on :%d'):format(server.port), vim.log.levels.INFO)
        return
      end

      local root = vim.fs.root(0, { 'pyproject.toml', '.venv' }) or vim.fn.fnamemodify(src, ':h')
      local venv_marimo = root .. '/.venv/bin/marimo'
      local marimo_bin = vim.uv.fs_stat(venv_marimo) and venv_marimo or 'marimo'
      local venv_python = root .. '/.venv/bin/python'
      local py = vim.uv.fs_stat(venv_python) and venv_python or 'python3'
      ensure_watchdog(py)
      -- edit --watch: notebook UI (code cells visible) + reload on nvim saves
      local cmd = vim.fn.shellescape(marimo_bin) .. ' edit --watch ' .. vim.fn.shellescape(src)
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
          if vim.b[bufnr].marimo_attached then
            vim.b[bufnr].marimo_attached = nil
          end
        end,
      })
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
