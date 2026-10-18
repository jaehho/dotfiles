# wombat

Self-hosted IBKR trading research. README.md covers use, design, costs, the wonhomelab host and sources; RESEARCH.md and `research/` hold registered research.

- Live execution is not enabled. Never switch Gateway to live or loosen the paper-only, read-only boundary without explicit authorization.
- Tasks, gotchas and decisions live in GitHub issues. Search before changing behavior: `gh issue list --label gotcha --state all --search <term>` (or `--label decision`). Completed milestones are closed `decision` issues (#13-#31, in the order they were listed). Never add TODO.md, ISSUES.md or DESIGN_LOG.md.
