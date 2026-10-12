# API Cheatsheet

> **Alpha Notice:** `modit` is currently in **alpha**. The API is subject to change, and backward compatibility is not guaranteed at this stage. Please design and develop with this in mind.

Quick reference to all functions available to game and mod files.

For more detailed documentation, refer to the specific sections you are interested in.

Most API functions are accessed through the `modit.` namespace, with the exception of `exports()` and `mod.` functions.

## Core

### log

```lua
modit.log.debug(msg, data) -- Prints a debug message.
modit.log.info(msg, data) -- Prints an informational message.
modit.log.success(msg, data) -- Prints a success message.
modit.log.warn(msg, data) -- Prints a warning message.
modit.log.error(msg, data) -- Prints an error message.

```

### hooks

```lua
modit.hooks.listen(name, callback) -- Adds a listener to a hook.
modit.hooks.unlisten(name, callback) -- Removes one listener.
modit.hooks.fire(name, ...) -- Calls every listener of a hook.

```

### json

```lua
modit.json.encode(value) -- Encodes a Lua value as JSON.
modit.json.decode(input) -- Decodes a JSON string into a Lua value.

```

## audio

### audio

```lua
modit.audio.load_sound(key, path) -- Load a sound effect from file.
modit.audio.play_sound(key) -- Play a sound effect.
modit.audio.set_sound_volume(key, volume) -- Set volume for a sound effect.
modit.audio.set_sound_pitch(key, pitch) -- Set pitch for a sound effect.
modit.audio.unload_sound(key) -- Unload a sound effect.
modit.audio.load_music(key, path) -- Load a music track from file.
modit.audio.play_music(key, loop) -- Play music, stopping current track if necessary.
modit.audio.stop_music() -- Stop current music.
modit.audio.pause_music() -- Pause current music.
modit.audio.resume_music() -- Resume current music.
modit.audio.set_music_volume(key, volume) -- Set music volume.
modit.audio.set_music_pitch(key, pitch) -- Set music pitch.
modit.audio.is_music_playing() -- Check if music is currently playing.
modit.audio.unload_music(key) -- Unload a music track.
modit.audio.cleanup() -- Clean up all audio resources.

```

## Camera

### cam

```lua
modit.camera.new(cfg) -- Creates a new camera state holder for 2D and 3D rendering.
cam:begin_3d() -- Begins the 3D rendering pass.
cam:end_3d() -- Ends the 3D rendering pass.
cam:begin_2d() -- Begins the 2D rendering pass.
cam:end_2d() -- Ends the 2D rendering pass.
cam:set_position(x, y, z) -- Sets the camera position.
cam:set_target(x, y, z) -- Sets the camera target position.
cam:set_offset(x, y) -- Sets the camera 2D offset.
cam:set_target_2d(x, y) -- Sets the camera 2D target.
cam:set_zoom(zoom) -- Sets the camera zoom level.
cam:set_rotation(angle) -- Sets the camera rotation angle.
cam:set_fov(fov) -- Sets the camera field of view.

```

## Input

### actions

```lua
modit.actions.map_action(name, bindings, owner) -- Maps an action name to a list of input bindings.
modit.actions.update(dt) -- Advances hold timers. Call once per frame (client only).
modit.actions.is_action_pressed(name) -- Checks if an action was pressed this frame.
modit.actions.is_action_down(name) -- Checks if an action is currently held down.
modit.actions.is_action_released(name) -- Checks if an action was released this frame.
modit.actions.hold_time(name) -- Gets how long an action has been held, in seconds.
modit.actions.remove_owner(owner) -- Removes every action mapped by an owner.
modit.actions.clear_actions() -- Clears all action mappings.

```

### keyboard

```lua
modit.keyboard.get_char() -- Gets the Unicode character code queued from key input during the frame.
modit.keyboard.get_clipboard() -- Retrieves text currently stored on the OS system clipboard.
modit.keyboard.set_clipboard(text) -- Sets text onto the OS system clipboard.
modit.keyboard.down(key) -- Checks if a key is currently held down.
modit.keyboard.pressed(key) -- Checks if a key was pressed down during the current frame.
modit.keyboard.released(key) -- Checks if a key was released during the current frame.
modit.keyboard.pressed_repeat(key) -- Checks if a key was pressed or repeated due to key-repeat delay.

```

### mouse

