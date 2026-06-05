#!/usr/bin/env -S uv run --quiet
# /// script
# requires-python = ">=3.10"
# dependencies = ["textual>=0.50"]
# ///
"""Interactive package browser for the dotfiles package lists.

Shows every installed and tracked package across arch/ubuntu/cargo/npm/uv.
Per-host columns reflect tag syntax in the list files:
  firefox                       everywhere
  blender @omnibook             only omnibook
  nvidia-beta-dkms @host1,host2 only those
  ruby !mililab                 everywhere except mililab

Keys
  hjkl / ↑↓←→  navigate cells
  ctrl-d/u     half-page down/up
  g / G        jump to top / bottom of table
  ] / [        next / previous backend tab
  space        toggle current cell (host column or U column)
  u            toggle uninstall mark for current row
  a            apply: write list files, then run uninstall commands
  /            filter rows
  q            quit

Package names are dimmed when the package is tracked but not installed
on this host. The pane at the bottom shows the description of the row
under the cursor (fetched lazily, cached).
"""
# pyright: reportMissingImports=false
# textual is fetched at runtime via PEP 723 metadata; not in system Python.
from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal
from textual.coordinate import Coordinate
from textual.screen import ModalScreen
from textual.widgets import (
    Button,
    DataTable,
    Footer,
    Header,
    Input,
    Label,
    Static,
    TabbedContent,
    TabPane,
)

# --- Paths and host detection ---------------------------------------------

DOTFILES = Path(os.environ.get("DOTFILES", Path(__file__).resolve().parent.parent))
PKGDIR = DOTFILES / "packages"
COMMON = PKGDIR / "common.txt"
ESSENTIAL = PKGDIR / "essential.txt"
PINNED = PKGDIR / "pinned.txt"
HOSTS_DIR = DOTFILES / "hosts"
CURRENT_HOST = socket.gethostname()

BACKEND_TOOL = {
    "arch": "pacman",
    "ubuntu": "apt-get",
    "cargo": "cargo",
    "npm": "npm",
    "uv": "uv",
}


def have(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def detect_backends() -> list[str]:
    if have("pacman"):
        primary = ["arch"]
    elif have("apt-get"):
        primary = ["ubuntu"]
    else:
        primary = []
    return primary + [b for b in ("cargo", "npm", "uv") if have(b)]


def known_hosts() -> list[str]:
    hosts: set[str] = {CURRENT_HOST}
    if HOSTS_DIR.exists():
        hosts.update(p.stem for p in HOSTS_DIR.glob("*.mk"))
    return sorted(hosts)


def load_essential() -> set[str]:
    """Names listed in packages/essential.txt — system-critical across backends."""
    if not ESSENTIAL.exists():
        return set()
    out: set[str] = set()
    for line in ESSENTIAL.read_text().splitlines():
        s = line.strip()
        if s and not s.startswith("#"):
            out.add(s.split()[0])
    return out


def load_pinned() -> set[str]:
    """Names listed in packages/pinned.txt — soft-warned on uninstall."""
    if not PINNED.exists():
        return set()
    out: set[str] = set()
    for line in PINNED.read_text().splitlines():
        s = line.strip()
        if s and not s.startswith("#"):
            out.add(s.split()[0])
    return out


def save_pinned(names: set[str]) -> None:
    """Rewrite packages/pinned.txt, preserving the file's header comments."""
    header: list[str] = []
    if PINNED.exists():
        for ln in PINNED.read_text().splitlines():
            stripped = ln.strip()
            if not stripped or stripped.startswith("#"):
                header.append(ln)
            else:
                break
        while header and not header[-1].strip():
            header.pop()
    body = sorted(names)
    out = list(header) + [""] + body
    PINNED.write_text("\n".join(out) + ("\n" if body else ""))


# --- Backend operations ---------------------------------------------------


def run(cmd: list[str]) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, check=False).stdout
    except FileNotFoundError:
        return ""


