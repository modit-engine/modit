--- @module server
--- @file src/engine/modules/server/init.lua
--- @description Handles initialision of server relevent modules.

--- @section Constants

local PATH = "src.engine.modules.server"

--- @section Module

return {

    console = require(PATH .. ".console"),
    network = require(PATH .. ".network"),

}