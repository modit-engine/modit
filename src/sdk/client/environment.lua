--- @module environment
--- @file src/sdk/client/environment.lua
--- @description Scene environment: lighting, fog and shadows, sky, post-processing and water.
--- Lighting is applied automatically by camera:begin_3d.

--- @section Imports

local _lighting_backend = require("src.engine.backend").lighting
local _sky_backend = require("src.engine.backend").sky
local _postfx_backend = require("src.engine.backend").postfx
local _water_backend = require("src.engine.backend").water
local _window = require("src.engine.core.window")
local _log = require("src.engine.core.log")

--- @section Constants

-- lighting
local LIGHTING_DEFAULTS = {
    sun_dir = { -0.4, -1, -0.3 },
    sun_colour = { 255, 242, 215 },
    ambient = { 100, 105, 125 },
    fog_near = 60,
    fog_far = 220,
    shadow_mode = "off",
    shadow_strength = 0.5,
    shadow_range = 40,
}

local SHADOW_MODES = { off = true, blob = true, projected = true, map = true }
local MAP_SIZE = 2048
local SHADOW_LIFT = 0.05
local MIN_SUN_DROP = -0.1
local BLOB_LAYERS = { { 1.0, 1 }, { 0.66, 1 }, { 0.33, 1 } }
local BLOB_LAYER_ALPHA = 0.5

-- sky
local DEFAULT_TOP = { 70, 120, 210 }
local DEFAULT_HORIZON = { 190, 215, 240 }

-- postfx
local POSTFX_DEFAULTS = {
    pixel_size = 1, -- window pixels per scene pixel (3 = chunky PS1 look)
    saturation = 1,
    contrast = 1,
    brightness = 0,
    vignette = 0,
    colour_levels = 0, -- colour levels per channel, 0 = off, 32 = PS1 15-bit colour
    dither = 0.5,
}

-- water
local MAX_CELLS = 200
local WAVE_FORWARD = 1.31 -- keep in sync with the water shader
local WAVE_BACKWARD = 0.8

local WATER_DEFAULTS = {
    x = 0, y = 0, z = 0,
    size = 80,
    cell = 2,
    colour = { 30, 95, 150 },
    opacity = 0.6,
    amplitude = 0.12,
    frequency = 0.6,
    speed = 1.2,
}

--- @section State

-- lighting
local sun_dir = { 0, -1, 0 }
local sun_colour = { 0, 0, 0 }
local ambient = { 0, 0, 0 }
local fog_near, fog_far = 0, 1
local fog_colour = nil
local shadow_mode = "off"
local shadow_strength = 0.5
local shadow_range = 40
local map_vp, map_depth = nil, 1
local map_ready = false

-- sky
local top = { DEFAULT_TOP[1], DEFAULT_TOP[2], DEFAULT_TOP[3] }
local horizon = { DEFAULT_HORIZON[1], DEFAULT_HORIZON[2], DEFAULT_HORIZON[3] }

-- postfx
local postfx_enabled = false
local in_scene = false
local settings = {}
local vertex_code = nil
local fragment_code = nil

-- water
local state = {}
local water_enabled = false
local handle = nil
local built_size, built_cells = nil, nil

--- @section Initialisation

local m = {}

--- @section Helpers

local function number(value, fallback, low, high)
    value = tonumber(value) or fallback
    return math.max(low, math.min(high, value))
end

-- lighting
local function channel(value, fallback)
    value = tonumber(value) or fallback
    return math.max(0, math.min(255, value))
end

local function normalise(x, y, z)
    local len = math.sqrt(x * x + y * y + z * z)
    if len < 1e-9 then return 0, 0, 0 end
    return x / len, y / len, z / len
end

local function cross(ax, ay, az, bx, by, bz)
    return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

local function mat_mul(a, b)
    local result = {}
    for row = 0, 3 do
        for col = 0, 3 do
            local sum = 0
            for k = 0, 3 do
                sum = sum + a[row * 4 + k + 1] * b[k * 4 + col + 1]
            end
            result[row * 4 + col + 1] = sum
        end
    end
    return result
end

