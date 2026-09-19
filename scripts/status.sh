#!/usr/bin/env bash
# status.sh: read-only report of stow / system / service / package state.
# Never modifies anything. Lists come from lib.sh, so this cannot drift out of
# step with what converge.sh actually installs.
#
#   status.sh           the report, for a terminal
#   status.sh --json    the same checks as one JSON array, for the `dotfiles` command
#
# Every check goes through `row`, so the two forms cannot disagree. A record is
# {section, name, state, level, detail}, where level says who acts on it:
#   ok      nothing to do
#   warn    `dotfiles sync` would change it
#   manual  sync will not fix it; a human has to (reboot, .pacnew, a rebuild)
#   info    context, not a problem

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib.sh"

JSON=0
[ "${1:-}" = --json ] && JSON=1

YELLOW=$'\033[33m'
RESET=$'\033[0m'
[ "$JSON" = 1 ] && { YELLOW=; RESET=; }

RECORDS=""
if [ "$JSON" = 1 ]; then
  RECORDS="$(mktemp -t status-json.XXXXXX)"
  trap 'rm -f "$RECORDS"' EXIT
fi

# heading TEXT: a section title, text mode only.
heading() { [ "$JSON" = 1 ] || echo "$1"; }
blank()   { [ "$JSON" = 1 ] || echo; }

# row SECTION NAME STATE LEVEL TEXT [DETAIL]
# TEXT is the exact line the terminal report prints; STATE and DETAIL are what
# the JSON carries instead.
row() {
  if [ "$JSON" = 1 ]; then
    jq -nc --arg section "$1" --arg name "$2" --arg state "$3" --arg level "$4" \
      --arg detail "${6:-}" \
      '{$section, $name, $state, $level} + (if $detail == "" then {} else {$detail} end)' \
      >> "$RECORDS"
  else
    printf '%s\n' "$5"
  fi
}

heading "Stow packages:"
for pkg in "${STOW_PACKAGES[@]}"; do
  if pkg_is_stowed "$pkg"; then
    row stow "$pkg" stowed ok "  $pkg: stowed"
  else
    row stow "$pkg" "not stowed" warn "  $pkg: not stowed"
  fi
done
# A package counts as stowed once any one file is linked, so a file added to it
# since the last sync stays invisible above. stow's own dry run names each link
# it would still make. "../../dotfiles/home/<pkg>/<path>" is where the package comes from.
if have stow; then
  while IFS= read -r line; do
    case "$line" in
      "LINK: "*)
        dst="${line#LINK: }"; dst="${dst%% => *}"
        src="${line##* => }"; src="${src#"${src%%[!./]*}"}"; src="${src#*/home/}"
        row stow "~/$dst" "not linked" warn "  ~/$dst: not linked" "${src%%/*}"
        ;;
      *"cannot stow"*|*"existing target"*)
        row stow conflict "$line" warn "  ${line#"${line%%[! ]*}"}"
        ;;
    esac
  done < <(stow --no-folding -n -v -d "$STOW_DIR" -t "$HOME" "${STOW_PACKAGES[@]}" 2>&1 || true)
fi

blank
heading "System configs (symlinked):"
for pair in "${SYSTEM_LINKS[@]}"; do
  dst="${pair##*:}"
  if [ -L "$dst" ]; then row system-link "$dst" linked ok "  $dst: linked"
  elif [ -e "$dst" ]; then row system-link "$dst" "exists (not linked)" warn "  $dst: exists (not linked)"
  else row system-link "$dst" missing warn "  $dst: missing"
  fi
done

heading "System configs (copied):"
for pair in "${SYSTEM_COPIES[@]}"; do
  src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
  if [ -L "$dst" ]; then
    row system-copy "$dst" "symlink, not a copy" warn \
      "$(printf '  %s: %ssymlink, not a copy%s' "$dst" "$YELLOW" "$RESET")"
  elif [ ! -f "$dst" ]; then
    row system-copy "$dst" missing warn "  $dst: missing"
  elif cmp -s "$src" "$dst"; then
    row system-copy "$dst" synced ok "  $dst: synced"
  else
    row system-copy "$dst" "out of sync" warn \
      "$(printf '  %s: %sout of sync%s' "$dst" "$YELLOW" "$RESET")"
  fi
done

blank
heading "Services:"
for svc in keyd sshfs-conway restic-backup.timer wallhelper-fetch.timer \
           battery-logd.service; do
  case "$svc" in
    keyd) active="$(systemctl is-active "$svc" 2>/dev/null || true)" ;;
    *)    active="$(systemctl --user is-active "$svc" 2>/dev/null || true)" ;;
  esac
  if [ "$active" = active ]; then row services "$svc" active ok "  $svc: active"
  else row services "$svc" inactive warn "  $svc: inactive"
  fi
done

