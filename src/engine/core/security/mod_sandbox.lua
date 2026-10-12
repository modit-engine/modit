--- @module mod_sandbox
--- @file src/engine/core/mod_sandbox.lua
--- @description Builds the restricted public API exposed to sandboxed mods.

--- @section Imports

local _hooks = require("src.engine.core.hooks")
local _log = require("src.engine.core.log")
local _exports = require("src.engine.modules.modding.exports")
local _commands = require("src.engine.modules.commands")
local _maths = require("src.engine.modules.maths")
local _filesystem = require("src.engine.modules.io.filesystem")

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
local LIGHTING = { "set_sun", "set_ambient", "set_fog", "set_shadows", "shadow_pass", "shadow_map_pass", "blob" }
local SKY = { "set", "draw" }
local FONT = { "draw", "measure", "width" }
local WATER = { "set", "set_enabled", "draw", "height_at" }
local SHAPES = { "push", "pop", "translate", "rotate", "scale", "draw" }
local POST = { "enable", "disable", "get_size", "begin_scene", "end_scene" }

-- Safe on any body: reads, queries and transient pushes
local PHYSICS = {
    "is_active", "is_valid", "get_gravity", "get_position", "get_rotation", "get_transform",
    "get_linear_velocity", "get_angular_velocity", "get_mass", "is_awake", "get_world_point",
    "get_local_point", "get_world_vector", "get_shape_body", "raycast", "overlap_box",
    "quat_from_euler", "quat_to_euler", "set_linear_velocity", "set_angular_velocity",
    "apply_force", "apply_impulse", "apply_torque", "apply_angular_impulse", "set_awake",
}
-- Change persistent state, so they only work on bodies the mod created
local PHYSICS_OWN_BODY = { "set_transform", "set_enabled", "set_gravity_scale", "set_damping" }
local PHYSICS_OWN_SHAPE = { "set_friction", "set_restitution", "set_filter" }
local PHYSICS_ADD_SHAPE = { "add_box", "add_sphere", "add_capsule" }
local MAX_PHYSICS_BODIES = 256
local MAX_PHYSICS_SHAPES = 1024

-- Flat names mods use -> { namespace, function } in engine.physics.
-- The world lifecycle (init, update, shutdown, set_gravity) is deliberately not mapped
local PHYSICS_FLAT = {
    is_active = { "world", "is_active" },
    get_gravity = { "world", "get_gravity" },
    get_events = { "world", "get_events" },

    create_body = { "body", "create" },
    destroy_body = { "body", "destroy" },
    is_valid = { "body", "is_valid" },
    get_position = { "body", "get_position" },
    get_rotation = { "body", "get_rotation" },
    get_transform = { "body", "get_transform" },
    set_transform = { "body", "set_transform" },
    get_world_point = { "body", "get_world_point" },
    get_local_point = { "body", "get_local_point" },
    get_world_vector = { "body", "get_world_vector" },
    get_linear_velocity = { "body", "get_linear_velocity" },
    set_linear_velocity = { "body", "set_linear_velocity" },
    get_angular_velocity = { "body", "get_angular_velocity" },
    set_angular_velocity = { "body", "set_angular_velocity" },
    apply_force = { "body", "apply_force" },
    apply_impulse = { "body", "apply_impulse" },
    apply_torque = { "body", "apply_torque" },
    apply_angular_impulse = { "body", "apply_angular_impulse" },
    get_mass = { "body", "get_mass" },
    set_gravity_scale = { "body", "set_gravity_scale" },
    set_damping = { "body", "set_damping" },
    is_awake = { "body", "is_awake" },
    set_awake = { "body", "set_awake" },
    set_enabled = { "body", "set_enabled" },

    add_box = { "shape", "add_box" },
    add_sphere = { "shape", "add_sphere" },
    add_capsule = { "shape", "add_capsule" },
    destroy_shape = { "shape", "destroy" },
    get_shape_body = { "shape", "get_body" },
    set_friction = { "shape", "set_friction" },
    set_restitution = { "shape", "set_restitution" },
    set_filter = { "shape", "set_filter" },

    raycast = { "query", "raycast" },
    overlap_box = { "query", "overlap_box" },

    quat_from_euler = { "rotation", "from_euler" },
    quat_to_euler = { "rotation", "to_euler" },
}

--- @section Initialisation

