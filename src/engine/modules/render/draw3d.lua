--- @module draw3d
--- @file src/engine/core/draw3d.lua
--- @description 3D primitives. Uses the colour set by draw.set_colour. Call between camera:begin_3d and end_3d.

local _backend = require("src.engine.backend").draw3d

local m = {}

m.line = _backend.line
m.cube = _backend.cube
m.cube_wires = _backend.cube_wires
m.plane = _backend.plane
m.sphere = _backend.sphere

function m.sphere_wires(x, y, z, radius, rings, slices)
    _backend.sphere_wires(x, y, z, radius or 1, rings or 16, slices or 16)
end

function m.grid(slices, spacing)
    _backend.grid(slices or 20, spacing or 1)
end

return m