# API Cheatsheet

Quick reference to the core modules and object-oriented asset handles currently implemented in the engine.
For more detailed documentation refer to the module specific sections.

## Core Modules

The modules are served to game files regardless.
They are either required by the engine, or required by other modules to function.

### `modit.json`

Utility module for encoding and decoding JSON data.

* **Realm:** `shared`
* **Mod-Safe:** `yes`

```lua
modit.json.encode(value) -- Encodes a Lua value as JSON.
modit.json.decode(input) -- Decodes a JSON string into a Lua value.
```

### `modit.log`

Color-coded logging subsystem with terminal ANSI formatting, level filtering, history ring buffer, and custom sink callbacks.

* **Realm:** `shared`
* **Mod-Safe:** `mixed` (printing allowed, controls restricted)

```lua
modit.log.debug(msg, data) -- Prints a debug message. [Mod-Safe: yes]
modit.log.info(msg, data) -- Prints an informational message. [Mod-Safe: yes]
modit.log.success(msg, data) -- Prints a success message. [Mod-Safe: yes]
modit.log.warn(msg, data) -- Prints a warning message. [Mod-Safe: yes]
modit.log.error(msg, data) -- Prints an error message. [Mod-Safe: yes]
modit.log.fatal(msg, data) -- Triggers a fatal exit. [Mod-Safe: no]
modit.log.get_history() -- Retrieves recorded log entries. [Mod-Safe: no]
```

### `modit.window`

High-level window lifecycle, display configuration, and frame timing facade.

* **Realm:** `client`
* **Mod-Safe:** `no`

```lua
modit.window.get_size() -- Retrieves current window dimensions in pixels. [Mod-Safe: no]
modit.window.get_dt() -- Retrieves elapsed delta time in seconds between frames. [Mod-Safe: no]
modit.window.get_fps() -- Retrieves current rendering frame rate. [Mod-Safe: no]
modit.window.get_position() -- Retrieves current desktop position of the window. [Mod-Safe: no]
modit.window.set_position(x, y) -- Repositions the window on the desktop. [Mod-Safe: no]
modit.window.minimize() -- Minimizes the window to the OS taskbar. [Mod-Safe: no]
modit.window.request_close() -- Requests a clean exit after the current frame. [Mod-Safe: no]
modit.window.toggle_fullscreen() -- Toggles windowed and fullscreen display modes. [Mod-Safe: no]
modit.window.set_borderless(enabled) -- Sets whether the window runs in borderless mode. [Mod-Safe: no]
modit.window.set_topmost(enabled) -- Sets whether the window stays on top of others. [Mod-Safe: no]
modit.window.set_resizable(enabled) -- Enables or disables user window resizing. [Mod-Safe: no]
modit.window.set_decorated(enabled) -- Toggles window frame decorations (title bar and borders). [Mod-Safe: no]
modit.window.is_flag_enabled(name) -- Queries whether a specific window flag is active. [Mod-Safe: no]
```

---

## Client Modules

---

### `modit.camera`

Camera state holder for 2D and 3D rendering, with lifecycle event hooks. Create one with `modit.camera.new(cfg)`.

* **Realm:** `client`
* **Mod-Safe:** `mixed` (setters allowed, render passes restricted)

```lua
modit.camera.new(cfg) -- Creates a camera. cfg: x, y, z, target_x/y/z, fov, offset_x/y, target_2d_x/y, rotation, zoom. [Mod-Safe: no]

cam:begin_3d() -- Begins the 3D rendering pass. [Mod-Safe: no]
cam:end_3d() -- Ends the 3D rendering pass. [Mod-Safe: no]
cam:begin_2d() -- Begins the 2D rendering pass. [Mod-Safe: no]
cam:end_2d() -- Ends the 2D rendering pass. [Mod-Safe: no]
cam:on(event, fn) -- Registers a callback for "begin_3d", "end_3d", "begin_2d" or "end_2d". [Mod-Safe: no]

cam:set_position(x, y, z) -- Sets the 3D position. [Mod-Safe: yes]
cam:set_target(x, y, z) -- Sets the 3D look-at target. [Mod-Safe: yes]
cam:set_fov(fov) -- Sets the 3D field of view in degrees. [Mod-Safe: yes]
cam:set_offset(x, y) -- Sets the 2D screen offset. [Mod-Safe: yes]
cam:set_target_2d(x, y) -- Sets the 2D world target. [Mod-Safe: yes]
cam:set_zoom(zoom) -- Sets the 2D zoom (minimum 0.1). [Mod-Safe: yes]
cam:set_rotation(angle) -- Sets the 2D rotation in degrees. [Mod-Safe: yes]
```

