"""
fc-stl — export visible PartDesign Bodies to STL.

Internal Python implementation. Invoked by the `fc-stl` wrapper under
`freecadcmd`. The wrapper passes user args through FC_STL_ARGS_FILE
(NUL-delimited) so freecadcmd's own positional parsing never sees them.
"""
import argparse
import os
import sys
from pathlib import Path

import FreeCAD
import MeshPart


def export_bodies(doc, out_dir, *, ld, ad, include_hidden):
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for obj in doc.Objects:
        if obj.TypeId != "PartDesign::Body" or obj.Tip is None:
            continue
        if not include_hidden and obj.ViewObject and not obj.ViewObject.Visibility:
            continue
        if obj.Shape.isNull() or obj.Shape.Volume < 1e-6:
            print(f"  skip {obj.Label} (empty)", file=sys.stderr)
            continue
        mesh = MeshPart.meshFromShape(
            Shape=obj.Shape, LinearDeflection=ld, AngularDeflection=ad
        )
        path = out_dir / f"{obj.Label}.stl"
        mesh.write(str(path))
        print(f"  {obj.Label}: {mesh.CountFacets} triangles, "
              f"V={obj.Shape.Volume:.1f} mm³ → {path}")
        written.append(path)
    return written


def _user_argv():
    """Read user args from the NUL-delimited file written by the wrapper."""
    args_file = os.environ.get("FC_STL_ARGS_FILE")
    if not args_file:
        print("error: FC_STL_ARGS_FILE not set "
              "(invoke via the fc-stl wrapper, not freecadcmd directly)",
              file=sys.stderr)
        sys.exit(1)
    with open(args_file, "rb") as f:
        raw = f.read()
    parts = raw.split(b"\0")
    if parts and parts[-1] == b"":
        parts = parts[:-1]
    return [p.decode() for p in parts]


def main(argv=None):
    if argv is None:
        argv = _user_argv()
    p = argparse.ArgumentParser(
        prog="fc-stl",
        description="Export PartDesign Bodies from a FreeCAD document to STL.",
    )
    p.add_argument("doc", help="Path to .FCStd document")
    p.add_argument("-o", "--out-dir", default=None,
                   help="Output directory (default: ./stl next to the document)")
    p.add_argument("--ld", type=float, default=0.05,
                   help="LinearDeflection in mm (default 0.05)")
    p.add_argument("--ad", type=float, default=0.3,
                   help="AngularDeflection in radians (default 0.3)")
    p.add_argument("--include-hidden", action="store_true",
                   help="Include bodies hidden in the tree")
    args = p.parse_args(argv)

    doc_path = Path(args.doc).resolve()
    if not doc_path.exists():
        # Explicit print+exit because sys.exit(string) under freecadcmd
        # doesn't reliably flush its message before the process tears down.
        print(f"error: {doc_path} not found", file=sys.stderr)
        sys.exit(1)
    out_dir = Path(args.out_dir).resolve() if args.out_dir else doc_path.parent / "stl"

    doc = FreeCAD.openDocument(str(doc_path))
    doc.recompute()
    written = export_bodies(doc, out_dir,
                            ld=args.ld, ad=args.ad,
                            include_hidden=args.include_hidden)
    print(f"\nWrote {len(written)} STL(s) to {out_dir}")


# freecadcmd doesn't set __name__ to "__main__", so call main() unconditionally.
# It also doesn't flush stdout before sys.exit, so wrap to force flushes.
try:
    main()
finally:
    sys.stdout.flush()
    sys.stderr.flush()