```lua
modit.mouse.get_position() -- Retrieves current screen coordinates of the mouse cursor.
modit.mouse.get_x() -- Retrieves current X position of the mouse cursor.
modit.mouse.get_y() -- Retrieves current Y position of the mouse cursor.
modit.mouse.get_wheel() -- Retrieves mouse wheel movement delta for the current frame.
modit.mouse.get_delta() -- Retrieves mouse movement delta since the previous frame.
modit.mouse.set_position(x, y) -- Repositions the mouse cursor on screen.
modit.mouse.show() -- Shows the hardware/system mouse cursor.
modit.mouse.hide() -- Hides the hardware/system mouse cursor.
modit.mouse.lock() -- Locks and hides the mouse cursor inside the window for relative 3D camera controls.
modit.mouse.unlock() -- Unlocks and restores normal mouse cursor behavior.
modit.mouse.pressed(button) -- Checks if a mouse button was pressed down during the current frame.
modit.mouse.down(button) -- Checks if a mouse button is currently being held down.
modit.mouse.released(button) -- Checks if a mouse button was released during the current frame.
modit.mouse.set_cursor(name) -- Sets the active OS cursor icon style.
modit.mouse.in_rect(x, y, w, h) -- Checks if the current mouse cursor position falls inside a rectangle boundary.

```

## IO

### filesystem

```lua
modit.filesystem.init(game_dir) -- Sets the save folder for this project.
modit.filesystem.serialize(tbl) -- Serializes a table to Lua source (sorted keys, so output is stable).
modit.filesystem.exists(path) -- Checks if a file or folder exists in the save folder.
modit.filesystem.create_directory(path) -- Creates a folder inside the save folder.
modit.filesystem.save(path, data) -- Saves a table to a file in the save folder.
modit.filesystem.load(path) -- Loads a table from a file in the save folder.
modit.filesystem.delete(path) -- Deletes a file in the save folder.

```

### http

```lua
modit.http.get(url, headers) -- Sends an HTTP GET request.

```

## Maths

### core

```lua
modit.maths.core.round(number, decimals) -- Rounds a number to the specified number of decimal places.
modit.maths.core.clamp(val, lower, upper) -- Clamps a value within a specified range.
modit.maths.core.lerp(a, b, t) -- Linearly interpolates between two values.
modit.maths.core.factorial(n) -- Calculates the factorial of a non-negative integer.
modit.maths.core.deg_to_rad(deg) -- Converts degrees to radians.
modit.maths.core.rad_to_deg(rad) -- Converts radians to degrees.

```

### probability

```lua
modit.maths.probability.set_seed(seed) -- Set the global random seed for reproducibility.
modit.maths.probability.random_between(min, max, rand_func) -- Returns a random float between min and max.
modit.maths.probability.random_int(min, max, rand_func) -- Returns a random integer between min and max (inclusive).
modit.maths.probability.chance(probability, rand_func) -- Check if something happens with a given probability.
modit.maths.probability.percent_chance(percentage, rand_func) -- Check if something happens with a given percentage chance.
modit.maths.probability.random_choice(tbl, rand_func) -- Select a random element from a dense array.
modit.maths.probability.weighted_choice(map, rand_func) -- Select a random key from a table of weighted options.
modit.maths.probability.shuffle(tbl, rand_func) -- Shuffle a dense array in-place using Fisher-Yates.
modit.maths.probability.random_normal(mean, stddev, rand_func) -- Generate a random value from a normal distribution.
modit.maths.probability.random_exponential(lambda, rand_func) -- Generate a random value from an exponential distribution.
modit.maths.probability.random_uniform(min, max, rand_func) -- Generate a random value from a uniform distribution.

```

### statistics

```lua
modit.maths.statistics.mean(numbers) -- Calculates the mean (average) of a list of numbers.
modit.maths.statistics.median(numbers) -- Calculates the median of a list of numbers.
modit.maths.statistics.mode(numbers) -- Calculates the mode (most frequent value).
modit.maths.statistics.variance(numbers, population) -- Calculates the variance of a dataset.
modit.maths.statistics.standard_deviation(numbers, population) -- Calculates the standard deviation of a dataset.
modit.maths.statistics.range(numbers) -- Calculates the range (maximum minus minimum).
modit.maths.statistics.min(numbers) -- Calculates the minimum value.
modit.maths.statistics.max(numbers) -- Calculates the maximum value.
modit.maths.statistics.sum(numbers) -- Calculates the sum of a dataset.
modit.maths.statistics.quantile(numbers, q) -- Calculates a quantile using linear interpolation.
modit.maths.statistics.linear_regression(points) -- Performs ordinary least-squares linear regression on 2D points.
modit.maths.statistics.correlation(x, y) -- Calculates the Pearson correlation coefficient between two datasets.
modit.maths.statistics.covariance(x, y, population) -- Calculates covariance between two datasets.

```

### vec2

