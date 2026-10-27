# writing

Drafts I write with Claude (mail, issues, messages) and, once delivered, what was actually sent. The history is a dataset of how I edit Claude's prose; keep it intact.

- One file per piece: `drafts/YYYY-MM-DD-<slug>.md`, revised in place each round, never a new file per round. Front matter: `kind` (`mail`, `issue`, `message`), then for mail `account`, `to`, `subject`, `attach`. Paste the text in chat too.
- Commit straight to `main`. Before revising, commit any change of mine as `user: <slug>`; then write the revision and commit it as `claude: <slug> rN`. I edit in nvim and diff with git.
- When it is sent, commit the text as actually sent as `sent: <slug>`, add `sent: <date>` to the front matter, and `git mv` the file to `sent/`. Never delete a draft.
- For mail, read the real sent copy with `gog gmail` (`--readonly`; never send from here). Match by recipient, subject, and body similarity, and read all of the dry-run before committing.
- Attachments stay out of the repo (gitignored).