local function build_light(cam)
    local range = shadow_range
    local lfx, lfy, lfz = sun_dir[1], sun_dir[2], sun_dir[3]

    local upx, upy, upz = 0, 1, 0
    if math.abs(lfy) > 0.99 then upx, upy, upz = 1, 0, 0 end

    local rx, ry, rz = normalise(cross(lfx, lfy, lfz, upx, upy, upz))
    local ux, uy, uz = cross(rx, ry, rz, lfx, lfy, lfz)

    local p, t = cam.position, cam.target
    local fx, fy, fz = normalise(t.x - p.x, t.y - p.y, t.z - p.z)
    local cx, cy, cz = p.x + fx * range * 0.5, p.y + fy * range * 0.5, p.z + fz * range * 0.5

    local texel = 2 * range / MAP_SIZE
    local lx = math.floor((cx * rx + cy * ry + cz * rz) / texel + 0.5) * texel
    local ly = math.floor((cx * ux + cy * uy + cz * uz) / texel + 0.5) * texel
    local lz = cx * lfx + cy * lfy + cz * lfz

    local half_depth = range * 1.5
    local ex = rx * lx + ux * ly + lfx * (lz - half_depth)
    local ey = ry * lx + uy * ly + lfy * (lz - half_depth)
    local ez = rz * lx + uz * ly + lfz * (lz - half_depth)

    local view = {
        rx, ry, rz, -(rx * ex + ry * ey + rz * ez),
        ux, uy, uz, -(ux * ex + uy * ey + uz * ez),
        -lfx, -lfy, -lfz, lfx * ex + lfy * ey + lfz * ez,
        0, 0, 0, 1,
    }

    local depth_range = half_depth * 2
    local proj = {
        1 / range, 0, 0, 0,
        0, 1 / range, 0, 0,
        0, 0, -2 / depth_range, -1,
        0, 0, 0, 1,
    }

    return mat_mul(proj, view), depth_range
end

-- sky
local function sky_channel(value, fallback)
    value = tonumber(value) or fallback
    return math.max(0, math.min(255, math.floor(value)))
end

-- water
local function water_channel(source, index, name, fallback)
    local value = source[name] or source[index]
    return math.max(0, math.min(255, tonumber(value) or fallback))
end

local function release()
    if handle then
        _water_backend.free(handle)
        handle, built_size, built_cells = nil, nil, nil
    end
end

local function cell_count()
    return math.max(1, math.min(MAX_CELLS, math.floor(state.size / state.cell + 0.5)))
end

local function build_vertices(size, cells)
    local vertices, count = {}, 0
    local step, half = size / cells, size / 2

    local function push(x, z)
        vertices[count + 1], vertices[count + 2], vertices[count + 3] = x, 0, z
        count = count + 3
    end

    for i = 0, cells - 1 do
        local x0, x1 = -half + i * step, -half + (i + 1) * step
        for j = 0, cells - 1 do
            local z0, z1 = -half + j * step, -half + (j + 1) * step
            push(x0, z0); push(x0, z1); push(x1, z1)
            push(x0, z0); push(x1, z1); push(x1, z0)
        end
    end

    return vertices
end

local function ensure_mesh()
    local cells = cell_count()
    if handle and built_size == state.size and built_cells == cells then return end

    release()
    handle = _water_backend.build(build_vertices(state.size, cells))
    built_size, built_cells = state.size, cells
end

-- postfx
local function apply_defaults()
    for key, value in pairs(POSTFX_DEFAULTS) do settings[key] = value end
    vertex_code, fragment_code = nil, nil
end

local function start_scene(width, height, r, g, b)
    return _postfx_backend.begin_scene(width, height, r, g, b, vertex_code, fragment_code)
end

--- @section Lighting

--- Sets the sun direction and colour
--- @access mod
--- @param dx number Direction X (the way the light travels)
--- @param dy number Direction Y
--- @param dz number Direction Z
--- @param r number|nil Red (0-255, default: unchanged)
--- @param g number|nil Green (0-255, default: unchanged)
--- @param b number|nil Blue (0-255, default: unchanged)
function m.set_sun(dx, dy, dz, r, g, b)
    dx, dy, dz = tonumber(dx), tonumber(dy), tonumber(dz)
    if dx and dy and dz then
        local nx, ny, nz = normalise(dx, dy, dz)
        if nx ~= 0 or ny ~= 0 or nz ~= 0 then
            sun_dir[1], sun_dir[2], sun_dir[3] = nx, ny, nz
        end
    end
    sun_colour[1] = channel(r, sun_colour[1])
    sun_colour[2] = channel(g, sun_colour[2])
    sun_colour[3] = channel(b, sun_colour[3])
