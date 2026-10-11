--- @module runner
--- @file src/engine/runner.lua
--- @description Single game entry point. Boots the client independently, or runs the dedicated server alone with --server.

--- @section Environment & Setup

package.path = "./?.lua;./?/init.lua;" .. package.path

local GLOBAL_NAME = "engine"

-- Set by the launcher stub of a built game. Nil when running from source
local BUNDLE = rawget(_G, "MODIT_BUNDLE")
local BUNDLED = BUNDLE ~= nil

local project
local log_path
local headless = false

for i = 1, #arg do
    local value = arg[i]
    if value == "--server" then
        headless = true
    elseif value:sub(1, 2) == "--" then
        print("unknown flag: " .. value)
        os.exit(1)
    elseif BUNDLED then
        -- built games always run their own project, so extra arguments are ignored
    elseif not project then
        project = value
    elseif not log_path then
        log_path = value
    end
end

if BUNDLED then
    project = "."
end

if not project then
    print("usage: luajit src/engine/runner.lua <project> [logfile] [--server]")
    os.exit(1)
end

local GAME_DIR = project .. "/game"


package.path = project .. "/?.lua;" ..
    project .. "/?/init.lua;" ..
    GAME_DIR .. "/?.lua;" ..
    GAME_DIR .. "/?/init.lua;" ..
    package.path

--- @section Imports

local _log = require("src.engine.core.log")

--- @section Logging

local log_file = log_path and io.open(log_path, "w")
if log_file then log_file:setvbuf("line") end

--- Writes formatted log entry to editor log sink
--- @param level string Severity level or message identifier
--- @param text string Output message contents
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

--- Overridden global print to mirror output to editor log sink
function print(...)
    raw_print(...)

    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end

    emit("print", table.concat(parts, "\t"))
end

--- @section Configuration

local conf = {
    window = {
        title = (BUNDLED and rawget(_G, "MODIT_NAME")) or project:match("([^/\\]+)[/\\]*$") or "Game",
        size = { width = 640, height = 360 },
        flags = {},
    },
    fps = { target = 144 },
    modules = { audio = false },
    server = { enabled = false, tick_rate = 30 },
}

--- Recursively merges user config over defaults
local function merge(base, over)
    for key, value in pairs(over) do
        if type(value) == "table" and type(base[key]) == "table" then
            merge(base[key], value)
        else
            base[key] = value
        end
    end
end

--- Checks for a file on disk, or embedded in a built game
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

local CONFIG_PATH = GAME_DIR .. "/config.lua"

if not file_exists(CONFIG_PATH) then
    _log.warn("game/config.lua not found, using defaults")
else
    local conf_chunk, conf_err = loadfile(CONFIG_PATH)
    if not conf_chunk then
        _log.error("game/config.lua failed to load, using defaults:\n" .. tostring(conf_err))
    else
        local ok, user = pcall(conf_chunk)

        if not ok then
            _log.error("game/config.lua errored, using defaults:\n" .. tostring(user))
        elseif type(user) ~= "table" then
            _log.error("game/config.lua must return a table, using defaults")
        else
            merge(conf, user)
        end
    end
end

--- @section Server

local server_host = require("src.engine.core.net.server_host")

local server_enabled = type(conf.server) == "table"
    and conf.server.enabled == true

--- Creates the server host for this project
local function new_server()
    return server_host.new({
        game_dir = GAME_DIR,
        tick_rate = conf.server.tick_rate,
        crash_log = project .. "/server_crash.log",
    })
end

local HEADLESS_MODULES = {
    log = "src.engine.core.log",
    json = "src.engine.core.json",
    hooks = "src.engine.core.hooks",
    exports = "src.engine.modules.modding.exports",
    commands = "src.engine.modules.commands",
    network = "src.engine.modules.server.network",
    runtime = "src.engine.modules.runtime",
    filesystem = "src.engine.modules.io.filesystem",
    mods = "src.engine.modules.modding.manager",
    server_console = "src.engine.modules.server.console",
    physics = "src.engine.modules.physics"
}

local CLIENT_ONLY = {
    actions = true,
    draw = true,
    draw3d = true,
    lighting = true,
    model = true,
    water = true,
    shapes = true,
    sky = true,
    camera = true,
    window = true,
    keyboard = true,
    mouse = true,
    font = true,
    ui = true,
}