### `modit.canvas`

Offscreen render targets for minimaps, secondary camera views, cached drawing and fixed-resolution rendering.

* **Realm:** `client`
* **Mod-Safe:** `no`

```lua
modit.canvas.new(width, height) -- Creates an offscreen render target.

canvas:get_size() -- Returns the width and height.
canvas:begin(r, g, b, a) -- Starts drawing into the canvas and clears it.
canvas:finish() -- Stops drawing into the canvas and returns to the screen.
canvas:draw(x, y, w, h) -- Draws the canvas stretched into a rectangle.
canvas:draw_fit(x, y, w, h) -- Draws the canvas letterboxed into a rectangle. Returns the drawn rectangle.
canvas:to_canvas(sx, sy) -- Converts screen coordinates to canvas coordinates, using the last drawn rectangle.
canvas:free() -- Frees the render target.
```

### `modit.draw`

2D and 3D drawing: shapes, colour state, text and scissor clipping. 3D calls only work between `cam:begin_3d()` and `cam:end_3d()`.

* **Realm:** `client`
* **Mod-Safe:** `yes`

```lua
modit.draw.set_colour(r_or_tbl, g_or_alpha, b, a) -- Sets the active colour for 2D and 3D using numbers or a colour table. (alias: set_color)
modit.draw.clear(r_or_tbl, g_or_alpha, b, a) -- Clears the target canvas using numbers or a colour table.

modit.draw.line(x1, y1, x2, y2) -- Draws a line.
modit.draw.rect(x, y, w, h) -- Draws a filled rectangle.
modit.draw.rect_lines(x, y, w, h) -- Draws a rectangle outline with 1px thickness.
modit.draw.rect_lines_ex(x, y, w, h, thick) -- Draws a rectangle outline with custom thickness.
modit.draw.rect_rounded(x, y, w, h, roundness, segments) -- Draws a filled rounded rectangle.
modit.draw.rect_rounded_lines(x, y, w, h, roundness, segments, thick) -- Draws a rounded rectangle outline.
modit.draw.circle(x, y, radius) -- Draws a filled circle.
modit.draw.circle_lines(x, y, radius) -- Draws a circle outline.
modit.draw.triangle(x1, y1, x2, y2, x3, y3) -- Draws a filled triangle.
modit.draw.triangle_lines(x1, y1, x2, y2, x3, y3) -- Draws a triangle outline.
modit.draw.ellipse(x, y, rx, ry) -- Draws a filled ellipse.
modit.draw.polygon(x, y, sides, radius, rotation) -- Draws a regular polygon.

modit.draw.line_3d(x1, y1, z1, x2, y2, z2) -- Draws a 3D line.
modit.draw.cube(x, y, z, w, h, l) -- Draws a filled cube.
modit.draw.cube_wires(x, y, z, w, h, l) -- Draws a wireframe cube.
modit.draw.plane(x, y, z, w, l) -- Draws a flat plane.
modit.draw.sphere(x, y, z, radius) -- Draws a filled sphere.
modit.draw.sphere_wires(x, y, z, radius, rings, slices) -- Draws a wireframe sphere.
modit.draw.grid(slices, spacing) -- Draws a ground grid centered on the origin.

modit.draw.text(str, x, y, size) -- Draws text with the default font.
modit.draw.measure_text(str, size) -- Returns text width and height.

modit.draw.push_clip(x, y, w, h) -- Pushes a clipping rectangle, clamped to the current one.
modit.draw.pop_clip() -- Pops the active clipping rectangle.
modit.draw.reset_clip() -- Clears every active clipping rectangle.
modit.draw.get_clip() -- Returns the active clipping rectangle, or nil.
```

### `modit.font`

Font handles: loading, glyph caching, text measurement and rendering. Loaded fonts are cached by path and size.

* **Realm:** `client`
* **Mod-Safe:** `mixed` (drawing and measuring allowed, loading and unloading restricted)