def list_installed(backend: str) -> set[str]:
    match backend:
        case "arch":
            native = run(["pacman", "-Qqen"]).split()
            foreign = [p for p in run(["pacman", "-Qqem"]).split() if not p.endswith("-debug")]
            return set(native) | set(foreign)
        case "ubuntu":
            return set(run(["apt-mark", "showmanual"]).split())
        case "cargo":
            out = run(["cargo", "install", "--list"]).splitlines()
            return {line.split()[0] for line in out if line and not line.startswith(" ")}
        case "npm":
            try:
                data = json.loads(run(["npm", "ls", "-g", "--depth=0", "--json"]) or "{}")
                names = set((data.get("dependencies") or {}).keys()) - {"npm", "corepack"}
            except json.JSONDecodeError:
                return set()
            # Filter out npm packages owned by pacman — arch's tree-sitter-cli
            # installs an npm module under /usr/lib/node_modules as a side
            # effect, and we don't want to double-track it.
            prefix = npm_root()
            if prefix and have("pacman"):
                names = {
                    n for n in names
                    if subprocess.run(
                        ["pacman", "-Qo", f"{prefix}/{n}"],
                        capture_output=True,
                    ).returncode != 0
                }
            return names
        case "uv":
            out = run(["uv", "tool", "list"]).splitlines()
            return {line.split()[0] for line in out if line and line[0].isalpha()}
    return set()


def file_for(backend: str) -> Path:
    return PKGDIR / f"{backend}.txt"


_NPM_ROOT: str | None = None


def npm_root() -> str:
    global _NPM_ROOT
    if _NPM_ROOT is None:
        _NPM_ROOT = run(["npm", "root", "-g"]).strip()
    return _NPM_ROOT


def batch_fetch_descriptions(backend: str, pkgs: list[str]) -> dict[str, str]:
    """One subprocess call (or single sweep) that returns {pkg: description}
    for as many of `pkgs` as we can. Used to prime the description cache so
    cursor movement stays instant."""
    if not pkgs:
        return {}
    result: dict[str, str] = {}
    match backend:
        case "arch":
            # `pacman -Qi <pkg ...>` reads the local DB (works for repo + AUR
            # once installed). Fast even with 200+ args.
            out = run(["pacman", "-Qi", *pkgs])
            current = None
            for line in out.splitlines():
                if line.startswith("Name") and ":" in line:
                    current = line.split(":", 1)[1].strip()
                elif line.startswith("Description") and ":" in line and current:
                    result[current] = line.split(":", 1)[1].strip()
                    current = None
        case "ubuntu":
            out = run(["apt-cache", "show", *pkgs])
            current = None
            for line in out.splitlines():
                if line.startswith("Package:"):
                    current = line.split(":", 1)[1].strip()
                elif (
                    line.startswith("Description-en:") or line.startswith("Description:")
                ) and current:
                    result[current] = line.split(":", 1)[1].strip()
                    current = None
        case "npm":
            root = npm_root()
            if root:
                for pkg in pkgs:
                    pkg_json = Path(root) / pkg / "package.json"
                    if not pkg_json.exists():
                        continue
                    try:
                        desc = json.loads(pkg_json.read_text()).get("description", "")
                        if desc:
                            result[pkg] = desc
                    except (json.JSONDecodeError, OSError):
                        pass
        case "cargo" | "uv":
            pass  # no offline source for these; descriptions left blank
    return result


def uninstall_cmd(backend: str, pkgs: list[str]) -> list[str]:
    match backend:
        case "arch":
            return ["sudo", "paru", "-Rns", "--noconfirm", *pkgs]
        case "ubuntu":
            return ["sudo", "apt-get", "remove", "-y", *pkgs]
        case "cargo":
            return ["cargo", "uninstall", *pkgs]
        case "npm":
            return ["npm", "uninstall", "-g", *pkgs]
        case "uv":
            return ["uv", "tool", "uninstall", *pkgs]
    return []


# --- File parsing with tags -----------------------------------------------


@dataclass(frozen=True)
class FileEntry:
    pkg: str
    hosts: frozenset[str]  # always subset of all_hosts when fully parsed


def parse_line(line: str, all_hosts: frozenset[str]) -> FileEntry | None:
    line = line.strip()
    if not line or line.startswith("#"):
        return None
    parts = line.split(maxsplit=1)
    pkg = parts[0]
    if len(parts) == 1:
        return FileEntry(pkg, all_hosts)
    tag = parts[1].strip()
    if tag.startswith("@"):
        wanted = {h.strip() for h in tag[1:].split(",") if h.strip()}
        return FileEntry(pkg, frozenset(wanted) & all_hosts)
    if tag.startswith("!"):
        excluded = {h.strip() for h in tag[1:].split(",") if h.strip()}
        return FileEntry(pkg, all_hosts - frozenset(excluded))
    return FileEntry(pkg, all_hosts)


