-- Pick a git worktree of the current repository by its branch and open
-- it in a new tab whose directory is the worktree.
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
      table.insert(worktrees, { path = path, branch = '(detached)' })
    elseif line == 'bare' then
      worktrees[#worktrees].bare = true
    else
      local branch = line:match('^branch refs/heads/(.+)$')
      if branch then
        worktrees[#worktrees].branch = branch
      end
    end
  end
  return worktrees
end

-- One row per worktree, named for its branch (git allows a branch in
-- one worktree at a time). The first worktree is the main checkout.
function M.items()
  local items = {}
  for i, worktree in ipairs(list_worktrees()) do
    if not worktree.bare then
      table.insert(items, {
        text = i == 1 and worktree.branch .. ' (main checkout)' or worktree.branch,
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
