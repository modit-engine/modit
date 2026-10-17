# API Cheatsheet

All functions are called through the `modit` global, e.g. `modit.draw2d.rect(...)`.

* `[mod]` usable by mods, games and the engine
* `[game]` games and the engine only
* Engine-only functions are not listed

---

## Client Modules

All modules that run exclusively on the client, managing window presentation, user input, audio playback, rendering, and user interfaces.

### modit.window

```lua
modit.window.get_size() -- Retrieves current window dimensions in pixels. [mod]
modit.window.get_dt() -- Retrieves elapsed delta time in seconds between frames. [mod]
modit.window.get_fps() -- Retrieves current rendering frame rate. [mod]
modit.window.get_position() -- Retrieves current desktop position of the window. [mod]
modit.window.set_position(x, y) -- Repositions the window on the desktop. [game]
modit.window.minimize() -- Minimizes the window to the OS taskbar. [game]
modit.window.request_close() -- Requests a clean exit after the current frame. [game]
modit.window.toggle_fullscreen() -- Toggles windowed and fullscreen display modes. [game]
modit.window.set_borderless(enabled) -- Sets whether the window runs in borderless mode. [game]
modit.window.set_topmost(enabled) -- Sets whether the window stays on top of others. [game]
modit.window.set_resizable(enabled) -- Enables or disables user window resizing. [game]
modit.window.set_decorated(enabled) -- Toggles window frame decorations (title bar and borders). [game]
modit.window.toggle_flag(name, enabled) -- Toggles or sets backend window configuration flag. [game]
modit.window.is_flag_enabled(name) -- Queries whether a specific window flag is active. [game]

```

Config: `window = { exit_key = true }` in `game/config.lua` lets ESC close the window. It is off by default.

### modit.audio

```lua
modit.audio.load_sound(path) -- Loads a sound effect. Returns a sound handle, or nil on failure. [mod]
modit.audio.load_music(path) -- Loads a music track. Returns a music handle, or nil on failure. [mod]
modit.audio.stop_music() -- Stops the current music. [mod]
modit.audio.pause_music() -- Pauses the current music. [mod]
modit.audio.resume_music() -- Resumes the current music. [mod]
modit.audio.is_music_playing() -- Checks if music is playing. [mod]

sound:play() -- Plays the sound effect. [mod]
sound:set_volume(volume) -- Sets volume, 0.0 to 1.0. [mod]
sound:set_pitch(pitch) -- Sets pitch, 1.0 is normal. [mod]
sound:unload() -- Unloads the sound. [mod]

music:play(loop) -- Plays the track, stopping any current music. [mod]
music:set_volume(volume) -- Sets volume, 0.0 to 1.0. [mod]
music:set_pitch(pitch) -- Sets pitch, 1.0 is normal. [mod]
music:unload() -- Unloads the track. [mod]

```

### modit.input

```lua
-- Keyboard
modit.input.key_down(key) -- Checks if a key is currently held down [mod]
modit.input.key_pressed(key) -- Checks if a key was pressed this frame [mod]
modit.input.key_released(key) -- Checks if a key was released this frame [mod]
modit.input.key_pressed_repeat(key) -- Checks if a key was pressed or auto-repeated this frame [mod]
modit.input.get_char() -- Gets the next Unicode character typed this frame [mod]

-- Clipboard
modit.input.get_clipboard() -- Retrieves text from the OS clipboard [game]
modit.input.set_clipboard(text) -- Sets text on the OS clipboard [game]

-- Mouse Position
modit.input.get_mouse_position() -- Gets the cursor position in screen space [mod]
modit.input.get_mouse_x() -- Gets the cursor X position [mod]
modit.input.get_mouse_y() -- Gets the cursor Y position [mod]
modit.input.get_mouse_delta() -- Gets cursor movement since the previous frame [mod]
modit.input.get_mouse_wheel() -- Gets wheel movement for this frame [mod]
modit.input.set_mouse_position(x, y) -- Moves the cursor [game]
modit.input.mouse_in_rect(x, y, w, h) -- Checks if the cursor is inside a rectangle [mod]

-- Mouse Buttons
modit.input.mouse_pressed(button) -- Checks if a button was pressed this frame [mod]
modit.input.mouse_down(button) -- Checks if a button is held down [mod]
modit.input.mouse_released(button) -- Checks if a button was released this frame [mod]

-- Cursor
modit.input.set_cursor(name) -- Sets the OS cursor icon [mod]
modit.input.show_cursor() -- Shows the system cursor [game]
modit.input.hide_cursor() -- Hides the system cursor [game]
modit.input.lock_mouse() -- Locks and hides the cursor inside the window for 3D camera control [game]
modit.input.unlock_mouse() -- Unlocks the cursor and restores normal behaviour [game]

-- Actions
modit.input.map_action(name, bindings, owner) -- Maps an action name to a list of input bindings [mod]
modit.input.action_pressed(name) -- Checks if an action was pressed this frame [mod]
modit.input.action_down(name) -- Checks if an action is held down [mod]
modit.input.action_released(name) -- Checks if an action was released this frame [mod]
modit.input.get_action_hold_time(name) -- Gets how long an action has been held [mod]
modit.input.clear_owner_actions(owner) -- Removes every action made by an owner [mod]
modit.input.clear_actions() -- Removes every action [game]

```

### modit.canvas

