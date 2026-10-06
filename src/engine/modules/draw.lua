--- @module draw
--- @file src/engine/core/draw.lua
--- @description Vector shape drawing, color state management, text rendering, and scissor clipping stack facade.

--- @section Imports

local _backend = require("src.engine.backend").draw

--- @section Initialisation

local m = {}

--- @section Colour

--- Sets active drawing color using RGBA numbers or color table
--- @param r_or_tbl number|table Red value (0-255) OR RGBA table `{r, g, b, [a]}`
--- @param g_or_alpha number|nil Green value (0-255) OR alpha override if table passed
--- @param b number|nil Blue value (0-255)
--- @param a number|nil Alpha value (0-255)
function m.set_colour(r_or_tbl, g_or_alpha, b, a)
    if type(r_or_tbl) == "table" then
        local c = r_or_tbl
        _backend.set_colour(c[1], c[2], c[3], g_or_alpha or c[4] or 255)
    else
        _backend.set_colour(r_or_tbl, g_or_alpha, b, a or 255)
    end
end
m.set_color = m.set_colour

--- Clears target canvas using RGBA numbers or color table
--- @param r_or_tbl number|table Red value (0-255) OR RGBA table `{r, g, b, [a]}`
--- @param g_or_alpha number|nil Green value (0-255) OR alpha override if table passed
--- @param b number|nil Blue value (0-255)
--- @param a number|nil Alpha value (0-255)
function m.clear(r_or_tbl, g_or_alpha, b, a)
    if type(r_or_tbl) == "table" then
        local c = r_or_tbl
        _backend.clear(c[1], c[2], c[3], g_or_alpha or c[4] or 255)
    else
        _backend.clear(r_or_tbl, g_or_alpha, b, a or 255)
    end
end

--- @section Shapes

m.line = _backend.line
m.rect = _backend.rect
m.rect_lines = _backend.rect_lines
m.circle = _backend.circle
m.circle_lines = _backend.circle_lines
m.triangle = _backend.triangle
m.triangle_lines = _backend.triangle_lines
m.ellipse = _backend.ellipse

--- Draws filled rounded rectangle
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param w number Width in pixels
--- @param h number Height in pixels
--- @param roundness number|nil Corner rounding factor (default 0.3)
--- @param segments number|nil Corner segment count (default 0)
function m.rect_rounded(x, y, w, h, roundness, segments)
    _backend.rect_rounded(x, y, w, h, roundness or 0.3, segments or 0)
end

--- Draws outlined rounded rectangle
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param w number Width in pixels
--- @param h number Height in pixels
--- @param roundness number|nil Corner rounding factor (default 0.3)
--- @param segments number|nil Corner segment count (default 0)
--- @param thick number|nil Line thickness in pixels (default 1)
function m.rect_rounded_lines(x, y, w, h, roundness, segments, thick)
    _backend.rect_rounded_lines(x, y, w, h, roundness or 0.3, segments or 0, thick or 1)
end

--- Draws regular polygon
--- @param x number Center X coordinate
--- @param y number Center Y coordinate
--- @param sides number|nil Number of polygon sides (default 6)
--- @param radius number|nil Polygon radius (default 20)
--- @param rotation number|nil Rotation angle in degrees (default 0)
function m.polygon(x, y, sides, radius, rotation)
    _backend.polygon(x, y, sides or 6, radius or 20, rotation or 0)
end

--- Draws outlined rectangle with custom border thickness
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param w number Width in pixels
--- @param h number Height in pixels
--- @param thick number|nil Line thickness in pixels (default 2)
function m.rect_lines_ex(x, y, w, h, thick)
    _backend.rect_lines_ex(x, y, w, h, thick or 2)
end

--- @section Text

--- Draws text string at specified coordinates
--- @param str string Text string to draw
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param size number|nil Font size in pixels (default 16)
function m.text(str, x, y, size)
    _backend.text(str, x, y, size or 16)
end

--- Measures dimensions of text string at given font size
--- @param str string Text string to measure
--- @param size number|nil Font size in pixels (default 16)
--- @return number width Text width in pixels
--- @return number height Text height in pixels
function m.measure_text(str, size)
    return _backend.measure_text(str, size or 16)
end

--- @section Clipping Stack

local cx, cy, cw, ch = {}, {}, {}, {}
local depth = 0

--- Pushes new scissor clipping rectangle onto stack
--- @param x number Clipping rectangle X position
--- @param y number Clipping rectangle Y position
--- @param w number Clipping rectangle width
--- @param h number Clipping rectangle height
function m.push_clip(x, y, w, h)
    if depth > 0 then
        local px, py = cx[depth], cy[depth]
        local x2 = math.min(x + w, px + cw[depth])
        local y2 = math.min(y + h, py + ch[depth])
        x, y = math.max(x, px), math.max(y, py)
        w, h = math.max(0, x2 - x), math.max(0, y2 - y)
    end
    depth = depth + 1
    cx[depth], cy[depth], cw[depth], ch[depth] = x, y, w, h
    _backend.scissor_begin(x, y, w, h)
end

--- Pops active scissor clipping rectangle off stack
function m.pop_clip()
    if depth == 0 then
        return
    end
    depth = depth - 1
    _backend.scissor_end()
    if depth > 0 then
        _backend.scissor_begin(cx[depth], cy[depth], cw[depth], ch[depth])
    end
end

--- Resets and clears all active clipping rectangles from stack
function m.reset_clip()
    while depth > 0 do
        m.pop_clip()
    end
end

--- Retrieves current active clipping rectangle coordinates
--- @return number|nil x Active clip X position or nil if stack empty
--- @return number|nil y Active clip Y position
--- @return number|nil w Active clip width
--- @return number|nil h Active clip height
function m.get_clip()
    if depth == 0 then
        return nil
    end
    return cx[depth], cy[depth], cw[depth], ch[depth]
end

return m