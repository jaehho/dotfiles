---
paths:
  - "home/hypr/.config/quickshell/bar/Dash*.qml"
---

# Dash panel

- The panel never scrolls: every card at its worst case (each capped list full, every alert line showing, the pref-gated LLM rows on) fits the sheet, 1000px on a 1080px screen (1080 − 40 bar − 16 margins − 24 padding). A card with a variable list caps it in code, and a new card or row is paid for by cutting or compacting another. `DashPanel.qml` logs `dash panel overflows` to the bar's log when the content is taller; after a change, render the panel with worst-case data in the no-focus harness (quickshell skill) and check that log.
- It holds SESSIONS, LLM, TASKS and MARKET (2026-11-19); the worst case is 944px, so a new row means a cut. TASKS is only what is due (asst's Today: overdue and due today), never the inbox. SYSTEM was cut for btop (Ctrl+Shift+Escape, `hypr-btop-toggle`); ask before bringing it back. Its port of dash's LED rings is in commit 9a112d9.
