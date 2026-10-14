--- @module model.core
--- @file src/engine/sdk/client/model/core.lua
--- @description Core state, constants, and helper functions for the model module.

--- @section Imports

local _backend = require("src.engine.backend").model
local _mat4 = require("src.engine.sdk.shared.mat4")
local _log = require("src.engine.core.log")

--- @section Initialisation

local m = {}

m.supported_formats = { obj = true, gltf = true, glb = true, iqm = true, vox = true, m3d = true }

m.assets = {} -- key -> { handle, path, revision }
m.state = { asset_revision = 0, asset_sequence = 0 }
m.local_transforms = setmetatable({}, { __mode = "k" })
m.world_transforms = setmetatable({}, { __mode = "k" })
m.missing_component = {}

--- @section Helpers

--- @param reason any
--- @return boolean, string
function m.fail(reason)
    reason = tostring(reason)
    _log.warn("model: " .. reason)
    return false, reason
end

--- @param value any
--- @return boolean
function m.finite(value)
    return type(value) == "number" and value == value and math.abs(value) <= 3.402823466e38
end

--- @param key any
--- @return boolean
function m.valid_key(key)
    return type(key) == "string" and key ~= "" and not key:find("\0", 1, true)
end

--- @param path any
--- @return boolean
function m.valid_path(path)
    return type(path) == "string" and path ~= "" and not path:find("\0", 1, true)
end

--- @param value any
--- @param fallback any
--- @return any
function m.with_default(value, fallback)
    if value == nil then return fallback end
    return value
end

--- @param colour any
--- @return table|nil, string|nil
function m.colour_values(colour)
    if colour == nil then return { r = 255, g = 255, b = 255, a = 255 } end
    if type(colour) ~= "table" then return nil, "tint must be a colour table" end
    local result = {}
    for index, channel in ipairs({ "r", "g", "b", "a" }) do
        local value = colour[channel]
        if value == nil then value = colour[index] end
        if value == nil then value = 255 end
        if not m.finite(value) or value < 0 or value > 255 or value % 1 ~= 0 then
            return nil, "tint channels must be integers from 0 to 255"
        end
        result[channel] = value
    end
    return result
end

--- @param opts table
--- @return number[]|nil, string|nil
function m.transform_values(opts)
    if type(opts) ~= "table" or not m.valid_key(opts.key) then return nil, "expected options with a model key" end
    local axis = opts.axis
    if axis ~= nil and type(axis) ~= "table" then return nil, "axis must be a vector table" end
    axis = axis or { x = 0, y = 1, z = 0 }
    local scale = opts.scale
    if scale == nil then scale = 1 end
    local scale_x, scale_y, scale_z
    if type(scale) == "table" then
        scale_x, scale_y, scale_z = m.with_default(scale.x, 1), m.with_default(scale.y, 1), m.with_default(scale.z, 1)
    else
        scale_x, scale_y, scale_z = scale, scale, scale
    end
    local values = {
        m.with_default(opts.x, 0), m.with_default(opts.y, 0), m.with_default(opts.z, 0),
        m.with_default(axis.x, 0), m.with_default(axis.y, 0), m.with_default(axis.z, 0), m.with_default(opts.angle, 0),
        scale_x, scale_y, scale_z,
    }
    for _, value in ipairs(values) do
        if not m.finite(value) then return nil, "transforms must contain finite numbers" end
    end
    local axis_length = math.sqrt(values[4] ^ 2 + values[5] ^ 2 + values[6] ^ 2)
    if axis_length == 0 then
        if values[7] ~= 0 then return nil, "rotation needs a nonzero axis" end
        values[5] = 1
    else
        values[4], values[5], values[6] = values[4] / axis_length, values[5] / axis_length, values[6] / axis_length
    end
    local colour, reason = m.colour_values(opts.tint)
    if not colour then return nil, reason end
    values[11], values[12], values[13], values[14] = colour.r, colour.g, colour.b, colour.a
    return values
