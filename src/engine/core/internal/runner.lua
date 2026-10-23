--- @module runner
--- @file src/engine/core/internal/runner.lua
--- @description CLI bootstrapper. Parses environment, manages config, builds dynamic API surface via sandbox, and delegates.

--- @section Constants & Package Paths

package.path = "./?.lua;./?/init.lua;" .. package.path

local GLOBAL_NAME = "modit"
local BUNDLE = rawget(_G, "MODIT_BUNDLE")
local BUNDLED = BUNDLE ~= nil

--- @section Imports

local _log = require("src.engine.core.log")
local _sandbox = require("src.engine.core.internal.sandbox")

--- @section Variables

local project
local log_path
local headless = false

--- @section Argument Parsing

for i = 1, #arg do
    local value = arg[i]
    if value == "--server" then
        headless = true
    elseif value:sub(1, 2) == "--" then
        print("unknown flag: " .. value)
        os.exit(1)
    elseif BUNDLED then
    elseif not project then
        project = value
    elseif not log_path then
        log_path = value
    end
end

if BUNDLED then project = "." end

if not project then
    print("usage: luajit runner <project> [logfile] [--server]")
    os.exit(1)
end

--- @section Package Paths

local GAME_DIR = project .. "/game"

package.path = project .. "/?.lua;" ..
    project .. "/?/init.lua;" ..
    GAME_DIR .. "/?.lua;" ..
    GAME_DIR .. "/?/init.lua;" ..
    package.path

--- @section Default Config

local conf = {
    window = {
        title = (BUNDLED and rawget(_G, "MODIT_NAME")) or project:match("([^/\\]+)[/\\]*$") or "Game",
        size = { width = 1280, height = 720 },
        flags = {},
    },
    fps = { target = 144 },
    modules = {},
    modding = { enabled = false, blacklisted_modules = {} },
    server = { enabled = false, tick_rate = 30, port = 7777, server_console = false, network = false },
}

--- @section Logging

local log_file = log_path and io.open(log_path, "w")
if log_file then log_file:setvbuf("line") end

local function emit(level, text)
    if not log_file then return end
    local time = os.date("%H:%M:%S")
    for line in (text .. "\n"):gmatch("(.-)\n") do
        log_file:write(level, "\t", time, "\t", line, "\n")
    end
    log_file:flush()
end

_log.sink = emit

local raw_print = print
function print(...)
    raw_print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    emit("print", table.concat(parts, "\t"))
end

--- @section Configuration Helpers

local function merge(base, over)
    for key, value in pairs(over) do
        if type(value) == "table" and type(base[key]) == "table" then
            merge(base[key], value)
        else
            base[key] = value
        end
    end
end

local function file_exists(path)
    if BUNDLED then
        local key = path:gsub("\\", "/"):gsub("^%./", "")
        if BUNDLE.has(key) then return true end
    end
    local handle = io.open(path, "rb")
    if handle then
        handle:close()
        return true
    end
    return false
end

--- @section Configuration Loading

local CONFIG_PATH = GAME_DIR .. "/config.lua"

if file_exists(CONFIG_PATH) then
    local conf_chunk = loadfile(CONFIG_PATH)
    if conf_chunk then
        local ok, user = pcall(conf_chunk)
        if ok and type(user) == "table" then
            merge(conf, user)
        end
    end
end

--- @section Dynamic Engine API

local function build_dynamic_engine(is_headless)
    local runtime_realm = is_headless and "server" or "client"
    local enabled_modules = {}

    if type(conf.modules) == "table" then
        for name, enabled in pairs(conf.modules) do
            if enabled == true then
                enabled_modules[name] = true
            end
        end
    end

    local engine = _sandbox.load_environment(runtime_realm, "engine", { enabled = enabled_modules })

    engine.config = conf
    engine.game_dir = GAME_DIR
    engine.project_dir = project
    engine.global_name = GLOBAL_NAME
    _G[GLOBAL_NAME] = engine

    if engine.command and enabled_modules.command then
        local ok, builtin_commands = pcall(require, "src.engine.core.builtin_commands")
        if ok then engine.builtin_commands = builtin_commands end
    end

    return setmetatable(engine, {
        __index = function(_, key)
            if is_headless and (key == "window" or key == "draw" or key == "ui" or key == "renderer") then
                error(("%s.%s is client-only and unavailable on a dedicated server"):format(GLOBAL_NAME, key), 2)
            end
            return nil
        end
    })
end

--- @section Server Execution

if headless then
    local server_enabled = type(conf.server) == "table" and conf.server.enabled == true
    if not server_enabled then
        _log.error("--server needs server.enabled = true in game/config.lua")
        if log_file then log_file:close() end
        os.exit(1)
    end

    local engine = build_dynamic_engine(true)
    if engine.filesystem then engine.filesystem.init(GAME_DIR, BUNDLE) end
    if engine.mods and conf.modding and conf.modding.enabled == true then
        engine.mods.init(conf, GAME_DIR)
        engine.mods.scan()
        engine.mods.start_all("server")
    end

    local server_host = require("src.engine.core.internal.server_host")
    local srv = server_host.new({
        game_dir = GAME_DIR,
        tick_rate = conf.server.tick_rate,
        crash_log = project .. "/server_crash.log",
    })

    engine.server = { stop = function() srv:stop() end }

    local should_stop
    local console_ok, console = pcall(require, "src.sdk.server.console")
    if console_ok and type(console.is_closed) == "function" then
        should_stop = function() return console.is_closed() end
    end

    if srv:load() then srv:run({ should_stop = should_stop }) end
    srv:quit()

    if console_ok and console.close then pcall(console.close) end
    if log_file then log_file:close() end
    os.exit(srv.crashed and 1 or 0)
end

--- @section Client Execution

local engine = build_dynamic_engine(false)
if engine.filesystem then engine.filesystem.init(GAME_DIR, BUNDLE) end
local run = require("src.engine.core.internal.run")
local ok, err = pcall(run.run, engine, conf)

if not ok then
    _log.error(err)
end

--- @section Cleanup

if log_file then log_file:close() end