def format_entry(pkg: str, hosts: set[str], all_hosts: frozenset[str]) -> str:
    if frozenset(hosts) == all_hosts:
        return pkg
    excluded = all_hosts - hosts
    if len(hosts) <= len(excluded):
        return f"{pkg} @{','.join(sorted(hosts))}"
    return f"{pkg} !{','.join(sorted(excluded))}"


def read_entries(backend: str, all_hosts: frozenset[str]) -> dict[str, FileEntry]:
    """Returns {pkg: FileEntry} across the per-backend file + common.txt."""
    files = [file_for(backend)]
    if backend in ("arch", "ubuntu"):
        files.append(COMMON)
    entries: dict[str, FileEntry] = {}
    for f in files:
        if not f.exists():
            continue
        for line in f.read_text().splitlines():
            entry = parse_line(line, all_hosts)
            if entry is None:
                continue
            # If same pkg appears in both common.txt and per-distro file, union the hosts.
            existing = entries.get(entry.pkg)
            if existing:
                entries[entry.pkg] = FileEntry(entry.pkg, existing.hosts | entry.hosts)
            else:
                entries[entry.pkg] = entry
    return entries


def write_backend(backend: str, rows: list[Row], all_hosts: frozenset[str]) -> None:
    """Rewrite the per-backend file from Row state. Preserves header comments
    in the original file. common.txt is left untouched: entries that lived
    there are now written to the per-backend file, and the user can re-dedup."""
    file = file_for(backend)
    # Preserve top-of-file comments and blank lines (header).
    header: list[str] = []
    if file.exists():
        for ln in file.read_text().splitlines():
            stripped = ln.strip()
            if not stripped or stripped.startswith("#"):
                header.append(ln)
            else:
                break
        # Strip trailing blank lines from header
        while header and not header[-1].strip():
            header.pop()
    out_lines = list(header)
    for row in sorted(rows, key=lambda r: r.pkg):
        if not row.hosts:
            continue  # untracked
        out_lines.append(format_entry(row.pkg, row.hosts, all_hosts))
    file.write_text("\n".join(out_lines) + "\n")
    # Strip any entries we just wrote from common.txt so we don't double-track.
    if backend in ("arch", "ubuntu") and COMMON.exists():
        managed = {row.pkg for row in rows}
        keep = []
        for ln in COMMON.read_text().splitlines():
            entry = parse_line(ln, all_hosts)
            if entry is None or entry.pkg not in managed:
                keep.append(ln)
        COMMON.write_text("\n".join(keep) + ("\n" if keep else ""))


# --- Row state ------------------------------------------------------------


@dataclass
class Row:
    pkg: str
    installed: bool
    hosts: set[str] = field(default_factory=set)
    uninstall: bool = False
    essential: bool = False
    pinned: bool = False

    @property
    def tracked(self) -> bool:
        return bool(self.hosts)


# --- DataTable subclass with vim navigation -------------------------------


class VimDataTable(DataTable):
    """DataTable with hjkl + g/G + ctrl-d/u bindings. Arrow keys still work."""

    BINDINGS = [
        Binding("h", "cursor_left", show=False),
        Binding("j", "cursor_down", show=False),
        Binding("k", "cursor_up", show=False),
        Binding("l", "cursor_right", show=False),
        Binding("ctrl+d", "page_down", show=False),
        Binding("ctrl+u", "page_up", show=False),
        Binding("g", "vim_top", show=False),
        Binding("G", "vim_bottom", show=False),
    ]

    def action_vim_top(self) -> None:
        if self.row_count > 0:
            self.move_cursor(row=0)

    def action_vim_bottom(self) -> None:
        if self.row_count > 0:
            self.move_cursor(row=self.row_count - 1)


# --- Confirmation modal ---------------------------------------------------


class ConfirmModal(ModalScreen[bool]):
    CSS = """
    ConfirmModal {
        align: center middle;
    }
    #dialog {
        background: $panel;
        border: thick $accent;
        padding: 1 2;
        width: 70;
        max-height: 80%;
    }
    #buttons { margin-top: 1; align-horizontal: right; }
    Button { margin-left: 1; }
    """

    def __init__(self, summary: str, details: str):
        super().__init__()
        self._summary = summary
        self._details = details

    def compose(self) -> ComposeResult:
        with Container(id="dialog"):
            yield Label(self._summary, classes="summary")
            yield Static(self._details, classes="details")
            with Horizontal(id="buttons"):
                yield Button("Cancel", id="cancel", variant="default")
                yield Button("Confirm", id="confirm", variant="error")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(event.button.id == "confirm")


