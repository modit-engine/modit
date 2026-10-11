--- @module engine
--- @file src/engine/init.lua
--- @description Engine core module aggregator and initialization facade.

--- @section Sub-module Imports

local _input = require("src.engine.modules.input")
local _runtime = require("src.engine.modules.runtime")
local _render = require("src.engine.modules.render")
local _audio = require("src.engine.modules.audio")
local _camera = require("src.engine.modules.camera")
local _modding = require("src.engine.modules.modding")
local _server = require("src.engine.modules.server")
local _io = require("src.engine.modules.io")

--- @section Initialisation

local m = {
    --- Core
    canvas = require("src.engine.core.canvas"),
    json = require("src.engine.core.json"),
    log = require("src.engine.core.log"),
    window = require("src.engine.core.window"),
    hooks = require("src.engine.core.hooks")
}

--- @section Audio Modules

m.audio = _audio.audio

--- @section Camera Modules

m.camera = _camera.cam

--- @section Modding Modules

m.exports = _modding.exports
m.mods = _modding.mods

--- @section Server Modules

m.network = _server.network

--- @section IO Modules

m.http = _io.http

--- @section Maths Modules

m.maths = require("src.engine.modules.maths")

--- @section Physics Modules

m.physics = require("src.engine.modules.physics")

--- @section Commands Modules

m.commands = require("src.engine.modules.commands")

--- @section Render Modules

m.draw = _render.draw
m.draw3d = _render.draw3d
m.font = _render.font
m.image = _render.image
m.lighting = _render.lighting
m.sky = _render.sky
m.model = _render.model
m.water = _render.water
m.shapes = _render.shapes
m.post = _render.post

--- @section Input Modules

m.actions = _input.actions
m.keyboard = _input.keyboard
m.mouse = _input.mouse

--- @section Runtime Modules

m.runtime = _runtime

--- @section UI Modules

m.ui = require("src.engine.ui")

--- @section Return

return m