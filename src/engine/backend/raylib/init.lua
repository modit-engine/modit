--- @module raylib
--- @file src/engine/backend/raylib/init.lua
--- @description Raylib backend entry point aggregating window management, 2D rendering primitives, offscreen canvases, and input handlers.

--- @section Modules

return {
    window = require("src.engine.backend.raylib.render.window"),
    draw = require("src.engine.backend.raylib.render.draw"),
    canvas = require("src.engine.backend.raylib.render.canvas"),
    mouse = require("src.engine.backend.raylib.input.mouse"),
    keyboard = require("src.engine.backend.raylib.input.keyboard"),
    camera = require("src.engine.backend.raylib.render.camera"),
    draw3d = require("src.engine.backend.raylib.render.draw3d"),
}