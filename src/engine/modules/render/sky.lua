--- @module sky
--- @file src/engine/modules/sky.lua
--- @description Gradient sky backdrop that follows camera pitch. Draw it before camera:begin_3d.

--- @section Imports

local _backend = require("src.engine.backend").sky

--- @section Constants

local DEFAULT_TOP = { 70, 120, 210 }
local DEFAULT_HORIZON = { 190, 215, 240 }

--- @section State

local top = { DEFAULT_TOP[1], DEFAULT_TOP[2], DEFAULT_TOP[3] }
local horizon = { DEFAULT_HORIZON[1], DEFAULT_HORIZON[2], DEFAULT_HORIZON[3] }

--- @section Initialisation

local m = {}

--- @section Helpers

local function channel(value, fallback)
    value = tonumber(value) or fallback
    return math.max(0, math.min(255, math.floor(value)))
end

--- @section Functions

--- Sets the sky colours
--- @param tr number Top red (0-255)
--- @param tg number Top green (0-255)
--- @param tb number Top blue (0-255)
--- @param hr number Horizon red (0-255)
--- @param hg number Horizon green (0-255)
--- @param hb number Horizon blue (0-255)
function m.set(tr, tg, tb, hr, hg, hb)
    top[1], top[2], top[3] = channel(tr, top[1]), channel(tg, top[2]), channel(tb, top[3])
    horizon[1], horizon[2], horizon[3] = channel(hr, horizon[1]), channel(hg, horizon[2]), channel(hb, horizon[3])
end

--- Restores the default sky colours
function m.reset()
    m.set(DEFAULT_TOP[1], DEFAULT_TOP[2], DEFAULT_TOP[3],
        DEFAULT_HORIZON[1], DEFAULT_HORIZON[2], DEFAULT_HORIZON[3])
end

--- Gets the horizon colour (the default fog colour)
--- @return number r Red (0-255)
--- @return number g Green (0-255)
--- @return number b Blue (0-255)
function m.get_horizon()
    return horizon[1], horizon[2], horizon[3]
end

--- Draws the sky over the whole screen, horizon placed by camera pitch and fov
--- @param cam table Camera from camera.new
--- @param width number Screen width in pixels
--- @param height number Screen height in pixels
function m.draw(cam, width, height)
    local p, t = cam.position, cam.target
    local dx, dy, dz = t.x - p.x, t.y - p.y, t.z - p.z
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)

    local pitch = len > 0 and math.asin(math.max(-1, math.min(1, dy / len))) or 0
    local half_fov = math.tan(math.rad(cam.fov) / 2)
    local horizon_y = height / 2 + math.tan(pitch) / half_fov * height / 2
    horizon_y = math.floor(math.max(0, math.min(height, horizon_y)))

    _backend.draw(width, height, horizon_y,
        top[1], top[2], top[3], horizon[1], horizon[2], horizon[3])
end

return m