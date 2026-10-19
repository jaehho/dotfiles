-- Claude Code bridge on non-Anthropic lanes via claude-open. claude-open only
-- adds ANTHROPIC_* and execs claude, so the plugin's IDE WebSocket vars
-- (ENABLE_IDE_INTEGRATION, CLAUDE_CODE_SSE_PORT) still reach the process and
-- the nvim bridge keeps working.
--
-- Mirrors the `case "$lane"` block in home/bin/.local/bin/claude-open: the
-- launch command plus the /model rows that lane serves. Keep both in step with
-- the script if a provider gains or drops an id. First row is the startup lane.

local lanes = {
  {
    label = 'MiMo',
    detail = 'mimo-v2.6-pro[1m] — 1M ctx',
    cmd = 'claude-open mimo',
    models = {
      { name = 'MiMo v2.6 Pro', value = 'mimo-v2.6-pro[1m]' },
      { name = 'MiMo v2.6 Flash', value = 'mimo-v2.6-flash' },
    },
  },
  {
    label = 'z.ai',
    detail = 'glm-5.3[1m] — GLM Coding Plan',
    cmd = 'claude-open zai',
    models = {
      { name = 'GLM 5.3', value = 'glm-5.3[1m]' },
      { name = 'GLM 5.3 Flash', value = 'glm-5.3-flash[1m]' },
    },
  },
  {
    label = 'OpenRouter',
    detail = 'glm-5.3-flash / gpt-6-astra',
    cmd = 'claude-open openrouter',
    models = {
      { name = 'GLM 5.3', value = 'z-ai/glm-5.3[1m]' },
      { name = 'GLM 5.3 Flash', value = 'z-ai/glm-5.3-flash[1m]' },
      { name = 'GLM 5.3 FlashX', value = 'z-ai/glm-5.3-flashx[1m]' },
      { name = 'GPT-6 Astra', value = 'openai/gpt-6-astra[1m]' },
    },
  },
  {
    label = 'Local (Ollama)',
    detail = 'ornith:9b-49k — 49k ctx',
    cmd = 'claude-open local',
    models = {
      { name = 'Ornith 9B (local)', value = 'ornith:9b-49k' },
      { name = 'Qwen 2.5 7B (local)', value = 'qwen2.5:7b' },
    },
  },
}

-- Lane is baked into terminal_cmd at launch (claude-open reads it as a leading
-- positional and rejects a second one), so this rewrites terminal_cmd rather
-- than passing args. models goes with it: the plugin's own model picker would
-- otherwise offer the previous lane's ids, which that endpoint will not serve.
local function select_lane()
  vim.ui.select(lanes, {
    prompt = 'Claude provider lane:',
    format_item = function(item)
      return ('%-14s %s'):format(item.label, item.detail)
    end,
  }, function(choice)
    if not choice then
      return
    end
    require('claudecode.terminal').defaults.terminal_cmd = choice.cmd
    local state = require('claudecode').state
    if state and state.config then
      state.config.models = choice.models
    end
    local running = require('claudecode.terminal').get_active_terminal_bufnr()
    vim.notify(
      ('Claude lane: %s (%s)%s'):format(
        choice.label,
        choice.cmd,
        running and ' — reopen the terminal to apply' or ''
      )
    )
  end)
end

return {
  {
    'coder/claudecode.nvim',
    keys = {
      { '<leader>am', select_lane, desc = 'Claude [M]odel / provider lane' },
    },
    opts = {
      terminal_cmd = lanes[1].cmd,
      models = lanes[1].models,
    },
  },
}