end

--- Sets the ambient light colour
--- @access mod
--- @param r number Red (0-255)
--- @param g number Green (0-255)
--- @param b number Blue (0-255)
function m.set_ambient(r, g, b)
    ambient[1] = channel(r, ambient[1])
    ambient[2] = channel(g, ambient[2])
    ambient[3] = channel(b, ambient[3])
end

--- Sets distance fog. Without a colour, fog follows the sky horizon
--- @access mod
--- @param near number Distance where fog starts
--- @param far number Distance where fog is fully opaque
--- @param r number|nil Red (0-255)
--- @param g number|nil Green (0-255)
--- @param b number|nil Blue (0-255)
function m.set_fog(near, far, r, g, b)
    fog_near = math.max(0, tonumber(near) or fog_near)
    fog_far = math.max(fog_near + 0.001, tonumber(far) or fog_far)

    if r and g and b then
        fog_colour = { channel(r, 0), channel(g, 0), channel(b, 0) }
    else
        fog_colour = nil
    end
end

--- Sets the shadow mode
--- @access mod
--- @param mode string "off", "blob", "projected" or "map"
--- @param strength number|nil Shadow opacity (0-1, default: unchanged)
--- @param range number|nil Shadow map half-size in world units around the camera
function m.set_shadows(mode, strength, range)
    if SHADOW_MODES[mode] then
        shadow_mode = mode
    end
    strength = tonumber(strength)
    if strength then
        shadow_strength = math.max(0, math.min(1, strength))
    end
    range = tonumber(range)
    if range then
        shadow_range = math.max(1, range)
    end
end

--- Draws shadow casters flattened onto a ground plane along the sun direction.
--- Call inside camera begin_3d/end_3d, after drawing the ground.
--- @access game
--- @param draw_casters function Draws the casters with draw3d
--- @param ground_y number|nil World Y of the flat ground (default: 0)
function m.shadow_pass(draw_casters, ground_y)
    if shadow_mode ~= "projected" or type(draw_casters) ~= "function" then return end
    if sun_dir[2] > MIN_SUN_DROP then return end

    local started = _lighting_backend.shadow_begin(
        sun_dir[1], sun_dir[2], sun_dir[3],
        (tonumber(ground_y) or 0) + SHADOW_LIFT, shadow_strength, fog_near, fog_far)
    if not started then return end

    local ok, err = pcall(draw_casters)
    _lighting_backend.shadow_end()
    if not ok then error(err, 2) end
end

--- Renders the shadow map from the sun.
--- Call once per frame BEFORE camera:begin_3d, outside any canvas.
--- @access game
--- @param cam table Camera from camera.new
--- @param draw_casters function Draws the casters, normally with model.draw
function m.shadow_map_pass(cam, draw_casters)
    map_ready = false
    if shadow_mode ~= "map" or type(draw_casters) ~= "function" then return end

    local light_vp, depth_range = build_light(cam)
    if not _lighting_backend.map_begin(MAP_SIZE, light_vp) then return end

    local ok, err = pcall(draw_casters)
    _lighting_backend.map_end()

    map_vp, map_depth, map_ready = light_vp, depth_range, true
    if not ok then error(err, 2) end
end

--- Draws a soft blob shadow on the ground.
--- Call inside camera begin_3d/end_3d.
--- @access game
--- @param x number Centre X
--- @param y number Ground Y under the caster
--- @param z number Centre Z
--- @param radius number Blob radius
function m.draw_blob_shadow(x, y, z, radius)
    if shadow_mode ~= "blob" then return end

    local alpha = shadow_strength * BLOB_LAYER_ALPHA
    for index, layer in ipairs(BLOB_LAYERS) do
        _lighting_backend.blob_disc(x, y + SHADOW_LIFT + index * 0.005, z, radius * layer[1], alpha * layer[2])
    end
end

--- Restores the default lighting, fog and shadows
--- @access mod
function m.reset_lighting()
    _lighting_backend.set_local_lights({}, {})
    local d = LIGHTING_DEFAULTS
    sun_dir[1], sun_dir[2], sun_dir[3] = normalise(d.sun_dir[1], d.sun_dir[2], d.sun_dir[3])
    sun_colour[1], sun_colour[2], sun_colour[3] = d.sun_colour[1], d.sun_colour[2], d.sun_colour[3]
    ambient[1], ambient[2], ambient[3] = d.ambient[1], d.ambient[2], d.ambient[3]
    fog_near, fog_far, fog_colour = d.fog_near, d.fog_far, nil
    shadow_mode, shadow_strength, shadow_range = d.shadow_mode, d.shadow_strength, d.shadow_range
    map_ready = false
