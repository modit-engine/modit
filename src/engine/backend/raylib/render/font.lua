--- @module font
--- @file src/engine/backend/raylib/render/font.lua
--- @description Raylib custom font loading, unloading, drawing and measuring.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _draw = require("src.engine.backend.raylib.render.draw2d")
local _ffi, _lib = _raylib.ffi, _raylib.lib

--- @section Types & State

local _Vector2 = _ffi.typeof("Vector2")
local pos_vec = _Vector2()

--- @section Initialisation

local m = {}

--- @section Font Lifecycle

--- Loads custom font file with specified pixel height and codepoints
--- @param path string Font file path
--- @param size number Base font size in pixels
--- @param codepoints table|nil Optional array of character codepoints to load
--- @return cdata|nil font Loaded font handle or nil on failure
function m.load(path, size, codepoints)
    local codepoint_array, codepoint_count = nil, 0
    if codepoints and #codepoints > 0 then
        codepoint_count = #codepoints
        codepoint_array = _ffi.new("int[?]", codepoint_count)
        for i = 1, codepoint_count do
            codepoint_array[i - 1] = codepoints[i]
        end
    end

    local loaded_font = _lib.LoadFontEx(path, size, codepoint_array, codepoint_count)
    if loaded_font.texture.id == 0 or loaded_font.baseSize ~= size then
        return nil
    end
    _lib.SetTextureFilter(loaded_font.texture, 1)
    return loaded_font
end

--- Unloads custom font from VRAM
--- @param font cdata Font handle
function m.free(font)
    _lib.UnloadFont(font)
end

--- @section Rendering

--- Draws text using custom font in the active draw colour
--- @param font cdata Font handle
--- @param str string Text string
--- @param x number X position
--- @param y number Y position
--- @param size number Font rendering size
function m.text(font, str, x, y, size)
    pos_vec.x, pos_vec.y = x, y
    _lib.DrawTextEx(font, str, pos_vec, size, 0, _draw.get_colour())
end

--- Measures text width using custom font
--- @param font cdata Font handle
--- @param str string Text string
--- @param size number Font size
--- @return number width Measured text width in pixels
function m.measure(font, str, size)
    return _lib.MeasureTextEx(font, str, size, 0).x
end

return m