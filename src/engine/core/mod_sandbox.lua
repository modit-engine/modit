--- @module sandbox
--- @file src/engine/modules/sandbox.lua
--- @description Builds the restricted public API exposed to sandboxed mods.

--- @section Imports

local _draw = require("src.engine.modules.draw")
local _draw3d = require("src.engine.modules.draw3d")
local _camera = require("src.engine.modules.camera")
local _keyboard = require("src.engine.modules.keyboard")
local _mouse = require("src.engine.modules.mouse")
local _window = require("src.engine.core.window")
local _hooks = require("src.engine.modules.hooks")
local _log = require("src.engine.core.log")
local _exports = require("src.engine.modules.exports")
local _commands = require("src.engine.modules.commands")

--- @section Constants

local LOG_LEVELS = { "debug", "info", "success", "warn", "error" }
local REALMS = { client = true, server = true }

local RESERVED = {
    client = { update = true, draw = true, hud = true, console_toggled = true },
    server = { update = true },
}

local DRAW = {
    "set_colour", "set_color", "clear", "line", "rect", "rect_lines", "rect_lines_ex",
    "rect_rounded", "rect_rounded_lines", "circle", "circle_lines", "triangle",
    "triangle_lines", "ellipse", "polygon", "text", "measure_text", "push_clip", "pop_clip",
}

local DRAW3D = { "line", "cube", "cube_wires", "plane", "sphere", "sphere_wires", "grid" }
local KEYBOARD = { "pressed", "down", "released" }
local MOUSE = {
    "get_position", "get_x", "get_y", "get_wheel", "get_delta", "pressed", "down",
    "released", "set_cursor", "in_rect", "show", "hide",
}
local WINDOW = { "get_size", "get_dt", "get_fps" }

--- @section Initialisation

local m = {}

--- @section Helpers

local function pick(source, names)
    local result = {}
    for _, name in ipairs(names) do
        if source[name] ~= nil then result[name] = source[name] end
    end
    return result
end

local function join(...)
    local parts = {}
    for index = 1, select("#", ...) do parts[index] = tostring((select(index, ...))) end
    return table.concat(parts, "\t")
end

local function build_shared(mod, reserved)
    local log = {}
    for _, level in ipairs(LOG_LEVELS) do
        log[level] = function(...) _log.print(level, ("[%s] %s"):format(mod.name, join(...))) end
    end

    mod.on_stop(function()
        _hooks.remove_owner(mod.name)
        _exports.remove_owner(mod.name)
        _commands.remove_owner(mod.name)
    end)

    return {
        hooks = {
            listen = function(name, callback) _hooks.listen(name, callback, mod.name) end,
            unlisten = function(name, callback) _hooks.unlisten(name, callback) end,
            fire = function(name, ...)
                if reserved[name] then error("event '" .. tostring(name) .. "' is reserved", 2) end
                _hooks.fire(name, ...)
            end,
        },
        exports = _exports.api(mod.name),
        commands = {
            register = function(name, fn, help) _commands.register(name, fn, help, mod.name) end,
        },
        log = log,
    }
end

local function build_client(mod)
    local api = build_shared(mod, RESERVED.client)

    local mouse = pick(_mouse, MOUSE)
    local mouse_locked = false

    mouse.lock = function()
        _mouse.lock()
        mouse_locked = true
    end

    mouse.unlock = function()
        _mouse.unlock()
        mouse_locked = false
    end

    mod.on_stop(function()
        if mouse_locked then _mouse.unlock() end
    end)

    api.draw = pick(_draw, DRAW)
    api.draw3d = pick(_draw3d, DRAW3D)
    api.camera = { new = _camera.new }
    api.keyboard = pick(_keyboard, KEYBOARD)
    api.mouse = mouse
    api.window = pick(_window, WINDOW)

    return api
end

local function build_server(mod)
    return build_shared(mod, RESERVED.server)
end

--- @section Functions

--- Builds the restricted public API for one mod
--- @param mod table Mod handle { name, realm, on_stop }
--- @return table api
function m.build(mod)
    if not mod or not REALMS[mod.realm] then
        error("invalid sandbox realm: " .. tostring(mod and mod.realm), 2)
    end

    if mod.realm == "client" then
        return build_client(mod)
    end

    return build_server(mod)
end

return m