end

--- @param values table
--- @param length integer
--- @param label string
--- @param byte_values boolean
--- @return boolean, string|nil
function m.validate_array(values, length, label, byte_values)
    if type(values) ~= "table" or #values ~= length then return false, label .. " has the wrong length" end
    for index = 1, length do
        local value = values[index]
        if not m.finite(value) then return false, label .. " must contain finite numbers" end
        if byte_values and (value < 0 or value > 255 or value % 1 ~= 0) then
            return false, label .. " must contain integers from 0 to 255"
        end
    end
    return true
end

--- @param opts table
--- @return boolean, string|nil
function m.validate_mesh(opts)
    local vertices = opts.vertices
    if type(vertices) ~= "table" or #vertices == 0 or #vertices % 3 ~= 0 then
        return false, "vertices must be a nonempty flat x,y,z list"
    end
    local valid, reason = m.validate_array(vertices, #vertices, "vertices")
    if not valid then return false, reason end
    local vertex_count = #vertices / 3
    local indices = opts.indices
    if indices ~= nil then
        if type(indices) ~= "table" or #indices == 0 or #indices % 3 ~= 0 then
            return false, "indices must contain complete triangles"
        end
        if vertex_count > 65535 then return false, "indexed meshes support at most 65535 vertices" end
        for index = 1, #indices do
            local value = indices[index]
            if not m.finite(value) or value < 1 or value > vertex_count or value % 1 ~= 0 then
                return false, "indices must be whole vertex numbers from 1 to " .. vertex_count
            end
        end
    elseif #vertices % 9 ~= 0 then
        return false, "unindexed vertices must contain complete triangles"
    end
    for _, field in ipairs({ "uvs", "colours", "normals" }) do
        if opts[field] ~= nil then
            local components = field == "uvs" and 2 or (field == "colours" and 4 or 3)
            valid, reason = m.validate_array(opts[field], vertex_count * components, field, field == "colours")
            if not valid then return false, reason end
        end
    end
    return true
end

--- @param asset table
function m.release_asset(asset)
    if asset.handle then _backend.free(asset.handle) end
    for _, key in ipairs(asset.owned or {}) do
        if m.assets[key] then m.release_asset(m.assets[key]); m.assets[key] = nil end
    end
end

--- @param key string
--- @param handle userdata
--- @param path string
function m.replace_asset(key, handle, path)
    local previous = m.assets[key]
    m.state.asset_revision = m.state.asset_revision + 1
    m.assets[key] = { handle = handle, path = path, revision = m.state.asset_revision }
    if previous then m.release_asset(previous) end
end

--- @param instance table
--- @param asset table
--- @return table|nil, string|nil, table|nil
function m.animation_state(instance, asset)
    local animation = instance.animation
    if animation == nil then return nil end
    if type(animation) ~= "table" or not m.finite(animation.clip) or animation.clip % 1 ~= 0 then
        return nil, "invalid animation clip"
    end
    if animation.revision ~= asset.revision then return nil, "asset or clips changed; start playback again" end
    if not asset.handle then return nil, "group nodes do not have skeletal animation" end
    local clip = _backend.get_animations(asset.handle)[animation.clip]
    if not clip or not m.finite(animation.frame) or animation.frame < 0 or animation.frame >= clip.frames
        or not m.finite(animation.fps) or animation.fps <= 0 or not m.finite(animation.speed) or animation.speed < 0
        or type(animation.loop) ~= "boolean" or type(animation.playing) ~= "boolean" then
        return nil, "invalid animation playback state"
    end
    return animation, nil, clip
end

--- @param scale any
--- @param axis string
--- @return any
function m.scale_component(scale, axis)
    if type(scale) == "table" then return m.with_default(scale[axis], m.missing_component) end
    return m.with_default(scale, m.missing_component)
end

--- @param instance table
--- @return userdata|nil, string|nil, number[]|nil
function m.local_transform(instance)
    if type(instance) ~= "table" then return nil, "expected a model instance" end
    local axis, scale, pivot, tint = instance.axis, instance.scale, instance.pivot, instance.tint
    local signature
    if (axis == nil or type(axis) == "table") and (pivot == nil or type(pivot) == "table")
        and (tint == nil or type(tint) == "table") then
        local cached = m.local_transforms[instance]
        local previous = cached and cached.signature
        if previous
            and previous.key == (instance.key)
            and previous.x == (instance.x)
            and previous.y == (instance.y)
            and previous.z == (instance.z)
            and previous.angle == (instance.angle)
            and previous.axis_x == (axis and axis.x)
            and previous.axis_y == (axis and axis.y)
            and previous.axis_z == (axis and axis.z)
            and previous.scale_x == (m.scale_component(scale, "x"))
            and previous.scale_y == (m.scale_component(scale, "y"))
            and previous.scale_z == (m.scale_component(scale, "z"))
            and previous.pivot_x == (pivot and pivot.x)
            and previous.pivot_y == (pivot and pivot.y)
            and previous.pivot_z == (pivot and pivot.z)
            and previous.red == (tint and m.with_default(tint.r, tint[1]))
            and previous.green == (tint and m.with_default(tint.g, tint[2]))
            and previous.blue == (tint and m.with_default(tint.b, tint[3]))
            and previous.alpha == (tint and m.with_default(tint.a, tint[4]))
            and previous.has_axis == (axis ~= nil)
            and previous.has_pivot == (pivot ~= nil)
            and previous.has_tint == (tint ~= nil)
            and previous.scale_type == (type(scale))
        then return cached.matrix, nil, cached.values end
        signature = {
            key = instance.key, x = instance.x, y = instance.y, z = instance.z, angle = instance.angle,
            axis_x = axis and axis.x, axis_y = axis and axis.y, axis_z = axis and axis.z,
            scale_x = m.scale_component(scale, "x"), scale_y = m.scale_component(scale, "y"), scale_z = m.scale_component(scale, "z"),
            pivot_x = pivot and pivot.x, pivot_y = pivot and pivot.y, pivot_z = pivot and pivot.z,
            red = tint and m.with_default(tint.r, tint[1]), green = tint and m.with_default(tint.g, tint[2]),
            blue = tint and m.with_default(tint.b, tint[3]), alpha = tint and m.with_default(tint.a, tint[4]),
            has_axis = axis ~= nil, has_pivot = pivot ~= nil, has_tint = tint ~= nil, scale_type = (type(scale)),
        }
    end
    local values, reason = m.transform_values(instance)
    if not values then return nil, reason end
    local pivot = instance.pivot or { x = 0, y = 0, z = 0 }
    if type(pivot) ~= "table" or not m.finite(pivot.x) or not m.finite(pivot.y) or not m.finite(pivot.z) then
        return nil, "pivot must be a finite x,y,z vector"
    end
    local axis_x, axis_y, axis_z = values[4], values[5], values[6]
    local cosine, sine = math.cos(math.rad(values[7])), math.sin(math.rad(values[7]))
    local remaining = 1 - cosine
    local scale_x, scale_y, scale_z = values[8], values[9], values[10]
    local matrix = _mat4.new({
        (cosine + axis_x * axis_x * remaining) * scale_x,
        (axis_y * axis_x * remaining + axis_z * sine) * scale_x,
        (axis_z * axis_x * remaining - axis_y * sine) * scale_x, 0,
        (axis_x * axis_y * remaining - axis_z * sine) * scale_y,
        (cosine + axis_y * axis_y * remaining) * scale_y,
        (axis_z * axis_y * remaining + axis_x * sine) * scale_y, 0,
        (axis_x * axis_z * remaining + axis_y * sine) * scale_z,
        (axis_y * axis_z * remaining - axis_x * sine) * scale_z,
        (cosine + axis_z * axis_z * remaining) * scale_z, 0,
        0, 0, 0, 1,
    })
    local data = matrix.m
    data[13] = values[1] + pivot.x - data[1] * pivot.x - data[5] * pivot.y - data[9] * pivot.z
    data[14] = values[2] + pivot.y - data[2] * pivot.x - data[6] * pivot.y - data[10] * pivot.z
    data[15] = values[3] + pivot.z - data[3] * pivot.x - data[7] * pivot.y - data[11] * pivot.z
    if signature then m.local_transforms[instance] = { signature = signature, matrix = matrix, values = values } end
    return matrix, nil, values
end

--- @param instance table
--- @param visited table
--- @param depth integer
--- @param cache table
--- @return userdata|nil, string|nil, number[]|nil
function m.world_transform(instance, visited, depth, cache)
    depth = depth or 0
    if type(instance) ~= "table" or (visited and visited[instance]) or depth >= 64 then
        return nil, "cyclic or excessively deep model hierarchy"
    end
    if cache and cache[instance] then return cache[instance].matrix, nil, cache[instance].values end
    visited = visited or {}
    visited[instance] = true
    local matrix, reason, values = m.local_transform(instance)
    if not matrix then return nil, reason end
    local local_matrix, local_values = matrix, values
    local parent_matrix, parent_values
    if instance.parent then
        local parent_reason
        parent_matrix, parent_reason, parent_values = m.world_transform(instance.parent, visited, depth + 1, cache)
        if not parent_matrix then return nil, parent_reason end
    end
    local previous = m.world_transforms[instance]
    if previous and previous.local_matrix == local_matrix and previous.parent_matrix == parent_matrix
        and previous.parent_values == parent_values then
        if cache then cache[instance] = previous end
        return previous.matrix, nil, previous.values
    end
    if parent_matrix then
        matrix = parent_matrix:multiply(local_matrix)
        values = {}
        for index = 1, 10 do values[index] = local_values[index] end
        for index = 11, 14 do values[index] = math.floor(local_values[index] * parent_values[index] / 255) end
    end
    for _, value in ipairs(matrix.m) do
        if not m.finite(value) then return nil, "model transform exceeds renderer range" end
    end
    local result = { matrix = matrix, values = values, local_matrix = local_matrix,
        parent_matrix = parent_matrix, parent_values = parent_values }
    m.world_transforms[instance] = result
    if cache then cache[instance] = result end
    return matrix, nil, values
end

--- @param instance table
--- @param nodes table
--- @param seen table
--- @param skip_pose boolean
--- @param transform_cache table
--- @return boolean, string|nil
function m.collect_nodes(instance, nodes, seen, skip_pose, transform_cache)
    if type(instance) ~= "table" or seen[instance] then return false, "duplicate or cyclic model part" end
    seen[instance] = true
    transform_cache = transform_cache or {}
    local matrix, reason, values = m.world_transform(instance, nil, nil, transform_cache)
    if not matrix then return false, reason end
    local asset = m.assets[instance.key]
    if not asset then return false, "model is not loaded: " .. instance.key end
    if asset.parts and not instance.parts then return false, "assemblies require create_instance" end
    local animation, animation_reason = m.animation_state(instance, asset)
    if animation_reason then return false, animation_reason end
    local pose, pose_reason
    if asset.handle and not skip_pose then pose, pose_reason = _backend.prepare_pose(asset.handle, animation) end
    if pose_reason then return false, pose_reason end
    if asset.handle then
        nodes[#nodes + 1] = { handle = asset.handle, matrix = matrix, values = values, pose = pose, instance = instance }
    end
    if instance.parts ~= nil then
        if type(instance.parts) ~= "table" then return false, "parts must be a named table" end
        local names = {}
        for name in pairs(instance.parts) do
            if not m.valid_key(name) then return false, "part names must be nonempty strings" end
            names[#names + 1] = name
        end
        table.sort(names)
        for _, name in ipairs(names) do
            local child = instance.parts[name]
            if type(child) ~= "table" or child.parent ~= instance then return false, "part has the wrong parent" end
            local ok, child_reason = m.collect_nodes(child, nodes, seen, skip_pose, transform_cache)
            if not ok then return false, child_reason end
        end
    end
    return true
end

--- @param node table
--- @param mesh_index integer
--- @return boolean, string|nil
function m.draw_node(node, mesh_index)
    local values = node.values
    return _backend.draw(node.handle, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1,
        values[11], values[12], values[13], values[14], mesh_index, node.matrix.m, node.pose)
end

--- @param vector any
--- @return boolean
function m.valid_vector(vector)
    return type(vector) == "table" and m.finite(vector.x) and m.finite(vector.y) and m.finite(vector.z)
end

--- @param node table
--- @param ray table
--- @param distance number
--- @return boolean
function m.intersects_bounds(node, ray, distance)
    local bounds = _backend.get_bounds(node.handle, node.pose)
    local minimum = { x = math.huge, y = math.huge, z = math.huge }
    local maximum = { x = -math.huge, y = -math.huge, z = -math.huge }
    for corner = 0, 7 do
        local point = node.matrix:multiply_vec3({
            x = corner % 2 == 0 and bounds.min.x or bounds.max.x,
            y = math.floor(corner / 2) % 2 == 0 and bounds.min.y or bounds.max.y,
            z = math.floor(corner / 4) % 2 == 0 and bounds.min.z or bounds.max.z,
        })
        for _, axis in ipairs({ "x", "y", "z" }) do
            minimum[axis], maximum[axis] = math.min(minimum[axis], point[axis]), math.max(maximum[axis], point[axis])
        end
    end
    local near, far = 0, distance
    for _, axis in ipairs({ "x", "y", "z" }) do
        local direction, origin = ray.direction[axis], ray.origin[axis]
        if direction == 0 then
            if origin < minimum[axis] or origin > maximum[axis] then return false end
        else
            local first, last = (minimum[axis] - origin) / direction, (maximum[axis] - origin) / direction
            if first > last then first, last = last, first end
            near, far = math.max(near, first), math.min(far, last)
            if near > far then return false end
        end
    end
    return true
end

--- @param directory string
--- @param relative string
--- @return string
function m.asset_path(directory, relative)
    if not m.valid_path(relative) or relative:find(":", 1, true) or relative:match("^[/\\]") then
        error("asset references must be relative to their description", 0)
    end
    relative = relative:gsub("\\", "/")
    for part in relative:gmatch("[^/]+") do
        if part == ".." then error("asset reference leaves its description folder", 0) end
    end
    return directory .. "/" .. relative
end

return {
    m = m,
    assets = m.assets,
    state = m.state,
    local_transforms = m.local_transforms,
    world_transforms = m.world_transforms,
    missing_component = m.missing_component,
    supported_formats = m.supported_formats,
    _backend = _backend,
    _mat4 = _mat4,
    _log = _log,
    fail = m.fail,
    finite = m.finite,
    valid_key = m.valid_key,
    valid_path = m.valid_path,
    with_default = m.with_default,
    colour_values = m.colour_values,
    transform_values = m.transform_values,
    validate_array = m.validate_array,
    validate_mesh = m.validate_mesh,
    release_asset = m.release_asset,
    replace_asset = m.replace_asset,
    animation_state = m.animation_state,
    scale_component = m.scale_component,
    local_transform = m.local_transform,
    world_transform = m.world_transform,
    collect_nodes = m.collect_nodes,
    draw_node = m.draw_node,
    valid_vector = m.valid_vector,
    intersects_bounds = m.intersects_bounds,
    asset_path = m.asset_path,
}