```lua
modit.font.load(path, size, codepoints) -- Loads a font at a pixel size. Returns a font handle, or nil and an error. [Mod-Safe: no]
modit.font.get(size, path) -- Returns a cached font, loading it on demand. Path defaults to the engine font. [Mod-Safe: yes]
modit.font.width(size, text) -- Measures text width at a size using the cached default font. [Mod-Safe: yes]
modit.font.cleanup() -- Unloads every cached font. [Mod-Safe: no]

font:draw(text, x, y) -- Draws text with this font and the current colour. [Mod-Safe: yes]
font:measure(text) -- Returns the width of text in this font. [Mod-Safe: yes]
font:unload() -- Unloads this font and clears its cache entry. [Mod-Safe: no]
```

### `modit.image`

Image and sprite sheet handles: loading, drawing and animation frames. Loaded images are cached by path.

* **Realm:** `client`
* **Mod-Safe:** `mixed` (drawing allowed, loading and unloading restricted)

```lua
modit.image.load(opts) -- Loads an image or sprite sheet from a path or { path, type, frame_width, frame_height, animations }. Returns an image handle or nil. [Mod-Safe: no]
modit.image.cleanup() -- Unloads every cached image. [Mod-Safe: no]

img:get_size() -- Returns the image width and height in pixels. [Mod-Safe: yes]
img:draw(x, y, scale, tint) -- Draws the whole image. [Mod-Safe: yes]
img:draw_frame(frame_x, frame_y, frame_w, frame_h, x, y, scale, tint) -- Draws a region of the image. [Mod-Safe: yes]
img:draw_sprite(anim, frame_idx, x, y, scale, tint) -- Draws a named animation frame (1-based). [Mod-Safe: yes]
img:unload() -- Unloads this image. [Mod-Safe: no]
```

### `modit.lighting`

Sun direction, ambient color, distance fog, and shadows (blob, projected, shadow map) for the 3D pass. Applied automatically by `cam:begin_3d()`.

* **Realm:** `client`
* **Mod-Safe:** `mixed` (setting parameters and lights allowed; shadow/map passes restricted)

```lua
modit.lighting.set_sun(dx, dy, dz, r, g, b) -- Sets the sun direction vector and colour. [Mod-Safe: yes]
modit.lighting.set_ambient(r, g, b) -- Sets the global ambient light colour. [Mod-Safe: yes]
modit.lighting.set_fog(near, far, r, g, b) -- Sets distance fog (without colour, fog follows the sky horizon). [Mod-Safe: yes]
modit.lighting.set_shadows(mode, strength, range) -- Sets shadow mode ("off", "blob", "projected", "map"), strength, and range. [Mod-Safe: yes]
modit.lighting.shadow_pass(draw_casters, ground_y) -- Draws shadow casters flattened onto a ground plane (mode "projected"). [Mod-Safe: no]
modit.lighting.shadow_map_pass(cam, draw_casters) -- Renders the shadow map from the sun (mode "map"). [Mod-Safe: no]
modit.lighting.blob(x, y, z, radius) -- Draws a soft blob shadow on the ground (mode "blob"). [Mod-Safe: yes]
modit.lighting.reset() -- Restores default lighting, fog, and shadows. [Mod-Safe: yes]
modit.lighting.set_local_lights(lights, blockers) -- Sets up to 8 area lights and 32 box shadow casters. [Mod-Safe: yes]
```

### `modit.model`

Loads, builds, draws and queries 3D models and meshes. Model assets are referenced by keys; draw options and instances share the same transform and tint fields.

* **Realm:** `client`
* **Mod-Safe:** `mixed` (drawing, instances and queries allowed; asset loading, material changes and unloading restricted)

