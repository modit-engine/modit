# Models and animation

Use `engine.model` inside a client with an open engine window. The implementation is Lua over the bundled Raylib; games never need FFI or native model handles.

## Load once, draw many times

```lua
local ok, reason = engine.model.load({
    key = "crate",
    path = "assets/models/crate.glb",
})
assert(ok, reason)

local first_crate = assert(engine.model.create_instance({
    key = "crate",
    x = -2,
    scale = 1,
    tint = { 255, 180, 120, 255 },
}))

local second_crate = assert(engine.model.create_instance({
    key = "crate",
    x = 2,
    angle = 45,
    scale = { x = 1, y = 2, z = 1 },
}))

-- Inside camera:begin_3d() / camera:end_3d():
engine.model.draw_many({ first_crate, second_crate }, camera)
```

Instances are ordinary Lua tables with independent position, scale, axis, angle and tint. Edit their fields directly; they allocate no separate mesh or texture. Existing `model.draw({ key = "crate", ... })` calls still work. Rotation uses degrees around a normalized axis (default `{ x = 0, y = 1, z = 0 }`). Tint uses integer RGBA channels from 0 to 255, either named or positional. Draw tint multiplies the material colour.

Loading the same key and path again reuses the asset. Different keys are separate assets, even with the same path. A conflicting path returns `false, reason`; use `replace = true` to deliberately reload or replace. Replacement only releases the old asset after the new one succeeds, and existing instances then refer to the replacement.

## Meshes, materials and bounds

`model.build({ key, vertices, indices?, uvs?, colours?, normals? })` creates or replaces an asset. Vertices/normals are flat x,y,z lists, UVs are u,v pairs and colours are four integer RGBA channels per vertex. Indices are **1-based** triangle lists, limited to 65,535 vertices. Without indices, every nine vertex numbers form a triangle. Triangles face counter-clockwise from the outside. Invalid data or an allocation failure preserves an existing asset.

```lua
local materials = assert(engine.model.get_materials("crate"))
-- Copied tables: materials[1].tint and materials[1].texture.{width,height}.
-- Material indices are 1-based.
assert(engine.model.set_material({
    key = "crate",
    material = 1,
    texture = "assets/textures/crate.png",
    tint = { r = 255, g = 255, b = 255, a = 255 },
}))

local asset_bounds = assert(engine.model.get_bounds("crate"))
local world_bounds = assert(engine.model.get_bounds(second_crate))
-- Each result contains min/max vectors with x, y, z.
```

Material edits affect every instance of that key. For individual colour changes, edit the instance tint instead. Omit `texture` to keep it; set it to `false` to restore the default white texture. A failed texture load leaves both texture and colour unchanged. Images loaded through `engine.image` are separate resources, not borrowed by models.

World bounds enclose the transformed asset box and all attached parts, including rotation, pivots and negative scale. Animated instances use their current posed geometry. They are conservative axis-aligned bounds, not exact collision geometry. Returned material/bounds tables are copies.

## Optional Lua asset descriptions

Use `load_asset` when a model needs reusable import settings or named parts. A description is an ordinary Lua file returning a data table; no editor registration or asset database is needed.

```lua
-- game/assets/robot/robot.lua
return {
    scale = 0.01,
    parts = {
        body = {
            source = "body.glb",
            materials = {
                [1] = { smooth = false, emissive = { 40, 180, 255 } },
            },
        },
        arm = {
            source = "arm.obj",
            x = 25,
            pivot = { x = 0, y = 10, z = 0 },
            axis = { x = 0, y = 0, z = 1 },
        },
    },
}
```

```lua
assert(engine.model.load_asset({
    key = "robot",
    path = "assets/robot/robot.lua",
    base_dir = engine.game_dir,
}))
local robot = assert(engine.model.create_instance({ key = "robot", x = 4 }))
engine.model.get_part(robot, "arm").angle = 30
engine.model.draw(robot)
```

Each node supports `source`, `x/y/z`, `scale`, `axis`, `angle`, `pivot`, `tint`, `materials`, `animations` and named `parts`. A node without a source is a transform group. For skeletal assets, `animations = true` loads clips from the source; a relative animation filename loads clips from another compatible file. Groups cannot have their own materials or skeletal clips; edit the relevant mesh part.

All source, texture and animation references are relative to the description's folder, including references in nested parts. Use subfolders for shared textures or meshes. References cannot be absolute or contain a `..` path component. `base_dir` is optional; without it the description path is relative to the process working directory, or absolute. Model-native dependencies such as OBJ/MTL textures and glTF buffers keep their normal file-relative layout.

