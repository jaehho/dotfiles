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

-- One uv pip install per interpreter so run --watch has real file events.
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

      local root = vim.fs.root(0, { 'pyproject.toml', '.venv' }) or vim.fn.fnamemodify(src, ':h')
      local venv_marimo = root .. '/.venv/bin/marimo'
      local marimo_bin = vim.uv.fs_stat(venv_marimo) and venv_marimo or 'marimo'
      local venv_python = root .. '/.venv/bin/python'
      local py = vim.uv.fs_stat(venv_python) and venv_python or 'python3'
      ensure_watchdog(py)
      local cmd = vim.fn.shellescape(marimo_bin) .. ' run --watch ' .. vim.fn.shellescape(src)
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