```lua
modit.canvas.new(width, height) -- Creates an offscreen render target. [mod]

canvas:get_size() -- Returns the width and height. [mod]
canvas:begin(r, g, b, a) -- Starts drawing into the canvas and clears it. [mod]
canvas:finish() -- Stops drawing into the canvas and returns to the screen. [mod]
canvas:draw(x, y, w, h) -- Draws the canvas stretched into a rectangle. [mod]
canvas:draw_fit(x, y, w, h) -- Draws the canvas letterboxed into a rectangle. Returns the drawn rectangle. [mod]
canvas:to_canvas(sx, sy) -- Converts screen coordinates to canvas coordinates, using the last drawn rectangle. [mod]
canvas:free() -- Frees the render target. [mod]

```

### modit.camera

```lua
modit.camera.new(cfg) -- Creates a camera. cfg may set x, y, z, target_x, target_y, target_z, fov, offset_x, offset_y, target_2d_x, target_2d_y, rotation and zoom. [mod]

camera:begin_3d() -- Starts 3D rendering through this camera. [mod]
camera:end_3d() -- Ends 3D rendering. [mod]
camera:begin_2d() -- Starts 2D rendering through this camera. [mod]
camera:end_2d() -- Ends 2D rendering. [mod]
camera:on(event, fn) -- Runs a function on "begin_3d", "end_3d", "begin_2d" or "end_2d". [mod]
camera:set_position(x, y, z) -- Sets the 3D position. [mod]
camera:set_target(x, y, z) -- Sets the 3D look-at point. [mod]
camera:set_fov(fov) -- Sets the field of view in degrees. [mod]
camera:set_offset(x, y) -- Sets the 2D screen offset. [mod]
camera:set_target_2d(x, y) -- Sets the 2D world target. [mod]
camera:set_zoom(zoom) -- Sets the 2D zoom, minimum 0.1. [mod]
camera:set_rotation(angle) -- Sets the 2D rotation in degrees. [mod]

```

### modit.draw2d

```lua
modit.draw2d.set_colour(r_or_tbl, g_or_alpha, b, a) -- Sets active drawing colour for 2D using numbers or a colour table. (alias: set_color) [mod]
modit.draw2d.clear(r_or_tbl, g_or_alpha, b, a) -- Clears the target canvas using numbers or a colour table. [mod]

modit.draw2d.line(x1, y1, x2, y2) -- Draws a line. [mod]
modit.draw2d.rect(x, y, w, h) -- Draws a filled rectangle. [mod]
modit.draw2d.rect_lines(x, y, w, h) -- Draws a rectangle outline with 1px thickness. [mod]
modit.draw2d.rect_lines_ex(x, y, w, h, thick) -- Draws a rectangle outline with custom thickness. [mod]
modit.draw2d.rect_rounded(x, y, w, h, roundness, segments) -- Draws a filled rounded rectangle. [mod]
modit.draw2d.rect_rounded_lines(x, y, w, h, roundness, segments, thick) -- Draws a rounded rectangle outline. [mod]
modit.draw2d.circle(x, y, radius) -- Draws a filled circle. [mod]
modit.draw2d.circle_lines(x, y, radius) -- Draws a circle outline. [mod]
modit.draw2d.triangle(x1, y1, x2, y2, x3, y3) -- Draws a filled triangle. [mod]
modit.draw2d.triangle_lines(x1, y1, x2, y2, x3, y3) -- Draws a triangle outline. [mod]
modit.draw2d.ellipse(x, y, rx, ry) -- Draws a filled ellipse. [mod]
modit.draw2d.polygon(x, y, sides, radius, rotation) -- Draws a regular polygon. [mod]

modit.draw2d.text(str, x, y, size) -- Draws text with the default font. [mod]
modit.draw2d.measure_text(str, size) -- Returns text width and height. [mod]

modit.draw2d.push_clip(x, y, w, h) -- Pushes a clipping rectangle, clamped to the current one. [mod]
modit.draw2d.pop_clip() -- Pops the active clipping rectangle. [mod]
modit.draw2d.reset_clip() -- Clears every active clipping rectangle. [mod]
modit.draw2d.get_clip() -- Returns the active clipping rectangle, or nil. [mod]

```

### modit.draw3d

```lua
modit.draw3d.set_colour(r_or_tbl, g_or_alpha, b, a) -- Sets active drawing colour for 3D using numbers or a colour table. [mod]
modit.draw3d.line(x1, y1, z1, x2, y2, z2) -- Draws a 3D line. [mod]
modit.draw3d.cube(x, y, z, w, h, l) -- Draws a filled cube. [mod]
modit.draw3d.cube_wires(x, y, z, w, h, l) -- Draws a wireframe cube. [mod]
modit.draw3d.plane(x, y, z, w, l) -- Draws a flat plane. [mod]
modit.draw3d.sphere(x, y, z, radius) -- Draws a filled sphere. [mod]
modit.draw3d.sphere_wires(x, y, z, radius, rings, slices) -- Draws a wireframe sphere. [mod]
modit.draw3d.grid(slices, spacing) -- Draws a ground grid centered on the origin. [mod]

```

### modit.font

```lua
modit.font.load(path, size, codepoints) -- Loads a font at a pixel size. Returns a font handle, or nil and an error. [mod]
modit.font.get(size, path) -- Returns a cached font, loading it on demand. Path defaults to the engine font. [mod]
modit.font.width(size, text) -- Measures text width at a size using the cached default font. [mod]
modit.font.cleanup() -- Unloads every cached font. [game]

font:draw(text, x, y) -- Draws text with this font and the current colour. [mod]
font:measure(text) -- Returns the width of text in this font. [mod]
font:unload() -- Unloads this font and clears its cache entry. [mod]

```

### modit.image

