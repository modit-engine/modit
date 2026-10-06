--- @module engine
--- @file src/engine/init.lua
--- @description Engine core module aggregator and initialization facade.

-- @section Module

return {

    --- Core
    log = require("src.engine.core.log"),
    window = require("src.engine.core.window"),
    canvas = require("src.engine.core.canvas"),

    --- Modules
    mouse = require("src.engine.modules.mouse"),
    keyboard = require("src.engine.modules.keyboard"),
    camera = require("src.engine.modules.camera"),
    draw = require("src.engine.modules.draw"),
    draw3d = require("src.engine.modules.draw3d"),
    font = require("src.engine.modules.font"),
    hooks = require("src.engine.modules.hooks"),

    ui = require("src.engine.ui"),
}