```lua
modit.maths.vec2.new(x, y) -- Create a new vec2 instance.
modit.maths.vec2.copy(v) -- Create a copy of a vector.
modit.maths.vec2.set(v, x, y) -- Set vector components in-place.
modit.maths.vec2.add(a, b) -- Add two vectors.
modit.maths.vec2.sub(a, b) -- Subtract two vectors.
modit.maths.vec2.scale(v, s) -- Scale a vector by a scalar.
modit.maths.vec2.dot(a, b) -- Calculate the dot product.
modit.maths.vec2.cross(a, b) -- Calculate the 2D scalar cross product.
modit.maths.vec2.length(v) -- Calculate vector length.
modit.maths.vec2.length_squared(v) -- Calculate squared vector length.
modit.maths.vec2.normalize(v) -- Normalize a vector.
modit.maths.vec2.is_zero(v) -- Check whether a vector is effectively zero.
modit.maths.vec2.distance(a, b) -- Calculate distance between two points.
modit.maths.vec2.distance_squared(a, b) -- Calculate squared distance between two points.
modit.maths.vec2.lerp(a, b, t) -- Linear interpolation.
modit.maths.vec2.rotate(v, angle) -- Rotate a vector by an angle in radians.
modit.maths.vec2.perpendicular(v) -- Return a perpendicular vector rotated 90 degrees counterclockwise.
modit.maths.vec2.angle(v) -- Return the angle of the vector in radians.

```

### vec3

```lua
modit.maths.vec3.new(x, y, z) -- Create a new vec3 instance.
modit.maths.vec3.copy(v) -- Create a copy of a vector.
modit.maths.vec3.set(v, x, y, z) -- Set vector components in-place.
modit.maths.vec3.add(a, b) -- Add two vectors.
modit.maths.vec3.sub(a, b) -- Subtract two vectors.
modit.maths.vec3.scale(v, s) -- Scale a vector by a scalar.
modit.maths.vec3.dot(a, b) -- Calculate the dot product of two vectors.
modit.maths.vec3.cross(a, b) -- Calculate the cross product of two vectors.
modit.maths.vec3.length(v) -- Calculate the length (magnitude) of a vector.
modit.maths.vec3.length_squared(v) -- Calculate squared length.
modit.maths.vec3.normalize(v) -- Normalize a vector.
modit.maths.vec3.is_zero(v) -- Check if a vector is effectively zero.
modit.maths.vec3.distance(a, b) -- Calculate distance between two points.
modit.maths.vec3.distance_squared(a, b) -- Calculate squared distance.
modit.maths.vec3.lerp(a, b, t) -- Linear interpolation between two vectors.

```

### vec4

```lua
modit.maths.vec4.new(x, y, z, w) -- Create a new vec4 instance.
modit.maths.vec4.copy(v) -- Create a copy of a vector.
modit.maths.vec4.set(v, x, y, z, w) -- Set vector components in-place.
modit.maths.vec4.xyz(v) -- Extract the first three components as a plain table.
modit.maths.vec4.add(a, b) -- Add two vectors.
modit.maths.vec4.sub(a, b) -- Subtract two vectors.
modit.maths.vec4.scale(v, s) -- Scale a vector by a scalar.
modit.maths.vec4.dot(a, b) -- Calculate the dot product.
modit.maths.vec4.length(v) -- Calculate vector length.
modit.maths.vec4.length_squared(v) -- Calculate squared vector length.
modit.maths.vec4.normalize(v) -- Normalize a vector.
modit.maths.vec4.is_zero(v) -- Check whether a vector is effectively zero.
modit.maths.vec4.distance(a, b) -- Calculate distance between two points.
modit.maths.vec4.distance_squared(a, b) -- Calculate squared distance between two points.
modit.maths.vec4.lerp(a, b, t) -- Linear interpolation.

```

### easing

```lua
modit.maths.easing.linear(t) -- Linear easing (no curve).
modit.maths.easing.in_quad(t) -- Quadratic ease-in.
modit.maths.easing.out_quad(t) -- Quadratic ease-out.
modit.maths.easing.in_out_quad(t) -- Quadratic ease-in-out.
modit.maths.easing.in_cubic(t) -- Cubic ease-in.
modit.maths.easing.out_cubic(t) -- Cubic ease-out.
modit.maths.easing.in_out_cubic(t) -- Cubic ease-in-out.
modit.maths.easing.out_elastic(t) -- Elastic ease-out.

```

### geo2d