```lua
modit.image.load(opts) -- Loads an image or sprite sheet from a path or { path, type, frame_width, frame_height, animations }. Returns an image handle or nil. [mod]
modit.image.cleanup() -- Unloads every cached image. [game]

img:get_size() -- Returns the image width and height in pixels. [mod]
img:draw(x, y, scale, tint) -- Draws the whole image. [mod]
img:draw_frame(frame_x, frame_y, frame_w, frame_h, x, y, scale, tint) -- Draws a region of the image. [mod]
img:draw_sprite(anim, frame_idx, x, y, scale, tint) -- Draws a named animation frame (1-based). [mod]
img:unload() -- Unloads this image. [mod]

```

### modit.model

```lua
modit.model.load({ key, path, replace? }) -- Loads OBJ, glTF/GLB, IQM, VOX or M3D from a path relative to the working directory. [mod]
modit.model.build({ key, vertices, indices?, uvs?, colours?, normals? }) -- Builds/replaces a mesh; vertices are flat x,y,z values, optional indices are 1-based. [mod]
modit.model.load_asset({ key, path, base_dir?, replace?, combine_vox_colours? }) -- Loads a Lua asset description or VOX scene; description references are relative to its folder. [mod]
modit.model.draw({ key, x?, y?, z?, scale?, angle?, axis?, pivot?, tint? }) -- Draws an asset or instance; call inside a 3D camera pass. [mod]
modit.model.draw_many(instances, camera) -- Draws models with opaque batching and back-to-front blended parts. [mod]
modit.model.create_instance({ key, ... }) -- Creates an editable transform/tint instance for a loaded asset. [mod]
modit.model.attach(parent, name, child) -- Attaches a named child instance. [mod]
modit.model.detach(parent, name) -- Detaches a named child and returns it. [mod]
modit.model.get_part(parent, name) -- Gets an attached child instance. [mod]
modit.model.load_animations({ key, path? }) -- Loads skeletal animation clips for a model. [mod]
modit.model.get_animations(key) -- Returns copied animation clip descriptions. [mod]
modit.model.play(instance, { clip?, fps?, speed?, loop? }) -- Starts independent playback; clip may be a 1-based index or name. [mod]
modit.model.update(instance, dt) -- Advances playback for an instance and its attached parts. [mod]
modit.model.pause(instance, paused) -- Pauses or resumes playback. [mod]
modit.model.stop(instance) -- Returns an instance to its bind pose. [mod]
modit.model.seek(instance, seconds) -- Sets the playback position in seconds. [mod]
modit.model.get_bounds(key_or_draw_options) -- Returns copied world-space min/max bounds. [mod]
modit.model.get_materials(key) -- Returns copied, 1-based material descriptions. [mod]
modit.model.set_material({ key, material?, texture?, tint?, emissive?, emissive_texture?, emissive_strength?, alpha_mode?, alpha_cutoff?, smooth?, double_sided?, cast_shadows? }) -- Changes asset-wide material settings and may load texture files. [mod]
modit.model.screen_ray(camera, x, y, width?, height?) -- Creates a viewport-local world-space ray; width and height default to the window. [mod]
modit.model.raycast(instances, ray, max_distance?) -- Finds the nearest triangle hit; returns nil on a miss. [mod]
modit.model.unload(key) -- Unloads an asset and its owned textures. [mod]
modit.model.cleanup() -- Unloads all model assets. [game]

```

### modit.environment

```lua
-- Lighting
modit.environment.set_sun(dx, dy, dz, r, g, b) -- Sets the sun direction and colour [mod]
modit.environment.set_ambient(r, g, b) -- Sets the ambient light colour [mod]
modit.environment.set_fog(near, far, r, g, b) -- Sets distance fog. Without a colour, fog follows the sky horizon [mod]
modit.environment.set_shadows(mode, strength, range) -- Sets the shadow mode [mod]
modit.environment.shadow_pass(draw_casters, ground_y) -- Draws shadow casters flattened onto a ground plane along the sun direction. [game]
modit.environment.shadow_map_pass(cam, draw_casters) -- Renders the shadow map from the sun. [game]
modit.environment.draw_blob_shadow(x, y, z, radius) -- Draws a soft blob shadow on the ground. [game]
modit.environment.reset_lighting() -- Restores the default lighting, fog and shadows [mod]
modit.environment.set_local_lights(lights, blockers) -- Sets up to eight world-space area lights and 32 box shadow casters. [mod]

-- Sky
modit.environment.set_sky(tr, tg, tb, hr, hg, hb) -- Sets the sky colours [mod]
modit.environment.reset_sky() -- Restores the default sky colours [mod]
modit.environment.get_sky_horizon() -- Gets the horizon colour (the default fog colour) [mod]
modit.environment.draw_sky(cam, width, height) -- Draws the sky over the whole screen, horizon placed by camera pitch and fov [mod]

-- Post Processing
modit.environment.enable_postfx(opts) -- Turns post-processing on. Unlisted options go back to their defaults [mod]
modit.environment.disable_postfx() -- Turns post-processing off [mod]
modit.environment.get_scene_size() -- Gets the size scene drawing should use: the low-resolution canvas when enabled, else the window [mod]
modit.environment.begin_scene(r, g, b) -- Starts drawing the scene (sky and 3D). Everything until end_scene is drawn at scene size. [mod]
modit.environment.end_scene() -- Finishes the scene and draws it to the window through the post effects [mod]
modit.environment.reset_postfx() -- Turns post-processing off and restores the defaults [mod]

-- Water
modit.environment.set_water(opts) -- Sets up the water and turns it on [mod]
modit.environment.set_water_enabled(flag) -- Turns the water on or off without losing its settings [mod]
modit.environment.draw_water() -- Draws the water. Call last inside camera begin_3d/end_3d, after the opaque scene [mod]
modit.environment.get_water_height(x, z) -- Gets the water surface height at a point, matching what is drawn (for boats and floating objects) [mod]
modit.environment.reset_water() -- Turns the water off, frees its mesh and restores the defaults [mod]

```

