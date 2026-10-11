--- @module modding
--- @file src/engine/modules/modding/init.lua
--- @description Handles initialision of modding relevent modules.

--- @section Constants

local PATH = "src.engine.modules.modding"

--- @section Module

return {

    exports = require(PATH .. ".exports"),
    mods = require(PATH .. ".manager"),

}