```lua
modit.model.load({ key, path, replace? }) -- Loads OBJ, glTF/GLB, IQM, VOX or M3D from a path relative to the working directory. [Mod-Safe: no]
modit.model.build({ key, vertices, indices?, uvs?, colours?, normals? }) -- Builds/replaces a mesh; vertices are flat x,y,z values, optional indices are 1-based. [Mod-Safe: no]
modit.model.load_asset({ key, path, base_dir?, replace?, combine_vox_colours? }) -- Loads a Lua asset description or VOX scene; description references are relative to its folder. [Mod-Safe: no]
modit.model.draw({ key, x?, y?, z?, scale?, angle?, axis?, pivot?, tint? }) -- Draws an asset or instance; call inside a 3D camera pass. [Mod-Safe: yes]
modit.model.draw_many(instances, camera) -- Draws models with opaque batching and back-to-front blended parts. [Mod-Safe: yes]
modit.model.create_instance({ key, ... }) -- Creates an editable transform/tint instance for a loaded asset. [Mod-Safe: yes]
modit.model.attach(parent, name, child) -- Attaches a named child instance. [Mod-Safe: yes]
modit.model.detach(parent, name) -- Detaches a named child and returns it. [Mod-Safe: yes]
modit.model.get_part(parent, name) -- Gets an attached child instance. [Mod-Safe: yes]
modit.model.load_animations({ key, path? }) -- Loads skeletal animation clips for a model. [Mod-Safe: no]
modit.model.get_animations(key) -- Returns copied animation clip descriptions. [Mod-Safe: yes]
modit.model.play(instance, { clip?, fps?, speed?, loop? }) -- Starts independent playback; clip may be a 1-based index or name. [Mod-Safe: yes]
modit.model.update(instance, dt) -- Advances playback for an instance and its attached parts. [Mod-Safe: yes]
modit.model.pause(instance, paused) -- Pauses or resumes playback. [Mod-Safe: yes]
modit.model.stop(instance) -- Returns an instance to its bind pose. [Mod-Safe: yes]
modit.model.seek(instance, seconds) -- Sets the playback position in seconds. [Mod-Safe: yes]
modit.model.get_bounds(key_or_draw_options) -- Returns copied world-space min/max bounds. [Mod-Safe: yes]
modit.model.get_materials(key) -- Returns copied, 1-based material descriptions. [Mod-Safe: yes]
modit.model.set_material({ key, material?, texture?, tint?, emissive?, emissive_texture?, emissive_strength?, alpha_mode?, alpha_cutoff?, smooth?, double_sided?, cast_shadows? }) -- Changes asset-wide material settings and may load texture files. [Mod-Safe: no]
modit.model.screen_ray(camera, x, y, width?, height?) -- Creates a viewport-local world-space ray; width and height default to the window. [Mod-Safe: yes]
modit.model.raycast(instances, ray, max_distance?) -- Finds the nearest triangle hit; returns nil on a miss. [Mod-Safe: yes]
modit.model.unload(key) -- Unloads an asset and its owned textures. [Mod-Safe: no]
modit.model.cleanup() -- Unloads all model assets. [Mod-Safe: no]
```

### `modit.keyboard`

Keyboard input state tracking, text input, and OS clipboard access.

* **Realm:** `client`
* **Mod-Safe:** `mixed` (key state allowed, clipboard restricted)

```lua
modit.keyboard.down(key) -- Checks if a key is currently held down. [Mod-Safe: yes]
modit.keyboard.pressed(key) -- Checks if a key was pressed this frame. [Mod-Safe: yes]
modit.keyboard.released(key) -- Checks if a key was released this frame. [Mod-Safe: yes]
modit.keyboard.pressed_repeat(key) -- Checks if a key was pressed or repeated by key-repeat. [Mod-Safe: yes]
modit.keyboard.get_char() -- Gets the next queued Unicode character typed this frame. [Mod-Safe: yes]
modit.keyboard.get_clipboard() -- Retrieves text from the OS clipboard. [Mod-Safe: no]
modit.keyboard.set_clipboard(text) -- Sets text on the OS clipboard. [Mod-Safe: no]
```

### `modit.keymap`

Maps names to keyboard and mouse bindings. Prefer this over raw `keyboard` and `mouse` in games. Hold timers are advanced by the engine each frame.

* **Realm:** `client`
* **Mod-Safe:** `mixed` (mapping and queries allowed, global clear restricted)

```lua
modit.keymap.map(name, bindings, owner) -- Maps a name to a list of input bindings. [Mod-Safe: yes]
modit.keymap.pressed(name) -- Checks if a mapping was pressed this frame. [Mod-Safe: yes]
modit.keymap.down(name) -- Checks if a mapping is currently held down. [Mod-Safe: yes]
modit.keymap.released(name) -- Checks if a mapping was released this frame. [Mod-Safe: yes]
modit.keymap.hold_time(name) -- Gets how long a mapping has been held, in seconds. [Mod-Safe: yes]
modit.keymap.remove_owner(owner) -- Removes every mapping made by an owner (e.g. mod unload). [Mod-Safe: yes]
modit.keymap.clear() -- Removes every mapping. [Mod-Safe: no]
```

