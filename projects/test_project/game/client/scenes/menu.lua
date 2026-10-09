--- @module menu
--- @file projects/test_project/game/client/scenes/menu.lua
--- @description Main menu screen: direct connect and play locally.

--- @section Imports

local _engine = require("src.engine")
local _ui = require("src.engine.ui")
local _launch = require("projects.test_project.game.client.core.launch")

--- @section Initialisation

local m = {}

local address_input = { text = "127.0.0.1:7777", max = 64 }
local status_message = nil

--- @section Functions

function m.draw()
    local theme = _ui.theme.get()
    local window_w, window_h = _engine.window.get_size()

    _engine.draw.set_colour(theme.bg_main)
    _engine.draw.rect(0, 0, window_w, window_h)

    local column_w = math.min(420, window_w - 40)
    local x = (window_w - column_w) / 2
    local y = math.floor(window_h * 0.25)

    _ui.components.label("Planet Lua", x, y, 28, theme.text_primary)
    y = y + 56

    _ui.components.label("Server address", x, y, 16, theme.text_secondary)
    y = y + 24

    local join_w = 90
    local submitted = _ui.components.textfield(address_input, x, y, column_w - join_w - 8, 30, "[%w%.:%-]", "ip:port")
    local join_clicked = _ui.components.button("Join", x + column_w - join_w, y, join_w, 30)
    if submitted or join_clicked then
        status_message = _launch.join(address_input.text)
    end
    y = y + 54

    if _ui.components.button("Play locally", x, y, column_w, 36, 16, nil, "outlined") then
        status_message = _launch.local_play("default_world")
    end
    y = y + 54

    if status_message then
        _ui.components.label(status_message, x, y, 16, theme.accent3)
    end
end

return m