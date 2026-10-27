# writing

Drafts I write with Claude (mail, issues, messages) and, once delivered, what was actually sent. The history is a dataset of how I edit Claude's prose; keep it intact.

- Read `STYLE.md` before drafting. When the same edit of mine recurs, propose it as a rule there with the commit it came from.
- One file per piece: `drafts/YYYY-MM-DD-<slug>.md`, revised in place each round, never a new file per round. Front matter: `kind` (`mail`, `issue`, `message`), then for mail `account`, `to`, `subject`, `attach`. Paste the text in chat too.
- Commit straight to `main`. Before revising, commit any change of mine as `user: <slug>`; then write the revision and commit it as `claude: <slug> rN`. I edit in nvim and diff with git.
- When it is sent, commit the text as actually sent as `sent: <slug>`, add `sent: <date>` to the front matter, and `git mv` the file to `sent/`. Never delete a draft.
- For mail, `uv run scripts/writing_sync.py` dry-runs every unsent draft against the real sent copy (read through `gog gmail --readonly`; never send from here). Read all of it, then `--apply <slug>` for the one I say was sent; it needs my edits committed first.
- Attachments stay out of the repo (gitignored).
