--- @module draw3d
--- @file src/engine/api/client/draw3d.lua
--- @description 3D drawing: shapes and grid rendering. Only works between camera:begin_3d and camera:end_3d.

--- @section Imports

local _backend = require("src.engine.backend")
local _draw2d = _backend.draw2d
local _draw3d = _backend.draw3d

--- @section Initialisation

local m = {}

--- @section 3D Shapes

--- Draws a 3D line
--- @access mod
--- @param x1 number Start X
--- @param y1 number Start Y
--- @param z1 number Start Z
--- @param x2 number End X
--- @param y2 number End Y
--- @param z2 number End Z
m.line = _draw3d.line

--- Draws a filled cube
--- @access mod
--- @param x number Center X
--- @param y number Center Y
--- @param z number Center Z
--- @param w number Width
--- @param h number Height
--- @param l number Length
m.cube = _draw3d.cube

--- Draws a wireframe cube
--- @access mod
--- @param x number Center X
--- @param y number Center Y
--- @param z number Center Z
--- @param w number Width
--- @param h number Height
--- @param l number Length
m.cube_wires = _draw3d.cube_wires

--- Draws a flat plane
--- @access mod
--- @param x number Center X
--- @param y number Center Y
--- @param z number Center Z
--- @param w number Size along X
--- @param l number Size along Z
m.plane = _draw3d.plane

--- Draws a filled sphere
--- @access mod
--- @param x number Center X
--- @param y number Center Y
--- @param z number Center Z
--- @param radius number Radius
m.sphere = _draw3d.sphere

--- Draws a wireframe sphere
--- @access mod
--- @param x number Center X
--- @param y number Center Y
--- @param z number Center Z
--- @param radius number|nil Radius (default 1)
--- @param rings number|nil Ring count (default 16)
--- @param slices number|nil Slice count (default 16)
function m.sphere_wires(x, y, z, radius, rings, slices)
    _draw3d.sphere_wires(x, y, z, radius or 1, rings or 16, slices or 16)
end

--- Draws a ground grid centered on the origin
--- @access mod
--- @param slices number|nil Lines per side (default 20)
--- @param spacing number|nil Distance between lines (default 1)
function m.grid(slices, spacing)
    _draw3d.grid(slices or 20, spacing or 1)
end

--- Sets active drawing color using RGBA numbers or color table
--- @access mod
--- @param r_or_tbl number|table Red value (0-255) OR RGBA table `{r, g, b, [a]}`
--- @param g_or_alpha number|nil Green value (0-255) OR alpha override if table passed
--- @param b number|nil Blue value (0-255)
--- @param a number|nil Alpha value (0-255)
function m.set_colour(r_or_tbl, g_or_alpha, b, a)
    if type(r_or_tbl) == "table" then
        local c = r_or_tbl
        _draw2d.set_colour(c[1], c[2], c[3], g_or_alpha or c[4] or 255)
    else
        _draw2d.set_colour(r_or_tbl, g_or_alpha, b, a or 255)
    end
end

--- @access mod
m.set_color = m.set_colour

return m