### modit.ui

```lua
modit.ui.button(label?, x, y, width, height, opts?) -- Draws an interactive button supporting text, icons, custom radii, font handles, and styling. Returns boolean. [mod]
modit.ui.item(label?, sub?, x, y, width, height, opts?) -- Draws an interactive list item row supporting main text, subtext, icons, and custom styling. Returns boolean. [mod]
modit.ui.label(str?, x, y, size?, colour?) -- Renders a static text label with optional font size, colour, or opts table. [mod]
modit.ui.panel(x, y, width, height, title?, opts?) -- Renders a structural panel container with an optional title header. Supports custom radius and color overrides. [mod]
modit.ui.scroll_begin(state, x, y, w, h, content_h) -- Begins a scroll viewport clip area and handles wheel input. Returns max scroll offset. [mod]
modit.ui.scroll_finish() -- Ends the scroll viewport and renders the vertical scrollbar track/thumb if needed. [mod]
modit.ui.splitter(x, y, w, h, axis, value, dir) -- Renders an interactive panel divider and returns updated dimension and dragging state. [mod]
modit.ui.textfield(state, x, y, w, h, filter?, holder?) -- Renders an interactive text input field with focus and cursor tracking. Returns submitted boolean. [mod]
modit.ui.toggle(value, x, y, w, h, opts?) -- Draws a square on/off switch. Returns true on the frame it is clicked, so the caller flips the value. opts.passive draws it without handling clicks. [mod]
modit.ui.build_dropdown(menu_id, label, x, y, w, h, items) -- Renders a stateful dropdown menu button and handles popup overlay interactions. Returns index, sub_index. [mod]
modit.ui.close_dropdown() -- Closes all active dropdown menus and submenus. [mod]
modit.ui.open_modal(opts) -- Opens a modal confirmation/input dialog. [mod]
modit.ui.close_modal() -- Closes the active modal. [mod]
modit.ui.is_modal_open() -- Returns true if a modal is currently open. [mod]
modit.ui.draw_modal(w, h) -- Renders the active modal overlay and processes input. [mod]

```

---

## Shared Modules

Modules and utility libraries available across both client and server environments, handling data serialization, logging, mathematics, physics, and mod extensibility.

### modit.json

```lua
modit.json.encode(value) -- Encodes a Lua value as JSON. [mod]
modit.json.decode(input) -- Decodes a JSON string into a Lua value. [mod]

```

### modit.log

```lua
modit.log.get_history() -- Retrieves recorded log entries. [mod]
modit.log.debug(msg, data) -- Prints a debug message. [mod]
modit.log.info(msg, data) -- Prints an informational message. [mod]
modit.log.success(msg, data) -- Prints a success message. [mod]
modit.log.warn(msg, data) -- Prints a warning message. [mod]
modit.log.error(msg, data) -- Prints an error message. [mod]
modit.log.print(level, msg, data) -- Prints a message at the given level. [mod]
modit.log.fatal(msg, data) -- Triggers a fatal exit. [game]

```

### modit.runtime

```lua
-- Timers
modit.runtime.after(delay, fn, owner) -- Run a function once after a delay [mod]
modit.runtime.every(interval, fn, count, owner) -- Run a function repeatedly at a given interval [mod]
modit.runtime.clear_timers() -- Clear all active timers [game]
modit.runtime.clear_owner_timers(owner) -- Cancel every timer registered by an owner [game]

-- Cooldowns
modit.runtime.add_cooldown(id, kind, duration) -- Start a cooldown for a given id + kind [mod]
modit.runtime.has_cooldown(id, kind) -- Check if a cooldown is still active [mod]
modit.runtime.get_cooldown(id, kind) -- Get remaining time on cooldown (0 if none) [mod]
modit.runtime.clear_cooldown(id, kind) -- Clear a specific cooldown [mod]
modit.runtime.clear_cooldowns(id) -- Remove all cooldowns for a given id [mod]

-- Random
modit.runtime.set_seed(s) -- Sets the seed for the RNG [game]
modit.runtime.get_seed() -- Gets the last set seed value [mod]
modit.runtime.random_float() -- Returns a raw float in [0, 1) [mod]
modit.runtime.random_int(min, max) -- Returns an integer in [min, max] inclusive [mod]
modit.runtime.get_rng_state() -- Gets the internal RNG state for snapshot/rewind [mod]
modit.runtime.set_rng_state(s) -- Restores a previously saved RNG state [game]

```

### modit.math

