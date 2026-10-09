--- @module image
--- @file src/engine/backend/raylib/render/image.lua
--- @description Raylib texture loading, unloading, and region drawing.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib, _Color = _raylib.ffi, _raylib.lib, _raylib.Color

--- @section Types & State

local _Rectangle = _ffi.typeof("Rectangle")
local _Vector2 = _ffi.typeof("Vector2")

local source_rect = _Rectangle()
local dest_rect = _Rectangle()
local origin_vec = _Vector2(0, 0)
local tint = _Color(255, 255, 255, 255)

--- @section Initialisation

local m = {}

--- @section Texture Lifecycle

--- Loads a texture from disk
--- @param path string File path
--- @return cdata|nil texture Texture object, or nil if loading failed
function m.load(path)
    local texture = _lib.LoadTexture(path)
    if texture.id == 0 then return nil end
    return texture
end

--- Unloads a texture from VRAM
--- @param texture cdata Texture object to release
function m.free(texture)
    _lib.UnloadTexture(texture)
end

--- @section Information & Rendering

--- Gets texture dimensions
--- @param texture cdata Texture object
--- @return number width Width in pixels
--- @return number height Height in pixels
function m.get_size(texture)
    return texture.width, texture.height
end

--- Draws a region of a texture into a destination rectangle
--- @param texture cdata Texture object
--- @param sx number Source X
--- @param sy number Source Y
--- @param sw number Source width
--- @param sh number Source height
--- @param dx number Destination X
--- @param dy number Destination Y
--- @param dw number Destination width
--- @param dh number Destination height
--- @param r number Tint red (0-255)
--- @param g number Tint green (0-255)
--- @param b number Tint blue (0-255)
--- @param a number Tint alpha (0-255)
function m.draw(texture, sx, sy, sw, sh, dx, dy, dw, dh, r, g, b, a)
    source_rect.x, source_rect.y, source_rect.width, source_rect.height = sx, sy, sw, sh
    dest_rect.x, dest_rect.y, dest_rect.width, dest_rect.height = dx, dy, dw, dh
    tint.r, tint.g, tint.b, tint.a = r, g, b, a
    _lib.DrawTexturePro(texture, source_rect, dest_rect, origin_vec, 0, tint)
end

return m