end

--- Sets up to eight world-space area lights and 32 box shadow casters.
--- Call outside a draw pass; pass empty tables to clear lights between scenes.
--- @access mod
--- @param lights table Array of {x,y,z,radius,r,g,b,strength}
--- @param blockers table Array of {min_x,min_y,min_z,max_x,max_y,max_z}
function m.set_local_lights(lights, blockers)
    if type(lights or {}) ~= "table" or type(blockers or {}) ~= "table" then
        return false, "local lights and blockers must be tables"
    end
    local sources, boxes = {}, {}
    for group, entries in ipairs({ lights or {}, blockers or {} }) do
        local fields = group == 1 and { "x", "y", "z", "radius", "r", "g", "b", "strength" }
            or { "min_x", "min_y", "min_z", "max_x", "max_y", "max_z" }
        for index = 1, math.min(#entries, group == 1 and 8 or 32) do
            local source, copy = entries[index], {}
            if type(source) ~= "table" then return false, "invalid local lighting entry" end
            for _, field in ipairs(fields) do
                local value = source[field]
                if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
                    return false, "invalid local lighting " .. field
                end
                copy[field] = value
            end
            if group == 1 then
                if copy.radius <= 0 or copy.strength < 0 then return false, "invalid local light radius or strength" end
                for _, channel_name in ipairs({ "r", "g", "b" }) do
                    copy[channel_name] = math.max(0, math.min(255, copy[channel_name]))
                end
                sources[index] = copy
            else
                if copy.min_x > copy.max_x or copy.min_y > copy.max_y or copy.min_z > copy.max_z then
                    return false, "invalid local light blocker bounds"
                end
                boxes[index] = copy
            end
        end
    end
    _lighting_backend.set_local_lights(sources, boxes)
    return true
end

--- Binds the lit shader for the camera.
--- @access game
--- @param cam table Camera from camera.new
--- @return boolean bound True if the shader was bound
function m.begin_lighting(cam)
    local p, t, u = cam.position, cam.target, cam.up

    local fx, fy, fz = normalise(t.x - p.x, t.y - p.y, t.z - p.z)
    local rx, ry, rz = normalise(cross(fx, fy, fz, u.x, u.y, u.z))
    local ux, uy, uz = cross(rx, ry, rz, fx, fy, fz)

    local dx, dy, dz = sun_dir[1], sun_dir[2], sun_dir[3]
    local vx = dx * rx + dy * ry + dz * rz
    local vy = dx * ux + dy * uy + dz * uz
    local vz = -(dx * fx + dy * fy + dz * fz)

    local fr, fg, fb
    if fog_colour then
        fr, fg, fb = fog_colour[1], fog_colour[2], fog_colour[3]
    else
        fr, fg, fb = m.get_sky_horizon()
    end

    local bound = _lighting_backend.begin(
        vx, vy, vz,
        sun_colour[1] / 255, sun_colour[2] / 255, sun_colour[3] / 255,
        ambient[1] / 255, ambient[2] / 255, ambient[3] / 255,
        fog_near, fog_far,
        fr / 255, fg / 255, fb / 255)

    if bound then
        if map_ready then
            _lighting_backend.map_receive(map_vp, 1 / MAP_SIZE, map_depth, shadow_strength)
        else
            _lighting_backend.map_receive(nil)
        end
    end

    return bound
end

--- Unbinds the lit shader. Called by camera:end_3d
--- @access game
function m.finish_lighting()
    _lighting_backend.finish()
    map_ready = false
end

--- @section Sky

--- Sets the sky colours
--- @access mod
--- @param tr number Top red (0-255)
--- @param tg number Top green (0-255)
--- @param tb number Top blue (0-255)
--- @param hr number Horizon red (0-255)
--- @param hg number Horizon green (0-255)
--- @param hb number Horizon blue (0-255)
function m.set_sky(tr, tg, tb, hr, hg, hb)
    top[1], top[2], top[3] = sky_channel(tr, top[1]), sky_channel(tg, top[2]), sky_channel(tb, top[3])
    horizon[1], horizon[2], horizon[3] = sky_channel(hr, horizon[1]), sky_channel(hg, horizon[2]), sky_channel(hb, horizon[3])
end

--- Restores the default sky colours
--- @access mod
function m.reset_sky()
    m.set_sky(DEFAULT_TOP[1], DEFAULT_TOP[2], DEFAULT_TOP[3], DEFAULT_HORIZON[1], DEFAULT_HORIZON[2], DEFAULT_HORIZON[3])
end

--- Gets the horizon colour (the default fog colour)
--- @access mod
--- @return number r Red (0-255)
--- @return number g Green (0-255)
--- @return number b Blue (0-255)
function m.get_sky_horizon()
    return horizon[1], horizon[2], horizon[3]
end

--- Draws the sky over the whole screen, horizon placed by camera pitch and fov
--- @access mod
--- @param cam table Camera from camera.new
--- @param width number Screen width in pixels
--- @param height number Screen height in pixels
function m.draw_sky(cam, width, height)
    local p, t = cam.position, cam.target
    local dx, dy, dz = t.x - p.x, t.y - p.y, t.z - p.z
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)

    local pitch = len > 0 and math.asin(math.max(-1, math.min(1, dy / len))) or 0
    local half_fov = math.tan(math.rad(cam.fov) / 2)
    local horizon_y = height / 2 + math.tan(pitch) / half_fov * height / 2
    horizon_y = math.floor(math.max(0, math.min(height, horizon_y)))

    _sky_backend.draw(width, height, horizon_y, top[1], top[2], top[3], horizon[1], horizon[2], horizon[3])
