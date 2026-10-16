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
engine.mods = require("src.engine.core.internal.mod_manager")

--- Client Modules
-- audio
engine.audio = require("src.sdk.client.audio")

-- Render
engine.canvas = require("src.sdk.client.canvas")
engine.draw2d = require("src.sdk.client.draw2d")
engine.draw3d = require("src.sdk.client.draw3d")
engine.font = require("src.sdk.client.font")
engine.image = require("src.sdk.client.image")
engine.environment = require("src.sdk.client.environment")
engine.model = require("src.sdk.client.model")

-- Camera
engine.camera = require("src.sdk.client.camera")

-- Input
engine.input = require("src.sdk.client.input")

engine.ui = require("src.sdk.ui")

--- Shared Modules
engine.command = require("src.sdk.shared.command")
engine.filesystem = require("src.sdk.shared.filesystem")
engine.hook = require("src.sdk.shared.hook")

-- Maths Modules
engine.mat4 = require("src.sdk.shared.mat4")
engine.math = require("src.sdk.shared.math")
engine.vector = require("src.sdk.shared.vector")

-- Runtime Modules
engine.runtime = require("src.sdk.shared.runtime")

-- Physics Modules
--engine.physics2d = require("src.sdk.shared.physics2d") -- @todo will add when have box2d added in backend
engine.physics = require("src.sdk.shared.physics")

-- Utility Modules
engine.string = require("src.sdk.shared.string")
engine.table = require("src.sdk.shared.table")
engine.timestamp = require("src.sdk.shared.timestamp")

--- Server Modules
engine.server_console = require("src.sdk.server.console")
engine.network = require("src.sdk.server.network")

--- @section Functions

engine.run = function(cfg)
    return require("src.engine.core.internal.run").run(engine, cfg)
end

return engine