### `modit.sky`

Gradient sky backdrop that follows camera pitch. Draw it before `cam:begin_3d()`.

* **Realm:** `client`
* **Mod-Safe:** `mixed` (color configuration and horizon queries allowed; screen drawing restricted)

```lua
modit.sky.set(tr, tg, tb, hr, hg, hb) -- Sets sky top and horizon colours (0-255). [Mod-Safe: yes]
modit.sky.reset() -- Restores default sky colours. [Mod-Safe: yes]
modit.sky.get_horizon() -- Returns the horizon colour (used as default fog colour). [Mod-Safe: yes]
modit.sky.draw(cam, width, height) -- Draws the sky over the whole screen based on camera pitch and FOV. [Mod-Safe: no]
```

### `modit.mouse`

Mouse buttons, position, wheel, and cursor state.

* **Realm:** `client`
* **Mod-Safe:** `mixed` (reading input allowed, cursor control restricted)

```lua
modit.mouse.down(button) -- Checks if a button is currently held down. [Mod-Safe: yes]
modit.mouse.pressed(button) -- Checks if a button was pressed this frame. [Mod-Safe: yes]
modit.mouse.released(button) -- Checks if a button was released this frame. [Mod-Safe: yes]
modit.mouse.get_position() -- Retrieves screen coordinates of the cursor. [Mod-Safe: yes]
modit.mouse.get_x() -- Retrieves the cursor X position. [Mod-Safe: yes]
modit.mouse.get_y() -- Retrieves the cursor Y position. [Mod-Safe: yes]
modit.mouse.get_delta() -- Retrieves movement since the previous frame. [Mod-Safe: yes]
modit.mouse.get_wheel() -- Retrieves wheel movement for this frame. [Mod-Safe: yes]
modit.mouse.in_rect(x, y, w, h) -- Checks if the cursor is inside a rectangle. [Mod-Safe: yes]
modit.mouse.set_position(x, y) -- Repositions the cursor on screen. [Mod-Safe: no]
modit.mouse.set_cursor(name) -- Sets the active OS cursor icon. [Mod-Safe: no]
modit.mouse.show() -- Shows the system cursor. [Mod-Safe: no]
modit.mouse.hide() -- Hides the system cursor. [Mod-Safe: no]
modit.mouse.lock() -- Locks and hides the cursor inside the window for 3D camera control. [Mod-Safe: no]
modit.mouse.unlock() -- Restores normal cursor behaviour. [Mod-Safe: no]
```

### `modit.postfx`

Post-processing for the 3D scene: pixelation, colour grade, vignette, PS1-style colour quantising with dithering, and optional custom shaders.

* **Realm:** `client`
* **Mod-Safe:** `mixed` (effects allowed, custom shaders restricted)

```lua
modit.postfx.enable(opts) -- Turns post-processing on. opts: pixel_size, saturation, contrast, brightness, vignette, colour_levels, dither, shader { vertex, fragment }. [Mod-Safe: yes, without opts.shader]
modit.postfx.disable() -- Turns post-processing off. [Mod-Safe: yes]
modit.postfx.reset() -- Turns post-processing off and restores the defaults. [Mod-Safe: yes]
modit.postfx.get_size() -- Returns the size scene drawing should use (low-res canvas when enabled, else the window). [Mod-Safe: yes]
modit.postfx.begin_scene(r, g, b) -- Starts drawing the scene at scene size with a clear colour. Does nothing when post is off. [Mod-Safe: yes]
modit.postfx.end_scene() -- Finishes the scene and draws it through the post effects. [Mod-Safe: yes]
```

### `modit.ui`

Collection of premade UI components and overlays.

* **Realm:** `client`
* **Mod-Safe:** `yes`

