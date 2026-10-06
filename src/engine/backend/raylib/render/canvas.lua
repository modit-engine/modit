--- @module canvas
--- @file src/engine/backend/raylib/render/canvas.lua
--- @description Raylib offscreen render texture (canvas) creation, lifecycle management, target binding, and texture drawing.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib, _Color = _raylib.ffi, _raylib.lib, _raylib.Color

--- @section Types & State

local _Vector2 = _ffi.typeof("Vector2")
local _Rectangle = _ffi.typeof("Rectangle")

local source_rect = _Rectangle()
local dest_rect = _Rectangle()
local origin_vec = _Vector2(0, 0)
local tint_white = _Color(255, 255, 255, 255)

--- @section Initialisation

local m = {}

--- @section Canvas Lifecycle

--- Creates a new offscreen render texture target canvas
--- @param width number Target width in pixels
--- @param height number Target height in pixels
--- @return cdata target Created render texture object
function m.new(width, height)
    local target = _lib.LoadRenderTexture(width, height)
    _lib.SetTextureFilter(target.texture, 1)
    return target
end

--- Unloads and frees render texture canvas from VRAM memory
--- @param target cdata Render texture object to release
function m.free(target)
    _lib.UnloadRenderTexture(target)
end

--- @section Target Binding

--- Begins drawing offscreen into specified render texture target
--- @param target cdata Render texture target object
function m.begin_target(target)
    _lib.BeginTextureMode(target)
end

--- Ends drawing into current render texture target, restoring main screen target
function m.end_target()
    _lib.EndTextureMode()
end

--- @section Information & Rendering

--- Gets width and height dimensions of render texture target
--- @param target cdata Render texture target object
--- @return number width Width in pixels
--- @return number height Height in pixels
function m.get_size(target)
    return target.texture.width, target.texture.height
end

--- Draws render texture target to screen (corrects upside-down Y coordinates)
--- @param target cdata Render texture target object
--- @param pos_x number Destination X position
--- @param pos_y number Destination Y position
--- @param width number Destination width
--- @param height number Destination height
function m.draw(target, pos_x, pos_y, width, height)
    source_rect.x, source_rect.y = 0, 0
    source_rect.width, source_rect.height = target.texture.width, -target.texture.height
    dest_rect.x, dest_rect.y, dest_rect.width, dest_rect.height = pos_x, pos_y, width, height
    _lib.DrawTexturePro(target.texture, source_rect, dest_rect, origin_vec, 0, tint_white)
end

return m