end

--- @section Post Processing

--- Turns post-processing on. Unlisted options go back to their defaults
--- @access mod
--- @param opts table|nil `{ pixel_size?, saturation?, contrast?, brightness?, vignette?, colour_levels?, dither?, shader? }` pixel_size 1-16, saturation and contrast around 1, brightness around 0, vignette 0-1, colour_levels 0 or 2-256, dither 0-1, shader `{ vertex?, fragment? }` GLSL 330 source strings
function m.enable_postfx(opts)
    opts = opts or {}
    apply_defaults()

    settings.pixel_size = math.floor(number(opts.pixel_size, POSTFX_DEFAULTS.pixel_size, 1, 16))
    settings.saturation = number(opts.saturation, POSTFX_DEFAULTS.saturation, 0, 4)
    settings.contrast = number(opts.contrast, POSTFX_DEFAULTS.contrast, 0, 4)
    settings.brightness = number(opts.brightness, POSTFX_DEFAULTS.brightness, -1, 1)
    settings.vignette = number(opts.vignette, POSTFX_DEFAULTS.vignette, 0, 1)
    settings.colour_levels = math.floor(number(opts.colour_levels, POSTFX_DEFAULTS.colour_levels, 0, 256))
    settings.dither = number(opts.dither, POSTFX_DEFAULTS.dither, 0, 1)

    if type(opts.shader) == "table" then
        vertex_code = type(opts.shader.vertex) == "string" and opts.shader.vertex or nil
        fragment_code = type(opts.shader.fragment) == "string" and opts.shader.fragment or nil
    end

    postfx_enabled = true
end

--- Turns post-processing off
--- @access mod
function m.disable_postfx()
    m.close_scene()
    postfx_enabled = false
end

--- Gets the size scene drawing should use: the low-resolution canvas when enabled, else the window
--- @access mod
--- @return number width Scene width in pixels
--- @return number height Scene height in pixels
function m.get_scene_size()
    local width, height = _window.get_size()
    if not postfx_enabled then return width, height end

    local size = settings.pixel_size
    return math.max(1, math.floor(width / size)), math.max(1, math.floor(height / size))
end

--- Starts drawing the scene (sky and 3D). Everything until end_scene is drawn at scene size.
--- Run lighting.shadow_map_pass BEFORE this, and draw the HUD AFTER end_scene so it stays sharp.
--- Does nothing when post-processing is off.
--- @access mod
--- @param r number|nil Clear red (0-255, default: 0)
--- @param g number|nil Clear green (0-255, default: 0)
--- @param b number|nil Clear blue (0-255, default: 0)
function m.begin_scene(r, g, b)
    if not postfx_enabled or in_scene then return end

    local width, height = m.get_scene_size()
    local clear_r, clear_g, clear_b = number(r, 0, 0, 255), number(g, 0, 0, 255), number(b, 0, 0, 255)

    local started = start_scene(width, height, clear_r, clear_g, clear_b)

    if not started and (vertex_code or fragment_code) then
        _log.warn("post: custom shader failed to compile, falling back to the default shader")
        vertex_code, fragment_code = nil, nil
        started = start_scene(width, height, clear_r, clear_g, clear_b)
    end

    if started then
        in_scene = true
    else
        _log.warn("post: shader failed to compile, post-processing disabled")
        postfx_enabled = false
    end
