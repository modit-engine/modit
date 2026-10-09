--- @file projects/test_project/game/server.lua
--- @description PlanetLuaServer.exe entry point

package.path = "./?.lua;./?/init.lua;" .. package.path

local _ffi = require("ffi")
pcall(_ffi.cdef, "void Sleep(unsigned long ms);")

local _server = require("projects.test_project.game.server")

_server.init()

local TICK = 1 / _server.tick_rate
local last = os.clock()
local accumulated = 0

local ok, err = xpcall(function()
    while _server.running do
        local now = os.clock()
        accumulated = math.min(accumulated + (now - last), 0.25)
        last = now

        while accumulated >= TICK do
            _server.update(TICK)
            accumulated = accumulated - TICK
        end

        _ffi.C.Sleep(1)
    end
end, debug.traceback)

local function log_exit(text)
    local f = io.open("server_crash.log", "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. "  " .. text .. "\n\n")
        f:close()
    end
end

if ok then
    log_exit("loop exited cleanly (_server.running became false)\n" .. debug.traceback())
else
    log_exit("loop crashed:\n" .. tostring(err))
end

local close_ok, close_err = pcall(_server.close)
if not close_ok then
    log_exit("_server.close failed:\n" .. tostring(close_err))
end

if not ok then error(err, 0) end