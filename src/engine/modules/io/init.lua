--- @module io
--- @file src/engine/modules/io/init.lua
--- @description Handles initialision of io relevent modules.

--- @section Constants

local PATH = "src.engine.modules.io"

--- @section Module

return {

    http = require(PATH .. ".http"),
    filesystem = require(PATH .. ".filesystem"),

}