```lua
modit.maths.geo2d.circle_circumference(radius) -- Calculates the circumference of a circle.
modit.maths.geo2d.circle_area(radius) -- Calculates the area of a circle.
modit.maths.geo2d.triangle_area(p1, p2, p3) -- Calculates the area of a triangle using its 2D vertices.
modit.maths.geo2d.distance_2d(p1, p2) -- Calculates the distance between two 2D points.
modit.maths.geo2d.is_point_in_rect(p, rect) -- Determines if a point is inside or on a rectangle.
modit.maths.geo2d.is_point_on_line_segment(p, s, e, t) -- Determines if a point lies on a line segment.
modit.maths.geo2d.project_point_on_line(p, p1, p2) -- Projects a point onto an infinite line.
modit.maths.geo2d.calculate_slope(p1, p2) -- Calculates the slope of a line.
modit.maths.geo2d.angle_between_points(p1, p2) -- Returns the angle from p1 to p2 in degrees.
modit.maths.geo2d.do_rects_intersect(a, b) -- Determines if two rectangles overlap or touch.
modit.maths.geo2d.do_circles_intersect(c1, r1, c2, r2) -- Determines if two circles intersect or touch.
modit.maths.geo2d.is_point_in_circle(p, center, radius) -- Determines if a point is inside or on a circle.
modit.maths.geo2d.do_lines_intersect(a, b, c, d) -- Determines if two line segments intersect or touch.
modit.maths.geo2d.line_intersects_circle(s, e, center, radius) -- Determines if a line segment intersects or touches a circle.
modit.maths.geo2d.does_rect_intersect_line(rect, s, e) -- Determines if a rectangle intersects a line segment.
modit.maths.geo2d.closest_point_on_line_segment(p, s, e) -- Finds the closest point on a segment to a given point.
modit.maths.geo2d.is_point_in_convex_polygon(p, poly) -- Determines if a point is inside or on a convex polygon.
modit.maths.geo2d.rotate_point_around_point_2d(p, pivot, deg) -- Rotates a point around a pivot by an angle in degrees.

```

### geo3d

```lua
modit.maths.geo3d.distance_3d(start_coords, end_coords) -- Calculates the distance between two 3D points.
modit.maths.geo3d.midpoint(p1, p2) -- Returns the midpoint between two 3D points.
modit.maths.geo3d.is_point_in_box(p, box) -- Determines if a point is inside or on a 3D box.
modit.maths.geo3d.angle_between_3_points(p1, p2, p3) -- Calculates the angle between three 3D points.
modit.maths.geo3d.triangle_area_3d(p1, p2, p3) -- Calculates the area of a triangle in 3D space.
modit.maths.geo3d.is_point_in_sphere(p, center, radius) -- Determines if a point is inside or on a sphere.
modit.maths.geo3d.do_spheres_intersect(c1, r1, c2, r2) -- Determines if two spheres intersect or touch.
modit.maths.geo3d.distance_point_to_plane(p, pt, norm) -- Calculates the shortest distance from a point to a plane.
modit.maths.geo3d.normalize_vector(v) -- Normalizes a 3D vector.

```

### mat4

```lua
modit.maths.mat4.new(values) -- Creates a new identity or custom 4x4 matrix.
modit.maths.mat4.translate(x, y, z) -- Creates a translation matrix.
modit.maths.mat4.rotate_euler(rx, ry, rz) -- Creates a rotation matrix from Euler angles.
modit.maths.mat4.rotate_axis(axis, angle) -- Creates a rotation matrix around an arbitrary axis.
modit.maths.mat4.scale(sx, sy, sz) -- Creates a scale matrix.
modit.maths.mat4.perspective(fov, aspect, near, far) -- Creates an OpenGL-style perspective projection matrix.
modit.maths.mat4.orthographic(l, r, b, t, n, f) -- Creates an OpenGL-style orthographic projection matrix.
modit.maths.mat4.look_at(eye, target, up) -- Creates a right-handed look-at view matrix.
mat4:multiply(other) -- Multiplies this matrix by another matrix.
mat4:multiply_vec3(v) -- Transforms a position using homogeneous coordinates.
mat4:transpose() -- Transposes the matrix.
mat4:invert() -- Inverts the matrix using Gauss-Jordan elimination.
mat4:get_translation() -- Extracts translation from the matrix.
mat4:get_scale() -- Extracts the magnitudes of the three basis vectors.
mat4:raw() -- Returns the underlying 16-element matrix table.

```

## Modding Support

### mod

```lua
mod.name -- Returns the name of the current mod.
mod.realm -- Returns the current realm ("client" or "server").
mod.dir -- Returns the absolute directory path of the mod.
mod.persist -- Persistent state table shared across reloads.
mod.on_stop(callback) -- Registers a cleanup handler called when the mod stops.

```

### exports

```lua
exports(name, fn) -- Registers an export function for the current mod.
exports.provider.name(...) -- Calls an export function exposed by another mod.

```

## Physics

### world

```lua
modit.physics.is_active() -- Checks whether the physics world exists.
modit.physics.get_gravity() -- Returns world gravity.
modit.physics.get_events() -- Returns the events collected by the last update.

```

### body

