--- @module canvas
--- @file src/engine/sdk/client/canvas.lua
--- @description Offscreen render target handle: drawing into it, stretched and letterboxed display, and screen to canvas coordinate mapping.

--- @section Imports

local _backend = require("src.engine.backend").canvas
local _draw = require("src.sdk.client.draw2d")

--- @section Class Definition

--- @class Canvas
--- @field handle cdata|nil Backend render target
--- @field width number Width in pixels
--- @field height number Height in pixels
local Canvas = {}
Canvas.__index = Canvas

--- @section Constructor

--- Creates an offscreen render target
--- @access mod
--- @param width number Width in pixels
--- @param height number Height in pixels
--- @return Canvas canvas New canvas
function Canvas.new(width, height)
    local handle = _backend.new(width, height)
    local w, h = _backend.get_size(handle)

    return setmetatable({
        handle = handle,
        width = w,
        height = h,
        rect = nil,
    }, Canvas)
end

--- @section Methods

--- Gets the canvas size
--- @return number width Width in pixels
--- @return number height Height in pixels
function Canvas:get_size()
    return self.width, self.height
end

--- Starts drawing into this canvas and clears it
--- @param r number|nil Red (0-255, default 0)
--- @param g number|nil Green (0-255, default 0)
--- @param b number|nil Blue (0-255, default 0)
--- @param a number|nil Alpha (0-255, default 255)
function Canvas:begin(r, g, b, a)
    if not self.handle then return end
    _backend.begin_target(self.handle)
    _draw.clear(r or 0, g or 0, b or 0, a or 255)
end

--- Stops drawing into the canvas and returns to the screen
function Canvas:finish()
    _backend.end_target()
end

--- Draws the canvas stretched into a rectangle
--- @param x number Top-left X
--- @param y number Top-left Y
--- @param w number Width
--- @param h number Height
function Canvas:draw(x, y, w, h)
    if not self.handle then return end
    self.rect = { x, y, w, h }
    _backend.draw(self.handle, x, y, w, h)
end

--- Draws the canvas letterboxed into a rectangle, keeping its aspect ratio
--- @param x number Container top-left X
--- @param y number Container top-left Y
--- @param w number Container width
--- @param h number Container height
--- @return number dx Drawn X
--- @return number dy Drawn Y
--- @return number dw Drawn width
--- @return number dh Drawn height
function Canvas:draw_fit(x, y, w, h)
    local scale = math.min(w / self.width, h / self.height)
    local dw, dh = self.width * scale, self.height * scale
    local dx, dy = x + (w - dw) / 2, y + (h - dh) / 2

    self:draw(dx, dy, dw, dh)
    return dx, dy, dw, dh
end

--- Converts screen coordinates to canvas coordinates, using the rectangle it was last drawn into
--- @param sx number Screen X
--- @param sy number Screen Y
--- @return number|nil cx Canvas X, or nil if the canvas has not been drawn yet
--- @return number|nil cy Canvas Y
function Canvas:to_canvas(sx, sy)
    local r = self.rect
    if not r then return nil, nil end
    return (sx - r[1]) * self.width / r[3], (sy - r[2]) * self.height / r[4]
end

--- Frees the render target
function Canvas:free()
    if not self.handle then return end
    _backend.free(self.handle)
    self.handle = nil
    self.rect = nil
end

return Canvas