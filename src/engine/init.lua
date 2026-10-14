--- @module engine
--- @file src/engine/init.lua
--- @description Handles initialisation of engine modules and function setup.

--- @section Namespace

local engine = {}

--- @section Modules

--- Core Modules
engine.json = require("src.engine.core.json")
engine.log = require("src.engine.core.log")
engine.window = require("src.engine.core.window")

--- Client Modules
-- audio
engine.audio = require("src.engine.sdk.client.audio")

-- Render
engine.canvas = require("src.engine.sdk.client.render.canvas")
engine.draw2d = require("src.engine.sdk.client.render.draw2d")
engine.draw3d = require("src.engine.sdk.client.render.draw3d")
engine.font = require("src.engine.sdk.client.render.font")
engine.image = require("src.engine.sdk.client.render.image")
engine.lighting = require("src.engine.sdk.client.render.lighting")
engine.postfx = require("src.engine.sdk.client.render.postfx")
engine.sky = require("src.engine.sdk.client.render.sky")
engine.model = require("src.engine.sdk.client.render.model")
engine.water = require("src.engine.sdk.client.render.water")

-- Camera
engine.camera = require("src.engine.sdk.client.camera")

-- Input
engine.keyboard = require("src.engine.sdk.client.input.keyboard")
engine.keymap = require("src.engine.sdk.client.input.keymap")
engine.mouse = require("src.engine.sdk.client.input.mouse")

--- Shared Modules
engine.commands = require("src.engine.sdk.shared.commands")
engine.filesystem = require("src.engine.sdk.shared.filesystem")
engine.hooks = require("src.engine.sdk.shared.hooks")

--- Maths Modules
engine.geometry2d = require("src.engine.sdk.shared.maths.geometry2d")
engine.geometry3d = require("src.engine.sdk.shared.maths.geometry3d")
engine.mat4 = require("src.engine.sdk.shared.maths.mat4")
engine.maths = require("src.engine.sdk.shared.maths.maths")
engine.vector = require("src.engine.sdk.shared.maths.vector")

--- Modding Modules

--engine.mods = require("src.engine.sdk.shared.mods") -- @todo finish new mod_sandbox before uncomment

--- Physics Modules
--engine.physics2d = require("src.engine.sdk.shared.physics2d") -- @todo will add when have box2d added in backend
engine.physics3d = require("src.engine.sdk.shared.physics3d")

--- @section Functions

engine.run = function(cfg)
    return require("src.engine.core.internal.run").run(engine, cfg)
end

return engine