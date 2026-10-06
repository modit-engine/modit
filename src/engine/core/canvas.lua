--- @module canvas
--- @file src/engine/core/canvas.lua
--- @description Offscreen render target manager supporting frame buffer binding, aspect-ratio letterbox rendering, and viewport coordinate space translation.

--- @section Imports

local _backend = require("src.engine.backend").canvas
local _draw = require("src.engine.modules.draw")

--- @section Initialization

local m = {}

--- @section Functions

--- Creates a new offscreen render target canvas
--- @param width number Target width in pixels
--- @param height number Target height in pixels
--- @return table canvas Offscreen target handle
m.new = _backend.new

--- Frees memory allocated for render target canvas
--- @param target table Offscreen target handle
m.free = _backend.free

--- Retrieves dimensions of render target canvas
--- @param target table Offscreen target handle
--- @return number width Width in pixels
--- @return number height Height in pixels
m.get_size = _backend.get_size

--- Binds canvas render target and clears background color
--- @param target table Offscreen target handle
--- @param r number|nil Red component (0-255, default: 0)
--- @param g number|nil Green component (0-255, default: 0)
--- @param b number|nil Blue component (0-255, default: 0)
--- @param a number|nil Alpha component (0-255, default: 255)
function m.begin(target, r, g, b, a)
    _backend.begin_target(target)
    _draw.clear(r or 0, g or 0, b or 0, a or 255)
end

--- Unbinds canvas render target and restores primary display context
function m.finish()
    _backend.end_target()
end

--- Renders render target stretched across target rectangular region
--- @param target table Offscreen target handle
--- @param x number Top-left X position
--- @param y number Top-left Y position
--- @param w number Width
--- @param h number Height
function m.draw(target, x, y, w, h)
    _backend.draw(target, x, y, w, h)
end

--- Renders render target letterboxed inside rectangular region maintaining original aspect ratio
--- @param target table Offscreen target handle
--- @param x number Container top-left X position
--- @param y number Container top-left Y position
--- @param w number Container width
--- @param h number Container height
--- @return number dx Scaled target top-left X position
--- @return number dy Scaled target top-left Y position
--- @return number dw Scaled width
--- @return number dh Scaled height
function m.draw_fit(target, x, y, w, h)
    local cw, ch = _backend.get_size(target)
    local scale = math.min(w / cw, h / ch)
    local dw, dh = cw * scale, ch * scale
    local dx, dy = x + (w - dw) / 2, y + (h - dh) / 2
    _backend.draw(target, dx, dy, dw, dh)
    return dx, dy, dw, dh
end

--- Translates screen mouse coordinates to canvas relative logical coordinates
--- @param target table Offscreen target handle
--- @param dx number Canvas render origin X
--- @param dy number Canvas render origin Y
--- @param dw number Canvas rendered width
--- @param dh number Canvas rendered height
--- @param sx number Screen X coordinate
--- @param sy number Screen Y coordinate
--- @return number cx Canvas X coordinate
--- @return number cy Canvas Y coordinate
function m.to_canvas(target, dx, dy, dw, dh, sx, sy)
    local cw, ch = _backend.get_size(target)
    return (sx - dx) * cw / dw, (sy - dy) * ch / dh
end

return m