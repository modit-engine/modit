--- @module draw
--- @file src/engine/backend/raylib/render/draw.lua
--- @description Raylib 2D primitive rendering, color state, scissor clipping, text drawing, and custom font handling.

--- @default_access mod

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib, _Color = _raylib.ffi, _raylib.lib, _raylib.Color

--- @section Types & State

local _Vector2 = _ffi.typeof("Vector2")
local _Rectangle = _ffi.typeof("Rectangle")

local active_color = _Color(255, 255, 255, 255)
local clear_color = _Color(0, 0, 0, 255)
local draw_rect = _Rectangle()
local pos_vec1, pos_vec2, pos_vec3 = _Vector2(), _Vector2(), _Vector2()

--- @section Initialisation

local m = {}

--- @section Colour State & Clear

--- Returns the active colour cdata, shared with the 3D backend
function m.get_colour()
    return active_color
end

--- Sets active drawing color for shapes and text
--- @param r number Red component (0-255)
--- @param g number Green component (0-255)
--- @param b number Blue component (0-255)
--- @param a number Alpha component (0-255)
function m.set_colour(r, g, b, a)
    active_color.r, active_color.g, active_color.b, active_color.a = r, g, b, a
end

--- Clears background screen buffer with target RGBA color
--- @param r number Red component (0-255)
--- @param g number Green component (0-255)
--- @param b number Blue component (0-255)
--- @param a number Alpha component (0-255)
function m.clear(r, g, b, a)
    clear_color.r, clear_color.g, clear_color.b, clear_color.a = r, g, b, a
    _lib.ClearBackground(clear_color)
end

--- @section Shape Primitives

--- Draws line from (x1, y1) to (x2, y2)
--- @param x1 number Start X position
--- @param y1 number Start Y position
--- @param x2 number End X position
--- @param y2 number End Y position
function m.line(x1, y1, x2, y2)
    _lib.DrawLine(x1, y1, x2, y2, active_color)
end

--- Draws filled rectangle
--- @param x number Top-left X position
--- @param y number Top-left Y position
--- @param w number Width
--- @param h number Height
function m.rect(x, y, w, h)
    draw_rect.x, draw_rect.y, draw_rect.width, draw_rect.height = x, y, w, h
    _lib.DrawRectangleRec(draw_rect, active_color)
end

--- Draws rectangle outline with 1px border thickness
--- @param x number Top-left X position
--- @param y number Top-left Y position
--- @param w number Width
--- @param h number Height
function m.rect_lines(x, y, w, h)
    _lib.DrawRectangleLines(x, y, w, h, active_color)
end

--- Draws rectangle outline with custom border thickness
--- @param x number Top-left X position
--- @param y number Top-left Y position
--- @param w number Width
--- @param h number Height
--- @param thick number Border thickness
function m.rect_lines_ex(x, y, w, h, thick)
    draw_rect.x, draw_rect.y, draw_rect.width, draw_rect.height = x, y, w, h
    _lib.DrawRectangleLinesEx(draw_rect, thick, active_color)
end

--- Draws filled rounded rectangle
--- @param x number Top-left X position
--- @param y number Top-left Y position
--- @param w number Width
--- @param h number Height
--- @param roundness number Roundness normalized factor (0.0 to 1.0)
--- @param segments number Corner segment resolution
function m.rect_rounded(x, y, w, h, roundness, segments)
    draw_rect.x, draw_rect.y, draw_rect.width, draw_rect.height = x, y, w, h
    _lib.DrawRectangleRounded(draw_rect, roundness, segments, active_color)
end

--- Draws rounded rectangle outline
--- @param x number Top-left X position
--- @param y number Top-left Y position
--- @param w number Width
--- @param h number Height
--- @param roundness number Roundness normalized factor (0.0 to 1.0)
--- @param segments number Corner segment resolution
--- @param thick number Border thickness
function m.rect_rounded_lines(x, y, w, h, roundness, segments, thick)
    draw_rect.x, draw_rect.y, draw_rect.width, draw_rect.height = x, y, w, h
    _lib.DrawRectangleRoundedLinesEx(draw_rect, roundness, segments, thick, active_color)
end

--- Draws filled circle
--- @param x number Center X position
--- @param y number Center Y position
--- @param radius number Circle radius
function m.circle(x, y, radius)
    _lib.DrawCircle(x, y, radius, active_color)
end

--- Draws circle outline
--- @param x number Center X position
--- @param y number Center Y position
--- @param radius number Circle radius
function m.circle_lines(x, y, radius)
    _lib.DrawCircleLines(x, y, radius, active_color)
end

--- Draws filled triangle defined by 3 vertices
--- @param x1 number Point 1 X
--- @param y1 number Point 1 Y
--- @param x2 number Point 2 X
--- @param y2 number Point 2 Y
--- @param x3 number Point 3 X
--- @param y3 number Point 3 Y
function m.triangle(x1, y1, x2, y2, x3, y3)
    -- Swapping 2 and 3 forces counter-clockwise winding order for raylib
    pos_vec1.x, pos_vec1.y = x1, y1
    pos_vec2.x, pos_vec2.y = x3, y3
    pos_vec3.x, pos_vec3.y = x2, y2
    _lib.DrawTriangle(pos_vec1, pos_vec2, pos_vec3, active_color)
end

--- Draws triangle outline defined by 3 vertices
--- @param x1 number Point 1 X
--- @param y1 number Point 1 Y
--- @param x2 number Point 2 X
--- @param y2 number Point 2 Y
--- @param x3 number Point 3 X
--- @param y3 number Point 3 Y
function m.triangle_lines(x1, y1, x2, y2, x3, y3)
    pos_vec1.x, pos_vec1.y, pos_vec2.x, pos_vec2.y, pos_vec3.x, pos_vec3.y = x1, y1, x2, y2, x3, y3
    _lib.DrawTriangleLines(pos_vec1, pos_vec2, pos_vec3, active_color)
end

--- Draws filled ellipse
--- @param x number Center X position
--- @param y number Center Y position
--- @param rx number Horizontal radius
--- @param ry number Vertical radius
function m.ellipse(x, y, rx, ry)
    _lib.DrawEllipse(x, y, rx, ry, active_color)
end

--- Draws filled regular polygon
--- @param x number Center X position
--- @param y number Center Y position
--- @param sides number Number of polygon sides
--- @param radius number Radius
--- @param rotation number Rotation angle in degrees
function m.polygon(x, y, sides, radius, rotation)
    pos_vec1.x, pos_vec1.y = x, y
    _lib.DrawPoly(pos_vec1, sides, radius, rotation, active_color)
end

--- @section Text Primitives

--- Draws text string using default font
--- @param str string Text string
--- @param x number X position
--- @param y number Y position
--- @param size number Font size
function m.text(str, x, y, size)
    _lib.DrawText(str, x, y, size, active_color)
end

--- Measures text string width in pixels using default font
--- @param str string Text string
--- @param size number Font size
--- @return number width Measured width in pixels
function m.measure_text(str, size)
    return _lib.MeasureText(str, size)
end

--- @section Scissor Clipping

--- Begins scissor clipping area box
--- @param x number Clipping rectangle top-left X position
--- @param y number Clipping rectangle top-left Y position
--- @param w number Clipping rectangle width
--- @param h number Clipping rectangle height
function m.scissor_begin(x, y, w, h)
    _lib.BeginScissorMode(x, y, w, h)
end

--- Ends current scissor clipping mode
function m.scissor_end()
    _lib.EndScissorMode()
end

return m