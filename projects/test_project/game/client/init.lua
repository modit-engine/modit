--- @module client
--- @file projects/test_project/game/client/init.lua
--- @description Planet Lua client entry: switches between the menu and game screens.

--- @section Imports

local _engine = require("src.engine")
local _ui = require("src.engine.ui")
local _state = require("projects.test_project.game.client.core.state")
local _menu = require("projects.test_project.game.client.scenes.menu")
local _game = require("projects.test_project.game.client.scenes.game")
local _log = require("src.engine.core.log")
local _hooks = require("src.engine.modules.hooks")
local _mods = require("src.engine.modules.mods")
local _commands = require("src.engine.modules.commands")
local _console = require("projects.test_project.game.client.ui.console")
local _builtin = require("src.engine.modules.builtin_commands")
local _network = require("projects.test_project.game.client.core.network")

--- @section Initialisation

local m = {
    config = require("projects.test_project.game.config"),
}

local screens = {
    menu = _menu,
    game = _game,
}

--- @section Functions

function m.init()
    _console.init()
    _hooks.register("update", "Fired every frame with delta time")
    _hooks.register("draw", "Fired every frame after the screen is ready to draw")
    _hooks.register("console_toggled", "Fired when the console opens or closes, with a boolean")
    _hooks.register("hud", "Fired after draw each frame, for 2D UI on top")

    _builtin.register("client")
    _mods.scan()

    _network.connect()
end

function m.update(delta_time)
    if _engine.keyboard.pressed("f8") or (_console.is_open() and _engine.keyboard.pressed("escape")) then
        _console.toggle()
    end

    _network.update()

    if _console.is_open() then return end

    local screen = screens[_state.current]
    if screen.update then screen.update(delta_time) end
end

function m.frame()
    local window_w, window_h = _engine.window.get_size()

    _engine.draw.set_colour(255, 255, 255, 255)
    _ui.input.begin_frame()
    _ui.input.set_blocked(_ui.components.modal.is_open() or _console.is_open())

    screens[_state.current].draw()

    _ui.input.set_blocked(false)
    _console.draw()
    _ui.components.modal.draw(window_w, window_h)
    _ui.input.end_frame()
    _engine.draw.reset_clip()
end

function m.close()
    _mods.stop_all()
    _network.close()
end

return m