```lua
modit.physics.create_body(opts) -- Creates a body.
modit.physics.destroy_body(body) -- Destroys a body and all of its shapes.
modit.physics.is_valid(handle) -- Checks whether a body or shape handle is still valid.
modit.physics.get_position(body) -- Returns the body position.
modit.physics.get_rotation(body) -- Returns the body rotation as a quaternion.
modit.physics.get_transform(body) -- Returns position and rotation in one call.
modit.physics.set_transform(body, x, y, z, qx, qy, qz, qw) -- Teleports a body.
modit.physics.get_world_point(body, x, y, z) -- Converts a local point to world space.
modit.physics.get_local_point(body, x, y, z) -- Converts a world point to local space.
modit.physics.get_world_vector(body, x, y, z) -- Rotates a local direction into world space.
modit.physics.get_linear_velocity(body) -- Returns linear velocity.
modit.physics.set_linear_velocity(body, x, y, z) -- Sets linear velocity.
modit.physics.get_angular_velocity(body) -- Returns angular velocity in radians per second.
modit.physics.set_angular_velocity(body, x, y, z) -- Sets angular velocity in radians per second.
modit.physics.apply_force(body, x, y, z, px, py, pz) -- Applies a force for the next step.
modit.physics.apply_impulse(body, x, y, z, px, py, pz) -- Applies an instant impulse.
modit.physics.apply_torque(body, x, y, z) -- Applies a torque for the next step.
modit.physics.apply_angular_impulse(body, x, y, z) -- Applies an instant angular impulse.
modit.physics.get_mass(body) -- Returns the body mass.
modit.physics.set_gravity_scale(body, scale) -- Sets the gravity scale.
modit.physics.set_damping(body, linear, angular) -- Sets linear and angular damping.
modit.physics.is_awake(body) -- Checks whether a body is awake.
modit.physics.set_awake(body, awake) -- Wakes or sleeps a body.
modit.physics.set_enabled(body, enabled) -- Enables or disables a body in the simulation.

```

### shape

```lua
modit.physics.add_box(body, half_x, half_y, half_z, opts) -- Attaches a box shape.
modit.physics.add_sphere(body, radius, opts) -- Attaches a sphere shape.
modit.physics.add_capsule(body, radius, half_height, opts) -- Attaches a capsule shape standing along the Y axis.
modit.physics.destroy_shape(shape) -- Destroys a shape.
modit.physics.get_shape_body(shape) -- Returns the body a shape is attached to.
modit.physics.set_friction(shape, friction) -- Sets surface friction.
modit.physics.set_restitution(shape, restitution) -- Sets surface restitution.
modit.physics.set_filter(shape, category, mask) -- Sets collision category and mask bits.

```

### query

```lua
modit.physics.raycast(ox, oy, oz, dx, dy, dz, max_distance, opts) -- Casts a ray and returns the closest hit.
modit.physics.overlap_box(min_x, min_y, min_z, max_x, max_y, max_z, opts) -- Lists the bodies whose shapes overlap a box.

```

### rotation

```lua
modit.physics.quat_from_euler(pitch, yaw, roll) -- Builds a quaternion from Euler angles.
modit.physics.quat_to_euler(x, y, z, w) -- Converts a quaternion to Euler angles.

```

## Render

### draw

```lua
modit.draw.set_colour(r_or_tbl, g_or_alpha, b, a) -- Sets active drawing color using RGBA numbers or color table.
modit.draw.clear(r_or_tbl, g_or_alpha, b, a) -- Clears target canvas using RGBA numbers or color table.
modit.draw.line(...) -- Draws a line.
modit.draw.rect(...) -- Draws a rectangle.
modit.draw.rect_lines(...) -- Draws a rectangle outline.
modit.draw.circle(...) -- Draws a circle.
modit.draw.circle_lines(...) -- Draws a circle outline.
modit.draw.triangle(...) -- Draws a triangle.
modit.draw.triangle_lines(...) -- Draws a triangle outline.
modit.draw.ellipse(...) -- Draws an ellipse.
modit.draw.rect_rounded(x, y, w, h, roundness, segments) -- Draws filled rounded rectangle.
modit.draw.rect_rounded_lines(x, y, w, h, roundness, segments, thick) -- Draws outlined rounded rectangle.
modit.draw.polygon(x, y, sides, radius, rotation) -- Draws regular polygon.
modit.draw.rect_lines_ex(x, y, w, h, thick) -- Draws outlined rectangle with custom border thickness.
modit.draw.text(str, x, y, size) -- Draws text string at specified coordinates.
modit.draw.measure_text(str, size) -- Measures dimensions of text string at given font size.
modit.draw.push_clip(x, y, w, h) -- Pushes new scissor clipping rectangle onto stack.
modit.draw.pop_clip() -- Pops active scissor clipping rectangle off stack.
modit.draw.reset_clip() -- Resets and clears all active clipping rectangles from stack.
modit.draw.get_clip() -- Retrieves current active clipping rectangle coordinates.

```

### draw3d

```lua
modit.draw3d.line(...) -- Draws 3D line.
modit.draw3d.cube(...) -- Draws 3D cube.
modit.draw3d.cube_wires(...) -- Draws 3D cube wireframe.
modit.draw3d.plane(...) -- Draws 3D plane.
modit.draw3d.sphere(...) -- Draws 3D sphere.
modit.draw3d.sphere_wires(x, y, z, radius, rings, slices) -- Draws 3D sphere wireframe.
modit.draw3d.grid(slices, spacing) -- Draws 3D grid.

```

### image

