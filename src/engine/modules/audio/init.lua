--- @module audio
--- @file src/engine/modules/audio/init.lua
--- @description Handles initialision of audio relevent modules.

--- @section Constants

local PATH = "src.engine.modules.audio"

--- @section Module

return {

    audio = require(PATH .. ".audio")

}