end

--- Finishes the scene and draws it to the window through the post effects
--- @access mod
function m.end_scene()
    if not in_scene then return end
    in_scene = false

    local width, height = _window.get_size()
    _postfx_backend.end_scene(width, height,
        settings.saturation, settings.contrast, settings.brightness,
        settings.vignette, settings.colour_levels, settings.dither)
end

--- Turns post-processing off and restores the defaults
--- @access mod
function m.reset_postfx()
    m.close_scene()
    postfx_enabled = false
    apply_defaults()
end

--- @section Engine Internal

--- Ends a scene left open (for example after an error). Called by the window at the end of every frame
function m.close_scene()
    m.end_scene()
end

--- Releases the render target and shader. Called by the window on close
function m.free_postfx()
    m.close_scene()
    postfx_enabled = false
    _postfx_backend.free()
end

--- @section Water

--- Sets up the water and turns it on
--- @access mod
--- @param opts table `{ x?, y?, z?, size?, cell?, colour?, opacity?, amplitude?, frequency?, speed? }` centre, level, square size and grid cell size, colour as `{ r, g, b }` (0-255), opacity 0-1, wave height, wave frequency and wave speed
function m.set_water(opts)
    opts = opts or {}

    state.x = number(opts.x, state.x, -1e6, 1e6)
    state.y = number(opts.y, state.y, -1e6, 1e6)
    state.z = number(opts.z, state.z, -1e6, 1e6)
    state.size = number(opts.size, state.size, 4, 2000)
    state.cell = number(opts.cell, state.cell, 0.25, 100)
    state.cell = math.max(state.cell, state.size / MAX_CELLS)
    state.opacity = number(opts.opacity, state.opacity, 0, 1)
    state.amplitude = number(opts.amplitude, state.amplitude, 0, 10)
    state.frequency = number(opts.frequency, state.frequency, 0.01, 10)
    state.speed = number(opts.speed, state.speed, 0, 20)

    if type(opts.colour) == "table" then
        local c, old = opts.colour, state.colour
        state.colour = { water_channel(c, 1, "r", old[1]), water_channel(c, 2, "g", old[2]), water_channel(c, 3, "b", old[3]) }
    end

    water_enabled = true
end

--- Turns the water on or off without losing its settings
--- @access mod
--- @param flag boolean True to show the water
function m.set_water_enabled(flag)
    water_enabled = flag and true or false
end

--- Draws the water. Call last inside camera begin_3d/end_3d, after the opaque scene
--- @access mod
function m.draw_water()
    if not water_enabled then return end

    ensure_mesh()
    local colour = state.colour
    _water_backend.draw(handle, state.x, state.y, state.z, os.clock(),
        state.amplitude, state.frequency, state.speed,
        colour[1] / 255, colour[2] / 255, colour[3] / 255, state.opacity)
end

--- Gets the water surface height at a point, matching what is drawn (for boats and floating objects)
--- @access mod
--- @param x number World X
--- @param z number World Z
--- @return number|nil height Surface Y, or nil when the water is off or the point is outside it
function m.get_water_height(x, z)
    if not water_enabled then return nil end

    local half = state.size / 2
    if x < state.x - half or x > state.x + half or z < state.z - half or z > state.z + half then
        return nil
    end

    local t = os.clock() * state.speed
    local f = state.frequency
    local wave = math.sin(x * f + t) + math.sin(z * f * WAVE_FORWARD - t * WAVE_BACKWARD)
    return state.y + wave * 0.5 * state.amplitude
end

--- Turns the water off, frees its mesh and restores the defaults
--- @access mod
function m.reset_water()
    water_enabled = false
    release()
    for key, value in pairs(WATER_DEFAULTS) do
        state[key] = type(value) == "table" and { value[1], value[2], value[3] } or value
    end
end

--- @section Defaults

m.reset_lighting()
apply_defaults()
m.reset_water()

return m