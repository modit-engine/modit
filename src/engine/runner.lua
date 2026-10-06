--- @module runner
--- @file src/engine/runner.lua
--- @description Standalone game launcher, hot-config loader, log redirection target, and runtime execution loop.

--- @section Environment & Setup

package.path = "./?.lua;./?/init.lua;" .. package.path

local project = arg[1]
local log_path = arg[2]

if not project then
    print("usage: luajit src/engine/runner.lua  [logfile]")
    os.exit(1)
end

--- @section Logging

local log_file = log_path and io.open(log_path, "w")
if log_file then log_file:setvbuf("line") end

--- Writes formatted log entry to editor log file
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

local raw_print = print

--- Overridden global print to mirror output to editor log sink
--- @param ... any Values to print
function print(...)
    raw_print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    emit("print", table.concat(parts, "\t"))
end

--- @section Configuration

local conf = {
    window = {
        title = project:match("([^/\\]+)[/\\]*$") or "Game",
        size = { width = 1280, height = 720 },
        flags = {},
    },
    fps = { target = 144 },
    modules = { audio = false },
}

local conf_chunk = loadfile(project .. "/config.lua")
if conf_chunk then
    for k, v in pairs(conf_chunk()) do conf[k] = v end
end

--- @section Error Handling

local crash_lines

--- Logs an error and formats line breaks for crash screen rendering
--- @param msg string Error message
local function fail(msg)
    msg = tostring(msg)
    raw_print("[error] " .. msg)
    emit("error", msg)

    crash_lines = {}
    for line in msg:gmatch("[^\n]+") do
        crash_lines[#crash_lines + 1] = (line:gsub("\t", "    "))
    end
end

--- Draws visual crash screen overlay on runtime exception
--- @param engine table Engine module instance
local function draw_crash(engine)
    local draw = engine.draw
    local w, h = engine.window.get_size()

    draw.reset_clip()
    draw.set_colour(40, 12, 12, 255)
    draw.rect(0, 0, w, h)

    draw.set_colour(255, 120, 120, 255)
    draw.text("Game error. Fix the code, then reload from the editor.", 20, 20, 20)

    draw.set_colour(255, 255, 255, 255)
    local y = 60
    for i = 1, #crash_lines do
        if y > h - 24 then break end
        draw.text(crash_lines[i], 20, y, 16)
        y = y + 20
    end
end

--- @section Boot

local engine = require("src.engine")
_G.engine = engine
engine.log.sink = emit

engine.window.init(conf)

local game

local chunk, load_err = loadfile(project .. "/main.lua")
if not chunk then
    fail(load_err)
else
    local ok, result = xpcall(chunk, debug.traceback)
    if not ok then
        fail(result)
    elseif type(result) ~= "table" then
        fail("main.lua must return a table")
    else
        game = result
        if game.load then
            local ok2, err2 = xpcall(game.load, debug.traceback)
            if not ok2 then fail(err2) end
        end
    end
end

--- @section Main Loop & Teardown

local frame_dt = 0

--- Executes single game logic update step
local function tick() game.update(frame_dt) end

--- Executes single game render pass
local function paint() game.draw() end

while not engine.window.should_close() do
    frame_dt = engine.window.get_dt()

    if game and not crash_lines and game.update then
        local ok, err = xpcall(tick, debug.traceback)
        if not ok then fail(err) end
    end

    engine.window.begin_draw()
    engine.draw.set_colour(255, 255, 255, 255)
    --engine.ui.begin_frame()

    if game and not crash_lines and game.draw then
        local ok, err = xpcall(paint, debug.traceback)
        if not ok then fail(err) end
    end
    if crash_lines then draw_crash(engine) end

    --engine.ui.end_frame()
    engine.draw.reset_clip()
    engine.window.end_draw()
end

if game and game.quit then pcall(game.quit) end
engine.window.close()
if log_file then log_file:close() end