Descriptions run in an empty Lua environment and should only return data. Instances copy their defaults and receive independent part tables. Explicit `create_instance` fields override that node's defaults; parent defaults still affect children. `get_bounds("robot")` includes default transforms and the complete assembly. Use `create_instance` before drawing an assembly; a bare `{ key = "robot" }` does not contain its parts.

Loading the same description path/key reuses it. Use `replace = true` after editing. Every source and material must load successfully before the new asset replaces the old one; failure releases staged resources and leaves the old asset usable. After successful assembly replacement, recreate its instances because their old child keys have been released. Unloading the root releases its owned parts. Child keys are implementation details: use them for material queries/edits, but do not separately unload or replace them.

Direct `load`, `build`, `create_instance` and manual `attach` remain available. Asset descriptions are optional. Mods have `load_asset` too; the description resolves inside the mod directory, with the same scoped ownership as other model methods. Mods cannot override that directory through `base_dir`.

## Complete VOX scenes

```lua
assert(engine.model.load_asset({ key = "machine", path = "assets/machine.vox" }))
local machine = assert(engine.model.create_instance({ key = "machine", scale = 0.1 }))
```

The asset workflow uses a small Lua VOX reader instead of Raylib's flattened geometry loader. It preserves static transform/group/shape nodes, names, model placements, rotations, hidden layers, palette colours and emissive materials. It converts MagicaVoxel's Z-up coordinates to the engine's Y-up coordinates (`x, z, -y`). One voxel is one engine unit before scaling. Model coordinates are centred around `floor(SIZE / 2)`; authored scene translations position those models, retaining their local rotation origins. You can override a part's `pivot` afterward through the normal instance API.

Named nodes remain nested exactly as the source hierarchy; use `get_part` at each level. Unnamed nodes use `node_<id>`, and duplicate sibling names receive suffixes. Mesh leaves use `palette_<index>` names (with extra chunks for large meshes). Scene instances remain independently editable. Multiple references to one VOX model preserve their placements, though this initial importer builds separate mesh assets for each reference.

A Lua description can also use `source = "machine.vox"`; the imported hierarchy appears beneath its `scene` part. Apply scale/orientation on the containing node. For regular mesh sources, `materials` uses the native loader's 1-based material indices; for VOX, edit the imported palette mesh parts after creating an instance.

The importer removes enclosed faces and merges adjacent exposed faces of the same palette colour into rectangles. It reads the standard palette when RGBA is absent, and maps MATL `_emit` materials into the existing emission shader. `_emit` (or legacy `_weight`) supplies emission strength. RGBA opacity is retained; glass refraction, metal/roughness response, flux-based lighting, render-camera settings and deprecated MATT materials are not reproduced. This is still the engine's existing lighting model, not MagicaVoxel's path tracer.

Static VOX versions 150/200 are supported. Transform/shape keyframe animation is rejected explicitly; animate the imported Lua parts yourself. Legacy multi-model files without a scene graph are rejected because they do not specify placement. Bounds/count checks reject truncated chunks, invalid references and scene cycles before mesh upload. Limits are 256 voxels per model axis, 16 million voxels per file, one million merged faces and 4,096 asset nodes; unusually fragmented scenes may need splitting.

`model.load({ key, path = "file.vox" })` deliberately retains the earlier native static-loading behaviour. Use `load_asset` for preserved multipart scenes.

## Project and exported-game layout

Keep each description and its source/dependency files together, for example under `game/assets/robot/`. The current builder copies non-Lua project files beside the executable, preserving folders; game Lua is embedded and available through the runtime's `loadfile`. The executable starts in its own directory. `base_dir = engine.game_dir` therefore works in both source and exported games.

No runtime extraction cache is needed for this build layout: meshes, textures and binary buffers already exist on disk where native loaders expect them. Moving just the executable without the copied asset folders will break loading. Models packed into a future all-assets archive would need an extraction/resolution layer then.

## Standalone preview

From the engine repository root:

```text
luajit tools/demos/model_viewer.lua "path/to/asset.lua"
luajit tools/demos/model_viewer.lua "path/to/scene.vox"
```

The viewer fits the asset, orbits it and allows scroll-wheel zoom. Click a part to highlight it. Animation clips enabled by a description play automatically. Ordinary mesh paths also work. Add `--check` for a hidden one-frame load/render check. It uses the public engine API and does not alter the asset or game project.

## Named parts and pivots

