# ome

The owner's always-on assistant on wonlab: a web app in Firefox (phone and desktop) as its only interface, with Web Push for notifications, jobs that wake a model only when a gate script says so, and memory as markdown in git. It replaces OpenClaw one job at a time. Decisions are this repo's `decision` issues; the design is in ~/.local/state/fleet/2026-11-20/agent/options.md (section C and the staged plan).

- Runs on wonlab as `jaeho`, a systemd user service. Build and test on the laptop. Anything on wonlab goes through the wonlab skill; services, Caddy blocks and secrets are staged scripts the owner runs.
- The model is a child process behind the `Harness` interface: `claude -p` (stream-json) now, an any-model CLI (opencode) later. No provider SDK in the core.
- A job is `jobs/<name>.toml` plus a gate script that prints `{"wakeAgent": true|false, "message": ...}`; the model runs only on true, with the message after the prompt. Every run goes to the run log, and every failure writes an inbox item, which Web Push will carry to the phone.
- Initiative policy (`POLICY.md` in the workspace): reading runs freely; drafts, calendar adds and starting a laptop session are approval cards; sending, deleting and paying never run.
- Secrets live in `~/.config/ome/` (mode 600), never in the repo or the workspace.
- Names and paths follow ~/dotfiles/docs/app-contract.md: command `ome`, environment `OME_*`, config `~/.config/ome/`, state `~/.local/state/ome/`.
- OpenClaw keeps running until a job has moved, and a job never runs in both, except the read-only `papers` digest during its comparison week. No Telegram anywhere (#8).
