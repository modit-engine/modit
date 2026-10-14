--- @module draw2d
--- @file src/engine/api/client/draw2d.lua
--- @description 2D drawing: shapes, colour state, text and scissor clipping.

--- @section Imports

local _backend = require("src.engine.backend")
local _draw = _backend.draw2d

--- @section Initialisation

local m = {}

local clip_x, clip_y, clip_w, clip_h = {}, {}, {}, {}
local depth = 0

--- @section Colour

--- Sets active drawing colour for 2D, using RGBA numbers or a colour table
--- @param r_or_tbl number|table Red value (0-255) OR RGBA table `{r, g, b, [a]}`
--- @param g_or_alpha number|nil Green value (0-255) OR alpha override if a table was passed
--- @param b number|nil Blue value (0-255)
--- @param a number|nil Alpha value (0-255, default 255)
function m.set_colour(r_or_tbl, g_or_alpha, b, a)
    if type(r_or_tbl) == "table" then
        local c = r_or_tbl
        _draw.set_colour(c[1], c[2], c[3], g_or_alpha or c[4] or 255)
    else
        _draw.set_colour(r_or_tbl, g_or_alpha, b, a or 255)
    end
end
m.set_color = m.set_colour

--- Clears the target canvas using RGBA numbers or a colour table
--- @param r_or_tbl number|table Red value (0-255) OR RGBA table `{r, g, b, [a]}`
--- @param g_or_alpha number|nil Green value (0-255) OR alpha override if a table was passed
--- @param b number|nil Blue value (0-255)
--- @param a number|nil Alpha value (0-255, default 255)
function m.clear(r_or_tbl, g_or_alpha, b, a)
    if type(r_or_tbl) == "table" then
        local c = r_or_tbl
        _draw.clear(c[1], c[2], c[3], g_or_alpha or c[4] or 255)
    else
        _draw.clear(r_or_tbl, g_or_alpha, b, a or 255)
    end
end

--- @section 2D Shapes

--- Draws a line
--- @param x1 number Start X
--- @param y1 number Start Y
--- @param x2 number End X
--- @param y2 number End Y
m.line = _draw.line

--- Draws a filled rectangle
--- @param x number Top-left X
--- @param y number Top-left Y
--- @param w number Width
--- @param h number Height
m.rect = _draw.rect

--- Draws a rectangle outline with 1px thickness
--- @param x number Top-left X
--- @param y number Top-left Y
--- @param w number Width
--- @param h number Height
m.rect_lines = _draw.rect_lines

--- Draws a filled circle
--- @param x number Center X
--- @param y number Center Y
--- @param radius number Radius
m.circle = _draw.circle

--- Draws a circle outline
--- @param x number Center X
--- @param y number Center Y
--- @param radius number Radius
m.circle_lines = _draw.circle_lines

--- Draws a filled triangle
--- @param x1 number Point 1 X
--- @param y1 number Point 1 Y
--- @param x2 number Point 2 X
--- @param y2 number Point 2 Y
--- @param x3 number Point 3 X
--- @param y3 number Point 3 Y
m.triangle = _draw.triangle

--- Draws a triangle outline
--- @param x1 number Point 1 X
--- @param y1 number Point 1 Y
--- @param x2 number Point 2 X
--- @param y2 number Point 2 Y
--- @param x3 number Point 3 X
--- @param y3 number Point 3 Y
m.triangle_lines = _draw.triangle_lines

--- Draws a filled ellipse
--- @param x number Center X
--- @param y number Center Y
--- @param rx number Horizontal radius
--- @param ry number Vertical radius
m.ellipse = _draw.ellipse

--- Draws filled rounded rectangle
--- @param x number X position
--- @param y number Y position
--- @param w number Width in pixels
--- @param h number Height in pixels
--- @param roundness number|nil Corner rounding factor (default 0.3)
--- @param segments number|nil Corner segment count (default 0)
function m.rect_rounded(x, y, w, h, roundness, segments)
    _draw.rect_rounded(x, y, w, h, roundness or 0.3, segments or 0)
end

--- Draws outlined rounded rectangle
--- @param x number X position
--- @param y number Y position
--- @param w number Width in pixels
--- @param h number Height in pixels
--- @param roundness number|nil Corner rounding factor (default 0.3)
--- @param segments number|nil Corner segment count (default 0)
--- @param thick number|nil Line thickness in pixels (default 1)
function m.rect_rounded_lines(x, y, w, h, roundness, segments, thick)
    _draw.rect_rounded_lines(x, y, w, h, roundness or 0.3, segments or 0, thick or 1)
end

--- Draws outlined rectangle with custom border thickness
--- @param x number X position
--- @param y number Y position
--- @param w number Width in pixels
--- @param h number Height in pixels
--- @param thick number|nil Line thickness in pixels (default 2)
function m.rect_lines_ex(x, y, w, h, thick)
    _draw.rect_lines_ex(x, y, w, h, thick or 2)
end

--- Draws regular polygon
--- @param x number Center X position
--- @param y number Center Y position
--- @param sides number|nil Number of sides (default 6)
--- @param radius number|nil Radius (default 20)
--- @param rotation number|nil Rotation in degrees (default 0)
function m.polygon(x, y, sides, radius, rotation)
    _draw.polygon(x, y, sides or 6, radius or 20, rotation or 0)
end

--- @section Text

--- Draws text with the default font
--- @param str string Text to draw
--- @param x number X position
--- @param y number Y position
--- @param size number|nil Font size in pixels (default 16)
function m.text(str, x, y, size)
    _draw.text(str, x, y, size or 16)
end

--- Measures text with the default font
--- @param str string Text to measure
--- @param size number|nil Font size in pixels (default 16)
--- @return number width Text width in pixels
--- @return number height Text height in pixels (the font size)
function m.measure_text(str, size)
    size = size or 16
    return _draw.measure_text(str, size), size
end

--- @section Clipping Stack

--- Pushes a scissor clipping rectangle, clamped to the current one
--- @param x number Clip X position
--- @param y number Clip Y position
--- @param w number Clip width
--- @param h number Clip height
function m.push_clip(x, y, w, h)
    if depth > 0 then
        local px, py = clip_x[depth], clip_y[depth]
        local x2 = math.min(x + w, px + clip_w[depth])
        local y2 = math.min(y + h, py + clip_h[depth])
        x, y = math.max(x, px), math.max(y, py)
        w, h = math.max(0, x2 - x), math.max(0, y2 - y)
    end

    depth = depth + 1
    clip_x[depth], clip_y[depth], clip_w[depth], clip_h[depth] = x, y, w, h
    _draw.scissor_begin(x, y, w, h)
end

--- Pops the active clipping rectangle and restores the previous one
function m.pop_clip()
    if depth == 0 then return end

    depth = depth - 1
    _draw.scissor_end()

    if depth > 0 then
        _draw.scissor_begin(clip_x[depth], clip_y[depth], clip_w[depth], clip_h[depth])
    end
end

--- Clears every active clipping rectangle
function m.reset_clip()
    while depth > 0 do
        m.pop_clip()
    end
end

--- Gets the active clipping rectangle
--- @return number|nil x Clip X position, or nil if no clip is active
--- @return number|nil y Clip Y position
--- @return number|nil w Clip width
--- @return number|nil h Clip height
function m.get_clip()
    if depth == 0 then return nil end
    return clip_x[depth], clip_y[depth], clip_w[depth], clip_h[depth]
end

return m