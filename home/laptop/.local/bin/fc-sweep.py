"""
fc-sweep — interactive parameter sweep + STL export for one Body.

Pick a PartDesign Body, pick parameters that drive its features (from a
Spreadsheet or a VarSet), specify a range per alias, get one STL per
cartesian-product combination. Original values are restored on exit; the
document is never saved.

Invoked by the `fc-sweep` wrapper under `freecadcmd`. The wrapper passes
user args through FC_SWEEP_ARGS_FILE (NUL-delimited) so freecadcmd's own
positional parsing never sees them.
"""
import argparse
import itertools
import os
import re
import sys
from pathlib import Path

import FreeCAD
import MeshPart


BRACKET_RE = re.compile(r"<<([^>]+)>>\.(\w+)")
PLAIN_RE = re.compile(r"\b([A-Za-z_]\w*)\.(\w+)")

CONTAINER_TYPES = {"Spreadsheet::Sheet", "App::VarSet"}


def _user_argv():
    args_file = os.environ.get("FC_SWEEP_ARGS_FILE")
    if not args_file:
        print("error: FC_SWEEP_ARGS_FILE not set "
              "(invoke via the fc-sweep wrapper, not freecadcmd directly)",
              file=sys.stderr)
        sys.exit(1)
    with open(args_file, "rb") as f:
        raw = f.read()
    parts = raw.split(b"\0")
    if parts and parts[-1] == b"":
        parts = parts[:-1]
    return [p.decode() for p in parts]


def _value_of(q):
    return float(q.Value) if hasattr(q, "Value") else float(q)


def _linspace(start, end, n):
    if n <= 0:
        return []
    if n == 1:
        return [float(start)]
    return [float(start) + (float(end) - float(start)) * i / (n - 1)
            for i in range(n)]


def _list_bodies(doc):
    return [o for o in doc.Objects
            if o.TypeId == "PartDesign::Body" and o.Tip is not None]


def _parent_part(body, doc):
    """Return the App::Part wrapping this body, or None if unwrapped."""
    for o in doc.Objects:
        if o.TypeId == "App::Part" and body in o.Group:
            return o
    return None


def _body_display(body, doc):
    part = _parent_part(body, doc)
    return f"{part.Label} / {body.Label}" if part else body.Label


def _pick_body(doc, requested):
    bodies = _list_bodies(doc)
    if not bodies:
        print("error: no PartDesign::Body in document", file=sys.stderr)
        sys.exit(1)
    if requested:
        for b in bodies:
            if b.Label == requested or b.Name == requested:
                return b
        print(f"error: no body named {requested!r}", file=sys.stderr)
        print(f"  available: {', '.join(_body_display(b, doc) for b in bodies)}",
              file=sys.stderr)
        sys.exit(1)
    if len(bodies) == 1:
        print(f"Body: {_body_display(bodies[0], doc)} (only one in doc)")
        return bodies[0]
    print("Bodies in document:")
    for i, b in enumerate(bodies, 1):
        print(f"  [{i}] {_body_display(b, doc)}")
    while True:
        s = input("pick body [1]: ").strip() or "1"
        try:
            i = int(s) - 1
            if 0 <= i < len(bodies):
                return bodies[i]
        except ValueError:
            pass
        print(f"  invalid; pick 1-{len(bodies)}")


def _scan_refs(expr, container_lookup):
    """Yield (container, alias) pairs found in an expression string."""
    seen = set()
    for name, alias in BRACKET_RE.findall(expr):
        c = container_lookup.get(name)
        if c is not None and (c.Name, alias) not in seen:
            seen.add((c.Name, alias))
            yield c, alias
    for name, alias in PLAIN_RE.findall(expr):
        c = container_lookup.get(name)
        if c is not None and (c.Name, alias) not in seen:
            seen.add((c.Name, alias))
            yield c, alias


