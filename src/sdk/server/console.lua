--- @module server_console
--- @file src/sdk/server/server_console.lua
--- @description Platform-independent server console interface.

--- @default_access game

--- @section Imports

local _ffi = require("ffi")
local _log = require("src.engine.core.log")
local _version = require("src.version").engine

print(_version)

--- @section Initialisation

local m = {}
local platform = _ffi.os:lower()
local _console

if platform == "windows" then
    _console = require("src.engine.backend.platform.windows.console")
else
    error("unsupported server console platform: " .. platform)
end

--- @section Functions

--- Initialise the server console and redirect engine logging to it.
function m.init()
    _log.sink = function(level, text)
        _console.print(("[%s] %s"):format(level:upper(), text))
    end

    _console.init(nil, nil, _version)
end

--- Process pending server console input and events.
--- @return any result returned by the platform console poll.
function m.poll()
    return _console.poll()
end

--- Print a message to the server console.
--- @param message string Message to display.
function m.print(message)
    _console.print(message)
end

--- Check whether the server console has been closed.
--- @return boolean closed Whether the console is closed.
function m.is_closed()
    return _console.is_closed()
end

--- Close the server console and restore the default logging sink.
function m.close()
    _log.sink = nil
    _console.close()
end

return m