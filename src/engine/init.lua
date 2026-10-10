--- @module engine
--- @file src/engine/init.lua
--- @description Engine core module aggregator and initialization facade.

--- @section Imports

local _input = require("src.engine.modules.input")
local _runtime = require("src.engine.modules.runtime")

--- @section Module

return {

    --- Core
    canvas = require("src.engine.core.canvas"),
    json = require("src.engine.core.json"),
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
    maths = require("src.engine.modules.maths"),
    mods = require("src.engine.modules.mods"),
    network = require("src.engine.modules.network"),

    --- Input
    actions = _input.actions,
    keyboard = _input.keyboard,
    mouse = _input.mouse,

    --- Runtime
    runtime = _runtime,

    --- UI
    ui = require("src.engine.ui"),
}