local function build_headless_engine()
    local engine = {}

    engine.config = conf
    engine.game_dir = GAME_DIR
    _G[GLOBAL_NAME] = engine


    for name, path in pairs(HEADLESS_MODULES) do
        local ok, mod = pcall(require, path)

        if not ok then
            local reason = tostring(mod)
            _log.error(("%s.%s failed to load from %s:\n%s"):format(GLOBAL_NAME, name, path, reason))
            error(("Failed to load required headless module '%s':\n%s"):format(path, reason), 0)
        end

        engine[name] = mod
    end

    -- Load only after all its dependencies have been registered.
    local ok, builtin_commands = pcall(
        require, "src.engine.core.builtin_commands"
    )

    if not ok then
        local reason = tostring(builtin_commands)
        _log.error(("engine.builtin_commands failed to load:\n%s"):format(reason))
        error(("Failed to load required headless module 'src.engine.core.builtin_commands':\n%s"):format(reason), 0)
    end

    engine.builtin_commands = builtin_commands

    return setmetatable(engine, {
        __index = function(_, key)
            if CLIENT_ONLY[key] then
                error(("%s.%s is client only and not available in a dedicated server"):format(
                    GLOBAL_NAME, key
                ), 2)
            end
        end
    })
end

--- Runs the server alone, then exits the process
local function run_headless()
    if not server_enabled then
        _log.error("--server needs server.enabled = true in game/config.lua")

        if log_file then
            log_file:close()
        end

        os.exit(1)
    end

    local engine = build_headless_engine()
    engine.config = conf
    engine.game_dir = GAME_DIR
    _G[GLOBAL_NAME] = engine

    if engine.filesystem then
        engine.filesystem.init(GAME_DIR)
    end

    local srv = new_server()
    engine.server = {
        stop = function()
            srv:stop()
        end,
    }

    local should_stop

    local console_ok, console = pcall(require, "src.engine.modules.server.console")

    if console_ok then
        should_stop = function()
            return console.is_closed()
        end
    else
        local reason = tostring(console):match("[^\n]+") or "unknown error"
        _log.warn("server console unavailable: " .. reason)
    end

    if srv:load() then
        srv:run({ should_stop = should_stop })
    end

    srv:quit()

    if console_ok and console.close then
        pcall(console.close)
    end

    if log_file then
        log_file:close()
    end

    os.exit(srv.crashed and 1 or 0)
end

if headless then
    run_headless()
end

--- @section Error Handling

local crash_lines

--- Logs an error and formats line breaks for crash screen rendering
local function fail(msg)
    msg = tostring(msg)
    _log.error(msg)

    crash_lines = {}

    for line in msg:gmatch("[^\n]+") do
        crash_lines[#crash_lines + 1] = line:gsub("\t", "    ")
    end
end

--- Draws visual crash screen overlay on runtime exception
local function draw_crash(engine)
    local draw = engine.draw
    local w, h = engine.window.get_size()

    draw.reset_clip()
    draw.set_colour(40, 12, 12, 255)
    draw.rect(0, 0, w, h)

    draw.set_colour(255, 120, 120, 255)
    draw.text("Game error. Save a fix to reload.", 20, 20, 20)

    draw.set_colour(255, 255, 255, 255)

    local y = 60

    for i = 1, #crash_lines do
        if y > h - 24 then
            break
        end

        draw.text(crash_lines[i], 20, y, 16)
        y = y + 20
    end
end

--- @section Boot

local engine = require("src.engine")
engine.config = conf
engine.game_dir = GAME_DIR
_G[GLOBAL_NAME] = engine
engine.log.sink = emit

engine.window.init(conf)
engine.mods.init(conf, GAME_DIR)

if engine.filesystem then
    engine.filesystem.init(GAME_DIR)
end

-- Client startup is independent of the server.
-- Launch the dedicated server separately with --server.

local game

local chunk, load_err = loadfile(GAME_DIR .. "/main.lua")

if not chunk then
    fail("game/main.lua not found or invalid:\n" .. tostring(load_err))
else
    local ok, result = xpcall(chunk, debug.traceback)

    if not ok then
        fail(result)
    elseif type(result) ~= "table" then
        fail("game/main.lua must return a table")
    else
        game = result

        if game.load then
            local ok2, err2 = xpcall(game.load, debug.traceback)

            if not ok2 then
                fail(err2)
            end
        end
    end
end

--- @section Main Loop & Teardown

local frame_dt = 0

--- Executes a single update step: engine runtime first, then game logic
local function tick()
    engine.runtime.update(frame_dt)
    engine.actions.update(frame_dt)

    if game.update then
        game.update(frame_dt)
    end
end

--- Executes a single game render pass
local function paint()
    game.draw()
end

while not engine.window.should_close() do
    frame_dt = engine.window.get_dt()

    if game and not crash_lines then
        local ok, err = xpcall(tick, debug.traceback)

        if not ok then
            fail(err)
        end
    end

    engine.window.begin_draw()
    engine.draw.set_colour(255, 255, 255, 255)

    if game and not crash_lines and game.draw then
        local ok, err = xpcall(paint, debug.traceback)

        if not ok then
            fail(err)
        end
    end

    if crash_lines then
        draw_crash(engine)
    end

    engine.draw.reset_clip()
    engine.window.end_draw()
end

if game and game.quit then
    pcall(game.quit)
end

engine.window.close()

if log_file then
    log_file:close()
end