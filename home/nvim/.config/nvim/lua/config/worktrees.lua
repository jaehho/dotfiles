-- Pick a git worktree of the current repository and open it in a new
-- tab whose directory is the worktree. A worktree whose branch adds an
-- explorations/<slug>/ folder that the main worktree lacks opens on
-- its README.
local M = {}

local function list_worktrees()
  local lines = vim.fn.systemlist({ 'git', 'worktree', 'list', '--porcelain' })
  if vim.v.shell_error ~= 0 then
    return {}
  end
  local worktrees, current = {}, nil
  for _, line in ipairs(lines) do
    local path = line:match('^worktree (.+)$')
    if path then
      current = { path = path, branch = '(detached)' }
      table.insert(worktrees, current)
    elseif current then
      current.branch = line:match('^branch refs/heads/(.+)$') or current.branch
      current.bare = current.bare or line == 'bare'
    end
  end
  return worktrees
end

-- The README of each explorations/<slug>/ folder, by slug.
local function find_explorations(root)
  local readmes = {}
  for _, readme in ipairs(vim.fn.glob(root .. '/explorations/*/README.md', false, true)) do
    readmes[vim.fn.fnamemodify(readme, ':h:t')] = readme
  end
  return readmes
end

function M.items()
  local worktrees = list_worktrees()
  local items = {}
  if #worktrees == 0 then
    return items
  end
  local in_main = find_explorations(worktrees[1].path)
  for i, worktree in ipairs(worktrees) do
    if not worktree.bare then
      local own = {}
      if i > 1 then
        for slug, readme in pairs(find_explorations(worktree.path)) do
          if not in_main[slug] then
            table.insert(own, { slug = slug, readme = readme })
          end
        end
      end
      table.sort(own, function(a, b) return a.slug > b.slug end)
      local label = i == 1 and worktree.branch .. ' (main checkout)' or worktree.branch
      if #own == 0 then
        table.insert(items, { text = label, root = worktree.path })
      end
      for _, exploration in ipairs(own) do
        table.insert(items, {
          -- A branch normally holds one exploration; name the folder
          -- only when it holds more, so the rows stay distinct.
          text = #own > 1 and label .. '  ' .. exploration.slug or label,
          root = worktree.path,
          file = exploration.readme,
        })
      end
    end
  end
  return items
end

function M.pick()
  local items = M.items()
  if #items == 0 then
    vim.notify('No git worktrees here', vim.log.levels.WARN)
    return
  end
  Snacks.picker.pick({
    title = 'Worktrees',
    items = items,
    format = 'text',
    -- An item without a README previews its recent commits.
    preview = function(ctx)
      if ctx.item.file then
        return Snacks.picker.preview.file(ctx)
      end
      ctx.item.preview = {
        text = vim.fn.system({ 'git', '-C', ctx.item.root, 'log', '--oneline', '-20' }),
        ft = 'git',
      }
      return Snacks.picker.preview.preview(ctx)
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      vim.schedule(function()
        vim.cmd.tabnew()
        vim.cmd.tcd(vim.fn.fnameescape(item.root))
        vim.cmd.edit(vim.fn.fnameescape(item.file or item.root))
      end)
    end,
  })
end

return M
