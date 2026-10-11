--- @module raylib
--- @file src/engine/backend/raylib/init.lua
--- @description Raylib backend entry point aggregating window management, 2D rendering primitives, offscreen canvases, and input handlers.

--- @section Constants

local RENDER_PATH = "src.engine.backend.raylib.render"
local INPUT_PATH = "src.engine.backend.raylib.input"
local AUDIO_PATH = "src.engine.backend.raylib.audio"

--- @section Modules

return {
    window = require(RENDER_PATH .. ".window"),
    draw = require(RENDER_PATH .. ".draw"),
    canvas = require(RENDER_PATH .. ".canvas"),
    camera = require(RENDER_PATH .. ".camera"),
    draw3d = require(RENDER_PATH .. ".draw3d"),
    lighting = require(RENDER_PATH .. ".lighting"),
    sky = require(RENDER_PATH .. ".sky"),
    image = require(RENDER_PATH .. ".image"),
    model = require(RENDER_PATH .. ".model"),
    water = require(RENDER_PATH .. ".water"),
    font = require(RENDER_PATH .. ".font"),
    post = require(RENDER_PATH .. ".post"),

    mouse = require(INPUT_PATH .. ".mouse"),
    keyboard = require(INPUT_PATH .. ".keyboard"),

    audio = require(AUDIO_PATH .. ".audio"),
}