```lua
modit.image.load(opts) -- Loads an image or sprite sheet.
modit.image.get_size(key) -- Gets image dimensions.
modit.image.draw(opts) -- Draws a whole image.
modit.image.draw_frame(opts) -- Draws a region of a sprite sheet.
modit.image.draw_sprite(opts) -- Draws a named animation frame.
modit.image.unload(key) -- Unloads an image.
modit.image.cleanup() -- Unloads every image.

```

### lighting

```lua
modit.lighting.set_sun(dx, dy, dz, r, g, b) -- Sets the sun direction and colour.
modit.lighting.set_ambient(r, g, b) -- Sets the ambient light colour.
modit.lighting.set_fog(near, far, r, g, b) -- Sets distance fog.
modit.lighting.set_shadows(mode, strength, range) -- Sets the shadow mode.
modit.lighting.shadow_pass(draw_casters, ground_y) -- Draws shadow casters flattened onto a ground plane.
modit.lighting.shadow_map_pass(cam, draw_casters) -- Renders the shadow map from the sun.
modit.lighting.blob(x, y, z, radius) -- Draws a soft blob shadow on the ground.
modit.lighting.reset() -- Restores the default lighting, fog and shadows.
modit.lighting.set_local_lights(lights, blockers) -- Sets up local area lights and box shadow casters.
modit.lighting.begin(cam) -- Binds the lit shader for the camera.
modit.lighting.finish() -- Unbinds the lit shader.

```

### model

```lua
modit.model.load(opts) -- Loads a model asset once per key.
modit.model.build(opts) -- Builds/replaces a mesh atomically.
modit.model.draw(opts) -- Draws a model instance.
modit.model.draw_many(instances, camera) -- Draws multiple instances with batching and sorting.
modit.model.create_instance(opts) -- Returns an independent, editable Lua transform/tint table.
modit.model.attach(parent, name, child) -- Attaches a named instance.
modit.model.detach(parent, name) -- Removes a named part.
modit.model.get_part(parent, name) -- Gets an editable child instance by name.
modit.model.load_animations(opts) -- Loads clips from a compatible skeletal file.
modit.model.get_animations(key) -- Gets copied clip descriptions.
modit.model.play(instance, opts) -- Starts independent playback on one instance.
modit.model.update(instance, dt) -- Advances the instance and its attached parts by dt seconds.
modit.model.pause(instance, paused) -- Pauses/resumes an instance.
modit.model.stop(instance) -- Returns an instance to its bind pose.
modit.model.seek(instance, seconds) -- Sets an instance frame from seconds.
modit.model.get_bounds(opts) -- Returns a copied axis-aligned box.
modit.model.get_materials(key) -- Returns copied, 1-based material descriptions.
modit.model.set_material(opts) -- Edits asset-wide colour, emission, alpha and surface settings.
modit.model.screen_ray(camera, x, y, width, height) -- Creates a ray from viewport-local screen pixels.
modit.model.raycast(instances, ray, max_distance) -- Finds the closest triangle across instances and parts.
modit.model.load_asset(opts) -- Loads a Lua asset description or complete VOX scene.
modit.model.unload(key) -- Unloads a model and its owned textures.
modit.model.cleanup() -- Releases public assets.

```

### post

```lua
modit.post.enable(opts) -- Turns post-processing on.
modit.post.disable() -- Turns post-processing off.
modit.post.get_size() -- Gets the size scene drawing should use.
modit.post.begin_scene(r, g, b) -- Starts drawing the scene.
modit.post.end_scene() -- Finishes the scene and draws it through post effects.
modit.post.close_scene() -- Ends a scene a mod left open.
modit.post.reset() -- Turns post-processing off and restores defaults.

```

### shapes

```lua
modit.shapes.push() -- Saves the current transform.
modit.shapes.pop() -- Restores the transform saved by the last push.
modit.shapes.translate(x, y, z) -- Moves everything drawn after this in local space.
modit.shapes.rotate(angle, ax, ay, az) -- Rotates everything drawn after this around an axis.
modit.shapes.scale(x, y, z) -- Scales everything drawn after this.
modit.shapes.reset() -- Clears the transform stack.
modit.shapes.draw(opts) -- Draws a shape at the current transform.

```

### sky

```lua
modit.sky.set(tr, tg, tb, hr, hg, hb) -- Sets the sky colours.
modit.sky.reset() -- Restores the default sky colours.
modit.sky.get_horizon() -- Gets the horizon colour.
modit.sky.draw(cam, width, height) -- Draws the sky over the whole screen.

```

### vox

```lua
modit.vox.decode(source, combine_colours) -- Reads static scene nodes, shared palette, emission, hidden layers and signed rotations.

```

### water

```lua
modit.water.set(opts) -- Sets up the water and turns it on.
modit.water.set_enabled(flag) -- Turns the water on or off.
modit.water.draw() -- Draws the water.
modit.water.height_at(x, z) -- Gets the water surface height at a point.
modit.water.reset() -- Turns the water off, frees its mesh and restores defaults.

```

