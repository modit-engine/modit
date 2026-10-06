--- @module camera
--- @file src/engine/backend/raylib/render/camera.lua
--- @description Raylib 2D and 3D camera modes.

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib = _raylib.ffi, _raylib.lib

local cam3 = _ffi.new("Camera3D")
local cam2 = _ffi.new("Camera2D")

local m = {}

function m.begin_3d(px, py, pz, tx, ty, tz, ux, uy, uz, fov)
    cam3.position.x, cam3.position.y, cam3.position.z = px, py, pz
    cam3.target.x, cam3.target.y, cam3.target.z = tx, ty, tz
    cam3.up.x, cam3.up.y, cam3.up.z = ux, uy, uz
    cam3.fovy, cam3.projection = fov, 0
    _lib.BeginMode3D(cam3)
end

function m.end_3d()
    _lib.EndMode3D()
end

function m.begin_2d(ox, oy, tx, ty, rotation, zoom)
    cam2.offset.x, cam2.offset.y = ox, oy
    cam2.target.x, cam2.target.y = tx, ty
    cam2.rotation, cam2.zoom = rotation, zoom
    _lib.BeginMode2D(cam2)
end

function m.end_2d()
    _lib.EndMode2D()
end

return m