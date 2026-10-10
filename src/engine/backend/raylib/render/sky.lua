--- @module sky
--- @file src/engine/backend/raylib/render/sky.lua
--- @description Raylib sky backdrop: vertical gradient above the horizon, solid colour below.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _lib, _Color = _raylib.lib, _raylib.Color

--- @section State

local top_colour = _Color(0, 0, 0, 255)
local horizon_colour = _Color(0, 0, 0, 255)

--- @section Initialisation

local m = {}

--- @section Functions

--- Draws the sky over the whole screen
--- @param width number Screen width in pixels
--- @param height number Screen height in pixels
--- @param horizon_y number Horizon Y in pixels (0 to height)
--- @param tr number Top red (0-255)
--- @param tg number Top green (0-255)
--- @param tb number Top blue (0-255)
--- @param hr number Horizon red (0-255)
--- @param hg number Horizon green (0-255)
--- @param hb number Horizon blue (0-255)
function m.draw(width, height, horizon_y, tr, tg, tb, hr, hg, hb)
    top_colour.r, top_colour.g, top_colour.b = tr, tg, tb
    horizon_colour.r, horizon_colour.g, horizon_colour.b = hr, hg, hb

    if horizon_y > 0 then
        _lib.DrawRectangleGradientV(0, 0, width, horizon_y, top_colour, horizon_colour)
    end
    if horizon_y < height then
        _lib.DrawRectangle(0, horizon_y, width, height - horizon_y, horizon_colour)
    end
end

return m