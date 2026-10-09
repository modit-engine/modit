--- @module engine
--- @file src/engine/init.lua
--- @description Engine core module aggregator and initialization facade.

-- @section Module

return {

    --- Core
    canvas = require("src.engine.core.canvas"),
    json = require("src.engine.core.canvas"),
    log = require("src.engine.core.log"),
    window = require("src.engine.core.window"),

    --- Modules
    audio = require("src.engine.modules.audio"),
    camera = require("src.engine.modules.camera"),
    commands = require("src.engine.modules.commands"),
    draw = require("src.engine.modules.draw"),
    draw3d = require("src.engine.modules.draw3d"),
    exports = require("src.engine.modules.exports"),
    font = require("src.engine.modules.font"),
    hooks = require("src.engine.modules.hooks"),
    http = require("src.engine.modules.http"),
    image = require("src.engine.modules.image"),
    keyboard = require("src.engine.modules.keyboard"),
    maths = require("src.engine.modules.maths"),
    mouse = require("src.engine.modules.mouse"),
    network = require("src.engine.modules.network"),
    mods = require("src.engine.modules.mods"),

    --- UI
    ui = require("src.engine.ui"),
}