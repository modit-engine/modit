--- @module backend
--- @file src/engine/backend/init.lua
--- @description Engine backend entry point for Raylib modules and filesystem implementations.

--- @section Imports

local _ffi = require("ffi")
local _raylib = require("src.engine.backend.raylib")

--- @section Platform Detection

local PLATFORM = _ffi.os:lower()

--- @section Backend Export

return {
    window = _raylib.window,
    draw = _raylib.draw,
    canvas = _raylib.canvas,
    mouse = _raylib.mouse,
    keyboard = _raylib.keyboard,
    camera = _raylib.camera,
    draw3d = _raylib.draw3d,
    lighting = _raylib.lighting,
    sky = _raylib.sky,
    audio = _raylib.audio,
    font = _raylib.font,
    image = _raylib.image,
    model = _raylib.model,
    water = _raylib.water,

    process = require("src.engine.backend.platform." .. PLATFORM .. ".process"),
    filesystem = require("src.engine.backend.platform." .. PLATFORM .. ".filesystem"),
    http = require("src.engine.backend.platform." .. PLATFORM .. ".http"),
    network = require("src.engine.backend.platform." .. PLATFORM .. ".network"),
}