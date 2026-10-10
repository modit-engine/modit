--- @module maths
--- @file src/modules/maths/init.lua
--- @description Provides mathematical utilities, geometry, and vector operations.

--- @section Constants

local PATH = "src.engine.modules.maths"

--- @section Module

return {
    core = require(PATH .. ".core"),
    easing = require(PATH .. ".easing"),
    geo2d = require(PATH .. ".geo2d"),
    geo3d = require(PATH .. ".geo3d"),
    mat4 = require(PATH .. ".mat4"),
    probability = require(PATH .. ".probability"),
    statistics = require(PATH .. ".statistics"),
    vec2 = require(PATH .. ".vec2"),
    vec3 = require(PATH .. ".vec3"),
    vec4 = require(PATH .. ".vec4"),
}