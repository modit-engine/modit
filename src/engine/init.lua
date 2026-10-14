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
engine.camera = require("src.engine.sdk.client.camera")
engine.canvas = require("src.engine.sdk.client.canvas")
engine.draw = require("src.engine.sdk.client.draw")
engine.font = require("src.engine.sdk.client.font")
engine.image = require("src.engine.sdk.client.image")
engine.keyboard = require("src.engine.sdk.client.keyboard")
engine.keymap = require("src.engine.sdk.client.keymap")
engine.lighting = require("src.engine.sdk.client.lighting")
engine.mouse = require("src.engine.sdk.client.mouse")
engine.postfx = require("src.engine.sdk.client.postfx")
engine.sky = require("src.engine.sdk.client.sky")
engine.model = require("src.engine.sdk.client.model")

--- Shared Modules
engine.commands = require("src.engine.sdk.shared.commands")
engine.geometry = require("src.engine.sdk.shared.geometry")
engine.hooks = require("src.engine.sdk.shared.hooks")
engine.mat4 = require("src.engine.sdk.shared.mat4")
engine.maths = require("src.engine.sdk.shared.maths")
engine.vector = require("src.engine.sdk.shared.vector")

--- @section Functions

engine.run = function(cfg)
    return require("src.engine.core.internal.run").run(engine, cfg)
end

return engine