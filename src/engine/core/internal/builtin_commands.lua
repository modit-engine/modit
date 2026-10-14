--- @module builtin_commands
--- @file src/engine/modules/builtin_commands.lua
--- @description Engine mod management commands shared by the client console and server console.

local _engine = assert(rawget(_G, "engine"), "engine namespace is not initialized")

local _log = assert(_engine.log, "engine.log is unavailable")
local _commands = assert(_engine.commands, "engine.commands is unavailable")
local _mods = assert(_engine.mods, "engine.mods is unavailable")

local m = {}

--- Registers mods, start, stop and restart as engine commands
--- @param realm string "client" or "server"
function m.register(realm)
    _commands.register_engine("mods", function()
        for _, info in ipairs(_mods.list()) do
            _log.print("info", ("%-16s %-8s %s"):format(
                info.name,
                info.state,
                info.version or ""
            ))
        end
    end, "List mods")

    _commands.register_engine("start", function(args)
        if not args[1] then
            return "usage: start <mod>"
        end

        local ok, err = _mods.start(args[1], realm)
        if not ok then return err end
    end, "Start a mod")

    _commands.register_engine("stop", function(args)
        if not args[1] then
            return "usage: stop <mod>"
        end

        _mods.stop(args[1])
    end, "Stop a mod")

    _commands.register_engine("restart", function(args)
        if not args[1] then
            return "usage: restart <mod>"
        end

        local ok, err = _mods.restart(args[1])
        if not ok then return err end
    end, "Restart a mod")
end

return m