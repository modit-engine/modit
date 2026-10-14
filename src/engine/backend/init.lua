--- @module backend
--- @file src/engine/backend/init.lua
--- @description Backend entry point. Modules load on first access, so a headless server never loads raylib.

--- @section Imports

local _lazy = require("src.engine.core.internal.lazy")

--- @section Constants

local RAYLIB = "src.engine.backend.raylib"
local PLATFORM = "src.engine.backend.platform." .. require("ffi").os:lower()

--- @section Backend Export

return _lazy.new({
    -- client (raylib)
    camera = RAYLIB .. ".render.camera",
    canvas = RAYLIB .. ".render.canvas",
    draw = RAYLIB .. ".render.draw",
    draw3d = RAYLIB .. ".render.draw3d",
    font = RAYLIB .. ".render.font",
    image = RAYLIB .. ".render.image",
    lighting = RAYLIB .. ".render.lighting",
    model = RAYLIB .. ".render.model",
    postfx = RAYLIB .. ".render.postfx",
    sky = RAYLIB .. ".render.sky",
    window = RAYLIB .. ".render.window",

    mouse = RAYLIB .. ".input.mouse",
    keyboard = RAYLIB .. ".input.keyboard",
    -- water = RAYLIB .. ".render.water",
    -- audio = RAYLIB .. ".audio.audio",

    -- platform (shared, safe headless)
    -- process = PLATFORM .. ".process",
    -- filesystem = PLATFORM .. ".filesystem",
    http = PLATFORM .. ".http",
    -- network = PLATFORM .. ".network",
})