```lua
modit.ui.button(label?, x, y, width, height, opts?) -- Draws an interactive button supporting text, icons, custom radii, font handles, and styling. Returns boolean.
modit.ui.item(label?, sub?, x, y, width, height, opts?) -- Draws an interactive list item row supporting main text, subtext, icons, and custom styling. Returns boolean.
modit.ui.label(str?, x, y, size?, colour?) -- Renders a static text label with optional font size, colour, or opts table.
modit.ui.panel(x, y, width, height, title?, opts?) -- Renders a structural panel container with an optional title header. Supports custom radius and color overrides.
modit.ui.scroll_begin(state, x, y, w, h, content_h) -- Begins a scroll viewport clip area and handles wheel input. Returns max scroll offsetdropdown.
modit.ui.scroll_finish() -- Ends the scroll viewport and renders the vertical scrollbar track/thumb if neededdropdown.
modit.ui.splitter(x, y, w, h, axis, value, dir) -- Renders an interactive panel divider and returns updated dimension and dragging statedropdown.
modit.ui.textfield(state, x, y, w, h, filter?, holder?) -- Renders an interactive text input field with focus and cursor tracking. Returns submitted boolean[cite: 16].
modit.ui.build_dropdown(menu_id, label, x, y, w, h, items) -- Renders a stateful dropdown menu button and handles popup overlay interactions. Returns index, sub_index.
modit.ui.close_dropdown() -- Closes all active dropdown menus and submenus.
modit.ui.open_modal(opts) -- Opens a modal confirmation/input dialog.
modit.ui.close_modal() -- Closes the active modal.
modit.ui.is_modal_open() -- Returns true if a modal is currently open.
modit.ui.draw_modal(w, h) -- Renders the active modal overlay and processes input.
```

---

## Server Modules

---

## Shared Modules

Modules available across both client and server realms.

---

### `modit.commands`

Console command registry supporting engine and game layers, plus optional built-ins.

* **Realm:** `shared` (accessible to Engine and Game)
* **Mod-Safe:** `no` (Restricted to Game and Engine tiers; mods use hooks instead)

```lua
modit.commands.register(name, fn, help) -- Registers a game console command.
modit.commands.run(line) -- Parses and runs a raw command line input string.
modit.commands.list() -- Returns a sorted list of all registered commands.
modit.commands.register_builtins(realm, opts) -- Registers optional built-in console commands based on configuration.
```

### `modit.hooks`

Event hook system where listeners can be tagged with an owner so a whole mod can be unhooked at once.

* **Realm:** `shared`
* **Mod-Safe:** `mixed` (listeners and safe firing allowed; global clears restricted)

```lua
modit.hooks.register(name, description) -- Declares a hook name with an optional description. [Mod-Safe: no]
modit.hooks.listen(name, callback, owner) -- Adds a listener to a hook with an optional owner tag. [Mod-Safe: yes]
modit.hooks.fire(name, ...) -- Calls every listener of a hook in order. [Mod-Safe: yes]
modit.hooks.unlisten(name, callback) -- Removes a specific listener function. [Mod-Safe: yes]
modit.hooks.remove_owner(owner) -- Removes every listener tagged with a specific owner (e.g. mod unload). [Mod-Safe: yes]
modit.hooks.list() -- Lists all declared hook names. [Mod-Safe: yes]
modit.hooks.clear(name) -- Removes every listener of one hook. [Mod-Safe: no]
modit.hooks.clear_all() -- Removes every listener of every hook. [Mod-Safe: no]
```

### `modit.geometry`

Dedicated 2D and 3D spatial primitives, measurements, and intersection query functions.

* **Realm:** `shared`
* **Mod-Safe:** `yes`

