--- @module game
--- @file projects/test_project/game/client/scenes/game.lua
--- @description In-game screen: hosts a mod and fires its update and draw hooks.

--- @section Imports

local _engine = require("src.engine")
local _ui = require("src.engine.ui")
local _hooks = require("src.engine.modules.hooks")
local _mods = require("src.engine.modules.mods")
local _state = require("projects.test_project.game.client.core.state")
local _launch = require("projects.test_project.game.client.core.launch")

--- @section Initialisation

local m = {}

local active = nil
local failure = nil
local leave_requested = false

--- @section Helpers

local function leave()
    if active then _mods.stop_all() end
    active, failure = nil, nil
    _launch.leave()
end

--- @section Functions

function m.update(delta_time)
    if not active and not failure then
        _mods.start_all("client")
        local started = false
        for _, info in ipairs(_mods.list()) do
            if info.name == "default_world" and info.state == "started" then started = true end
        end
        if started then active = true else failure = "default_world failed to start" end
    end

    if _engine.keyboard.pressed("f10") then leave() return end

    if active then
        _hooks.fire("update", delta_time)
        if leave_requested then
            leave_requested = false
            leave()
        end
    end
end

function m.draw()
    if active then
        _engine.draw.clear(30, 36, 48, 255)
        _hooks.fire("draw")
        _hooks.fire("hud")
        return
    end

    local theme = _ui.theme.get()
    _engine.draw.clear(theme.bg_main)
    _ui.components.label("Mod failed to start", 24, 24, 28, theme.text_primary)
    _ui.components.label(failure or "", 24, 68, 16, theme.accent3)
    _ui.components.label("See the console for details", 24, 92, 16, theme.text_tertiary)
    if _ui.components.button("Leave", 24, 130, 90, 30, 16, nil, "outlined") then
        leave()
    end
end

return m