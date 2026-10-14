--- @module model.animation
--- @file src/engine/sdk/client/model/animation.lua
--- @description Skeletal animation playback, clips, updates, and state management.

--- @section Imports

local _core = require("src.engine.sdk.client.model.core")

--- @section Initialisation

local m, assets = _core.m, _core.assets
local _backend, _mat4, _log = _core._backend, _core._mat4, _core._log
local supported_formats = _core.supported_formats
local fail, finite, valid_key, valid_path = _core.fail, _core.finite, _core.valid_key, _core.valid_path
local with_default, colour_values, transform_values = _core.with_default, _core.colour_values, _core.transform_values
local validate_array, validate_mesh = _core.validate_array, _core.validate_mesh
local release_asset, replace_asset, animation_state = _core.release_asset, _core.replace_asset, _core.animation_state
local scale_component, local_transform, world_transform = _core.scale_component, _core.local_transform, _core.world_transform
local collect_nodes, draw_node = _core.collect_nodes, _core.draw_node
local valid_vector, intersects_bounds, asset_path = _core.valid_vector, _core.intersects_bounds, _core.asset_path

--- @section Functions

--- Loads clips from a compatible skeletal file (defaults to the model's source path)
--- @param opts table `{ key, path? }`
--- @return boolean ok
function m.load_animations(opts)
    if type(opts) ~= "table" or not assets[opts.key] then return fail("model is not loaded") end
    local asset = assets[opts.key]
    if not asset.handle then return fail("group nodes have no animation clips") end
    local path = opts.path or asset.path
    if not valid_path(path) then return fail("animation file path is required") end
    local extension = path:match("%.([^./\\]+)$")
    if not extension or not ({ iqm = true, gltf = true, glb = true, m3d = true })[extension:lower()] then
        return fail("unsupported animation format")
    end
    local ok, result, reason = pcall(_backend.load_animations, asset.handle, path)
    if not ok then return fail(result) end
    if not result then return fail(reason) end
    _core.state.asset_revision = _core.state.asset_revision + 1
    asset.revision = _core.state.asset_revision
    return true
end

--- Gets copied clip descriptions (index, name, frame count and optional source fps)
--- @param key string Model identifier
--- @return table|nil clips
--- @return string|nil reason
function m.get_animations(key)
    local asset = assets[key]
    if not asset then return nil, "model is not loaded" end
    return asset.handle and _backend.get_animations(asset.handle) or {}
end

--- Starts independent playback on one instance; clips may be selected by index or name
--- @param instance table Model instance
--- @param opts table `{ clip?, fps?, speed?, loop? }`
--- @return boolean ok
function m.play(instance, opts)
    if type(instance) ~= "table" or not assets[instance.key] then return fail("model is not loaded") end
    opts = opts or {}
    if type(opts) ~= "table" then return fail("play expects options") end
    local clips = m.get_animations(instance.key)
    local selected = opts.clip or 1
    if type(selected) == "string" then
        local found
        for _, clip in ipairs(clips) do
            if clip.name == selected then
                if found then return fail("clip name is ambiguous; use its index") end
                found = clip.index
            end
        end
        selected = found
    end
    if not finite(selected) or selected % 1 ~= 0 or not clips[selected] then return fail("animation clip does not exist") end
    local fps, speed = with_default(opts.fps, clips[selected].fps or 30), with_default(opts.speed, 1)
    if not finite(fps) or fps <= 0 or not finite(speed) or speed < 0 or (opts.loop ~= nil and type(opts.loop) ~= "boolean") then
        return fail("invalid animation timing")
    end
    instance.animation = { revision = assets[instance.key].revision, clip = selected, frame = 0, fps = fps, speed = speed, loop = with_default(opts.loop, true), playing = true }
    return true
end

--- Advances the instance and its attached parts by dt seconds (call once per game update)
--- @param instance table Model instance
--- @param dt number Delta time in seconds
--- @return boolean ok
function m.update(instance, dt)
    if not finite(dt) or dt < 0 then return fail("dt must be nonnegative and finite") end
    local nodes, updates = {}, {}
    local ok, reason = collect_nodes(instance, nodes, {}, true)
    if not ok then return fail(reason) end
    for _, node in ipairs(nodes) do
        local animation, _, clip = animation_state(node.instance, assets[node.instance.key])
        if animation and animation.playing then
            local frame = animation.frame + dt * animation.fps * animation.speed
            if not finite(frame) then return fail("animation time overflow") end
            updates[#updates + 1] = {
                animation = animation,
                frame = animation.loop and frame % clip.frames or math.min(frame, clip.frames - 1),
                playing = animation.loop or frame < clip.frames - 1,
            }
        end
    end
    for _, update in ipairs(updates) do
        update.animation.frame, update.animation.playing = update.frame, update.playing
    end
    return true
end

--- Pauses/resumes an instance without changing its frame
--- @param instance table Model instance
--- @param paused boolean|nil Pause state
--- @return boolean ok
function m.pause(instance, paused)
    if type(instance) ~= "table" or not assets[instance.key] then return fail("model is not loaded") end
    local animation, reason = animation_state(instance, assets[instance.key])
    if not animation then return fail(reason or "instance has no animation") end
    if paused ~= nil and type(paused) ~= "boolean" then return fail("paused must be a boolean") end
    animation.playing = not with_default(paused, true)
    return true
end

--- Returns an instance to its bind pose
--- @param instance table Model instance
--- @return boolean ok
function m.stop(instance)
    if type(instance) ~= "table" then return fail("stop expects an instance") end
    instance.animation = nil
    return true
end

--- Sets an instance frame from seconds; clamps to the clip's last frame
--- @param instance table Model instance
--- @param seconds number Target time in seconds
--- @return boolean ok
function m.seek(instance, seconds)
    if type(instance) ~= "table" or not assets[instance.key] then return fail("model is not loaded") end
    local animation, reason, clip = animation_state(instance, assets[instance.key])
    if not animation then return fail(reason or "instance has no animation") end
    if not finite(seconds) or seconds < 0 or not finite(seconds * animation.fps) then return fail("invalid seek time") end
    animation.frame = math.min(seconds * animation.fps, clip.frames - 1)
    return true
end

return m