---
paths:
  - "home/hypr/.config/quickshell/bar/Dash*.qml"
---

# Dash panel

- The panel never scrolls: every card at its worst case (each capped list full, every alert line showing, the pref-gated LLM rows on) fits the sheet, 1000px on a 1080px screen (1080 − 40 bar − 16 margins − 24 padding). A card with a variable list caps it in code, and a new card or row is paid for by cutting or compacting another. `DashPanel.qml` logs `dash panel overflows` to the bar's log when the content is taller; after a change, render the panel with worst-case data in the no-focus harness (quickshell skill) and check that log.
- It holds SYSTEM, SESSIONS and LLM, the cards the user reads (2026-11-18). MARKET and TASKS were cut from the old overlay's set; ask before bringing one back.
- SYSTEM keeps dash's look (LED rings, thermals row, net LED meter): the user prefers it to btop, which stays on Ctrl+Shift+Escape for detail.
