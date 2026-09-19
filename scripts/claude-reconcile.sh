#!/usr/bin/env bash
# claude-reconcile: enforce dotfiles-declared Claude Code state at user scope.
# Source manifests live in home/claude/.claude/reconcile/ and home/claude/.claude/skills/.

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)}"
RECONCILE_DIR="$DOTFILES/home/claude/.claude/reconcile"
CUSTOM_SKILLS_DIR="$DOTFILES/home/claude/.claude/skills"
SECRETS_FILE="${CLAUDE_MCP_SECRETS_FILE:-$HOME/.config/claude-mcp-secrets.env}"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_JSON="$HOME/.claude.json"
PLUGINS_DIR="$CLAUDE_DIR/plugins"
INSTALLED_PLUGINS="$PLUGINS_DIR/installed_plugins.json"
KNOWN_MARKETS="$PLUGINS_DIR/known_marketplaces.json"
SKILLS_DIR="$CLAUDE_DIR/skills"
SKILLS_SOURCES_DIR="$CLAUDE_DIR/skills-sources"
SETTINGS_JSON="$CLAUDE_DIR/settings.json"

DRY_RUN=0
INTERACTIVE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n)    DRY_RUN=1 ;;
    --interactive|-i) INTERACTIVE=1 ;;
    --help|-h)
      cat <<EOF
Usage: $0 [--dry-run] [--interactive]

Enforce dotfiles-declared Claude Code state at user scope. By default,
anything not declared gets removed silently (strict). With --interactive,
removals are confirmed once per category.

  - Plugins:      settings.json -> enabledPlugins
  - Marketplaces: home/claude/.claude/reconcile/marketplaces.json
  - MCP servers:  home/claude/.claude/reconcile/mcp-servers.json
                  (\${VAR} from \$CLAUDE_MCP_SECRETS_FILE or ~/.config/claude-mcp-secrets.env)
  - Skills:       custom (home/claude/.claude/skills/) + third-party (skills-sources.json)
  - Skill listing: settings.json -> skillOverrides, from skills-sources.json .listing
  - ~/.claude.json: keys declared in home/claude/.claude/reconcile/claude-json.json
  - Stale /mcp toggles in ~/.claude.json projects[].disabledMcpServers

Flags:
  -n, --dry-run       show what would change without applying
  -i, --interactive   confirm each category of removals before doing them
  -h, --help          this message
EOF
      exit 0
      ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# --- helpers -------------------------------------------------------------

step() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# confirm_remove <category-label> "<item1>" ["<item2>" ...]
# In strict (non-interactive) mode: returns 0 (proceed silently).
# In interactive mode: prints items, prompts y/N. Returns 0 if confirmed.
confirm_remove() {
  local label="$1"; shift
  local count=$#
  if [ "$INTERACTIVE" -ne 1 ]; then
    return 0
  fi
  printf '    %s to remove (%d):\n' "$label" "$count"
  printf '      - %s\n' "$@"
  local ans=""
  if [ -t 0 ]; then
    read -r -p "    Remove these ${count} ${label}? [y/N]: " ans
  else
    note "non-interactive stdin; defaulting to skip"
    return 1
  fi
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) note "skipped (drift accumulating)"; return 1 ;;
  esac
}

require() {
  local missing=()
  for c in "$@"; do
    command -v "$c" >/dev/null || missing+=("$c")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "missing required commands: ${missing[*]}" >&2
    exit 1
  fi
}

# --- preflight -----------------------------------------------------------

require jq git claude envsubst realpath

[ -d "$RECONCILE_DIR" ] || { echo "reconcile dir not found: $RECONCILE_DIR" >&2; exit 1; }
[ -f "$SETTINGS_JSON" ] || { echo "settings.json not found: $SETTINGS_JSON" >&2; exit 1; }
[ -f "$CLAUDE_JSON" ]   || { echo "~/.claude.json not found"             >&2; exit 1; }

mkdir -p "$SKILLS_DIR" "$SKILLS_SOURCES_DIR" "$PLUGINS_DIR"

# --- 1. Marketplaces -----------------------------------------------------

step "Marketplaces"
desired_markets=$(jq -r 'keys[]' "$RECONCILE_DIR/marketplaces.json")
current_markets=""
[ -f "$KNOWN_MARKETS" ] && current_markets=$(jq -r 'keys[]' "$KNOWN_MARKETS" 2>/dev/null || true)