blank
heading "Own projects:"
# Both are installed system-wide from a *-git package built out of a repo you
# also edit, so the question this answers is "is what's running what I wrote?".
# It reports rather than rebuilds: a rebuild is minutes of cargo and a sudo
# prompt, which is not something `dotfiles` status should spring on you. The fix
# for stale is `paru -Sua --devel`, once the commits are pushed.
for project in "wallhelper-git:$HOME/projects/wallhelper" "reel-git:$HOME/projects/reel"; do
  pkg="${project%%:*}"; dir="${project##*:}"
  version="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || true)"
  if [ ! -d "$dir/.git" ]; then
    row projects "$pkg" "${version:-not installed}" info \
      "  $pkg: ${version:-not installed}, no checkout at ${dir/#$HOME/\~}" "no checkout"
    continue
  fi
  head="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || true)"

  # Anything the package cannot contain yet, in the order it stops mattering:
  # uncommitted first, because that is the one `make run` already covers.
  notes=""
  [ -n "$(git -C "$dir" status --porcelain 2>/dev/null || true)" ] &&
    notes="uncommitted changes"
  ahead="$(git -C "$dir" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  [ "${ahead:-0}" != 0 ] && notes="${notes:+$notes, }$ahead unpushed"
  note="${notes:+ ($notes)}"

  if [ -z "$version" ]; then
    row projects "$pkg" "not installed" manual \
      "$(printf '  %s: %snot installed%s, HEAD %s' "$pkg" "$YELLOW" "$RESET" "$head")" "HEAD $head"
  else
    case "$version" in
      *g"$head"*) row projects "$pkg" current ok "  $pkg: $version$note" "$version$note" ;;
      *) row projects "$pkg" stale manual \
           "$(printf '  %s: %sstale%s — installed %s, HEAD %s%s' \
              "$pkg" "$YELLOW" "$RESET" "$version" "$head" "$note")" \
           "installed $version, HEAD $head$note; fix: paru -Sua --devel" ;;
    esac
  fi
done

heading "Audio:"
# Catches the silent-speaker failure whose whole problem is that every other
# readout (waybar, wpctl, the OSD) still looks fine. See bin/.local/bin/audio-health.
if have audio-health; then
  rc=0
  out="$(audio-health --check 2>&1)" || rc=$?
  level=ok; [ "$rc" = 0 ] || level=manual
  while IFS= read -r line; do
    line="${line#audio-health: }"
    row audio audio-health "$([ "$rc" = 0 ] && echo healthy || echo unhealthy)" "$level" \
      "  $line" "$line"
  done <<<"$out"
else
  row audio audio-health "not stowed" warn "  audio-health: not stowed"
fi

blank
heading "Packages:"
pkg_status="$(DOTFILES="$DOTFILES" bash "$DOTFILES/scripts/packages.sh" --status)"
if [ "$JSON" = 1 ]; then
  # packages.sh's own format: "[backend] in sync", or "[backend]" followed by
  # "  + name" (installed, not in the manifest) and "  - name" (the reverse).
  backend=""
  while IFS= read -r line; do
    case "$line" in
      "["*"] in sync")   b="${line%%]*}"; row packages "${b#[}" "in sync" ok "" ;;
      "["*"] ("*)        b="${line%%]*}"; row packages "${b#[}" "not installed" info "" ;;
      "["*"]")           backend="${line#[}"; backend="${backend%]}" ;;
      "  + "*)           row packages "$backend" untracked warn "" "${line#  + }" ;;
      "  - "*)           row packages "$backend" missing warn "" "${line#  - }" ;;
    esac
  done <<<"$pkg_status"
else
  printf '%s\n' "$pkg_status" | sed 's/^/  /'
fi

