--- @module lighting
--- @file src/engine/modules/lighting.lua
--- @description Sun, ambient light and distance fog for the 3D pass. Applied automatically by camera:begin_3d.

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
}

--- @section State

local sun_dir = { 0, -1, 0 }
local sun_colour = { 0, 0, 0 }
local ambient = { 0, 0, 0 }
local fog_near, fog_far = 0, 1
local fog_colour = nil -- nil follows the sky horizon

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

--- Restores the default lighting and fog
function m.reset()
    local d = DEFAULTS
    sun_dir[1], sun_dir[2], sun_dir[3] = normalise(d.sun_dir[1], d.sun_dir[2], d.sun_dir[3])
    sun_colour[1], sun_colour[2], sun_colour[3] = d.sun_colour[1], d.sun_colour[2], d.sun_colour[3]
    ambient[1], ambient[2], ambient[3] = d.ambient[1], d.ambient[2], d.ambient[3]
    fog_near, fog_far, fog_colour = d.fog_near, d.fog_far, nil
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

    return _backend.begin(
        vx, vy, vz,
        sun_colour[1] / 255, sun_colour[2] / 255, sun_colour[3] / 255,
        ambient[1] / 255, ambient[2] / 255, ambient[3] / 255,
        fog_near, fog_far,
        fr / 255, fg / 255, fb / 255)
end

--- Unbinds the lit shader. Called by camera:end_3d
function m.finish()
    _backend.finish()
end

m.reset()

return m