for m in $desired_markets; do
  if printf '%s\n' "$current_markets" | grep -qx "$m"; then
    note "ok: $m"
  else
    repo=$(jq -r --arg m "$m" '.[$m].repo' "$RECONCILE_DIR/marketplaces.json")
    note "+ add: $m  ($repo)"
    run claude plugin marketplace add "$repo"
  fi
done

markets_to_remove=()
for m in $current_markets; do
  printf '%s\n' "$desired_markets" | grep -qx "$m" || markets_to_remove+=("$m")
done
if [ ${#markets_to_remove[@]} -gt 0 ]; then
  if confirm_remove "marketplaces" "${markets_to_remove[@]}"; then
    for m in "${markets_to_remove[@]}"; do
      note "- remove: $m"
      run claude plugin marketplace remove "$m"
    done
  fi
fi

# --- 2. Plugins ----------------------------------------------------------

step "Plugins"
# Source of truth: settings.json -> enabledPlugins.
# value = true  -> install + enable
# value = false -> install + leave disabled (NOT removed)
# absent        -> uninstall
desired_kept=$(jq -r '.enabledPlugins // {} | keys[]' "$SETTINGS_JSON")
desired_enabled=$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true)  | .key' "$SETTINGS_JSON")

installed_user_plugins=""
if [ -f "$INSTALLED_PLUGINS" ]; then
  installed_user_plugins=$(jq -r '
    .plugins // {} | to_entries[]
    | .key as $name | .value[]
    | select(.scope == "user")
    | $name' "$INSTALLED_PLUGINS" 2>/dev/null | sort -u || true)
fi

for p in $desired_enabled; do
  if printf '%s\n' "$installed_user_plugins" | grep -qx "$p"; then
    note "ok: $p"
  else
    note "+ install: $p"
    run claude plugin install "$p"
  fi
done

plugins_to_remove=()
for p in $installed_user_plugins; do
  printf '%s\n' "$desired_kept" | grep -qx "$p" || plugins_to_remove+=("$p")
done
if [ ${#plugins_to_remove[@]} -gt 0 ]; then
  if confirm_remove "plugins" "${plugins_to_remove[@]}"; then
    for p in "${plugins_to_remove[@]}"; do
      note "- uninstall: $p"
      run claude plugin uninstall "$p" --scope user -y
    done
  fi
fi

# --- 3. MCP servers ------------------------------------------------------

step "MCP servers"
if [ -f "$SECRETS_FILE" ]; then
  set -a; . "$SECRETS_FILE"; set +a
  note "loaded secrets from $SECRETS_FILE"
else
  note "no secrets file at $SECRETS_FILE"
fi

referenced=$(grep -oE '\$\{[A-Za-z_][A-Za-z_0-9]*\}' "$RECONCILE_DIR/mcp-servers.json" \
             | sed -E 's/\$\{([^}]+)\}/\1/' | sort -u || true)
missing=()
for v in $referenced; do
  if ! env | grep -q "^${v}="; then
    missing+=("$v")
  fi
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: mcp-servers.json references unset variables:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  echo "       define them in $SECRETS_FILE (see reconcile/secrets.env.example) and re-run." >&2
  echo "       skipping MCP reconcile." >&2
else
  rendered=$(envsubst < "$RECONCILE_DIR/mcp-servers.json")
  printf '%s' "$rendered" | jq -e . >/dev/null

  current_mcp=$(jq -cS '.mcpServers // {}' "$CLAUDE_JSON")
  desired_mcp=$(printf '%s' "$rendered" | jq -cS .)

  if [ "$current_mcp" = "$desired_mcp" ]; then
    note "ok: mcpServers in sync"
  else
    # Determine if this update is purely additive (existing keys preserved) or
    # destructive (any current key dropped). Only the destructive case prompts.
    current_keys=$(printf '%s' "$current_mcp" | jq -r 'keys[]')
    desired_keys=$(printf '%s' "$desired_mcp" | jq -r 'keys[]')
    dropped=()
    for k in $current_keys; do
      printf '%s\n' "$desired_keys" | grep -qx "$k" || dropped+=("$k")
    done
    do_update=1
    if [ ${#dropped[@]} -gt 0 ]; then
      confirm_remove "MCP servers" "${dropped[@]}" || do_update=0
    fi
    if [ "$do_update" -eq 1 ]; then
      note "~ update mcpServers in $CLAUDE_JSON"
      if [ "$DRY_RUN" -eq 0 ]; then
        tmp=$(mktemp)
        jq --argjson new "$desired_mcp" '.mcpServers = $new' "$CLAUDE_JSON" > "$tmp"
        mv "$tmp" "$CLAUDE_JSON"
      fi
    fi
  fi
fi

# --- 4. Third-party skill clones -----------------------------------------

step "Third-party skill clones"
desired_sources=$(jq -r '.sources | keys[]' "$RECONCILE_DIR/skills-sources.json")

while IFS=$'\t' read -r name url ref; do
  dest="$SKILLS_SOURCES_DIR/$name"
  if [ ! -d "$dest/.git" ]; then
    note "+ clone: $name <- $url"
    run git clone --quiet "$url" "$dest"
  fi
  if [ -d "$dest/.git" ]; then
    current_ref=$(git -C "$dest" rev-parse HEAD 2>/dev/null || echo "(none)")
    if [ "$current_ref" != "$ref" ]; then
      note "~ checkout: $name -> ${ref:0:12}"
      run git -C "$dest" fetch --quiet origin
      run git -C "$dest" checkout --quiet "$ref"
    else
      note "ok: $name @ ${ref:0:12}"
    fi
  fi
done < <(jq -r '.sources | to_entries[] | [.key, .value.url, .value.ref] | @tsv' "$RECONCILE_DIR/skills-sources.json")

sources_to_remove=()
for top in "$SKILLS_SOURCES_DIR"/*; do
  [ -e "$top" ] || continue
  name=$(basename "$top")
  printf '%s\n' "$desired_sources" | grep -qx "$name" || sources_to_remove+=("$name")
done
if [ ${#sources_to_remove[@]} -gt 0 ]; then
  if confirm_remove "skill clones" "${sources_to_remove[@]}"; then
    for n in "${sources_to_remove[@]}"; do
      note "- remove: $n"
      run rm -rf "$SKILLS_SOURCES_DIR/$n"
    done
  fi
fi

# --- 5. Skills (custom + third-party symlinks) ---------------------------

step "Skill links"
custom_skills=()
if [ -d "$CUSTOM_SKILLS_DIR" ]; then
  for s in "$CUSTOM_SKILLS_DIR"/*/; do
    [ -d "$s" ] || continue
    custom_skills+=("$(basename "$s")")
  done
fi

third_party_skills=$(jq -r '.skills | keys[]' "$RECONCILE_DIR/skills-sources.json")

for s in "${custom_skills[@]:-}"; do
  [ -n "$s" ] || continue
  link="$SKILLS_DIR/$s"
  target="$CUSTOM_SKILLS_DIR/$s"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    note "ok: $s (custom)"
  else
    note "+ link: $s -> $target"
    run rm -rf "$link"
    run ln -sfn "$target" "$link"
  fi
done

while IFS=$'\t' read -r name source path; do
  link="$SKILLS_DIR/$name"
  if [ "$path" = "." ]; then
    target="$SKILLS_SOURCES_DIR/$source"
  else
    target="$SKILLS_SOURCES_DIR/$source/$path"
  fi
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    note "ok: $name (third-party)"
  else
    note "+ link: $name -> $target"
    run rm -rf "$link"
    run ln -sfn "$target" "$link"
  fi
done < <(jq -r '.skills | to_entries[] | [.key, .value.source, .value.path] | @tsv' "$RECONCILE_DIR/skills-sources.json")

desired_skills=$(printf '%s\n' "${custom_skills[@]:-}" $third_party_skills | sed '/^$/d' | sort -u)
# Entries Claude Code itself owns in ~/.claude/skills/ (skills-sources.json
# "managed"), e.g. `synced` — its claude.ai skill-sync bucket. Never pruned,
# and never a listing override: they are not single skills.
managed_skills=$(jq -r '.managed // [] | .[]' "$RECONCILE_DIR/skills-sources.json")
skills_to_remove=()
for s in "$SKILLS_DIR"/*; do
  [ -e "$s" ] || [ -L "$s" ] || continue
  name=$(basename "$s")
  printf '%s\n' "$desired_skills" $managed_skills | grep -qx "$name" || skills_to_remove+=("$name")
done
if [ ${#skills_to_remove[@]} -gt 0 ]; then
  if confirm_remove "skill links" "${skills_to_remove[@]}"; then
    for n in "${skills_to_remove[@]}"; do
      note "- remove: $n"
      run rm -rf "$SKILLS_DIR/$n"
    done
  fi
fi

# --- 6. Skill listing overrides ------------------------------------------
# Skills we install are hidden from the model's listing by default (still
# typable as /name). settings.json -> skillOverrides is derived, so a newly
# added skill is opted out without touching settings by hand. Plugin-provided
# skills ignore skillOverrides entirely; gate those via enabledPlugins.

step "Skill listing overrides"
listing_default=$(jq -r '.listing.default // "user-invocable-only"' "$RECONCILE_DIR/skills-sources.json")
desired_overrides=$(printf '%s\n' "$desired_skills" | jq -R . | jq -s \
  --arg def "$listing_default" \
  --argjson ov "$(jq -c '.listing.overrides // {}' "$RECONCILE_DIR/skills-sources.json")" \
  'map({key: ., value: ($ov[.] // $def)}) | from_entries | with_entries(select(.value != "on"))')
current_overrides=$(jq -cS '.skillOverrides // {}' "$SETTINGS_JSON")

if [ "$current_overrides" = "$(printf '%s' "$desired_overrides" | jq -cS .)" ]; then
  note "ok: skillOverrides in sync"
else
  note "~ update skillOverrides in $SETTINGS_JSON (default: $listing_default)"
  printf '%s' "$desired_overrides" | jq -r 'to_entries[] | "      \(.key) = \(.value)"'
  if [ "$DRY_RUN" -eq 0 ]; then
    tmp=$(mktemp)
    jq --argjson new "$desired_overrides" '.skillOverrides = $new' "$SETTINGS_JSON" > "$tmp"
    cat "$tmp" > "$SETTINGS_JSON"   # write through the stow symlink
    rm -f "$tmp"
  fi
fi

# --- 7. ~/.claude.json preferences ---------------------------------------
# Some toggles have no settings.json key and live only in ~/.claude.json.
# Enforce just the keys declared in claude-json.json; the rest is runtime state.

step "~/.claude.json preferences"
desired_prefs=$(jq -cS . "$RECONCILE_DIR/claude-json.json")
current_prefs=$(jq -cS --argjson d "$desired_prefs" 'with_entries(select(.key | IN($d | keys[])))' "$CLAUDE_JSON")
if [ "$current_prefs" = "$desired_prefs" ]; then
  note "ok: preferences in sync"
else
  note "~ set: $(printf '%s' "$desired_prefs" | jq -r 'to_entries | map("\(.key)=\(.value)") | join(" ")')"
  if [ "$DRY_RUN" -eq 0 ]; then
    tmp=$(mktemp)
    jq --argjson d "$desired_prefs" '. + $d' "$CLAUDE_JSON" > "$tmp"
    mv "$tmp" "$CLAUDE_JSON"
  fi
fi

# --- 8. Per-project disabled MCP lists -----------------------------------
# /mcp toggles land in ~/.claude.json -> projects[].disabledMcpServers and
# outlive the server. Drop names for plugins no longer enabled and standalone
# servers no longer declared. claude.ai connectors can't be checked offline;
# block one everywhere with settings.json -> deniedMcpServers instead.

step "Disabled MCP lists"
stale_disabled=$(jq -r \
  --argjson plugins "$(jq -c '[.enabledPlugins // {} | keys[] | split("@")[0]]' "$SETTINGS_JSON")" \
  --argjson servers "$(jq -c '[.mcpServers // {} | keys[]]' "$CLAUDE_JSON")" '
  def stale: if startswith("plugin:") then (split(":")[1] | IN($plugins[]) | not)
             elif startswith("claude.ai ") then false
             else (IN($servers[]) | not) end;
  [.projects // {} | .[] | .disabledMcpServers // [] | .[] | select(stale)] | unique[]' "$CLAUDE_JSON")

if [ -z "$stale_disabled" ]; then
  note "ok: no stale entries"
else
  printf '      - %s\n' $stale_disabled
  if [ "$DRY_RUN" -eq 0 ]; then
    tmp=$(mktemp)
    jq --argjson stale "$(printf '%s\n' "$stale_disabled" | jq -R . | jq -s .)" '
      .projects |= map_values(if .disabledMcpServers then
        .disabledMcpServers |= map(select(IN($stale[]) | not)) else . end)' "$CLAUDE_JSON" > "$tmp"
    mv "$tmp" "$CLAUDE_JSON"
  fi
fi

step "Done."