```lua
-- Core Maths
modit.math.round(number, decimals) -- Rounds a number to the specified number of decimal places. [mod]
modit.math.clamp(val, lower, upper) -- Clamps a value within a specified range. [mod]
modit.math.lerp(a, b, t) -- Linearly interpolates between two values. [mod]
modit.math.factorial(n) -- Calculates the factorial of a non-negative integer. [mod]
modit.math.deg_to_rad(deg) -- Converts degrees to radians. [mod]
modit.math.rad_to_deg(rad) -- Converts radians to degrees. [mod]

-- Easing
modit.math.ease_linear(t) -- Linear easing (no curve). [mod]
modit.math.ease_in_quad(t) -- Quadratic ease-in. [mod]
modit.math.ease_out_quad(t) -- Quadratic ease-out. [mod]
modit.math.ease_in_out_quad(t) -- Quadratic ease-in-out. [mod]
modit.math.ease_in_cubic(t) -- Cubic ease-in. [mod]
modit.math.ease_out_cubic(t) -- Cubic ease-out. [mod]
modit.math.ease_in_out_cubic(t) -- Cubic ease-in-out. [mod]
modit.math.ease_out_elastic(t) -- Elastic ease-out. [mod]

-- Statistics
modit.math.mean(numbers) -- Calculates the mean (average) of a list of numbers. [mod]
modit.math.median(numbers) -- Calculates the median of a list of numbers. [mod]
modit.math.mode(numbers) -- Calculates the mode (most frequent value). [mod]
modit.math.variance(numbers, population) -- Calculates the variance of a dataset. [mod]
modit.math.std_dev(numbers, population) -- Calculates the standard deviation of a dataset. [mod]
modit.math.range(numbers) -- Calculates the range (maximum minus minimum). [mod]
modit.math.min(numbers) -- Calculates the minimum value. [mod]
modit.math.max(numbers) -- Calculates the maximum value. [mod]
modit.math.sum(numbers) -- Calculates the sum of a dataset. [mod]
modit.math.quantile(numbers, q) -- Calculates a quantile using linear interpolation between sorted values. [mod]
modit.math.linear_regression(points) -- Performs ordinary least-squares linear regression on 2D points. [mod]
modit.math.correlation(x, y) -- Calculates the Pearson correlation coefficient between two datasets. [mod]
modit.math.covariance(x, y, population) -- Calculates covariance between two datasets. [mod]

-- Probability
modit.math.set_seed(seed) -- Set the global random seed for reproducibility. [mod]
modit.math.random_between(min, max, rand_func) -- Returns a random float between min and max. [mod]
modit.math.random_int(min, max, rand_func) -- Returns a random integer between min and max (inclusive). [mod]
modit.math.random_chance(probability, rand_func) -- Check if something happens with a given probability. [mod]
modit.math.random_percent_chance(percentage, rand_func) -- Check if something happens with a given percentage chance. [mod]
modit.math.random_choice(tbl, rand_func) -- Select a random element from a dense array. [mod]
modit.math.random_weighted_choice(map, rand_func) -- Select a random key from a table of weighted options. [mod]
modit.math.random_shuffle(tbl, rand_func) -- Shuffle a dense array in-place using Fisher-Yates. [mod]
modit.math.random_normal(mean, stddev, rand_func) -- Generate a random value from a normal (Gaussian) distribution. [mod]
modit.math.random_exponential(lambda, rand_func) -- Generate a random value from an exponential distribution. [mod]
modit.math.random_uniform(min, max, rand_func) -- Generate a random value from a uniform distribution. [mod]

-- Geometry
modit.math.distance(a, b) -- Calculates the distance between two points. Uses 3D when either point has a z value. [mod]
modit.math.triangle_area(p1, p2, p3) -- Calculates the area of a triangle. Uses 3D when any vertex has a z value. [mod]

-- 2D Geometry
modit.math.circle_circumference(radius) -- Calculates the circumference of a circle. [mod]
modit.math.circle_area(radius) -- Calculates the area of a circle. [mod]
modit.math.is_point_in_rect(p, rect) -- Determines if a point is inside or on a rectangle. [mod]
modit.math.is_point_on_line_segment(p, line_start, line_end, tolerance) -- Determines if a point lies on a line segment. [mod]
modit.math.project_point_on_line(p, p1, p2) -- Projects a point onto an infinite line. [mod]
modit.math.calculate_slope(p1, p2) -- Calculates the slope of a line. [mod]
modit.math.angle_between_points(p1, p2) -- Returns the angle from p1 to p2 in degrees. [mod]
modit.math.do_rects_intersect(a, b) -- Determines if two rectangles overlap or touch. [mod]
modit.math.do_circles_intersect(c1_center, c1_radius, c2_center, c2_radius) -- Determines if two circles intersect or touch. [mod]
modit.math.is_point_in_circle(p, circle_center, circle_radius) -- Determines if a point is inside or on a circle. [mod]
modit.math.do_lines_intersect(a, b, c, d) -- Determines if two line segments intersect or touch. [mod]
modit.math.line_intersects_circle(line_start, line_end, circle_center, circle_radius) -- Determines if a line segment intersects or touches a circle. [mod]
modit.math.does_rect_intersect_line(rect, line_start, line_end) -- Determines if a rectangle intersects a line segment. [mod]
modit.math.closest_point_on_line_segment(p, line_start, line_end) -- Finds the closest point on a segment to a given point. [mod]
modit.math.is_point_in_convex_polygon(p, polygon) -- Determines if a point is inside or on a convex polygon. [mod]
modit.math.rotate_point_around_point(p, pivot, angle_degrees) -- Rotates a point around a pivot by an angle in degrees. [mod]

-- 3D Geometry
modit.math.midpoint(a, b) -- Returns the midpoint between two points. [mod]
modit.math.is_point_in_box(p, box) -- Determines if a point is inside or on a box. Negative dimensions are supported. [mod]
modit.math.angle_between_three_points(p1, p2, p3) -- Calculates the angle at the second point in degrees. Returns nil for a zero-length arm. [mod]
modit.math.is_point_in_sphere(p, sphere_center, sphere_radius) -- Determines if a point is inside or on a sphere. Negative radii are treated as positive. [mod]
modit.math.do_spheres_intersect(s1_center, s1_radius, s2_center, s2_radius) -- Determines if two spheres intersect or touch. Negative radii are treated as positive. [mod]
modit.math.distance_point_to_plane(p, plane_point, plane_normal) -- Calculates the shortest distance from a point to a plane; nil for a zero-length normal. [mod]
modit.math.normalize_vector(v) -- Normalizes a vector. A zero-length vector returns a zero vector. [mod]

```

### modit.vector