## runtime

### cooldowns

```lua
modit.runtime.cooldowns.update(dt) -- Advances the cooldown clock.
modit.runtime.cooldowns.add_cooldown(id, kind, duration) -- Add a cooldown for a given id + kind.
modit.runtime.cooldowns.check_cooldown(id, kind) -- Check if a cooldown is still active.
modit.runtime.cooldowns.cooldown_time_remaining(id, kind) -- Get remaining time on cooldown (0 if none).
modit.runtime.cooldowns.clear_cooldown(id, kind) -- Clear a specific cooldown.
modit.runtime.cooldowns.clear_all_cooldowns(id) -- Remove all cooldowns for a given id.
modit.runtime.cooldowns.clear_expired_cooldowns() -- Clear all expired cooldowns.

```

### rng

```lua
modit.runtime.rng.set_rng_seed(s) -- Sets the seed for the RNG.
modit.runtime.rng.get_rng_seed() -- Gets the last set seed value.
modit.runtime.rng.random_rng() -- Returns a raw float in [0, 1).
modit.runtime.rng.random_int(min, max) -- Returns an integer in [min, max] inclusive.
modit.runtime.rng.get_rng_state() -- Gets the internal state for snapshot/rewind.
modit.runtime.rng.set_rng_state(s) -- Restores a previously saved state.

```

### state

```lua
modit.runtime.state.use_state(name) -- Switch to a named state (creates it if missing).
modit.runtime.state.current_state() -- Get the current state name.
modit.runtime.state.set_state(key, value, scope) -- Set a value in a state (default: current).
modit.runtime.state.get_state(key, fallback, scope) -- Get a value from a state (default: current).
modit.runtime.state.clear_state(key, scope) -- Clear a single key from a state (default: current).
modit.runtime.state.clear_all(scope) -- Clear all keys from a state (default: current).
modit.runtime.state.dump_state(scope) -- Return the key-value table of a state (default: current).
modit.runtime.state.delete_state(name) -- Delete a named state completely.
modit.runtime.state.list_states() -- List all state names, sorted.
modit.runtime.state.with_state(scope, fn) -- Temporarily run code in another state scope.

```

### timers

```lua
modit.runtime.timers.set_timer(delay, fn, owner) -- Run a function once after a delay.
modit.runtime.timers.repeat_timer(interval, fn, count, owner) -- Run a function repeatedly (like setInterval).
modit.runtime.timers.cancel_timer(id) -- Cancel a timer by ID.
modit.runtime.timers.remove_owner(owner) -- Cancel every timer registered by an owner.
modit.runtime.timers.clear_all_timers() -- Clear all active timers.
modit.runtime.timers.update(dt) -- Advances timers (also aliased as update_timer).

```

### callbacks

```lua
modit.runtime.callbacks.register_callback(name, fn, overwrite) -- Register a callback.
modit.runtime.callbacks.trigger_callback(name, ...) -- Trigger a callback.
modit.runtime.callbacks.unregister_callback(name) -- Remove a callback.
modit.runtime.callbacks.callback_exists(name) -- Check whether a callback exists.
modit.runtime.callbacks.get_each_callback() -- Iterate over all callbacks.

```

## server

### server_console

```lua
modit.server_console.init() -- Initializes the server console interface and log sink.
modit.server_console.poll() -- Polls the server console.
modit.server_console.print(message) -- Prints a message to the server console.
modit.server_console.is_closed() -- Checks if the server console is closed.
modit.server_console.close() -- Closes the server console and resets log sink.

```

### network

```lua
modit.network.tcp_listen(port) -- Starts listening for TCP connections.
modit.network.tcp_accept(listener) -- Accepts one pending connection, if any.
modit.network.tcp_connect(host, port) -- Begins a non-blocking connection to a server.
modit.network.tcp_status(socket) -- Polls the state of a connecting socket.
modit.network.tcp_send(socket, data) -- Sends raw bytes over a socket.
modit.network.tcp_recv(socket) -- Receives any raw bytes waiting on a socket.
modit.network.close(socket) -- Closes a socket or listener.
modit.network.cleanup() -- Releases network backend resources on shutdown.
modit.network.connection.new(socket) -- Creates a framed connection around a TCP socket.
modit.network.connection.send(connection, value) -- Queues a Lua value as a framed packet.
modit.network.connection.flush(connection) -- Flushes queued bytes to the socket.
modit.network.connection.receive(connection) -- Polls the socket and returns all complete packets.
modit.network.connection.close(connection) -- Closes the connection and its socket.

```

## commands

```lua
modit.commands.register_engine(name, fn, help) -- Registers an engine builtin.
modit.commands.register(name, fn, help, owner) -- Registers a game command or a mod command.
modit.commands.remove_owner(owner) -- Removes every command registered by a mod.
modit.commands.run(line) -- Parses and runs one line of input.
modit.commands.list() -- Returns list of registered commands.

```

