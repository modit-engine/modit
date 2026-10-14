--- @module run
--- @file src/engine/core/run.lua
--- @description Client frame loop. Opens the window, checks the version, runs the frame loop, closes the window.

--- @section Initialisation

local m = {}

--- @section Functions

--- Runs the client loop until the window closes
--- @param modit table Engine table (passed in by engine/init.lua)
--- @param cfg table { version, check_updates, window, modules, load, update, draw, close }
function m.run(modit, cfg)
    modit.version = cfg.version or "0.0.0"

    if cfg.check_updates then
        local info = require("src.engine.core.internal.version").check(modit.version)
        if info and info.update_available and cfg.window then
            cfg.window.title = (cfg.window.title or "Modit Engine") .. " (Update Available: v" .. info.latest .. ")"
        end
    end

    modit.window.init(cfg.window, cfg.modules)

    if cfg.load then cfg.load() end

    while not modit.window.should_close() do
        local dt = modit.window.get_dt()

        if cfg.update then cfg.update(dt) end

        modit.window.begin_draw()
        if cfg.draw then cfg.draw() end
        modit.window.end_draw()
    end

    if cfg.close then cfg.close() end

    modit.window.close()
end

return m