```lua
modit.geometry.circle_circumference(radius) -- Calculates the circumference of a circle.
modit.geometry.circle_area(radius) -- Calculates the area of a circle.
modit.geometry.triangle_area(p1, p2, p3) -- Calculates the area of a triangle using its 2D vertices.
modit.geometry.distance_2d(p1, p2) -- Calculates the distance between two 2D points.
modit.geometry.is_point_in_rect(p, rect) -- Determines if a point is inside or on a rectangle { x, y, width, height }.
modit.geometry.is_point_on_line_segment(p, line_start, line_end, tolerance?) -- Determines if a point lies on a line segment.
modit.geometry.project_point_on_line(p, p1, p2) -- Projects a point onto an infinite line.
modit.geometry.calculate_slope(p1, p2) -- Calculates the slope of a line (nil for a vertical line).
modit.geometry.angle_between_points(p1, p2) -- Returns the angle from p1 to p2 in degrees.
modit.geometry.do_rects_intersect(a, b) -- Determines if two rectangles overlap or touch.
modit.geometry.do_circles_intersect(c1_center, c1_radius, c2_center, c2_radius) -- Determines if two circles intersect or touch.
modit.geometry.is_point_in_circle(p, circle_center, circle_radius) -- Determines if a point is inside or on a circle.
modit.geometry.do_lines_intersect(a, b, c, d) -- Determines if two line segments intersect or touch.
modit.geometry.line_intersects_circle(line_start, line_end, circle_center, circle_radius) -- Determines if a line segment intersects or touches a circle.
modit.geometry.does_rect_intersect_line(rect, line_start, line_end) -- Determines if a rectangle intersects a line segment.
modit.geometry.closest_point_on_line_segment(p, line_start, line_end) -- Finds the closest point on a segment to a given point.
modit.geometry.is_point_in_convex_polygon(p, polygon) -- Determines if a point is inside or on a convex polygon.
modit.geometry.rotate_point_around_point_2d(p, pivot, angle_degrees) -- Rotates a point around a pivot by an angle in degrees.

modit.geometry.distance_3d(a, b) -- Calculates the distance between two 3D points.
modit.geometry.midpoint_3d(a, b) -- Returns the midpoint between two 3D points.
modit.geometry.is_point_in_box_3d(p, box) -- Determines if a point is inside or on a 3D box { x, y, z, width, height, depth }. Negative sizes are supported.
modit.geometry.angle_between_three_points_3d(p1, p2, p3) -- Calculates the angle at the second point in degrees.
modit.geometry.triangle_area_3d(p1, p2, p3) -- Calculates the area of a triangle in 3D space.
modit.geometry.is_point_in_sphere(p, sphere_center, sphere_radius) -- Determines if a point is inside or on a sphere.
modit.geometry.do_spheres_intersect(s1_center, s1_radius, s2_center, s2_radius) -- Determines if two spheres intersect or touch.
modit.geometry.distance_point_to_plane_3d(p, plane_point, plane_normal) -- Calculates the shortest distance from a point to a plane.
modit.geometry.normalize_vector_3d(v) -- Normalizes a 3D vector.
```

### `modit.mat4`

4x4 matrix utilities for 3D transformations.

* **Realm:** `shared`
* **Mod-Safe:** `yes`

```lua
modit.mat4.new(values?) -- Creates a new 4x4 matrix, defaulting to an identity matrix if values are omitted.
modit.mat4.translate(x, y, z) -- Creates a translation matrix.
modit.mat4.scale(sx, sy, sz) -- Creates a scale matrix.
modit.mat4.rotate_euler(rx, ry, rz) -- Creates a rotation matrix from Euler angles (XYZ order).
modit.mat4.rotate_axis(axis, angle) -- Creates a rotation matrix around an arbitrary axis.
modit.mat4.perspective(fov, aspect, near, far) -- Creates an OpenGL-style perspective projection matrix.
modit.mat4.orthographic(left, right, bottom, top, near, far) -- Creates an OpenGL-style orthographic projection matrix.
modit.mat4.look_at(eye, target, up) -- Creates a right-handed look-at view matrix.

--- local matrix = modit.mat4.new(values?)
matrix:multiply(other) -- Multiplies this matrix by another matrix instance.
matrix:multiply_vec3(v) -- Transforms a 3D position vector using homogeneous coordinates (w = 1).
matrix:transpose() -- Transposes the matrix rows and columns.
matrix:invert() -- Inverts the matrix using Gauss-Jordan elimination.
matrix:get_translation() -- Extracts translation components from the matrix.
matrix:get_scale() -- Extracts scale magnitudes from the transformation basis.
matrix:raw() -- Returns the underlying raw 16-element column-major array.
matrix * other -- Metamethod supporting matrix multiplication using the * operator.
```

### `modit.maths`

Shared math, easing, probability, and statistics functions. All functions are called directly on `modit.maths`.

* **Realm:** `shared`
* **Mod-Safe:** `yes`