```lua
modit.vector.vec2(x, y) -- Creates a Vec2. Also vector2 and vec2.new. [mod]
modit.vector.vec3(x, y, z) -- Creates a Vec3. Also vector3 and vec3.new. [mod]
modit.vector.vec4(x, y, z, w) -- Creates a Vec4. Also vector4 and vec4.new. [mod]

-- Vector methods (v is a Vec2, Vec3 or Vec4. + - * / and unary - also work)
v:clone() -- Returns a copy. [mod]
v:set(x, y, z, w) -- Sets every component and returns v. [mod]
v:add(other) -- Returns v + other. [mod]
v:sub(other) -- Returns v - other. [mod]
v:scale(scalar) -- Returns v scaled by a number. [mod]
v:dot(other) -- Returns the dot product. [mod]
v:length_squared() -- Returns the squared length. [mod]
v:length() -- Returns the length. [mod]
v:distance_squared(other) -- Returns the squared distance to other. [mod]
v:distance(other) -- Returns the distance to other. [mod]
v:normalize() -- Returns a unit vector, or zero for a zero vector. [mod]
v:is_zero() -- Checks if the vector is (almost) zero. [mod]
v:lerp(other, t) -- Returns the interpolation towards other. [mod]
v:cross(other) -- Cross product. Vec2 returns a number, Vec3 returns a Vec3. [mod]
v:angle() -- Vec2 only. Returns the angle in radians. [mod]
v:rotate(angle) -- Vec2 only. Returns v rotated by an angle in radians. [mod]
v:perpendicular() -- Vec2 only. Returns the perpendicular vector. [mod]
v:xyz() -- Vec4 only. Returns the x, y, z part as a Vec3. [mod]

```

### modit.mat4

```lua
-- Factory
modit.mat4.new(values) -- Creates a new 4x4 matrix (defaults to an identity matrix). [mod]

-- Functions
modit.mat4.translate(x, y, z) -- Creates a translation matrix. [mod]
modit.mat4.scale(sx, sy, sz) -- Creates a scale matrix. [mod]
modit.mat4.rotate_euler(rx, ry, rz) -- Creates a rotation matrix from Euler angles (XYZ order). [mod]
modit.mat4.rotate_axis(axis, angle) -- Creates a rotation matrix around an arbitrary axis. [mod]
modit.mat4.perspective(fov, aspect, near, far) -- Creates an OpenGL-style perspective projection matrix. [mod]
modit.mat4.orthographic(left, right, bottom, top, near, far) -- Creates an OpenGL-style orthographic projection matrix. [mod]
modit.mat4.look_at(eye, target, up) -- Creates a right-handed look-at view matrix. [mod]

-- Methods
matrix:multiply(other) -- Multiplies this matrix by another matrix instance. [mod]
a * b -- Multiplies two matrices, same as a:multiply(b). [mod]
matrix:multiply_vec3(v) -- Transforms a 3D position vector using homogeneous coordinates (w = 1). [mod]
matrix:transpose() -- Transposes the matrix rows and columns. [mod]
matrix:invert() -- Inverts the matrix using Gauss-Jordan elimination. [mod]
matrix:get_translation() -- Extracts translation components from the matrix. [mod]
matrix:get_scale() -- Extracts scale magnitudes from the transformation basis. [mod]
matrix:raw() -- Returns the underlying raw 16-element column-major array. [mod]

```

### modit.physics

