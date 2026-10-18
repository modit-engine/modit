--- @module run
--- @file src/engine/core/internal/run.lua
--- @description Client loop manager. Initializes window, runs lifecycle ticks, and manages rendering.

--- @section Imports

local _sandbox = require("src.engine.core.internal.sandbox")

--- @section Initalisation

local m = {}

local ffi = require("ffi")
pcall(ffi.cdef, "int GetSystemMetrics(int index);")

local position_checks = 0

--- @section Helpers

local function ensure_window_on_screen(engine)
    local ok, x, y = pcall(engine.window.get_position)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return end

    local w, h = engine.window.get_size()
    local screen_w, screen_h = ffi.C.GetSystemMetrics(0), ffi.C.GetSystemMetrics(1)
    local off_screen = x > screen_w - 50 or x < -w + 50 or y > screen_h - 50 or y < -h + 50
    if not off_screen then return end

    engine.window.set_position(math.max(0, (screen_w - w) / 2), math.max(0, (screen_h - h) / 2))
    engine.log.info(("window was off-screen at %d,%d, recentred"):format(x, y))
end

local function draw_crash(engine, crash_lines)
    local draw = engine.draw or engine.draw2d
    if not draw then return end
    local w, h = engine.window.get_size()

    draw.reset_clip()
    draw.set_colour(40, 12, 12, 255)
    draw.rect(0, 0, w, h)

    draw.set_colour(255, 120, 120, 255)
    draw.text("Game error. Save a fix to reload.", 20, 20, 20)

    draw.set_colour(255, 255, 255, 255)
    local y = 60
    for i = 1, #crash_lines do
        if y > h - 24 then break end
        draw.text(crash_lines[i], 20, y, 16)
        y = y + 20
    end
end

local function load_game(engine, conf)
    local chunk, load_err = loadfile(engine.game_dir .. "/main.lua")
    if not chunk then
        error("game/main.lua not found or invalid:\n" .. tostring(load_err))
    end

    local game_env = _sandbox.create_env("client", "game", conf, {
        root = engine.game_dir,
        global_name = engine.global_name,
        extra = {
            config = _sandbox.deep_copy(conf),
            game_dir = engine.game_dir,
        },
    })
    setfenv(chunk, game_env)

    local ok, result = xpcall(chunk, debug.traceback)
    if not ok then error(result) end
    if type(result) ~= "table" then error("game/main.lua must return a table") end

    if result.load then
        local ok2, err2 = xpcall(result.load, debug.traceback)
        if not ok2 then error(err2) end
    end
    return result
end

--- @section Functions

--- Handles running game/engine files
--- @param engine table Engine api loaded in engine/init.lua
--- @param conf table Engine/game configuration file
function m.run(engine, conf)
    engine.window.init(conf.window, conf.modules)
    
    if engine.filesystem and engine.game_dir then 
        engine.filesystem.init(engine.game_dir) 
    end
    
    if engine.mods and engine.game_dir and conf.modding and conf.modding.enabled == true then 
        engine.mods.init(conf, engine.game_dir) 
        engine.mods.scan()
        engine.mods.start_all("client")
    end

    local game = {}
    if conf.update or conf.draw then
        game.update = conf.update
        game.draw = conf.draw
        game.load = conf.load
        game.quit = conf.quit

        if conf.load then
            local ok, err = xpcall(conf.load, debug.traceback)
            if not ok then error(err) end
        end
    elseif engine.game_dir then
        game = load_game(engine, conf)
    else
        error("No game_dir specified and no inline update/draw callbacks provided in config.")
    end

    local frame_dt = 0
    local crash_lines = nil

    local function fail(msg)
        msg = tostring(msg)
        engine.log.error(msg)
        crash_lines = {}
        for line in msg:gmatch("[^\n]+") do
            crash_lines[#crash_lines + 1] = (line:gsub("\t", "    "))
        end
    end

    local tickable_modules = {
        runtime = true,
        input = true,
        physics = true,
    }

    local function tick()
        local modules_cfg = conf.modules or {}

        for name in pairs(tickable_modules) do
            local mod = engine[name]
            if modules_cfg[name] == true and type(mod) == "table" and type(mod.update) == "function" then
                mod.update(frame_dt)
            end
        end

        position_checks = position_checks + 1
        if position_checks == 2 or position_checks == 30 then ensure_window_on_screen(engine) end

        if game.update then game.update(frame_dt) end
    end

    local function paint()
        local ui_input = conf.modules and conf.modules.ui == true and engine.ui and engine.ui.input
        if ui_input then ui_input.begin_frame() end
        if game.draw then game.draw() end
        if ui_input then ui_input.end_frame() end
    end

    while not engine.window.should_close() do
        frame_dt = engine.window.get_dt()

        if not crash_lines then
            local ok, err = xpcall(tick, debug.traceback)
            if not ok then fail(err) end
        end

        engine.window.begin_draw()

        if not crash_lines and game.draw then
            local ok, err = xpcall(paint, debug.traceback)
            if not ok then fail(err) end
        end

        if crash_lines then
            draw_crash(engine, crash_lines)
        end

        engine.window.end_draw()
    end

    if game.quit then pcall(game.quit) end
    engine.window.close()
end

return m