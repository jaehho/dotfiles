# The .drawy format (Drawy 1.0.2)

Checked 2026-10-29 by loading boards in the installed Drawy 1.0.2 and reading its source (`~/projects/upstream/drawy/src`, tag v1.0.2). Recheck after a Drawy upgrade.

## Container

- One zstd frame with the content size in its header: Python's `compression.zstd.compress(data, level=4)` reproduces Drawy's bytes. Plain JSON, a streamed frame (no size), two frames or a truncated file abort Drawy at load (`std::terminate`). Opened from File > Open, that also ends a session holding unsaved work (read in source, not run).
- The payload is compact JSON with sorted keys and no `NaN`. Unknown keys load but vanish at Drawy's next save.

## Document

- `version` (always 1, never read), `zoom_factor` (1.0 = 100%, clamped 0.1–30), `offset_pos {x, y}` (canvas point at the view's top-left), `items` (top level, back to front).
- Array order is the stacking order, at the top level and inside a group. `zorder` is written by Drawy but never read.
- `items` missing or not an array loads an empty board under the file's name, so a Save wipes it.

## Items

- Every item has `type`, `id` (32 lowercase hex, `uuid.uuid4().hex`; Drawy's paste duplicates ids, so do not assume they are unique), `properties` (a list of `{type, value}`), and `transform` (`m11`..`m33`, all nine required and numeric: a missing entry or a string such as `"m31": "500"` reads as 0, which moves, collapses or drops the item). `locked: true` appears only when locked.
- Types, exact and uppercase: `RECTANGLE`, `ELLIPSE`, `DIAMOND`, `LINE`, `ARROW`, `FREEFORM`, `TEXT`, `IMAGE`, `GROUP`, and `CUSTOM` with `pluginName: "standardforms"` and `customObjectName` `TRIANGLE` or `XBOX`. Any other type is dropped without a word.

| type | fields beyond the common ones |
|---|---|
| RECTANGLE, ELLIPSE, DIAMOND, CUSTOM | `start {x,y}`, `end {x,y}` (opposite corners, local coordinates) |
| LINE, ARROW | `start`, `end` |
| FREEFORM | `points [{x,y}]`, `pressures [0..1]` (same length as points), `simulatePressure` |
| TEXT | `text` (non-empty; `\n` breaks lines), `top_left {x,y}` (local, not a canvas position). The box size is not stored: Drawy measures it at load in Fuzzy Bubbles at FontSize points |
| IMAGE | `image_data` (base64 PNG only; other formats load blank and save as `""`), `bounding_box {x,y,width,height}` (local; the pixmap is stretched into it) |
| GROUP | `items` (children, back to front, at least one with a non-zero box). Its `properties` are ignored at load; style the children |

## Properties

| type | value | owned by |
|---|---|---|
| `FontSize` | int, points, default 18 | TEXT |
| `Opacity` | int 0–255 | every leaf type |
| `StrokeColor` | colour; TEXT defaults to `#ffffff` if missing | all but IMAGE |
| `StrokeWidth` | int, canvas px | shapes, lines, FREEFORM |
| `StrokeStyle` | `Solid`, `DashLine`, `DotLine` | shapes, lines, FREEFORM |
| `BackgroundColor` | colour, default `#00000000` | shapes |
| `BackgroundStyle` | `Solid`, `Diagonal`, `CrossDiagonal`, `None` | shapes |
| `StartArrowType`, `EndArrowType` | `None`, `Open`, `Unfilled`, `Filled`, `Circle`, `Diamond` | ARROW |

- Colours are `#rrggbb`, or `#aarrggbb` with alpha **first** (Qt's form, not CSS). A property the type does not own is ignored.

## Coordinates

- Qt's convention: `x' = m11·x + m21·y + m31`, `y' = m12·x + m22·y + m32`.
- A child's canvas point is `p · T_child · T_group` (child first, then each ancestor). A top-level item uses its own transform.
- On load Drawy rewrites every group to a pure translation to its children's top-left and folds rotation and scale into the children. Canvas positions do not change, so a writer may leave a group in any form.
- Drawy keeps scale out of transforms: a resize multiplies `bounding_box` (IMAGE), `FontSize` and `top_left` (TEXT, FontSize rounded) or the children (GROUP).
- Moving an item adds the canvas delta to `m31`/`m32`.

## Dropped at load without a word

- A top-level item whose box has zero area, such as a rectangle without `start`/`end` or a group whose only child is empty text.
- A group with no items, or one made zero-area by an empty TEXT.
- `CUSTOM` with an unknown plugin, and a non-object entry in `items`.
- Whatever is dropped stays dropped: Drawy's next save writes the board without it.
