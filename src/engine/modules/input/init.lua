--- @module input
--- @file src/modules/input/init.lua
--- @description Handles initialising input modules.

--- @section Constants

local PATH = "src.engine.modules.input"

-- @section Module

return {

    mouse = require(PATH .. ".mouse"),
    keyboard = require(PATH .. ".keyboard"),
    actions = require(PATH .. ".actions"),

}