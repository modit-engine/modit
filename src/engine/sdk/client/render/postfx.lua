--- @module postfx
--- @file src/engine/sdk/client/postfx.lua
--- @description Post-processing for the 3D scene: pixelation, colour grade, vignette, PS1-style colour quantising with dithering, and optional custom shaders.

--- @section Imports

local _backend = require("src.engine.backend").postfx
local _window = require("src.engine.core.window")
local _log = require("src.engine.core.log")

--- @section Constants

local DEFAULTS = {
    pixel_size = 1, -- window pixels per scene pixel (3 = chunky PS1 look)
    saturation = 1,
    contrast = 1,
    brightness = 0,
    vignette = 0,
    colour_levels = 0, -- colour levels per channel, 0 = off, 32 = PS1 15-bit colour
    dither = 0.5,
}

--- @section State

local enabled = false
local in_scene = false
local settings = {}
local vertex_code = nil
local fragment_code = nil

--- @section Initialisation

local m = {}

--- @section Helpers

local function number(value, fallback, low, high)
    value = tonumber(value) or fallback
    return math.max(low, math.min(high, value))
end

local function apply_defaults()
    for key, value in pairs(DEFAULTS) do settings[key] = value end
    vertex_code, fragment_code = nil, nil
end

local function start_scene(width, height, r, g, b)
    return _backend.begin_scene(width, height, r, g, b, vertex_code, fragment_code)
end

--- @section Functions

--- Turns post-processing on. Unlisted options go back to their defaults
--- @param opts table|nil `{ pixel_size?, saturation?, contrast?, brightness?, vignette?, colour_levels?, dither?, shader? }` pixel_size 1-16, saturation and contrast around 1, brightness around 0, vignette 0-1, colour_levels 0 or 2-256, dither 0-1, shader `{ vertex?, fragment? }` GLSL 330 source strings
function m.enable(opts)
    opts = opts or {}
    apply_defaults()

    settings.pixel_size = math.floor(number(opts.pixel_size, DEFAULTS.pixel_size, 1, 16))
    settings.saturation = number(opts.saturation, DEFAULTS.saturation, 0, 4)
    settings.contrast = number(opts.contrast, DEFAULTS.contrast, 0, 4)
    settings.brightness = number(opts.brightness, DEFAULTS.brightness, -1, 1)
    settings.vignette = number(opts.vignette, DEFAULTS.vignette, 0, 1)
    settings.colour_levels = math.floor(number(opts.colour_levels, DEFAULTS.colour_levels, 0, 256))
    settings.dither = number(opts.dither, DEFAULTS.dither, 0, 1)

    if type(opts.shader) == "table" then
        vertex_code = type(opts.shader.vertex) == "string" and opts.shader.vertex or nil
        fragment_code = type(opts.shader.fragment) == "string" and opts.shader.fragment or nil
    end

    enabled = true
end

--- Turns post-processing off
function m.disable()
    m.close_scene()
    enabled = false
end

--- Gets the size scene drawing should use: the low-resolution canvas when enabled, else the window
--- @return number width Scene width in pixels
--- @return number height Scene height in pixels
function m.get_size()
    local width, height = _window.get_size()
    if not enabled then return width, height end

    local size = settings.pixel_size
    return math.max(1, math.floor(width / size)), math.max(1, math.floor(height / size))
end

--- Starts drawing the scene (sky and 3D). Everything until end_scene is drawn at scene size.
--- Run lighting.shadow_map_pass BEFORE this, and draw the HUD AFTER end_scene so it stays sharp.
--- Does nothing when post-processing is off.
--- @param r number|nil Clear red (0-255, default: 0)
--- @param g number|nil Clear green (0-255, default: 0)
--- @param b number|nil Clear blue (0-255, default: 0)
function m.begin_scene(r, g, b)
    if not enabled or in_scene then return end

    local width, height = m.get_size()
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
        enabled = false
    end
end

--- Finishes the scene and draws it to the window through the post effects
function m.end_scene()
    if not in_scene then return end
    in_scene = false

    local width, height = _window.get_size()
    _backend.end_scene(width, height,
        settings.saturation, settings.contrast, settings.brightness,
        settings.vignette, settings.colour_levels, settings.dither)
end

--- Turns post-processing off and restores the defaults
function m.reset()
    m.close_scene()
    enabled = false
    apply_defaults()
end

--- @section Engine Internal

--- Ends a scene left open (for example after an error). Called by the window at the end of every frame
function m.close_scene()
    m.end_scene()
end

--- Releases the render target and shader. Called by the window on close
function m.free()
    m.close_scene()
    enabled = false
    _backend.free()
end

apply_defaults()

return m