def _container_lookup(doc):
    out = {}
    for o in doc.Objects:
        if o.TypeId in CONTAINER_TYPES:
            out[o.Label] = o
            out[o.Name] = o
    return out


def _has_alias(container, alias):
    if container.TypeId == "Spreadsheet::Sheet":
        return bool(container.getCellFromAlias(alias))
    return alias in container.PropertiesList


def _is_derived(container, alias):
    if container.TypeId == "Spreadsheet::Sheet":
        addr = container.getCellFromAlias(alias)
        if not addr:
            return False
        return (container.getContents(addr) or "").lstrip().startswith("=")
    return any(p == f".{alias}" for p, _e in container.ExpressionEngine)


def _current_value(container, alias):
    return getattr(container, alias)


def _description(container, alias):
    if container.TypeId == "Spreadsheet::Sheet":
        addr = container.getCellFromAlias(alias)
        if not addr:
            return ""
        m = re.match(r"^([A-Z]+)(\d+)$", addr)
        if not m:
            return ""
        raw = container.getContents(f"A{m.group(2)}") or ""
        if raw.startswith("'"):
            raw = raw[1:]
        raw = raw.strip()
        if raw and raw != alias and not (raw.startswith("[") and raw.endswith("]")):
            return raw
        return ""
    try:
        return container.getDocumentationOfProperty(alias) or ""
    except Exception:
        return ""


def _snapshot(container, alias):
    """Capture the data needed to restore this alias after a sweep."""
    if container.TypeId == "Spreadsheet::Sheet":
        addr = container.getCellFromAlias(alias)
        return ("sheet", container.getContents(addr) or "")
    return ("varset", getattr(container, alias))


def _set_value(container, alias, value):
    if container.TypeId == "Spreadsheet::Sheet":
        container.set(alias, repr(float(value)))
    else:
        setattr(container, alias, float(value))


def _restore(container, alias, snap):
    kind, payload = snap
    if kind == "sheet":
        container.set(alias, payload)
    else:
        setattr(container, alias, payload)


def _discover_aliases(body, doc):
    """Return dicts for each non-derived container alias driving the body.

    Walks the Body and its features, plus the wrapping App::Part (if any)
    and its non-Body siblings — so Part-level datums/sketches and a sibling
    VarSet's own expressions also surface as candidate sweep axes.
    """
    lookup = _container_lookup(doc)
    found = {}
    objs = [body] + list(body.Group)
    part = _parent_part(body, doc)
    if part is not None:
        objs.append(part)
        for sibling in part.Group:
            if sibling.Name != body.Name and sibling.TypeId != "PartDesign::Body":
                objs.append(sibling)
    for obj in objs:
        engine = getattr(obj, "ExpressionEngine", None) or []
        for _path, expr in engine:
            for container, alias in _scan_refs(expr, lookup):
                key = (container.Name, alias)
                if key in found:
                    continue
                if not _has_alias(container, alias):
                    continue
                if _is_derived(container, alias):
                    continue
                try:
                    current = _current_value(container, alias)
                except AttributeError:
                    continue
                found[key] = {
                    "container": container,
                    "container_label": container.Label,
                    "alias": alias,
                    "current": current,
                    "description": _description(container, alias),
                }
    return list(found.values())


def _other_users(candidate, body, doc):
    """Bodies (other than the chosen one) that also reference this alias."""
    container = candidate["container"]
    alias = candidate["alias"]
    others = []
    lookup = {container.Label: container, container.Name: container}
    for b in _list_bodies(doc):
        if b.Name == body.Name:
            continue
        for obj in [b] + list(b.Group):
            engine = getattr(obj, "ExpressionEngine", None) or []
            for _path, expr in engine:
                for c, a in _scan_refs(expr, lookup):
                    if c.Name == container.Name and a == alias:
                        others.append(b.Label)
                        break
                else:
                    continue
                break
            else:
                continue
            break
    return others