Load each reusable part as an asset, create instances, then attach them by name:

```lua
local body = assert(engine.model.create_instance({ key = "body" }))
local arm = assert(engine.model.create_instance({
    key = "arm",
    x = 1,
    pivot = { x = 0, y = 1, z = 0 },
    axis = { x = 0, y = 0, z = 1 },
}))
assert(engine.model.attach(body, "arm", arm))

engine.model.get_part(body, "arm").angle = 45
engine.model.draw(body) -- Draws body and all its attached parts.
```

Each child uses local coordinates. Transforms combine as `parent * translation * pivot * rotation * scale * inverse_pivot`; full matrices preserve nonuniform parent scaling. Tint multiplies down the hierarchy. `model.detach(parent, name)` returns the child, retaining its local transform. Detach before attaching elsewhere. Cycles and hierarchies deeper than 64 instances are rejected.

Pass hierarchy roots to `draw_many`; it sorts all their meshes together. Do not also pass a child already included beneath a root. Querying a child directly still includes its parent transforms. For authored VOX hierarchies, use `load_asset` as described above.

## Skeletal playback

```lua
assert(engine.model.load({ key = "worker", path = "assets/models/worker.glb" }))
assert(engine.model.load_animations({ key = "worker" }))
local clips = assert(engine.model.get_animations("worker"))
-- Each clip has index, name, frames and optional fps.

local worker = assert(engine.model.create_instance({ key = "worker" }))
assert(engine.model.play(worker, { clip = clips[1].index, loop = true }))

-- In the game update hook, once per hierarchy root:
engine.model.update(worker, dt)
-- In the 3D draw hook:
engine.model.draw(worker)
```

Animation loading is explicit and separate from static loading. `load_animations({ key, path? })` defaults to the asset's original path, or takes a compatible animation file. It accepts glTF/GLB, IQM and M3D through the bundled loader. Use the same skeleton and bone ordering: native compatibility checks do not retarget animations or match bone names. The current limit is 256 bones with up to four influences per vertex.

`play(instance, { clip?, fps?, speed?, loop? })` starts at frame zero. Clip defaults to index 1; unique clip names also work. glTF/GLB defaults to the native loader's 60 sampled frames per second. Other formats default to 30; supply `fps` to match the source because native clips do not retain their original timing. `speed` defaults to 1; zero freezes advancement. Looping defaults to true; a non-looping clip stops on its last frame.

- `update(instance, dt)` advances that instance and its children. Games control when it runs, so pausing the game requires no internal timers.
- `pause(instance, true)` freezes playback; `pause(instance, false)` resumes.
- `seek(instance, seconds)` samples a time, clamped to the last frame, without changing its paused state.
- `stop(instance)` clears playback and returns to the bind pose. Playback controls other than `update` affect only the supplied instance.

Instances share assets but keep independent playback and pose buffers. Pose positions and normals are skinned on the CPU and temporarily uploaded for drawing, then the shared bind buffers are restored, including after a Lua draw failure. This works with existing lighting, transparency and shadow passes. CPU skinning and per-instance uploads can be expensive for large animated crowds; measure your scene before choosing its animation budget. There is no GPU instancing, clip blending, root-motion extraction, morph animation or bone-attachment API.

Replacing an asset or successfully reloading its clips invalidates old playback; call `play` again. Failed clip loads preserve the previous clips and playback. Unloading the asset releases its native clips too.

**Bundled-loader restriction:** glTF/GLB skeletons must have an armature/parent node above the first joint. The bundled Raylib otherwise crashes while loading animation. The Lua wrapper detects this and returns an error asking for re-export with a parent. Static loading is unaffected. Exported assets should still be trusted; this check is not a complete native-parser sandbox.

## Picking

The editor also opens OBJ, glTF/GLB, IQM, VOX and M3D files from the Files panel in read-only preview tabs. Drag to orbit, scroll to zoom, and use Reset view to refit the model. Multipart VOX scenes show their named parts in a scrollable sidebar; click a part to highlight it. Reload refreshes an externally edited asset. Closing a tab releases its preview resources. Lua source files continue to open in the code editor.

```lua
local ray = assert(engine.model.screen_ray(camera, mouse_x, mouse_y))
local hit, reason = engine.model.raycast(instances, ray)
if hit then
    selected_part = hit.instance
elseif reason then
    print(reason)
end
```

`screen_ray(camera, x, y, width?, height?)` accepts an engine perspective camera and viewport-local pixel coordinates. The viewport defaults to the open window; provide both dimensions for a custom viewport. The result is a plain Lua table with `origin` and `direction` vectors.