```lua
-- World Lifecycle
modit.physics.init_world(opts) -- Creates the physics world, replacing any existing one [game]
modit.physics.shutdown_world() -- Destroys the world and invalidates every body and shape handle [game]
modit.physics.is_world_active() -- Checks whether the physics world exists [game]

-- World Simulation
modit.physics.update_world(dt) -- Advances the simulation in fixed steps and collects events [game]
modit.physics.get_world_events() -- Returns the events collected by the last update: touch_begin, touch_end, hit, sensor_begin, sensor_end. Each has shape_a, shape_b, body_a, body_b. Hit events also have x, y, z (point), nx, ny, nz (normal) and speed (approach speed). Only shapes created with events = true produce events. Handles may refer to bodies destroyed since, check is_body_valid [game]

-- World Gravity
modit.physics.set_world_gravity(x, y, z) -- Sets world gravity [game]
modit.physics.get_world_gravity() -- Returns world gravity [game]

-- Body Lifecycle
modit.physics.create_body(opts) -- Creates a body [game]
modit.physics.destroy_body(body) -- Destroys a body and all of its shapes [game]
modit.physics.is_body_valid(body) -- Checks whether a body handle is still valid [game]

-- Body Transform
modit.physics.get_body_position(body) -- Returns the body position [game]
modit.physics.get_body_rotation(body) -- Returns the body rotation as a quaternion [game]
modit.physics.get_body_transform(body) -- Returns position and rotation in one call [game]
modit.physics.set_body_transform(body, x, y, z, qx, qy, qz, qw) -- Teleports a body [game]
modit.physics.get_body_world_point(body, x, y, z) -- Converts a local point to world space [game]
modit.physics.get_body_local_point(body, x, y, z) -- Converts a world point to local space [game]
modit.physics.get_body_world_vector(body, x, y, z) -- Rotates a local direction into world space [game]

-- Body Velocity
modit.physics.get_body_linear_velocity(body) -- Returns linear velocity [game]
modit.physics.set_body_linear_velocity(body, x, y, z) -- Sets linear velocity [game]
modit.physics.get_body_angular_velocity(body) -- Returns angular velocity in radians per second [game]
modit.physics.set_body_angular_velocity(body, x, y, z) -- Sets angular velocity in radians per second [game]

-- Body Forces
modit.physics.apply_body_force(body, x, y, z, px, py, pz) -- Applies a force for the next step. With a point it is applied at that world position [game]
modit.physics.apply_body_impulse(body, x, y, z, px, py, pz) -- Applies an instant impulse. With a point it is applied at that world position [game]
modit.physics.apply_body_torque(body, x, y, z) -- Applies a torque for the next step [game]
modit.physics.apply_body_angular_impulse(body, x, y, z) -- Applies an instant angular impulse [game]

-- Body Properties
modit.physics.get_body_mass(body) -- Returns the body mass [game]
modit.physics.set_body_gravity_scale(body, scale) -- Sets the gravity scale [game]
modit.physics.set_body_damping(body, linear, angular) -- Sets linear and angular damping [game]
modit.physics.is_body_awake(body) -- Checks whether a body is awake [game]
modit.physics.set_body_awake(body, awake) -- Wakes or sleeps a body [game]
modit.physics.set_body_enabled(body, enabled) -- Enables or disables a body in the simulation [game]

-- Joints
modit.physics.create_spherical_joint(body_a, body_b, opts) -- Creates a ball and socket joint. Opts: anchor_a, anchor_b {x,y,z} in each body's local space, frame_a, frame_b {x,y,z,w}, cone_angle, twist_lower, twist_upper (radians), spring_hertz, spring_damping, collide_connected [game]
modit.physics.create_revolute_joint(body_a, body_b, opts) -- Creates a hinge joint. Opts: anchor_a, anchor_b, frame_a, frame_b, lower, upper (radians), spring_hertz, spring_damping, collide_connected [game]
modit.physics.destroy_joint(joint) -- Destroys a joint [game]
modit.physics.is_joint_valid(joint) -- Checks whether a joint handle is still valid [game]

-- Shape Creation
modit.physics.add_box_shape(body, half_x, half_y, half_z, opts) -- Attaches a box shape. Opts: density, friction, restitution, sensor, events, category, mask, ox, oy, oz [game]
modit.physics.add_sphere_shape(body, radius, opts) -- Attaches a sphere shape [game]
modit.physics.add_capsule_shape(body, radius, half_height, opts) -- Attaches a capsule shape standing along the Y axis [game]

-- Shape Management
modit.physics.destroy_shape(shape) -- Destroys a shape [game]
modit.physics.get_shape_body(shape) -- Returns the body a shape is attached to [game]

-- Shape Properties
modit.physics.set_shape_friction(shape, friction) -- Sets surface friction [game]
modit.physics.set_shape_restitution(shape, restitution) -- Sets surface restitution [game]
modit.physics.set_shape_filter(shape, category, mask) -- Sets collision category and mask bits [game]

-- Queries
modit.physics.raycast(ox, oy, oz, dx, dy, dz, max_distance, opts) -- Casts a ray and returns the closest hit [game]
modit.physics.overlap_box(min_x, min_y, min_z, max_x, max_y, max_z, opts) -- Lists the bodies whose shapes overlap a box [game]

-- Rotation
modit.physics.from_euler(pitch, yaw, roll) -- Builds a quaternion from Euler angles (Y-up, applied yaw then pitch then roll) [game]
modit.physics.to_euler(x, y, z, w) -- Converts a quaternion to Euler angles, the inverse of from_euler [game]

```

### modit.command

```lua
modit.command.register(name, fn, help) -- Registers a game console command [game]
modit.command.run(line) -- Parses and runs a raw command line input string [game]
modit.command.list() -- Returns a sorted list of all registered command [game]
modit.command.register_builtins(realm, opts) -- Registers optional built-in console command based on configuration [game]

```

### modit.filesystem

```lua
modit.filesystem.init(game_dir) -- Sets the save folder for this project. Call once at boot [mod]
modit.filesystem.serialize(tbl) -- Serializes a table to a stable Lua source string [mod]
modit.filesystem.exists(path) -- Checks if a file or folder exists in the save folder [mod]
modit.filesystem.create_directory(path) -- Recursively creates a folder inside the save folder [mod]
modit.filesystem.save(path, data) -- Safely saves a table to a file using atomic writing (temp file swap) [mod]
modit.filesystem.load(path) -- Loads and parses a saved table inside a secure sandbox [mod]
modit.filesystem.delete(path) -- Deletes a file in the save folder [mod]

```

### modit.string

```lua
modit.string.capitalize(str) -- Capitalizes the first letter of each word in a string. [mod]
modit.string.split(str, delimiter) -- Splits a string into a table based on a delimiter. [mod]
modit.string.trim(str) -- Trims whitespace from the beginning and end of a string. [mod]
modit.string.random_string(length) -- Generates a random alphanumeric string of specified length. [mod]
modit.string.starts_with(str, prefix) -- Checks if string starts with a prefix. [mod]
modit.string.ends_with(str, suffix) -- Checks if string ends with a suffix. [mod]
modit.string.replace(str, old, new) -- Replaces first occurrence of old substring with new. [mod]
modit.string.replace_all(str, old, new) -- Replaces all occurrences of old substring with new. [mod]
modit.string.reverse(str) -- Reverses a string. [mod]
modit.string.repeat_string(str, count) -- Repeats a string N times. [mod]
modit.string.truncate(str, max_length, suffix) -- Truncates string to max length, adding suffix if truncated. [mod]
modit.string.is_empty(str) -- Checks if string is empty or contains only whitespace. [mod]
modit.string.lowercase(str) -- Converts string to lowercase. [mod]
modit.string.uppercase(str) -- Converts string to uppercase. [mod]
modit.string.count(str, substring) -- Counts occurrences of substring in string. [mod]
modit.string.pad_left(str, length, char) -- Pads string to length with character (left side). [mod]
modit.string.pad_right(str, length, char) -- Pads string to length with character (right side). [mod]
modit.string.contains(str, substring) -- Checks if string contains substring. [mod]
modit.string.between(str, start_delim, end_delim) -- Extracts substring between two delimiters. [mod]

```

