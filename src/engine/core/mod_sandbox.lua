--- @module mod_sandbox
--- @file src/engine/core/mod_sandbox.lua
--- @description Builds the restricted public API exposed to sandboxed mods.

--- @section Imports

local _hooks = require("src.engine.modules.hooks")
local _log = require("src.engine.core.log")
local _exports = require("src.engine.modules.exports")
local _commands = require("src.engine.modules.commands")
local _maths = require("src.engine.modules.maths")
local _filesystem = require("src.engine.modules.filesystem")

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
local AUDIO = {
    "load_sound", "unload_sound", "play_sound", "set_sound_volume", "set_sound_pitch",
    "load_music", "unload_music", "play_music", "stop_music", "pause_music", "resume_music",
    "set_music_volume", "set_music_pitch", "is_music_playing",
}
local IMAGE = { "get_size", "draw", "draw_frame", "draw_sprite" }
local LIGHTING = { "set_sun", "set_ambient", "set_fog" }
local SKY = { "set", "draw" }

--- @section Initialisation

local m = {}

--- @section Helpers

local function safe_path(path)
    return type(path) == "string" and path ~= ""
        and not path:find("..", 1, true)
        and not path:find("[:\\]")
        and path:sub(1, 1) ~= "/"
end

local function pick(source, names)
    local result = {}
    for _, name in ipairs(names) do
        if source[name] ~= nil then
            result[name] = source[name]
        end
    end
    return result
end

local function deep_copy(source, seen)
    if type(source) ~= "table" then return source end

    seen = seen or {}
    if seen[source] then return seen[source] end

    local result = {}
    seen[source] = result

    for key, value in pairs(source) do
        result[key] = deep_copy(value, seen)
    end

    return setmetatable(result, getmetatable(source))
end

local function join(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = tostring((select(index, ...)))
    end
    return table.concat(parts, "\t")
end

local function load_client_modules()
    return {
        draw = require("src.engine.modules.render.draw"),
        draw3d = require("src.engine.modules.render.draw3d"),
        camera = require("src.engine.modules.camera"),
        keyboard = require("src.engine.modules.input.keyboard"),
        mouse = require("src.engine.modules.input.mouse"),
        window = require("src.engine.core.window"),
        audio = require("src.engine.modules.audio"),
        lighting = require("src.engine.modules.render.lighting"),
        sky = require("src.engine.modules.render.sky"),
    }
end

local function build_shared(mod, reserved, modules)
    local log = {}

    for _, level in ipairs(LOG_LEVELS) do
        log[level] = function(...)
            _log.print(level, ("[%s] %s"):format(mod.name, join(...)))
        end
    end

    mod.on_stop(function()
        _hooks.remove_owner(mod.name)
        _exports.remove_owner(mod.name)
        _commands.remove_owner(mod.name)
    end)

    local api = {
        hooks = {
            listen = function(name, callback)
                _hooks.listen(name, callback, mod.name)
            end,
            unlisten = function(name, callback)
                _hooks.unlisten(name, callback)
            end,
            fire = function(name, ...)
                if reserved[name] then
                    error("event '" .. tostring(name) .. "' is reserved", 2)
                end
                _hooks.fire(name, ...)
            end,
        },

        exports = _exports.api(mod.name),

        commands = {
            register = function(name, fn, help)
                _commands.register(name, fn, help, mod.name)
            end,
        },

        log = log,
    }

    if modules.maths then
        api.maths = deep_copy(_maths)
    end

    if modules.filesystem then
        local prefix = mod.name .. "/"

        local function scope(path)
            if not safe_path(path) then
                error("invalid save path: " .. tostring(path), 3)
            end
            return prefix .. path
        end

        api.filesystem = {
            save = function(path, data)
                return _filesystem.save(scope(path), data)
            end,
            load = function(path)
                return _filesystem.load(scope(path))
            end,
            exists = function(path)
                return _filesystem.exists(scope(path))
            end,
            delete = function(path)
                return _filesystem.delete(scope(path))
            end,
        }
    end

    return api
end

local function build_client(mod, modules)
    local client = load_client_modules()

    local _draw = client.draw
    local _draw3d = client.draw3d
    local _camera = client.camera
    local _keyboard = client.keyboard
    local _mouse = client.mouse
    local _window = client.window
    local _audio = client.audio
    local _lighting = client.lighting
    local _sky = client.sky

    local api = build_shared(mod, RESERVED.client, modules)

    local function resolve(path)
        if not safe_path(path) then
            error("invalid asset path: " .. tostring(path), 3)
        end
        return mod.dir .. "/" .. path
    end

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
        if mouse_locked then
            _mouse.unlock()
        end
    end)

    if modules.draw then
        api.draw = pick(_draw, DRAW)
    end

    if modules.draw3d then
        api.draw3d = pick(_draw3d, DRAW3D)
    end

    if modules.camera then
        api.camera = { new = _camera.new }
    end

    if modules.keyboard then
        api.keyboard = pick(_keyboard, KEYBOARD)
    end

    if modules.mouse then
        api.mouse = mouse
    end

    if modules.window then
        api.window = pick(_window, WINDOW)
    end

    if modules.audio then
        local audio = pick(_audio, AUDIO)
        local load_sound = _audio.load_sound
        local load_music = _audio.load_music

        audio.load_sound = function(name, path)
            return load_sound(name, resolve(path))
        end

        audio.load_music = function(name, path)
            return load_music(name, resolve(path))
        end

        api.audio = audio
    end

    if modules.lighting then
        api.lighting = pick(_lighting, LIGHTING)

        mod.on_stop(function()
            _lighting.reset()
        end)
    end

    if modules.sky then
        api.sky = pick(_sky, SKY)

        mod.on_stop(function()
            _sky.reset()
        end)
    end

    if modules.image then
        local engine = assert(rawget(_G, "engine"), "engine namespace is not initialized")
        local _image = assert(engine.image, "engine.image is unavailable")
        local image = pick(_image, IMAGE)
        local loaded = {}

        image.load = function(opts)
            if type(opts) ~= "table" then
                error("image.load expects a table", 2)
            end

            local safe = {}
            for key, value in pairs(opts) do
                safe[key] = value
            end
            safe.path = resolve(opts.path)

            local ok = _image.load(safe)
            if ok then
                loaded[opts.key] = true
            end
            return ok
        end

        image.unload = function(key)
            loaded[key] = nil
            _image.unload(key)
        end

        mod.on_stop(function()
            for key in pairs(loaded) do
                _image.unload(key)
            end
        end)

        api.image = image
    end

    return api
end

local function build_server(mod, modules)
    return build_shared(mod, RESERVED.server, modules)
end

--- @section Functions

--- Builds the restricted public API for one mod.
--- @param mod table Mod handle { name, realm, dir, on_stop }
--- @param modules table Enabled engine modules from game config
--- @return table api
function m.build(mod, modules)
    if not mod or not REALMS[mod.realm] then
        error("invalid sandbox realm: " .. tostring(mod and mod.realm), 2)
    end

    modules = modules or {}

    if mod.realm == "client" then
        return build_client(mod, modules)
    end

    return build_server(mod, modules)
end

return m