def _pick_aliases(candidates):
    print("\nParameters driving this body:")
    name_w = max(len(f"{c['container_label']}.{c['alias']}") for c in candidates)
    for i, c in enumerate(candidates, 1):
        v = _value_of(c["current"])
        name = f"{c['container_label']}.{c['alias']}"
        line = f"  [{i:>2}] {name:<{name_w}}  = {v:<8g}"
        if c.get("description"):
            line += f"  {c['description']}"
        print(line)
    while True:
        s = input("pick parameters (comma-separated indices): ").strip()
        try:
            picks = [int(x.strip()) - 1 for x in s.split(",") if x.strip()]
            if picks and all(0 <= i < len(candidates) for i in picks):
                return [candidates[i] for i in picks]
        except ValueError:
            pass
        print(f"  invalid; pick from 1-{len(candidates)}")


def _prompt_range(c):
    cur = _value_of(c["current"])
    name = f"{c['container_label']}.{c['alias']}"
    print(f"\n{name}  (current = {cur:g})")
    while True:
        s = input(f"  start [{cur:g}]: ").strip()
        try:
            start = float(s) if s else cur
            break
        except ValueError:
            print("    not a number")
    while True:
        s = input("  end: ").strip()
        try:
            end = float(s)
            break
        except ValueError:
            print("    not a number")
    while True:
        s = input("  steps [5]: ").strip() or "5"
        try:
            n = int(s)
            if n >= 1:
                break
        except ValueError:
            pass
        print("    must be a positive integer")
    return _linspace(start, end, n)


def _parse_values(spec):
    """Parse 'alias=v1,v2,v3' or 'container.alias=v1,v2,v3'."""
    if "=" not in spec:
        raise ValueError(f"--values needs alias=v1,v2,...; got {spec!r}")
    name, raw_vals = spec.split("=", 1)
    name = name.strip()
    if "." in name:
        container_label, alias = name.split(".", 1)
    else:
        container_label, alias = None, name
    vals = []
    for p in (x.strip() for x in raw_vals.split(",")):
        if not p:
            continue
        try:
            vals.append(float(p))
        except ValueError:
            raise ValueError(f"value {p!r} for {name!r} is not numeric")
    if not vals:
        raise ValueError(f"--values for {name!r} has no values")
    return container_label, alias, vals


def _resolve_value_specs(specs, candidates):
    out = []
    for spec in specs:
        container_label, alias, vals = _parse_values(spec)
        match = next(
            (c for c in candidates
             if c["alias"] == alias
             and (container_label is None or c["container_label"] == container_label)),
            None,
        )
        if match is None:
            avail = ", ".join(f"{c['container_label']}.{c['alias']}" for c in candidates)
            raise ValueError(
                f"alias {alias!r} not driving the chosen body (available: {avail})"
            )
        out.append((match, vals))
    return out


def _do_sweep(doc, body, axis_specs, *, out_dir, ld, ad, dry_run):
    out_dir.mkdir(parents=True, exist_ok=True)
    aliases = [c["alias"] for c, _ in axis_specs]
    containers = [c["container"] for c, _ in axis_specs]
    value_lists = [vs for _, vs in axis_specs]
    originals = [(c["container"], c["alias"], _snapshot(c["container"], c["alias"]))
                 for c, _ in axis_specs]

    part = _parent_part(body, doc)
    name_prefix = f"{part.Label}__{body.Label}" if part else body.Label

    written = []
    skipped = []
    try:
        for combo in itertools.product(*value_lists):
            for container, alias, value in zip(containers, aliases, combo):
                _set_value(container, alias, value)
            doc.recompute()

            tags = "__".join(f"{a}={v:g}" for a, v in zip(aliases, combo))
            name = f"{name_prefix}__{tags}.stl"
            path = out_dir / name

            if dry_run:
                print(f"  (dry-run) {name}")
                continue

            shape = body.Shape
            if shape.isNull() or shape.Volume < 1e-6:
                msg = "empty shape (combination broke the model)"
                skipped.append((name, msg))
                print(f"  SKIP  {name}  ({msg})", file=sys.stderr)
                continue
            mesh = MeshPart.meshFromShape(
                Shape=shape, LinearDeflection=ld, AngularDeflection=ad
            )
            mesh.write(str(path))
            written.append(path)
            print(f"  {name}: {mesh.CountFacets} tris, V={shape.Volume:.1f} mm³")
    finally:
        for container, alias, snap in originals:
            _restore(container, alias, snap)
        doc.recompute()
    return written, skipped