## ui

### input

```lua
modit.ui.input.text(str, pos_x, pos_y, font_size) -- Draws text using active font or falls back to engine draw module.
modit.ui.input.measure(str, font_size) -- Measures text width using active font or falls back to engine draw module.
modit.ui.input.set_blocked(blocked) -- Sets global input block status.
modit.ui.input.in_rect(rect_x, rect_y, rect_w, rect_h) -- Checks if current mouse coordinate sits inside bounding rectangle considering active scissor clip.
modit.ui.input.interact(rect_x, rect_y, rect_w, rect_h) -- Processes element interaction state for mouse hover, click release, and hold states.
modit.ui.input.mouse() -- Returns current mouse coordinates.
modit.ui.input.wheel() -- Returns scroll wheel movement delta.
modit.ui.input.pressed() -- Returns mouse left button pressed state for current frame.
modit.ui.input.down() -- Returns mouse left button down state.
modit.ui.input.released() -- Returns mouse left button released state for current frame.
modit.ui.input.new_id() -- Generates a unique UI element identifier.
modit.ui.input.set_hot(id) -- Sets current hot UI element identifier.
modit.ui.input.is_active(id) -- Checks if specified element ID is currently active.
modit.ui.input.set_active(id) -- Sets active UI element identifier.
modit.ui.input.set_cursor(cursor_name) -- Sets current mouse cursor icon name.
modit.ui.input.is_hovered() -- Checks if any UI element is currently hovered.
modit.ui.input.begin_frame() -- Prepares input state at start of frame.
modit.ui.input.end_frame() -- Finalizes input state and updates hardware cursor at end of frame.
modit.ui.input.blur() -- Clears active keyboard focus.
modit.ui.input.set_focus(token) -- Assigns keyboard focus to given focus token.
modit.ui.input.has_focus(token) -- Checks if given focus token currently holds focus.
modit.ui.input.typed() -- Returns buffer of characters typed during current frame.
modit.ui.input.textfield(state, x, y, w, h, filter, placeholder) -- Renders interactive single-line text input field.
modit.ui.input.splitter(x, y, w, h, axis, value, dir) -- Renders panel resizing interactive splitter handle.
modit.ui.input.scroll_begin(state, x, y, w, h, content_h) -- Begins a scrollable clipping container region.
modit.ui.input.scroll_end() -- Ends active scrollable region and renders scrollbar thumb indicator.

```

### theme

```lua
modit.ui.theme.register(name, theme) -- Registers a theme with fallback to default.
modit.ui.theme.set(theme_name) -- Sets the active theme by name.
modit.ui.theme.get() -- Returns the active theme palette.
modit.ui.theme.name() -- Returns the active theme's name.
modit.ui.theme.get_value(key) -- Retrieves a single value from the active theme.
modit.ui.theme.list() -- Returns a sorted list of registered theme names.
modit.ui.theme.on_change(fn) -- Subscribes to theme changes.

```

### icons

```lua
modit.ui.icons.draw(name, rect_x, rect_y, rect_w, rect_h, size) -- Draws a Lucide icon centered inside a bounding rectangle.

```

### components

```lua
modit.ui.components.button(label, x, y, width, height, size, colour, style) -- Draws an interactive button and returns true if clicked.
modit.ui.components.icon_button(name, x, y, w, h, colour, size) -- Square button showing an icon, background appears on hover/press.
modit.ui.components.dropdown(menu_id, label_text, x_pos, y_pos, width, height, items) -- Renders a stateful dropdown menu button and handles popup overlay interactions.
modit.ui.components.modal.open(opts) -- Opens a modal dialog with configuration options.
modit.ui.components.modal.is_open() -- Checks if a modal dialog is currently active and open.
modit.ui.components.modal.close() -- Closes the currently active modal dialog.
modit.ui.components.modal.draw(w, h) -- Renders active modal overlay and processes user inputs.
modit.ui.components.panel(x, y, w, h, title) -- Draws a panel container with optional title header bar.
modit.ui.components.label(str, x, y, size, c) -- Renders a text label string with optional font sizing and color overriding.
modit.ui.components.item(label, sub, x, y, w, h) -- Renders a clickable row component with a main label and optional secondary subtext.
modit.ui.components.textfield(state, x, y, w, h, filter, placeholder) -- Renders an interactive textfield input component with focus and filtering.
modit.ui.components.splitter(x, y, w, h, axis, value, dir) -- Renders an interactive panel splitter handle and calculates updated panel dimension.
modit.ui.components.scroll_begin(state, x, y, w, h, content_h) -- Begins a scroll viewport clip area and updates scroll position from mouse wheel.
modit.ui.components.scroll_end() -- Closes active scroll viewport, renders scrollbar track/thumb, and restores scissor rect.

```