local m = {}
local model_scope_id = 0

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
        camera = require("src.engine.modules.camera.cam"),
        keyboard = require("src.engine.modules.input.keyboard"),
        mouse = require("src.engine.modules.input.mouse"),
        window = require("src.engine.core.window"),
        audio = require("src.engine.modules.audio.audio"),
        lighting = require("src.engine.modules.render.lighting"),
        sky = require("src.engine.modules.render.sky"),
        font = require("src.engine.modules.render.font"),
        water = require("src.engine.modules.render.water"),
        shapes = require("src.engine.modules.render.shapes"),
        post = require("src.engine.modules.render.post"),
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

    if modules.physics then
        -- Required lazily so projects without physics never need the Box3D library
        local _engine_physics = require("src.engine.modules.physics")
        local _physics = {}

        for flat_name, path in pairs(PHYSICS_FLAT) do
            _physics[flat_name] = _engine_physics[path[1]][path[2]]
        end

        local physics = pick(_physics, PHYSICS)
        local owned = {}
        local body_count, shape_count = 0, 0

        --- Drops bodies that no longer exist (world was shut down) and recounts
        local function prune()
            body_count, shape_count = 0, 0
            for handle, shapes in pairs(owned) do
                if _physics.is_valid(handle) then
                    body_count = body_count + 1
                    shape_count = shape_count + shapes
                else
                    owned[handle] = nil
                end
            end
        end

        local function own_body(body)
            if owned[body] == nil then
                error("physics body is not owned by this mod: " .. tostring(body), 3)
            end
            return body
        end

        local function own_shape(shape)
            own_body(_physics.get_shape_body(shape))
            return shape
        end

        physics.get_events = function()
            return deep_copy(_physics.get_events())
        end

        physics.create_body = function(opts)
            if body_count >= MAX_PHYSICS_BODIES then prune() end
            if body_count >= MAX_PHYSICS_BODIES then
                error("physics body limit reached (" .. MAX_PHYSICS_BODIES .. ")", 2)
            end

            local handle = _physics.create_body(opts)
            owned[handle] = 0
            body_count = body_count + 1
            return handle
        end

        physics.destroy_body = function(body)
            own_body(body)

            local shapes = owned[body]
            local destroyed = _physics.destroy_body(body)
            owned[body] = nil
            body_count = body_count - 1
            shape_count = shape_count - shapes
            return destroyed
        end

        for _, name in ipairs(PHYSICS_ADD_SHAPE) do
            local add = _physics[name]

            physics[name] = function(body, ...)
                own_body(body)

                if shape_count >= MAX_PHYSICS_SHAPES then prune() end
                if shape_count >= MAX_PHYSICS_SHAPES then
                    error("physics shape limit reached (" .. MAX_PHYSICS_SHAPES .. ")", 2)
                end

                local handle = add(body, ...)
                owned[body] = owned[body] + 1
                shape_count = shape_count + 1
                return handle
            end
        end

        physics.destroy_shape = function(shape)
            local body = _physics.get_shape_body(own_shape(shape))

            _physics.destroy_shape(shape)
            owned[body] = owned[body] - 1
            shape_count = shape_count - 1
        end

        for _, name in ipairs(PHYSICS_OWN_BODY) do
            local fn = _physics[name]

            physics[name] = function(body, ...)
                return fn(own_body(body), ...)
            end
        end

        for _, name in ipairs(PHYSICS_OWN_SHAPE) do
            local fn = _physics[name]

            physics[name] = function(shape, ...)
                return fn(own_shape(shape), ...)
            end
        end

        mod.on_stop(function()
            for handle in pairs(owned) do
                if _physics.is_valid(handle) then
                    pcall(_physics.destroy_body, handle)
                end
            end

            owned = {}
            body_count, shape_count = 0, 0
        end)

        api.physics = physics
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
    local _font = client.font
    local _water = client.water
    local _shapes = client.shapes
    local _post = client.post

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

    if modules.shapes then
        api.shapes = pick(_shapes, SHAPES)

        mod.on_stop(function()
            _shapes.reset()
        end)
    end

    if modules.post then
        api.post = pick(_post, POST)

        mod.on_stop(function()
            _post.reset()
        end)
    end

    if modules.water then
        api.water = pick(_water, WATER)

        mod.on_stop(function()
            _water.reset()
        end)
    end

    if modules.font then
        local font = pick(_font, FONT)
        font.get = function(size, path)
            if path then
                return _font.get(size, resolve(path))
            else
                return _font.get(size)
            end
        end
        api.font = font
    end

    if modules.model then
        local modit = assert(rawget(_G, "modit"), "modit namespace is not initialized")
        local _model = assert(modit.model, "modit.model is unavailable")
        local model = {}
        local owned = {}
        local stopped = false
        model_scope_id = model_scope_id + 1
        local prefix = "mod_model:" .. model_scope_id .. ":"

        local function scoped_key(key)
            if stopped then error("model scope has stopped", 3) end
            if type(key) ~= "string" or key == "" or key:find("\0", 1, true) then
                error("model key must be a nonempty string", 3)
            end
            return prefix .. key
        end

        local function scoped_options(opts)
            if type(opts) ~= "table" then error("model operation expects a table", 3) end
            local safe = {}
            for key, value in pairs(opts) do safe[key] = value end
            safe.key = scoped_key(opts.key)
            return safe
        end

        local function scoped_graph(instance, copies, depth)
            if type(instance) ~= "table" then error("model instance must be a table", 3) end
            copies, depth = copies or {}, depth or 0
            if copies[instance] then return copies[instance] end
            if depth >= 128 then error("model hierarchy is too deep", 3) end
            local safe = scoped_options(instance)
            copies[instance] = safe
            if instance.parent then safe.parent = scoped_graph(instance.parent, copies, depth + 1) end
            if instance.parts then
                if type(instance.parts) ~= "table" then error("parts must be a table", 3) end
                safe.parts = {}
                for name, child in pairs(instance.parts) do safe.parts[name] = scoped_graph(child, copies, depth + 1) end
            end
            return safe
        end

        for _, operation in ipairs({ "load", "build", "draw", "create_instance", "set_material", "load_animations", "load_asset" }) do
            local operation_name = operation
            model[operation_name] = function(opts)
                local safe = operation_name == "draw" and scoped_graph(opts) or scoped_options(opts)
                if operation_name == "load" or operation_name == "load_asset" or (operation_name == "load_animations" and opts.path ~= nil) then safe.path = resolve(opts.path) end
                if operation_name == "load_asset" then safe.base_dir = nil end
                if operation_name == "set_material" then
                    for _, field in ipairs({ "texture", "emissive_texture" }) do
                        if opts[field] ~= nil and opts[field] ~= false then safe[field] = resolve(opts[field]) end
                    end
                end
                local result, reason = _model[operation_name](safe)
                if result and (operation_name == "load" or operation_name == "build" or operation_name == "load_asset") then
                    owned[opts.key] = true
                elseif result and operation_name == "create_instance" then
                    local function public_keys(instance)
                        instance.key = instance.key:sub(#prefix + 1)
                        for _, child in pairs(instance.parts or {}) do public_keys(child) end
                    end
                    public_keys(result)
                end
                return result, reason
            end
        end

        model.draw_many = function(instances, camera)
            if type(instances) ~= "table" then error("draw_many expects an instance array", 2) end
            local safe = {}
            local copies = {}
            for index, instance in ipairs(instances) do safe[index] = scoped_graph(instance, copies) end
            return _model.draw_many(safe, camera)
        end

        model.screen_ray = function(...)
            if stopped then error("model scope has stopped", 2) end
            return _model.screen_ray(...)
        end

        model.raycast = function(instances, ray, max_distance)
            if type(instances) ~= "table" then error("raycast expects an instance array", 2) end
            local safe, copies, originals = {}, {}, {}
            for index, instance in ipairs(instances) do safe[index] = scoped_graph(instance, copies) end
            for original, copy in pairs(copies) do originals[copy] = original end
            local hit, reason = _model.raycast(safe, ray, max_distance)
            if hit then
                hit.instance = originals[hit.instance]
                hit.key = hit.instance.key
            end
            return hit, reason
        end

        model.get_bounds = function(opts)
            if type(opts) == "string" then return _model.get_bounds(scoped_key(opts)) end
            return _model.get_bounds(scoped_graph(opts))
        end

        model.get_animations = function(key)
            return _model.get_animations(scoped_key(key))
        end

        for _, operation in ipairs({ "play", "update", "pause", "stop", "seek" }) do
            local operation_name = operation
            model[operation_name] = function(instance, value)
                local copies = {}
                local safe = scoped_graph(instance, copies)
                local ok, reason = _model[operation_name](safe, value)
                if ok then
                    for original, copy in pairs(copies) do original.animation = copy.animation end
                end
                return ok, reason
            end
        end

        model.attach = function(parent, name, child)
            scoped_key(parent.key)
            scoped_key(child.key)
            return _model.attach(parent, name, child)
        end

        model.detach = function(parent, name)
            scoped_key(parent.key)
            return _model.detach(parent, name)
        end

        model.get_part = function(parent, name)
            scoped_key(parent.key)
            return _model.get_part(parent, name)
        end

        model.get_materials = function(key)
            return _model.get_materials(scoped_key(key))
        end

        model.unload = function(key)
            local private_key = scoped_key(key)
            owned[key] = nil
            return _model.unload(private_key)
        end

        mod.on_stop(function()
            if stopped then return end
            for key in pairs(owned) do _model.unload(prefix .. key) end
            owned = {}
            stopped = true
        end)

        api.model = model
    end

    if modules.image then
        local modit = assert(rawget(_G, "modit"), "modit namespace is not initialized")
        local _image = assert(modit.image, "modit.image is unavailable")
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