# --- Main app -------------------------------------------------------------


class PackagesApp(App[str]):
    CSS = """
    Screen { background: $surface; }
    #help { background: $panel; color: $text-muted; padding: 0 1; }
    TabbedContent { height: 1fr; }
    DataTable { height: 1fr; }
    #description {
        background: $panel;
        color: $text;
        padding: 0 1;
        height: 2;
        border-top: solid $accent;
    }
    """

    BINDINGS = [
        Binding("space", "toggle", "Toggle"),
        Binding("u", "uninstall", "Uninstall"),
        Binding("f", "pin", "Pin"),
        Binding("a", "apply", "Apply"),
        # `]`/`[` are priority so they fire even when the DataTable has focus
        # and would otherwise swallow them.
        Binding("]", "next_tab", "Next tab", show=False, priority=True),
        Binding("[", "prev_tab", "Prev tab", show=False, priority=True),
        Binding("/", "filter", "Filter", show=False),
        Binding("escape", "clear_filter", "Clear filter", show=False),
        Binding("q", "quit", "Quit"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.all_hosts: frozenset[str] = frozenset(known_hosts())
        self.host_order: list[str] = sorted(self.all_hosts)
        self.backends: list[str] = [
            b for b in detect_backends() if have(BACKEND_TOOL[b])
        ]
        self.rows_per_backend: dict[str, list[Row]] = {}
        self.tables: dict[str, DataTable] = {}
        self._filter: str = ""
        self._desc_cache: dict[tuple[str, str], str] = {}
        self.essential: set[str] = load_essential()
        self.pinned: set[str] = load_pinned()
        for b in self.backends:
            installed = list_installed(b)
            entries = read_entries(b, self.all_hosts)
            all_pkgs = set(installed) | set(entries.keys())
            rows = []
            for pkg in sorted(all_pkgs):
                entry = entries.get(pkg)
                rows.append(
                    Row(
                        pkg=pkg,
                        installed=pkg in installed,
                        hosts=set(entry.hosts) if entry else set(),
                        essential=pkg in self.essential,
                        pinned=pkg in self.pinned,
                    )
                )
            self.rows_per_backend[b] = rows

    # --- composition ------------------------------------------------------

    def compose(self) -> ComposeResult:
        yield Header(show_clock=False, name="dotfiles packages")
        yield Static(
            "[b]hjkl[/] move  [b]][/]/[b][[/] tabs  [b]space[/] toggle  "
            "[b]u[/] uninstall  [b]f[/] pin  [b]a[/] apply  "
            "[b]/[/] filter  [b]q[/] quit  "
            "[yellow]![/] essential  [magenta]*[/] pinned",
            id="help",
        )
        with TabbedContent(id="tabs"):
            for b in self.backends:
                with TabPane(self._tab_label(b), id=f"tab-{b}"):
                    table = self._build_table(b)
                    self.tables[b] = table
                    yield table
        yield Static("", id="description")
        yield Footer()

    def _tab_label(self, backend: str) -> str:
        rows = self.rows_per_backend[backend]
        return f"{backend} ({len(rows)})"

    def _build_table(self, backend: str) -> DataTable:
        table: DataTable = VimDataTable(cursor_type="cell", zebra_stripes=True)
        table.add_column("Package", key="pkg", width=36)
        for h in self.host_order:
            label = f"*{h}" if h == CURRENT_HOST else h
            table.add_column(label, key=f"host-{h}", width=max(len(label) + 1, 5))
        table.add_column("U", key="uninstall", width=2)
        for i, row in enumerate(self.rows_per_backend[backend]):
            table.add_row(*self._render_row(row), key=str(i))
        return table

    def _render_row(self, row: Row) -> list[str]:
        # Dim package name when tracked but not installed on this host —
        # makes the "installed" axis visible without a separate column.
        # Two glyph slots before the name:
        #   yellow ! — essential (packages/essential.txt)
        #   magenta * — pinned (packages/pinned.txt)
        ess = "[yellow]![/]" if row.essential else " "
        pin = "[magenta]*[/]" if row.pinned else " "
        name = row.pkg if row.installed else f"[dim italic]{row.pkg}[/]"
        cells: list[str] = [f"{ess}{pin} {name}"]
        for h in self.host_order:
            cells.append("✓" if h in row.hosts else " ")
        cells.append("[red b]U[/]" if row.uninstall else " ")
        return cells

    # --- focus + tab handling ---------------------------------------------

    def on_mount(self) -> None:
        # Land focus inside the first DataTable so arrow/hjkl work immediately,
        # instead of getting eaten by TabbedContent's own tab-switch bindings.
        if self.backends:
            self.tables[self.backends[0]].focus()
        # Prefetch descriptions for all installed packages so cursor navigation
        # never blocks on a subprocess.
        for backend, rows in self.rows_per_backend.items():
            installed = [r.pkg for r in rows if r.installed]
            for pkg, desc in batch_fetch_descriptions(backend, installed).items():
                self._desc_cache[(backend, pkg)] = desc
        self._refresh_description()

    def on_tabbed_content_tab_activated(
        self, event: TabbedContent.TabActivated
    ) -> None:
        pane_id = event.pane.id if event.pane else None
        if not pane_id:
            return
        backend = pane_id.removeprefix("tab-")
        if backend in self.tables:
            self.tables[backend].focus()
            self._refresh_description()

    # --- description pane -------------------------------------------------

    def on_data_table_cell_highlighted(
        self, event: DataTable.CellHighlighted
    ) -> None:
        del event  # required by Textual handler signature; content unused
        self._refresh_description()

    def _refresh_description(self) -> None:
        backend = self._active_backend()
        if not backend or backend not in self.tables:
            return
        table = self.tables[backend]
        rows = self.rows_per_backend[backend]
        row_idx = table.cursor_row
        widget = self.query_one("#description", Static)
        if row_idx < 0 or row_idx >= len(rows):
            widget.update("")
            return
        row = rows[row_idx]
        # Cache-only lookup. Prefetch covers installed packages; not-installed
        # rows just show "—" to avoid a network round-trip per cursor move.
        desc = self._desc_cache.get((backend, row.pkg), "")
        widget.update(f"[b]{row.pkg}[/]  {desc}" if desc else f"[b]{row.pkg}[/]  [dim]—[/]")

    def action_next_tab(self) -> None:
        self._step_tab(+1)

    def action_prev_tab(self) -> None:
        self._step_tab(-1)

    def _step_tab(self, delta: int) -> None:
        tabbed = self.query_one("#tabs", TabbedContent)
        ids = [f"tab-{b}" for b in self.backends]
        if not ids or tabbed.active not in ids:
            return
        idx = (ids.index(tabbed.active) + delta) % len(ids)
        tabbed.active = ids[idx]

    # --- actions ----------------------------------------------------------

    def _active_backend(self) -> str:
        tabbed = self.query_one("#tabs", TabbedContent)
        return (tabbed.active or "tab-").removeprefix("tab-") or self.backends[0]

    def _refresh_row(self, backend: str, row_idx: int) -> None:
        table = self.tables[backend]
        row = self.rows_per_backend[backend][row_idx]
        rendered = self._render_row(row)
        for col_idx, value in enumerate(rendered):
            table.update_cell_at(Coordinate(row_idx, col_idx), value)

    def action_toggle(self) -> None:
        backend = self._active_backend()
        table = self.tables[backend]
        if table.cursor_row < 0 or table.cursor_column < 0:
            return
        row = self.rows_per_backend[backend][table.cursor_row]
        col = table.cursor_column
        # Columns: 0=pkg (read-only), 1..N=hosts, last=uninstall
        if col == 0:
            return
        last = 1 + len(self.host_order)
        if 1 <= col < last:
            host = self.host_order[col - 1]
            if host in row.hosts:
                row.hosts.discard(host)
            else:
                row.hosts.add(host)
        elif col == last:
            row.uninstall = not row.uninstall
        self._refresh_row(backend, table.cursor_row)

    def action_uninstall(self) -> None:
        backend = self._active_backend()
        table = self.tables[backend]
        if table.cursor_row < 0:
            return
        row = self.rows_per_backend[backend][table.cursor_row]
        if not row.installed:
            self.notify(f"{row.pkg} is not installed", severity="warning")
            return
        row.uninstall = not row.uninstall
        if row.uninstall:
            # Auto-untrack on uninstall mark.
            row.hosts.clear()
            if row.essential:
                self.notify(
                    f"{row.pkg} is essential — removing it will break your system",
                    severity="error",
                    timeout=8,
                )
            elif row.pinned:
                self.notify(
                    f"{row.pkg} is pinned — are you sure?",
                    severity="warning",
                    timeout=5,
                )
        self._refresh_row(backend, table.cursor_row)

    def action_pin(self) -> None:
        backend = self._active_backend()
        table = self.tables[backend]
        if table.cursor_row < 0:
            return
        row = self.rows_per_backend[backend][table.cursor_row]
        row.pinned = not row.pinned
        if row.pinned:
            self.pinned.add(row.pkg)
        else:
            self.pinned.discard(row.pkg)
        save_pinned(self.pinned)
        self._refresh_row(backend, table.cursor_row)

    def action_apply(self) -> None:
        # Gather uninstalls per backend
        to_uninstall: dict[str, list[str]] = {}
        for b, rows in self.rows_per_backend.items():
            pkgs = [r.pkg for r in rows if r.uninstall]
            if pkgs:
                to_uninstall[b] = pkgs

        if to_uninstall:
            details_lines = []
            for b, pkgs in to_uninstall.items():
                details_lines.append(f"[b]{b}[/]")
                for p in pkgs:
                    details_lines.append(f"  {p}")
            self.push_screen(
                ConfirmModal(
                    summary=f"Uninstall {sum(len(p) for p in to_uninstall.values())} package(s)?",
                    details="\n".join(details_lines),
                ),
                lambda result: self._do_apply(to_uninstall, bool(result)),
            )
        else:
            self._do_apply({}, True)

    def _do_apply(self, to_uninstall: dict[str, list[str]], proceed: bool) -> None:
        if not proceed:
            self.notify("Apply cancelled.", severity="warning")
            return

        # Write list files first (so a failed uninstall doesn't leave files unchanged).
        files_written = 0
        for b, rows in self.rows_per_backend.items():
            write_backend(b, rows, self.all_hosts)
            files_written += 1

        # Run uninstalls.
        results: list[str] = [f"Wrote {files_written} list file(s)."]
        for b, pkgs in to_uninstall.items():
            cmd = uninstall_cmd(b, pkgs)
            if not cmd:
                continue
            try:
                proc = subprocess.run(cmd, capture_output=True, text=True)
                if proc.returncode == 0:
                    results.append(f"[{b}] uninstalled {len(pkgs)} package(s).")
                else:
                    results.append(
                        f"[{b}] uninstall failed (exit {proc.returncode}):\n{proc.stderr.strip()}"
                    )
            except Exception as e:
                results.append(f"[{b}] uninstall error: {e}")

        self.exit("\n".join(results))

    # --- filter -----------------------------------------------------------

    def action_filter(self) -> None:
        # Open an inline input prompt. For simplicity, use notify + input modal-light.
        self.push_screen(FilterModal(self._filter), self._set_filter)

    def _set_filter(self, value: str | None) -> None:
        self._filter = (value or "").lower()
        for b, rows in self.rows_per_backend.items():
            table = self.tables[b]
            table.clear()
            for i, row in enumerate(rows):
                if self._filter and self._filter not in row.pkg.lower():
                    continue
                table.add_row(*self._render_row(row), key=str(i))

    def action_clear_filter(self) -> None:
        if self._filter:
            self._set_filter("")


class FilterModal(ModalScreen[str]):
    CSS = """
    FilterModal { align: center middle; }
    #wrap { background: $panel; border: thick $accent; padding: 1 2; width: 60; }
    """

    def __init__(self, initial: str = "") -> None:
        super().__init__()
        self._initial = initial

    def compose(self) -> ComposeResult:
        with Container(id="wrap"):
            yield Label("Filter (substring match, blank = clear)")
            yield Input(value=self._initial, id="q")

    def on_input_submitted(self, event: Input.Submitted) -> None:
        self.dismiss(event.value)


# --- entrypoint -----------------------------------------------------------


if __name__ == "__main__":
    result = PackagesApp().run()
    if isinstance(result, str):
        print(result)