`raycast(instances, ray, max_distance?)` tests an array of hierarchy roots and their parts. It normalizes the ray direction without modifying it, rejects bounds misses, then tests mesh triangles using the current animation pose. Drawing first is unnecessary. The nearest hit contains the original `instance` reference, asset `key`, 1-based `mesh` index, world-space `distance`, `position` and `normal`. The optional distance limit is in world units. A miss returns `nil, nil`; invalid input returns `nil, reason`. Mods receive their original instance references and local asset keys.

Picking tests geometry from either side, including transparent meshes. It does not sample texture alpha or discard invisible texels, and does not provide physics or collision response. Supply only the objects you want selectable.

## Lighting, emission and transparency

Use the engine camera's `begin_3d` / `end_3d` so model shaders receive the sun, ambient light and fog settings. Meshes with normals use smooth lighting, including inverse-transpose correction for nonuniform scale. Missing normals fall back to faceted lighting. Set `smooth = false` on a material to keep a low-poly appearance.

```lua
assert(engine.model.set_material({
    key = "crate",
    material = 1,
    emissive = { 80, 180, 255 },
    emissive_strength = 2,
    -- Optional: emissive_texture = "assets/textures/crate_lights.png",
    smooth = false,
}))

assert(engine.model.set_material({
    key = "leaves",
    alpha_mode = "mask",
    alpha_cutoff = 0.5,
    double_sided = true,
}))
```

Emission adds colour independently of the sun and ambient light, but still fades into fog. It does not light neighbouring objects or add bloom. An emission texture multiplies the emission colour; use white `emissive` to show the texture's own colours. `emissive_texture = false` removes the texture; `emissive = { 0, 0, 0 }` disables emission. Imported emission colours/textures use the data supplied by Raylib; format-specific metadata is not reconstructed.

`get_materials` also returns `emissive`, `emissive_texture` dimensions (or nil), `emissive_strength`, `alpha_mode`, `alpha_cutoff`, `smooth`, `double_sided` and `cast_shadows`. Material edits are shared by every instance of that asset.

| Setting | Behaviour |
| --- | --- |
| `alpha_mode = "auto"` (default) | Blends when the base texture, vertex colours, material colour or instance tint has alpha below 255. Texture alpha is inspected on load/update, not every frame. |
| `alpha_mode = "opaque"` | Ignores alpha and writes depth normally. |
| `alpha_mode = "mask"` | Discards pixels below `alpha_cutoff` (default 0.5); remaining pixels are opaque and write depth. |
| `alpha_mode = "blend"` | Blends colour without writing depth. Use sorted drawing. |
| `double_sided = true` | Draws both sides; default is back-face culling. |
| `cast_shadows = false` | Excludes this material from both shadow passes. Default is true. |

`model.draw_many(instances, camera)` draws opaque/cutout meshes first, then sorts blended meshes back-to-front by their transformed centres along the camera's view direction. Pass all mutually overlapping transparent models together. It does not modify the supplied tables. `model.draw(instance)` remains immediate and does not sort other objects for you.

Mapped and projected shadows respect cutout textures, vertex alpha and tint. Blended materials do not cast solid shadows. Blob shadows remain explicit calls to `engine.lighting.blob`; they are not generated from model geometry. Depth writes, culling and borrowed material bindings are restored after drawing, including a Lua draw failure.

## Ownership, paths and shutdown

- `load`, `build`, `draw`, `draw_many` and `set_material` return success, or `false, reason`. Queries/instance creation return a table, or `nil, reason`.
- `model.unload(key)` releases an asset and its owned textures. Instances referencing that key stop drawing until it is loaded again. `model.cleanup()` releases all public model assets; repeated cleanup is safe.
- `engine.window.close()` resets water, releases model assets and backend caches, then destroys the graphics context. Use this lifecycle rather than closing Raylib directly.
- Games pass filesystem paths, relative to the process working directory or absolute. Models and their dependent files must be present on disk; keep relative texture/buffer references intact.
- Mods with the model module enabled use the same methods. Model and texture paths resolve inside the mod directory. Keys are isolated per running mod; stopping one mod releases only its own assets. The internal `mod_model:` key prefix is reserved for the sandbox.

## Supported scope

The bundled renderer loads OBJ, glTF/GLB, IQM, VOX and M3D. This API supports static and skeletal geometry, named Lua assemblies, base-colour and emission textures/colours, smooth or faceted sun/ambient lighting, fog, shadow maps, projected shadows, alpha cutouts and sorted alpha blending.