# --- maintenance ----------------------------------------------------------
# State that stays invisible until it bites: a kernel upgrade that needs a
# reboot, a cache quietly eating tens of GB, orphans, and .pacnew files
# shadowing configs. Every command here is read-only and needs no sudo.
if [ "$DISTRO_FAMILY" = arch ]; then
  blank
  heading "Maintenance:"
  fmt_row() { printf '  %-18s %s' "$1" "$2"; }

  # sync's own gate is 24h; a week is when not having synced starts to matter.
  age="$(upgrade_age)"
  if [ -z "$age" ]; then
    row maintenance "last upgrade" unknown info "$(fmt_row "last upgrade:" "unknown")"
  elif [ "$age" -ge 604800 ]; then
    row maintenance "last upgrade" "$(fmt_age "$age") ago" warn \
      "$(fmt_row "last upgrade:" "${YELLOW}$(fmt_age "$age") ago${RESET}")"
  else
    row maintenance "last upgrade" "$(fmt_age "$age") ago" ok \
      "$(fmt_row "last upgrade:" "$(fmt_age "$age") ago")"
  fi

  if have checkupdates; then
    rc=0
    pending="$(checkupdates 2>/dev/null)" || rc=$?
    n_pending="$(printf '%s' "$pending" | grep -c . || true)"
    # Here-string, not a pipe: `grep -q` SIGPIPEs its producer, which trips
    # `set -o pipefail`.
    kernel_note=""
    grep -qE '^linux ' <<<"$pending" && kernel_note=" (includes kernel)"
    # checkupdates exits 1 on a failed database sync (offline) and 2 for "none".
    if [ "$rc" = 1 ]; then
      row maintenance "pending updates" unknown info "$(fmt_row "pending updates:" "$n_pending$kernel_note")" \
        "could not reach the mirrors"
    else
      row maintenance "pending updates" "$n_pending" info "$(fmt_row "pending updates:" "$n_pending$kernel_note")" \
        "${pending:+$(awk '{print $1}' <<<"$pending" | paste -sd' ')}"
    fi
  else
    row maintenance "pending updates" unknown info \
      "$(fmt_row "pending updates:" "unknown — pacman-contrib not installed")"
  fi

  # Two different questions, and the module-directory test only answers the
  # second one:
  #   1. is a newer kernel installed than the one running?  -> reboot pending
  #   2. can the running kernel still load modules at all?  -> reboot NOW
  #
  # This used to test (2) alone, which on a host with kernel-modules-hook
  # installed can never fire: the hook restores the running kernel's module
  # tree after every upgrade, exactly so (2) stays false. The line then read
  # "no" while sitting two kernel versions behind.
  #
  # uname reports 7.2.2-arch1-1 where pacman says 7.2.2.arch1-1, hence the sed.
  running="$(uname -r)"
  installed="$(pacman -Q linux 2>/dev/null | awk '{print $2}' | sed 's/\.arch/-arch/')"
  if [ ! -d "/usr/lib/modules/$running" ]; then
    row maintenance "reboot required" yes manual \
      "$(fmt_row "reboot required:" "${YELLOW}yes — running kernel's modules are gone${RESET}")" \
      "running kernel's modules are gone"
  elif [ -n "$installed" ] && [ "$installed" != "$running" ]; then
    row maintenance "reboot required" yes manual \
      "$(fmt_row "reboot required:" "${YELLOW}yes — running $running, installed $installed${RESET}")" \
      "running $running, installed $installed"
  else
    row maintenance "reboot required" no ok "$(fmt_row "reboot required:" "no")"
  fi

  cache="$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1 || true)"
  if have paccache; then
    # paccache prints "no candidate packages found for pruning" instead of a
    # size when there is nothing to reclaim, so fall back to "none".
    saved() {
      local out
      out="$(paccache -d "$@" 2>&1 | grep -oE 'disk space saved: [0-9.]+ [KMG]iB' || true)"
      printf '%s' "${out#*saved: }"
    }
    old="$(saved)"; gone="$(saved -uk0)"
    row maintenance "pacman cache" "${cache:-?}" info \
      "$(fmt_row "pacman cache:" "${cache:-?} (reclaimable: ${old:-none} old, ${gone:-none} removed)")" \
      "reclaimable: ${old:-none} old, ${gone:-none} removed"
  else
    row maintenance "pacman cache" "${cache:-?}" info "$(fmt_row "pacman cache:" "${cache:-?}")"
  fi

  orphans="$(pacman -Qtdq 2>/dev/null || true)"
  n_orph="$(printf '%s' "$orphans" | grep -c . || true)"
  if [ "$n_orph" -gt 0 ]; then
    orph_size="$(printf '%s\n' "$orphans" | xargs -r pacman -Qi 2>/dev/null |
      awk -F': +' '/Installed Size/{v=$2; sub(/ .*/,"",v); u=$2;
        if(u~/KiB/)v/=1024; else if(u~/GiB/)v*=1024; s+=v} END{printf "%.0f MiB", s}')"
    row maintenance orphans "$n_orph" info \
      "$(fmt_row "orphans:" "$n_orph ($orph_size) — review before removing, -bin pkgs underdeclare deps")" \
      "$(paste -sd' ' <<<"$orphans")"
  else
    row maintenance orphans 0 ok "$(fmt_row "orphans:" "0")"
  fi

  pacnew="$(find /etc -name '*.pacnew' -o -name '*.pacsave' 2>/dev/null || true)"
  n_pacnew="$(printf '%s' "$pacnew" | grep -c . || true)"
  row maintenance ".pacnew/.pacsave" "$n_pacnew" "$([ "$n_pacnew" -gt 0 ] && echo manual || echo ok)" \
    "$(fmt_row ".pacnew/.pacsave:" "$n_pacnew")" "$(paste -sd' ' <<<"$pacnew")"
  # `if` (not `&&`) so a zero count — the clean state — doesn't become the
  # script's non-zero exit status under `set -e`.
  if [ "$n_pacnew" -gt 0 ] && [ "$JSON" = 0 ]; then printf '%s\n' "$pacnew" | sed 's/^/      /'; fi
fi

if [ "$JSON" = 1 ]; then
  jq -s . "$RECORDS"
fi
