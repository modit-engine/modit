--- @module draw3d
--- @file src/engine/backend/raylib/render/draw3d.lua
--- @description Raylib 3D primitives using the active draw colour.

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib = _raylib.ffi, _raylib.lib
local _draw = require("src.engine.backend.raylib.render.draw2d")

local _Vector3, _Vector2 = _ffi.typeof("Vector3"), _ffi.typeof("Vector2")
local pos_a, pos_b, size_vec = _Vector3(), _Vector3(), _Vector2()

local m = {}

function m.line(x1, y1, z1, x2, y2, z2)
    pos_a.x, pos_a.y, pos_a.z = x1, y1, z1
    pos_b.x, pos_b.y, pos_b.z = x2, y2, z2
    _lib.DrawLine3D(pos_a, pos_b, _draw.get_colour())
end

function m.cube(x, y, z, w, h, l)
    pos_a.x, pos_a.y, pos_a.z = x, y, z
    _lib.DrawCube(pos_a, w, h, l, _draw.get_colour())
end

function m.cube_wires(x, y, z, w, h, l)
    pos_a.x, pos_a.y, pos_a.z = x, y, z
    _lib.DrawCubeWires(pos_a, w, h, l, _draw.get_colour())
end

function m.plane(x, y, z, w, l)
    pos_a.x, pos_a.y, pos_a.z = x, y, z
    size_vec.x, size_vec.y = w, l
    _lib.DrawPlane(pos_a, size_vec, _draw.get_colour())
end

function m.sphere(x, y, z, radius)
    pos_a.x, pos_a.y, pos_a.z = x, y, z
    _lib.DrawSphere(pos_a, radius, _draw.get_colour())
end

function m.sphere_wires(x, y, z, radius, rings, slices)
    pos_a.x, pos_a.y, pos_a.z = x, y, z
    _lib.DrawSphereWires(pos_a, radius, rings, slices, _draw.get_colour())
end

function m.grid(slices, spacing)
    _lib.DrawGrid(slices, spacing)
end

return m