This is not a full PBR renderer: metallic/roughness, normal maps, occlusion maps, image-based lighting, HDR/bloom, refraction and coloured/translucent shadows are not implemented. Imported glTF alpha modes, double-sided flags and emission-strength extensions are not exposed by Raylib's Model structure; set those explicitly with `set_material` when needed. Texture alpha is detected, but a cutout texture needs explicit `alpha_mode = "mask"` to cast a cutout shadow.

Transparency sorting is per mesh, not per triangle. Intersecting transparent surfaces, nested glass and transparent objects drawn outside the same batch may still need application-specific ordering or separate meshes. The optional asset workflow adds named assemblies and static VOX scene import; unsupported authoring features are listed above.

Validation rejects missing/empty files, files larger than 256 MiB through the native loader, malformed glTF JSON, invalid GLB/VOX/M3D headers, invalid IQM header spans and unusable returned geometry. Transform overflow is rejected before drawing. These checks catch common mistakes; they are not complete validation of every format. Native format parsers still run in-process: Lua error handling cannot recover from a native parser crash or guarantee safe loading of arbitrary corrupt/untrusted files. Load trusted source assets. The exported-game layout uses loose native assets alongside embedded Lua descriptions.

## Performance

Instance transforms use direct matrix composition to avoid chains of temporary matrices. Assets remain shared; `draw_many` groups opaque and transparent passes but still issues per-mesh draws. No separate batching or GPU-instancing API is required to use this pipeline.

On a Ryzen 5 7600X / RTX 3050, a matched 120-frame test improved 1,000 opaque triangle instances from 13.21 to 8.90 ms/frame and blended instances from 15.37 to 10.45 ms/frame. A longer 1,000-frame run measured 9.79 and 9.65 ms/frame respectively. This is a synthetic hidden 512×512 scene with synchronous GPU readback each frame, not a prediction of game FPS. The sustained run retained at most 12 KiB of additional Lua memory per case and up to 2 MiB of additional process private memory; 500 build/unload cycles also completed. These observations do not prove that every workload is leak-free.

Keep animation, transparent overlap and triangle counts representative when profiling your own game. The public instance API can accommodate future backend optimizations without making games manage native buffers.

## Regression checks

From the engine repository root:

```text
luajit tools/tests/model.lua
luajit tools/tests/model_rendering.lua
luajit tools/tests/model_animation.lua
luajit tools/tests/model_assets.lua
luajit tools/tests/model_picking.lua
luajit tools/tests/model_errors.lua
```

The checks create a hidden graphics window and temporary fixtures. They cover replacement rollback, invalid data, allocation failures, independent instances, transformed bounds, texture lifetime, mod isolation, lighting/shadow integration, water, cleanup and context reopening. Rendering checks read actual GPU pixels for smooth normals, emission, fog, cutouts, both shadow modes and transparency ordering. They do not build a game client.

Animation checks generate a skeletal glTF fixture and verify independent native poses, GPU buffer restoration, playback timing, pivots, parent transforms, mod scoping, animation cleanup and the parentless-root guard for glTF/GLB.

Asset checks cover native OBJ/MTL/texture dependencies, Lua defaults and atomic rollback, exported folder layouts, animation descriptions, greedy VOX faces, palette emission, scene bounds/rotations, hidden nodes, mod scoping and GPU/resource cleanup.

The six self-contained suites pass 532 checks. Picking includes animated poses and scoped mod instances; error checks verify malformed containers and preservation of an existing asset after failed replacement.

Optional extended checks:

```text
luajit tools/tests/model_profile.lua 1000
luajit tools/tests/model_formats.lua "path/to/fixtures"
python tools/tests/model_export.py
```

The format test expects `guy.iqm`, `guyanim.iqm`, `guytex.png`, `cesium_man.m3d` and `greenman.glb` in one fixture folder. Obtain them from the [Raylib example models](https://github.com/raysan5/raylib/tree/master/examples/models/resources/models), under `iqm`, `m3d` and `gltf`. These artist-authored characters passed 745 checks covering independent animation, posed bounds, rendering and cleanup. The fixtures are optional and are not bundled with this repository.

The export test requires the normal Windows build tools. It creates a disposable project, builds both source and bytecode exports, launches each hidden executable from another working directory, and verifies embedded Lua descriptions, loose native assets, rendering and picking. Both variants passed. It does not build or modify an existing game.
