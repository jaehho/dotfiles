-- Claude Code bridge on MiMo via claude-open, not the Anthropic API.
-- claude-open only adds ANTHROPIC_* and execs claude, so the plugin's IDE
-- WebSocket vars (ENABLE_IDE_INTEGRATION, CLAUDE_CODE_SSE_PORT) still reach
-- the process and the nvim bridge keeps working.
return {
  {
    'coder/claudecode.nvim',
    opts = {
      -- Pin the lane: bare `claude-open` falls back to z.ai when
      -- MIMO_API_KEY is missing, which would be a silent surprise here.
      terminal_cmd = 'claude-open mimo',
      -- Rows for :ClaudeCodeSelectModel. The value is passed to
      -- `claude --model`, so it must be an id the MiMo endpoint serves.
      models = {
        { name = 'MiMo v2.6 Pro', value = 'mimo-v2.6-pro[1m]' },
        { name = 'MiMo v2.6 Flash', value = 'mimo-v2.6-flash' },
      },
    },
  },
}
