import type { Register } from 'claude-code'

// Buttons are pressed by the person's chord for an engine action.
// ctrl+up / ctrl+down default to these two (diff file list, which
// nothing else uses while no diff panel is mounted).
const PREV = 'app:diffFileListUp'
const NEXT = 'app:diffFileListDown'

const ROWS = new Set<string>([
  'UserMessage', 'AssistantMessage', 'ToolUse', 'ToolResult',
  'ToolGroup', 'CommandOutput', 'TurnDuration', 'InfoNotice',
])

export const register: Register = on => {
  // requestIds of the person's own prompts, oldest first.
  const ids: string[] = []
  // Index of the prompt last jumped to; null = at the bottom.
  let at: number | null = null

  // requestId of the newest transcript row, in first-drawn order.
  const seen = new Set<string>()
  let last: string | null = null

  on('ui.render', ($, e, next) => {
    if (ROWS.has(e.component) && !seen.has(e.requestId)) {
      seen.add(e.requestId)
      last = e.requestId
    }
    if (
      e.component === 'UserMessage' &&
      e.props.origin.kind === 'composer' &&
      !ids.includes(e.requestId)
    ) {
      ids.push(e.requestId)
    }

    return next(e)
  })

  on('prompt.submit', ($, e, next) => {
    at = null

    return next(e)
  })

  // The scroll target for a step of `by` prompts, or null if none.
  // Stepping down past the last prompt goes to the end.
  const step = (by: number) => {
    if (ids.length === 0) return null
    const to = Math.max((at ?? ids.length) + by, 0)
    if (to >= ids.length) {
      at = null

      return last ? ({ to: { requestId: last }, block: 'end' } as const) : null
    }
    at = to

    return { to: { requestId: ids[to]! }, block: 'start' } as const
  }

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)
    const { Box, Button } = $.ui.resolve(e)

    return (
      <Box display="none">
        <Button key="prev" plain dimColor action={PREV}
          label="ctrl+↑ prev prompt" onPress={async () => {
            const a = step(-1)
            if (a) await $.ui.scroll(a)
          }} />
        <Button key="next" plain dimColor action={NEXT}
          label="  ctrl+↓ next prompt" onPress={async () => {
            const a = step(1)
            if (a) await $.ui.scroll(a)
          }} />
      </Box>
    )
  })
}
