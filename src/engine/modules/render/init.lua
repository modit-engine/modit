--- @module render
--- @file src/modules/render/init.lua
--- @description Initialisation of render modules.

--- @section Constants

local PATH = "src.engine.modules.render"

--- @section Module

return {
    draw = require(PATH .. ".draw"),
    draw3d = require(PATH .. ".draw3d"),
    font = require(PATH .. ".font"),
    image = require(PATH .. ".image"),
    lighting = require(PATH .. ".lighting"),
    sky = require(PATH .. ".sky"),
    model = require(PATH .. ".model")
}