```lua
modit.maths.round(number, decimals) -- Rounds a number to the specified number of decimal places.
modit.maths.clamp(val, lower, upper) -- Clamps a value within a specified range, swapping bounds if needed.
modit.maths.lerp(a, b, t) -- Linearly interpolates between two values without clamping t.
modit.maths.factorial(n) -- Calculates the factorial of a non-negative integer.
modit.maths.deg_to_rad(deg) -- Converts degrees to radians.
modit.maths.rad_to_deg(rad) -- Converts radians to degrees.

modit.maths.ease_linear(t) -- Linear easing (no curve).
modit.maths.ease_in_quad(t) -- Quadratic ease-in.
modit.maths.ease_out_quad(t) -- Quadratic ease-out.
modit.maths.ease_in_out_quad(t) -- Quadratic ease-in-out.
modit.maths.ease_in_cubic(t) -- Cubic ease-in.
modit.maths.ease_out_cubic(t) -- Cubic ease-out.
modit.maths.ease_in_out_cubic(t) -- Cubic ease-in-out.
modit.maths.ease_out_elastic(t) -- Elastic ease-out.

modit.maths.mean(numbers) -- Calculates the mean (average) of a list of numbers.
modit.maths.median(numbers) -- Calculates the median of a list of numbers.
modit.maths.mode(numbers) -- Calculates the mode (most frequent value), returning nil on a tie.
modit.maths.variance(numbers, population?) -- Calculates the variance of a dataset.
modit.maths.std_dev(numbers, population?) -- Calculates the standard deviation of a dataset.
modit.maths.range(numbers) -- Calculates the range (maximum minus minimum).
modit.maths.min(numbers) -- Calculates the minimum value in a dataset.
modit.maths.max(numbers) -- Calculates the maximum value in a dataset.
modit.maths.sum(numbers) -- Calculates the sum of a dataset.
modit.maths.quantile(numbers, q) -- Calculates a quantile using linear interpolation between sorted values.
modit.maths.linear_regression(points) -- Performs ordinary least-squares linear regression on 2D points.
modit.maths.correlation(x, y) -- Calculates the Pearson correlation coefficient between two datasets.
modit.maths.covariance(x, y, population?) -- Calculates covariance between two datasets.

modit.maths.set_seed(seed) -- Sets the global random seed for reproducibility.
modit.maths.random_between(min, max, rand_func?) -- Returns a random float between min and max.
modit.maths.random_int(min, max, rand_func?) -- Returns a random integer between min and max inclusive.
modit.maths.random_chance(probability, rand_func?) -- Check if something happens with a given probability (0.0 to 1.0).
modit.maths.random_percent_chance(percentage, rand_func?) -- Check if something happens with a given percentage chance (0 to 100).
modit.maths.random_choice(tbl, rand_func?) -- Selects a random element from a dense array.
modit.maths.random_weighted_choice(map, rand_func?) -- Selects a random key from a table of weighted options.
modit.maths.random_shuffle(tbl, rand_func?) -- Shuffles a dense array in-place using Fisher-Yates.
modit.maths.random_normal(mean?, stddev?, rand_func?) -- Generates a random value from a normal (Gaussian) distribution.
modit.maths.random_exponential(lambda, rand_func?) -- Generates a random value from an exponential distribution.
modit.maths.random_uniform(min, max, rand_func?) -- Generates a random value from a uniform distribution (alias for random_between).
```

### `modit.vector`

Instance-oriented vector math module supporting 2D, 3D, and 4D vectors.

* **Realm:** `shared`
* **Mod-Safe:** `yes`

```lua
modit.vector.vec2(x?, y?) -- Creates a new 2D vector
modit.vector.vector2(x?, y?) -- vec2 alias
modit.vector.vec3(x?, y?, z?) -- Creates a new 3D vector
modit.vector.vector3(x?, y?, z?) -- vec3 alias
modit.vector.vec4(x?, y?, z?, w?) -- Creates a new 4D vector
modit.vector.vector4(x?, y?, z?, w?) -- vec4 alias

v:clone() -- Creates a copy of the vector
v:set(...) -- Sets vector components in-place
v:add(other) -- Adds two vectors
v:sub(other) -- Subtracts another vector
v:scale(scalar) -- Returns the vector scaled by a scalar
v:dot(other) -- Calculates the dot product
v:cross(other) -- Calculates the cross product (2D scalar, 3D vector)
v:length() -- Calculates the vector's magnitude
v:length_squared() -- Calculates the squared magnitude
v:distance(other) -- Calculates the Euclidean distance
v:distance_squared(other) -- Calculates the squared distance
v:normalize() -- Returns a unit vector; zero vector if near zero
v:is_zero() -- Checks if the vector is near zero
v:lerp(other, t) -- Linearly interpolates between vectors
v:angle() -- Returns the 2D vector's angle in radians
v:rotate(angle) -- Rotates a 2D vector by radians
v:perpendicular() -- Returns a perpendicular 2D vector
v:xyz() -- Extracts a Vec3 from a Vec4
```