### modit.table

```lua
modit.table.print(t, indent) -- Recursively prints a table's contents for debugging. [mod]
modit.table.contains(tbl, val) -- Checks if a table contains a specific value, searching nested tables. [mod]
modit.table.deep_copy(orig) -- Creates a deep copy of a table. [mod]
modit.table.deep_compare(t1, t2) -- Deeply compares two tables for equality. [mod]

```

### modit.timestamp

```lua
modit.timestamp.convert(ts) -- Converts a UNIX timestamp (seconds) to date/time components. [mod]
modit.timestamp.now() -- Gets the current UNIX timestamp. [mod]
modit.timestamp.now_formatted() -- Gets the current date and time as formatted strings. [mod]
modit.timestamp.date_difference(start_date, end_date) -- Calculates the difference in days between two dates ("YYYY-MM-DD"). [mod]
modit.timestamp.difference(ts1, ts2) -- Calculates the difference in seconds between two timestamps. [mod]
modit.timestamp.add_days_to_date(date_str, days) -- Adds a number of days to a date string. [mod]
modit.timestamp.add_seconds(ts, seconds) -- Adds a number of seconds to a timestamp. [mod]
modit.timestamp.add_hours(ts, hours) -- Adds a number of hours to a timestamp. [mod]
modit.timestamp.add_minutes(ts, minutes) -- Adds a number of minutes to a timestamp. [mod]
modit.timestamp.format(ts, format) -- Formats a timestamp with a custom format string. [mod]
modit.timestamp.day_of_week(ts) -- Gets the day of week for a timestamp (1=Sunday, 7=Saturday). [mod]
modit.timestamp.day_name(ts) -- Gets the day of week name for a timestamp. [mod]
modit.timestamp.month_name(ts) -- Gets the month name for a timestamp. [mod]
modit.timestamp.is_leap_year(year) -- Checks if a given year is a leap year. [mod]
modit.timestamp.days_in_month(year, month) -- Gets the number of days in a month. [mod]
modit.timestamp.parse_date(date_str, time_str) -- Parses a date string into a UNIX timestamp. [mod]
modit.timestamp.is_past(ts) -- Checks if a timestamp is in the past. [mod]
modit.timestamp.is_future(ts) -- Checks if a timestamp is in the future. [mod]
modit.timestamp.format_duration(seconds) -- Formats a time duration in seconds to a human-readable string. [mod]

```

### modit.hook

```lua
modit.hook.register(name, description) -- Declares a hook name with an optional description [mod]
modit.hook.listen(name, callback, owner) -- Adds a listener to a hook with an optional owner tag [mod]
modit.hook.fire(name, ...) -- Calls every listener of a hook in order [mod]
modit.hook.unlisten(name, callback) -- Removes a specific listener function [mod]
modit.hook.list() -- Lists all declared hook names [mod]
modit.hook.clear(name) -- Removes every listener of one hook [game]
modit.hook.clear_all() -- Removes every listener of every hook [game]

```

### modit.exports

```lua
exports(name, fn) -- Registers an export function for the current mod [mod]
exports.provider.name(...) -- Calls an export function exposed by another mod [mod]

-- attached to mods on load
mod.name -- The name of the current mod [mod]
mod.realm -- The current realm ("client" or "server") [mod]
mod.dir -- The absolute directory path of the mod [mod]
mod.persist -- Persistent state table shared across reloads [mod]
mod.on_stop(callback) -- Registers a cleanup handler called when the mod stops [mod]

```

---

## Server Modules

Modules that run server-side for hosting dedicated multiplayer logic, networking, and server console management.

### modit.server_console

```lua
modit.server_console.init() -- Initializes the platform-independent server console interface and log redirection. [game]
modit.server_console.poll() -- Polls the console for input events. [game]
modit.server_console.print(message) -- Prints a message directly to the server console. [game]
modit.server_console.is_closed() -- Checks whether the server console window has been closed. [game]
modit.server_console.close() -- Closes the server console and restores standard logging sinks. [game]

```

### modit.network

Will undergo some changes soon once enet is added in.

```lua
-- Raw Sockets & Lifecycle
modit.network.tcp_listen(port) -- Starts listening for raw TCP connections on a specified port [game]
modit.network.tcp_accept(listener) -- Accepts one pending client connection, returning socket, IP, and port [game]
modit.network.tcp_connect(host, port) -- Begins a non-blocking TCP connection to a server [game]
modit.network.tcp_status(socket) -- Polls socket connection state ("connecting", "connected", or "failed") [game]
modit.network.tcp_send(socket, data) -- Sends raw byte data over a socket [game]
modit.network.tcp_recv(socket) -- Receives waiting raw bytes from a socket [game]
modit.network.close(socket) -- Closes a socket or listener handle [game]
modit.network.cleanup() -- Releases network backend resources; call once on shutdown [game]

-- Framed Connections (Connection State API)
modit.network.connection.new(socket) -- Wraps a raw socket into a framed connection state table [game]
modit.network.connection.send(connection, value) -- Serializes and queues a Lua value as a framed packet [game]
modit.network.connection.flush(connection) -- Flushes any queued data bytes to the network socket [game]
modit.network.connection.receive(connection) -- Polls socket and returns an array of fully decoded Lua packets [game]
modit.network.connection.close(connection) -- Gracefully closes the framed connection and its underlying socket [game]

```