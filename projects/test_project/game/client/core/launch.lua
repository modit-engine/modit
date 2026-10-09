--- @module launch
--- @file projects/test_project/game/client/core/launch.lua
--- @description Join, play locally and leave. Stubs until networking and the server exist.

--- @section Imports

local _state = require("projects.test_project.game.client.core.state")

--- @section Constants

local DEFAULT_PORT = 7777

--- @section Initialisation

local m = {}

--- @section Functions

function m.join(address)
    local host, port = address:match("^([%w%.%-]+):?(%d*)$")
    if not host then
        return "Enter an address like 127.0.0.1:7777"
    end
    port = tonumber(port) or DEFAULT_PORT

    _state.set("game", { mode = "remote", address = host .. ":" .. port })
end

function m.local_play(mod)
    _state.set("game", { mode = "local", mod = mod })
end

function m.leave()
    _state.set("menu")
end

return m