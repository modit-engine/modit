--- @module server
--- @file src/planetlua/server/init.lua
--- @description Headless Planet Lua server: loads server mods and runs a fixed tick.

--- Imports (nothing here may load raylib or UI code)

local _log = require("src.engine.core.log")
local _hooks = require("src.engine.modules.hooks")
local _mods = require("src.engine.modules.mods")
local _commands = require("src.engine.modules.commands")
local _builtin = require("src.engine.modules.builtin_commands")
local _terminal = require("projects.test_project.game.server.core.terminal")
local _network = require("projects.test_project.game.server.core.network")
local _console = require("src.engine.modules.server_console")

local m = {
    tick_rate = 30,
    running = true,
}

--- Loads mods and opens the terminal
function m.init()
    _hooks.register("update", "Fired every server tick with a fixed delta time")

    _builtin.register("server")

    _commands.register("quit", function() m.running = false end, "Stop the server")
    _commands.register("players", function()
        local players = _network.list()

        if #players == 0 then
            return "no players connected"
        end

        for _, player in ipairs(players) do
            _log.print("info", ("player %-4d %s:%d"):format(player.id, player.ip, player.port))
        end
    end, "List connected players")

    _mods.scan()
    _mods.start_all("server")

    _network.init()

    _log.print("success", ("server running at %d ticks per second. Type 'help' for commands"):format(m.tick_rate))
    _console.init()
    --_terminal.init()
end

--- Runs one tick
--- @param delta_time number Fixed tick length in seconds
function m.update(delta_time)
    if _console.is_closed() then
        m.running = false
        return
    end

    local command = _console.poll()
    if command then _commands.run(command) end

    --_terminal.poll(_commands.run)
    _network.update()
    _hooks.fire("update", delta_time)
end

--- Stops the server
function m.close()
    _console.close()
    _network.close()
    _mods.stop_all()
    m.running = false
end

return m