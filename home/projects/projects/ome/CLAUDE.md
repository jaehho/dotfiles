# ome

The owner's always-on assistant on wonlab: a web app in Firefox (phone and desktop) as its only interface, with Web Push for notifications, jobs that wake a model only when a gate script says so, and memory as markdown in git. It replaces OpenClaw one job at a time. Decisions are this repo's `decision` issues; the design is in ~/.local/state/fleet/2026-11-20/agent/options.md (section C and the staged plan).

- Runs on wonlab as `jaeho`, a systemd user service. Build and test on the laptop. Anything on wonlab goes through the wonlab skill; services, Caddy blocks and secrets are staged scripts the owner runs.
- No model in ome gets Bash or any other tool that runs commands. claude runs commands it judges read-only (`docker inspect`, `gh` view, `git log`, `cat`) without an allow rule even under `dontAsk` (ome#12), and ome's user on wonlab is in the docker group. The model returns structured output, and ome runs the fixed script itself. Every claude run passes `--strict-mcp-config` and `--setting-sources project`.
- The model is a child process behind the `Harness` interface: `claude -p` (stream-json) now, an any-model CLI (opencode) later. No provider SDK in the core.
- A job is `jobs/<name>.toml` plus a gate script that prints `{"wakeAgent": true|false, "message": ...}`; the model runs only on true, with the message after the prompt. Every run goes to the run log, and every failure writes an inbox item, which Web Push will carry to the phone.
- Initiative policy (`POLICY.md` in the workspace): reading, writing mail drafts and what the owner asks for directly run freely; what ome proposes on its own (calendar adds, tasks, starting a laptop session) is an approval card; sending, deleting and paying never run.
- Secrets live in `~/.config/ome/` (mode 600), never in the repo or the workspace.
- Names and paths follow ~/dotfiles/docs/app-contract.md: command `ome`, environment `OME_*`, config `~/.config/ome/`, state `~/.local/state/ome/`.
- Similar products and the features worth borrowing from them are in `docs/landscape.md`. When a change adds or plans a feature, update its table and list there. If one product then does everything ome does that the owner uses (on a model they accept, self-hosted without a relay), tell the owner before building more: they may switch to it.
- OpenClaw keeps running until a job has moved, and a job never runs in both, except the read-only `papers` digest during its comparison week. No Telegram anywhere (#8).
