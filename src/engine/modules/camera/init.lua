--- @module camera
--- @file src/engine/modules/camera/init.lua
--- @description Handles initialision of camera relevent modules.

--- @section Constants

local PATH = "src.engine.modules.camera"

--- @section Module

return {

    cam = require(PATH .. ".cam")

}