--- @module backend
--- @file src/engine/backend/init.lua
--- @description Backend entry point. Modules load on first access, so a headless server never loads raylib or unnecessary subsystems.

--- @section Imports

local _lazy = require("src.engine.core.internal.lazy")

--- @section Constants

local RAYLIB = "src.engine.backend.raylib"
local PLATFORM = "src.engine.backend.platform." .. require("ffi").os:lower()

--- @section Backend Export

return _lazy.new({
    -- Raylib render: client
    camera = RAYLIB .. ".render.camera",
    canvas = RAYLIB .. ".render.canvas",
    draw2d = RAYLIB .. ".render.draw2d",
    draw3d = RAYLIB .. ".render.draw3d",
    font = RAYLIB .. ".render.font",
    image = RAYLIB .. ".render.image",
    lighting = RAYLIB .. ".render.lighting",
    model = RAYLIB .. ".render.model",
    postfx = RAYLIB .. ".render.postfx",
    sky = RAYLIB .. ".render.sky",
    water = RAYLIB .. ".render.water",
    window = RAYLIB .. ".render.window",

    -- Raylib input: client
    mouse = RAYLIB .. ".input.mouse",
    keyboard = RAYLIB .. ".input.keyboard",
    
    -- Raylib audio: client
    audio = RAYLIB .. ".audio.audio",

    -- Physics Subsystem
    -- physics2d = "src.engine.backend.box2d", -- @todo uncomment when add box2d
    physics3d = "src.engine.backend.box3d",

    -- Platform: shared
    console = PLATFORM .. ".console",
    process = PLATFORM .. ".process",
    filesystem = PLATFORM .. ".filesystem",
    http = PLATFORM .. ".http",
    network = PLATFORM .. ".network",
})