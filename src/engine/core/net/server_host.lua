--- @module server_host
--- @file src/engine/core/server_host.lua
--- @description Loads a game's server code and runs it on a fixed timestep, either beside the client or headless on its own.

--- @section Imports

local _ffi = require("ffi")
local _log = require("src.engine.core.log")

--- @section Constants

local DEFAULT_TICK_RATE = 30
local MAX_FRAME = 0.25 

--- @section Initialisation

local m = {}
m.__index = m

--- @section Helpers

local sleep_ms

if _ffi.os == "Windows" then
    pcall(_ffi.cdef, "void Sleep(unsigned long ms);")
    sleep_ms = function(ms) _ffi.C.Sleep(ms) end
else
    pcall(_ffi.cdef, "int usleep(unsigned int usec);")
    sleep_ms = function(ms) _ffi.C.usleep(ms * 1000) end
end

local now

if _ffi.os == "Windows" then
    local ok = pcall(function()
        _ffi.cdef("int QueryPerformanceCounter(int64_t *count); int QueryPerformanceFrequency(int64_t *freq);")
        local value = _ffi.new("int64_t[1]")
        _ffi.C.QueryPerformanceFrequency(value)
        local freq = tonumber(value[0])
        now = function()
            _ffi.C.QueryPerformanceCounter(value)
            return tonumber(value[0]) / freq
        end
    end)
    if not ok then now = nil end
else
    local ok = pcall(function()
        _ffi.cdef("typedef struct { long tv_sec; long tv_nsec; } modit_timespec_t; int clock_gettime(int clk_id, void *tp);")
        local ts = _ffi.new("modit_timespec_t[1]")
        now = function()
            _ffi.C.clock_gettime(1, ts) -- CLOCK_MONOTONIC
            return tonumber(ts[0].tv_sec) + tonumber(ts[0].tv_nsec) / 1e9
        end
    end)
    if not ok then now = nil end
end

now = now or os.clock

local function file_exists(path)
    local bundle = rawget(_G, "MODIT_BUNDLE")

    if bundle then
        local key = path:gsub("\\", "/")
        key = key:gsub("^%./", "")

        if bundle.has(key) then
            return true
        end
    end

    local file = io.open(path, "rb")
    if not file then
        return false
    end

    file:close()
    return true
end

--- @section Functions

--- Creates a server host
--- @param opts table { game_dir = string, tick_rate = number, crash_log = string|nil }
--- @return table host
function m.new(opts)
    local rate = tonumber(opts.tick_rate)
    if not rate or rate <= 0 then
        if opts.tick_rate ~= nil then
            _log.warn(("server.tick_rate must be a positive number, using %d"):format(DEFAULT_TICK_RATE))
        end
        rate = DEFAULT_TICK_RATE
    end

    return setmetatable({
        game_dir = opts.game_dir,
        crash_log = opts.crash_log,
        tick_rate = rate,
        tick = 1 / rate,
        accumulated = 0,
        running = false,
        crashed = false,
        quit_done = false,
        game = nil,
    }, m)
end

--- Logs a server failure, writes the crash log and stops the server
--- @param stage string load | update | quit
--- @param err any Error value
function m:fail(stage, err)
    local text = ("server %s failed:\n%s"):format(stage, tostring(err))
    _log.error(text)

    self.crashed = true
    self.running = false

    if self.crash_log then
        local handle = io.open(self.crash_log, "a")
        if handle then
            handle:write(os.date("%Y-%m-%d %H:%M:%S"), "  ", text, "\n\n")
            handle:close()
        end
    end
end

--- Requires game/server/init.lua and calls its load
--- @return boolean ok
function m:load()
    local path = self.game_dir .. "/server/init.lua"
    if not file_exists(path) then
        self:fail("load", "server.enabled is true but " .. path .. " was not found")
        return false
    end

    local ok, result = xpcall(require, debug.traceback, "server")
    if not ok then
        self:fail("load", result)
        return false
    end

    self.game = type(result) == "table" and result or {}

    local init = self.game.load or self.game.init

    if init then
        local ok_init, err = xpcall(init, debug.traceback)
        if not ok_init then
            self:fail("load", err)
            return false
        end
    end

    self.running = true
    _log.info(("server running at %d ticks per second"):format(self.tick_rate))
    return true
end

--- Advances the server by real elapsed time, running as many fixed ticks as fit
--- @param dt number Seconds since the last call
function m:step(dt)
    if not self.running then return end

    self.accumulated = math.min(self.accumulated + dt, MAX_FRAME)

    while self.running and self.accumulated >= self.tick do
        self.accumulated = self.accumulated - self.tick

        if self.game.update then
            local ok, err = xpcall(self.game.update, debug.traceback, self.tick)
            if not ok then
                self:fail("update", err)
                return
            end
        end
    end
end

--- Stops ticking. quit is still called by m:quit
function m:stop()
    self.running = false
end

--- Calls the server's quit once
function m:quit()
    self.running = false
    if self.quit_done or not self.game then return end
    self.quit_done = true

    if self.game.quit then
        local ok, err = xpcall(self.game.quit, debug.traceback)
        if not ok then self:fail("quit", err) end
    end
end

--- Blocking loop for headless servers. Returns when stopped or crashed
--- @param opts table|nil { should_stop = function|nil }
function m:run(opts)
    opts = opts or {}
    local last = now()

    while self.running do
        local current = now()
        self:step(current - last)
        last = current

        if opts.should_stop and opts.should_stop() then
            self.running = false
        end

        sleep_ms(1)
    end
end

return m