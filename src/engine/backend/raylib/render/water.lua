--- @module water
--- @file src/engine/backend/raylib/render/water.lua
--- @description Raylib water surface mesh: build, free and draw with the water shader.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib, _Color = _raylib.ffi, _raylib.lib, _raylib.Color
local _lighting = require("src.engine.backend.raylib.render.lighting")
local _model = require("src.engine.backend.raylib.render.model")

--- @section Types & State

local _Vector3 = _ffi.typeof("Vector3")

local position_vec = _Vector3()
local axis_vec = _Vector3(0, 1, 0)
local scale_vec = _Vector3(1, 1, 1)
local tint = _Color(255, 255, 255, 255)

--- @section Initialisation

local m = {}

--- @section Functions

--- Builds a water mesh from flat x, y, z triangle vertices
--- @param vertices table Flat list: x, y, z per vertex
--- @return table model Backend-owned model asset
function m.build(vertices)
    return _model.build(vertices)
end

--- Releases a water mesh
--- @param model table Backend-owned model asset
function m.free(model)
    _model.free(model)
end

--- Draws the water mesh. Does nothing outside a lit 3D pass
--- @param model table Backend-owned model asset
--- @param x number Position X
--- @param y number Water level
--- @param z number Position Z
--- @param time number Animation time in seconds
--- @param amplitude number Wave height
--- @param frequency number Wave frequency
--- @param speed number Wave speed
--- @param r number Water red (0-1)
--- @param g number Water green (0-1)
--- @param b number Water blue (0-1)
--- @param opacity number Base opacity (0-1)
function m.draw(model, x, y, z, time, amplitude, frequency, speed, r, g, b, opacity)
    if not model or not model.native then return end
    local shader = _lighting.water_shader()
    if not shader then return end

    _lighting.set_water(time, amplitude, frequency, speed, r, g, b, opacity)

    local native_model = model.native
    for index = 0, native_model.materialCount - 1 do
        model.saved_shaders[index] = native_model.materials[index].shader
        native_model.materials[index].shader = shader
    end

    position_vec.x, position_vec.y, position_vec.z = x, y, z
    local ok, reason = pcall(_lib.DrawModelEx, native_model, position_vec, axis_vec, 0, scale_vec, tint)
    for index = 0, native_model.materialCount - 1 do
        native_model.materials[index].shader = model.saved_shaders[index]
    end
    if not ok then error(reason, 0) end
end

return m
