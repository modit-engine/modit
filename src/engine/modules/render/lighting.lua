--- @module lighting
--- @file src/engine/modules/render/lighting.lua
--- @description Sun, ambient light, distance fog and shadows (blob, projected, shadow map) for the 3D pass. Applied automatically by camera:begin_3d.

--- @section Imports

local _backend = require("src.engine.backend").lighting
local _sky = require("src.engine.modules.render.sky")

--- @section Constants

local DEFAULTS = {
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
local MAP_SIZE = 2048 -- shadow map width and height in pixels
local SHADOW_LIFT = 0.05 -- lifts shadows off the ground to avoid z-fighting
local MIN_SUN_DROP = -0.1 -- projected shadows need the sun clearly above the horizon

-- Soft blob: radius scale and opacity share, outer to inner
local BLOB_LAYERS = { { 1.0, 1 }, { 0.66, 1 }, { 0.33, 1 } }
local BLOB_LAYER_ALPHA = 0.5

--- @section State

local sun_dir = { 0, -1, 0 }
local sun_colour = { 0, 0, 0 }
local ambient = { 0, 0, 0 }
local fog_near, fog_far = 0, 1
local fog_colour = nil -- nil follows the sky horizon
local shadow_mode = "off"
local shadow_strength = 0.5
local shadow_range = 40 -- half-size of the area around the camera covered by the shadow map
local map_vp, map_depth = nil, 1
local map_ready = false -- true once the depth pass ran this frame

--- @section Initialisation

local m = {}

--- @section Helpers

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

--- Multiplies two 4x4 matrices stored as 16 numbers in row-major order
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

--- Builds the sun's view-projection for the shadow map, centred ahead of the camera.
--- The centre snaps to whole texels so shadow edges don't shimmer while the camera moves.
--- @return table light_vp 16 numbers, row-major
--- @return number depth_range Depth covered by the light, in world units
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

--- @section Functions

--- Sets the sun direction and colour
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
--- @param r number Red (0-255)
--- @param g number Green (0-255)
--- @param b number Blue (0-255)
function m.set_ambient(r, g, b)
    ambient[1] = channel(r, ambient[1])
    ambient[2] = channel(g, ambient[2])
    ambient[3] = channel(b, ambient[3])
end

--- Sets distance fog. Without a colour, fog follows the sky horizon
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
--- @param mode string "off", "blob" (lighting.blob), "projected" (lighting.shadow_pass, flat ground) or "map" (lighting.shadow_map_pass, meshes only)
--- @param strength number|nil Shadow opacity (0-1, default: unchanged)
--- @param range number|nil Shadow map half-size in world units around the camera (default: unchanged)
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
--- Call inside camera begin_3d/end_3d, after drawing the ground. Does nothing unless the mode is "projected".
--- The ground must be flat. Overlapping casters darken each other where their shadows overlap.
--- @param draw_casters function Draws the casters with draw3d (colours are ignored)
--- @param ground_y number|nil World Y of the flat ground (default: 0)
function m.shadow_pass(draw_casters, ground_y)
    if shadow_mode ~= "projected" or type(draw_casters) ~= "function" then return end
    if sun_dir[2] > MIN_SUN_DROP then return end

    local started = _backend.shadow_begin(
        sun_dir[1], sun_dir[2], sun_dir[3],
        (tonumber(ground_y) or 0) + SHADOW_LIFT, shadow_strength, fog_near, fog_far)
    if not started then return end

    local ok, err = pcall(draw_casters)
    _backend.shadow_end()
    if not ok then error(err, 2) end
end

--- Renders the shadow map from the sun. Call once per frame BEFORE camera:begin_3d, outside any canvas.
--- Does nothing unless the mode is "map". Only meshes (model.draw) receive map shadows; draw3d primitives do not.
--- @param cam table Camera from camera.new, the shadow map is centred ahead of it
--- @param draw_casters function Draws the casters, normally with model.draw (colours are ignored)
function m.shadow_map_pass(cam, draw_casters)
    map_ready = false
    if shadow_mode ~= "map" or type(draw_casters) ~= "function" then return end

    local light_vp, depth_range = build_light(cam)
    if not _backend.map_begin(MAP_SIZE, light_vp) then return end

    local ok, err = pcall(draw_casters)
    _backend.map_end()

    map_vp, map_depth, map_ready = light_vp, depth_range, true
    if not ok then error(err, 2) end
end

--- Draws a soft blob shadow on the ground. Does nothing unless the mode is "blob".
--- Call inside camera begin_3d/end_3d.
--- @param x number Centre X
--- @param y number Ground Y under the caster
--- @param z number Centre Z
--- @param radius number Blob radius
function m.blob(x, y, z, radius)
    if shadow_mode ~= "blob" then return end

    local alpha = shadow_strength * BLOB_LAYER_ALPHA
    for index, layer in ipairs(BLOB_LAYERS) do
        _backend.blob_disc(x, y + SHADOW_LIFT + index * 0.005, z, radius * layer[1], alpha * layer[2])
    end
end

--- Restores the default lighting, fog and shadows
function m.reset()
    _backend.set_local_lights({}, {})
    local d = DEFAULTS
    sun_dir[1], sun_dir[2], sun_dir[3] = normalise(d.sun_dir[1], d.sun_dir[2], d.sun_dir[3])
    sun_colour[1], sun_colour[2], sun_colour[3] = d.sun_colour[1], d.sun_colour[2], d.sun_colour[3]
    ambient[1], ambient[2], ambient[3] = d.ambient[1], d.ambient[2], d.ambient[3]
    fog_near, fog_far, fog_colour = d.fog_near, d.fog_far, nil
    shadow_mode, shadow_strength, shadow_range = d.shadow_mode, d.shadow_strength, d.shadow_range
    map_ready = false
end

--- Sets up to eight world-space area lights and 32 box shadow casters.
--- Call outside a draw pass; pass empty tables to clear lights between scenes.
--- @param lights table Array of {x,y,z,radius,r,g,b,strength}; RGB is 0..255.
--- @param blockers table Array of {min_x,min_y,min_z,max_x,max_y,max_z}.
--- Shadows have soft approximate edges and follow box bounds, not mesh silhouettes.
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
                for _, channel in ipairs({ "r", "g", "b" }) do copy[channel] = math.max(0, math.min(255, copy[channel])) end
                sources[index] = copy
            else
                if copy.min_x > copy.max_x or copy.min_y > copy.max_y or copy.min_z > copy.max_z then
                    return false, "invalid local light blocker bounds"
                end
                boxes[index] = copy
            end
        end
    end
    _backend.set_local_lights(sources, boxes)
    return true
end

--- Binds the lit shader for the camera. Called by camera:begin_3d
--- @param cam table Camera from camera.new
--- @return boolean bound True if the shader was bound
function m.begin(cam)
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
        fr, fg, fb = _sky.get_horizon()
    end

    local bound = _backend.begin(
        vx, vy, vz,
        sun_colour[1] / 255, sun_colour[2] / 255, sun_colour[3] / 255,
        ambient[1] / 255, ambient[2] / 255, ambient[3] / 255,
        fog_near, fog_far,
        fr / 255, fg / 255, fb / 255)

    if bound then
        if map_ready then
            _backend.map_receive(map_vp, 1 / MAP_SIZE, map_depth, shadow_strength)
        else
            _backend.map_receive(nil)
        end
    end

    return bound
end

--- Unbinds the lit shader. Called by camera:end_3d
function m.finish()
    _backend.finish()
    map_ready = false
end

m.reset()

return m