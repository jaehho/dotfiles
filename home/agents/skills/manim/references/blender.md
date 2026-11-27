# 3D with Blender

Read this when a scene shows 3D data (meshes, point clouds, neurons) that manim's Cairo 3D draws poorly. SKILL.md has the rules that always apply. The lab's working version is `lab.connectome.animate` with `lab.connectome.blender_render`; reuse it rather than writing another.

## Why and how it splits

- Blender (EEVEE) draws transparent meshes with real depth and outlines, millions of points, and smooth camera paths; manim's Cairo 3D has no depth order, writes point colours without blending, and slows with point count.
- Python plans every frame: the camera (an orbit about a target, with roll) and each object's opacity, growth or bend. It writes a JSON scene spec and an NPZ of arrays.
- A Blender script (`blender -b --factory-startup --python-exit-code 1 --python script.py -- SPEC ARRAYS FOLDER [FRAMES]`) builds the objects, keys every frame from the spec, and writes PNG frames. It uses only Blender's own Python and numpy; import `bpy` inside `main`, so the file still imports under pytest.
- manim draws captions, labels and an axes indicator on a transparent layer (`-t`, `format = mov`) from the same plan, projecting with the same camera maths.
- ffmpeg lays the layer on (`[0][1]overlay=format=auto`) and cuts one clip per transition (`select='between(n,a,b)'`), forward and reversed, into a cel storyboard (see references/workflow.md, Stepping through keyframes).

## Blender gotchas

- Blender exits 0 when the Python script raises; pass `--python-exit-code 1` and check that frames were written.
- Colours are linear: convert sRGB hex before setting a node's colour, or every colour renders lighter.
- Transparency needs `material.surface_render_method = "BLENDED"` and `use_backface_culling = False`. A Neuroglancer-like shell is an emission colour mixed with a transparent BSDF by `LayerWeight.Facing ** power` times a keyed opacity.
- Set `scene.view_settings.view_transform = "Standard"` so a white world is white.
- Key every frame from the plan rather than a few keys, so Blender's interpolation adds no overshoot and the overlay matches frame for frame.
- Aim the camera from a forward and an up vector (a rotation per frame), not a Track To constraint, which cannot roll.
- A line that draws on: a curve with `bevel_factor_mapping_end = "SPLINE"` and keyed `bevel_factor_end`. A line that bends: a shape key keyed from 0 to 1.
- A per-point colour on many balls: one mesh of icosahedra with a point-domain colour attribute read by an Attribute node.

## Camera

- Keep the world's up (dorsal, in anatomy) vertical while the camera moves, and do any roll in place before or after the move: a transition that orbits, pans, zooms and rolls at once disorients. Prefer framings that need little roll from a dorsal-up view.
- Orbit about the vertical (a turntable), not about an oblique axis, which tumbles the up direction.
- A still does not show 3D shape: give a keyframe that introduces a shape (neuropils, a cell) an orbit in its transition, a full turn when it should end where it began.

## Review

- Render stills of chosen frames first (each keyframe, and mid-transition), with the overlay's matching frame laid on (`trim=start_frame=n:end_frame=n+1`), and look at them before rendering the whole movie.
- At 1080p, EEVEE takes about half a second a frame for a brain shell and a few thousand balls on a laptop GPU.
