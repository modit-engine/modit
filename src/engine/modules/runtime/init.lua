--- @module runtime
--- @file src/engine/modules/runtime/init.lua
--- @description Aggregates runtime modules and provides a single per-frame update.

--- @section Constants

local PATH = "src.engine.modules.runtime"

--- @section Imports

local _timers = require(PATH .. ".timers")
local _cooldowns = require(PATH .. ".cooldowns")

--- @section Module

return {

    callbacks = require(PATH .. ".callbacks"),
    cooldowns = _cooldowns,
    rng = require(PATH .. ".rng"),
    state = require(PATH .. ".state"),
    timers = _timers,

    --- Advances timers and cooldowns. Call once per frame (client) or tick (server)
    --- @param dt number Delta time in seconds
    update = function(dt)
        _timers.update(dt)
        _cooldowns.update(dt)
    end,

}