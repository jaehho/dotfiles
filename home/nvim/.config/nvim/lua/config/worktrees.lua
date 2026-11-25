-- Pick a git worktree of the current repository by its name (the
-- folder's name) and open it in a new tab whose directory is the
-- worktree.
local M = {}

local function list_worktrees()
  local lines = vim.fn.systemlist({ 'git', 'worktree', 'list', '--porcelain' })
  if vim.v.shell_error ~= 0 then
    return {}
  end
  local worktrees = {}
  for _, line in ipairs(lines) do
    local path = line:match('^worktree (.+)$')
    if path then
      table.insert(worktrees, { path = path })
    elseif line == 'bare' then
      worktrees[#worktrees].bare = true
    end
  end
  return worktrees
end

function M.items()
  local items = {}
  for _, worktree in ipairs(list_worktrees()) do
    if not worktree.bare then
      table.insert(items, {
        text = vim.fn.fnamemodify(worktree.path, ':t'),
        root = worktree.path,
      })
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
    -- The preview shows the worktree's recent commits.
    preview = function(ctx)
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
        vim.cmd.edit(vim.fn.fnameescape(item.root))
      end)
    end,
  })
end

return M
