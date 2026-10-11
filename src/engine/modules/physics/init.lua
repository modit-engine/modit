--- @module physics
--- @file src/engine/modules/physics/init.lua
--- @description Handles initialisation of physics relevant modules.

--- @section Constants

local PATH = "src.engine.modules.physics"

--- @section Module

return {

    world = require(PATH .. ".world"),
    body = require(PATH .. ".body"),
    shape = require(PATH .. ".shape"),
    query = require(PATH .. ".query"),
    rotation = require(PATH .. ".rotation"),

}