def main(argv=None):
    if argv is None:
        argv = _user_argv()
    p = argparse.ArgumentParser(
        prog="fc-sweep",
        description="Vary container aliases driving a Body, export an STL per combination.",
    )
    p.add_argument("doc", help="Path to .FCStd document")
    p.add_argument("-o", "--out-dir", default=None,
                   help="Output directory (default: ./fc-sweep next to the doc)")
    p.add_argument("--ld", type=float, default=0.05,
                   help="LinearDeflection in mm (default 0.05)")
    p.add_argument("--ad", type=float, default=0.3,
                   help="AngularDeflection in radians (default 0.3)")
    p.add_argument("--body", default=None,
                   help="Body Label or Name (skips the body picker)")
    p.add_argument("--values", action="append", default=[],
                   metavar="alias=v1,v2,...",
                   help="Non-interactive sweep axis. Repeat for each parameter.")
    p.add_argument("--dry-run", action="store_true",
                   help="Print combinations + filenames, write 0 STLs")
    p.add_argument("--yes", action="store_true",
                   help="Skip the size confirmation prompt for >50 combos")
    args = p.parse_args(argv)

    doc_path = Path(args.doc).resolve()
    if not doc_path.exists():
        print(f"error: {doc_path} not found", file=sys.stderr)
        sys.exit(1)
    out_dir = (Path(args.out_dir).resolve() if args.out_dir
               else doc_path.parent / "fc-sweep")

    doc = FreeCAD.openDocument(str(doc_path))
    doc.recompute()

    body = _pick_body(doc, args.body)
    candidates = _discover_aliases(body, doc)
    if not candidates:
        print(f"error: {body.Label} has no parameter-driven inputs to sweep",
              file=sys.stderr)
        sys.exit(1)

    if args.values:
        try:
            axis_specs = _resolve_value_specs(args.values, candidates)
        except ValueError as e:
            print(f"error: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        picked = _pick_aliases(candidates)
        axis_specs = [(c, _prompt_range(c)) for c in picked]

    for c, _vals in axis_specs:
        others = _other_users(c, body, doc)
        if others:
            print(f"  note: {c['container_label']}.{c['alias']} also drives "
                  f"{', '.join(others)}; only {body.Label} is exported")

    total = 1
    for _, vals in axis_specs:
        total *= len(vals)
    print(f"\nBody:    {body.Label}")
    print(f"Out dir: {out_dir}")
    for c, vals in axis_specs:
        vals_fmt = ", ".join(f"{v:g}" for v in vals)
        print(f"  {c['container_label']}.{c['alias']}: [{vals_fmt}]")
    print(f"Total combinations: {total}")

    if not args.dry_run and total > 50 and not args.yes:
        s = input(f"{total} STL files will be written. Proceed? [y/N] ").strip().lower()
        if s != "y":
            print("aborted")
            sys.exit(1)

    print()
    written, skipped = _do_sweep(
        doc, body, axis_specs,
        out_dir=out_dir, ld=args.ld, ad=args.ad, dry_run=args.dry_run,
    )
    if args.dry_run:
        print(f"\n(dry-run) {total} combinations planned for {out_dir}")
    else:
        msg = f"\nWrote {len(written)} STL(s) to {out_dir}"
        if skipped:
            msg += f"  ({len(skipped)} skipped)"
        print(msg)


try:
    main()
finally:
    sys.stdout.flush()
    sys.stderr.flush()
