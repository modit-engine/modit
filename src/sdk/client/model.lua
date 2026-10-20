--- @module model
--- @file src/sdk/client/model.lua
--- @description Model assets, Lua assemblies, animation, materials and world bounds.

--- @section Imports

local _backend = require("src.engine.backend").model
local _mat4 = require("src.sdk.shared.mat4")
local _log = require("src.engine.core.log")

--- @section Constants

local SUPPORTED_FORMATS = { obj = true, gltf = true, glb = true, iqm = true, vox = true, m3d = true }

--- @section Initialisation

local m = {}
local assets = {} -- key -> { handle, path, revision }
local asset_revision = 0
local asset_sequence = 0
local local_transforms = setmetatable({}, { __mode = "k" })
local world_transforms = setmetatable({}, { __mode = "k" })

--- @section Helpers

local function fail(reason)
    reason = tostring(reason)
    _log.warn("model: " .. reason)
    return false, reason
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) <= 3.402823466e38
end

local function valid_key(key)
    return type(key) == "string" and key ~= "" and not key:find("\0", 1, true)
end

local function valid_path(path)
    return type(path) == "string" and path ~= "" and not path:find("\0", 1, true)
end

local function with_default(value, fallback)
    if value == nil then return fallback end
    return value
end

local function colour_values(colour)
    if colour == nil then return { r = 255, g = 255, b = 255, a = 255 } end
    if type(colour) ~= "table" then return nil, "tint must be a colour table" end
    local result = {}
    for index, channel in ipairs({ "r", "g", "b", "a" }) do
        local value = colour[channel]
        if value == nil then value = colour[index] end
        if value == nil then value = 255 end
        if not finite(value) or value < 0 or value > 255 or value % 1 ~= 0 then
            return nil, "tint channels must be integers from 0 to 255"
        end
        result[channel] = value
    end
    return result
end

local function transform_values(opts)
    if type(opts) ~= "table" or not valid_key(opts.key) then return nil, "expected options with a model key" end
    local axis = opts.axis
    if axis ~= nil and type(axis) ~= "table" then return nil, "axis must be a vector table" end
    axis = axis or { x = 0, y = 1, z = 0 }
    local scale = opts.scale
    if scale == nil then scale = 1 end
    local scale_x, scale_y, scale_z
    if type(scale) == "table" then
        scale_x, scale_y, scale_z = with_default(scale.x, 1), with_default(scale.y, 1), with_default(scale.z, 1)
    else
        scale_x, scale_y, scale_z = scale, scale, scale
    end
    local values = {
        with_default(opts.x, 0), with_default(opts.y, 0), with_default(opts.z, 0),
        with_default(axis.x, 0), with_default(axis.y, 0), with_default(axis.z, 0), with_default(opts.angle, 0),
        scale_x, scale_y, scale_z,
    }
    for _, value in ipairs(values) do
        if not finite(value) then return nil, "transforms must contain finite numbers" end
    end
    local axis_length = math.sqrt(values[4] ^ 2 + values[5] ^ 2 + values[6] ^ 2)
    if axis_length == 0 then
        if values[7] ~= 0 then return nil, "rotation needs a nonzero axis" end
        values[5] = 1
    else
        values[4], values[5], values[6] = values[4] / axis_length, values[5] / axis_length, values[6] / axis_length
    end
    local colour, reason = colour_values(opts.tint)
    if not colour then return nil, reason end
    values[11], values[12], values[13], values[14] = colour.r, colour.g, colour.b, colour.a
    return values
end

local function validate_array(values, length, label, byte_values)
    if type(values) ~= "table" or #values ~= length then return false, label .. " has the wrong length" end
    for index = 1, length do
        local value = values[index]
        if not finite(value) then return false, label .. " must contain finite numbers" end
        if byte_values and (value < 0 or value > 255 or value % 1 ~= 0) then
            return false, label .. " must contain integers from 0 to 255"
        end
    end
    return true
end

local function validate_mesh(opts)
    local vertices = opts.vertices
    if type(vertices) ~= "table" or #vertices == 0 or #vertices % 3 ~= 0 then
        return false, "vertices must be a nonempty flat x,y,z list"
    end
    local valid, reason = validate_array(vertices, #vertices, "vertices")
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
            if not finite(value) or value < 1 or value > vertex_count or value % 1 ~= 0 then
                return false, "indices must be whole vertex numbers from 1 to " .. vertex_count
            end
        end
    elseif #vertices % 9 ~= 0 then
        return false, "unindexed vertices must contain complete triangles"
    end
    for _, field in ipairs({ "uvs", "colours", "normals" }) do
        if opts[field] ~= nil then
            local components = field == "uvs" and 2 or (field == "colours" and 4 or 3)
            valid, reason = validate_array(opts[field], vertex_count * components, field, field == "colours")
            if not valid then return false, reason end
        end
    end
    return true
end

local function release_asset(asset)
    if asset.handle then _backend.free(asset.handle) end
    for _, key in ipairs(asset.owned or {}) do
        if assets[key] then release_asset(assets[key]); assets[key] = nil end
    end
end

local function replace_asset(key, handle, path)
    local previous = assets[key]
    asset_revision = asset_revision + 1
    assets[key] = { handle = handle, path = path, revision = asset_revision }
    if previous then release_asset(previous) end
end

--- Validates public playback data before any native array access
local function animation_state(instance, asset)
    local animation = instance.animation
    if animation == nil then return nil end
    if type(animation) ~= "table" or not finite(animation.clip) or animation.clip % 1 ~= 0 then
        return nil, "invalid animation clip"
    end
    if animation.revision ~= asset.revision then return nil, "asset or clips changed; start playback again" end
    if not asset.handle then return nil, "group nodes do not have skeletal animation" end
    local clip = _backend.get_animations(asset.handle)[animation.clip]
    if not clip or not finite(animation.frame) or animation.frame < 0 or animation.frame >= clip.frames
        or not finite(animation.fps) or animation.fps <= 0 or not finite(animation.speed) or animation.speed < 0
        or type(animation.loop) ~= "boolean" or type(animation.playing) ~= "boolean" then
        return nil, "invalid animation playback state"
    end
    return animation, nil, clip
end

local missing_component = {}

local function scale_component(scale, axis)
    if type(scale) == "table" then return with_default(scale[axis], missing_component) end
    return with_default(scale, missing_component)
end

local function local_transform(instance)
    -- Instances are editable tables. Compare scalar inputs, not table identities, so
    -- in-place edits to vectors/colours invalidate the cached validated transform.
    if type(instance) ~= "table" then return nil, "expected a model instance" end
    local axis, scale, pivot, tint = instance.axis, instance.scale, instance.pivot, instance.tint
    local signature
    if (axis == nil or type(axis) == "table") and (pivot == nil or type(pivot) == "table")
        and (tint == nil or type(tint) == "table") then
        local cached = local_transforms[instance]
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
            and previous.scale_x == (scale_component(scale, "x"))
            and previous.scale_y == (scale_component(scale, "y"))
            and previous.scale_z == (scale_component(scale, "z"))
            and previous.pivot_x == (pivot and pivot.x)
            and previous.pivot_y == (pivot and pivot.y)
            and previous.pivot_z == (pivot and pivot.z)
            and previous.red == (tint and with_default(tint.r, tint[1]))
            and previous.green == (tint and with_default(tint.g, tint[2]))
            and previous.blue == (tint and with_default(tint.b, tint[3]))
            and previous.alpha == (tint and with_default(tint.a, tint[4]))
            and previous.has_axis == (axis ~= nil)
            and previous.has_pivot == (pivot ~= nil)
            and previous.has_tint == (tint ~= nil)
            and previous.scale_type == (type(scale))
        then return cached.matrix, nil, cached.values end
        signature = {
            key = instance.key,
            x = instance.x,
            y = instance.y,
            z = instance.z,
            angle = instance.angle,
            axis_x = axis and axis.x,
            axis_y = axis and axis.y,
            axis_z = axis and axis.z,
            scale_x = scale_component(scale, "x"),
            scale_y = scale_component(scale, "y"),
            scale_z = scale_component(scale, "z"),
            pivot_x = pivot and pivot.x,
            pivot_y = pivot and pivot.y,
            pivot_z = pivot and pivot.z,
            red = tint and with_default(tint.r, tint[1]),
            green = tint and with_default(tint.g, tint[2]),
            blue = tint and with_default(tint.b, tint[3]),
            alpha = tint and with_default(tint.a, tint[4]),
            has_axis = axis ~= nil,
            has_pivot = pivot ~= nil,
            has_tint = tint ~= nil,
            scale_type = type(scale),
        }
    end
    local values, reason = transform_values(instance)
    if not values then return nil, reason end
    local pivot = instance.pivot or { x = 0, y = 0, z = 0 }
    if type(pivot) ~= "table" or not finite(pivot.x) or not finite(pivot.y) or not finite(pivot.z) then
        return nil, "pivot must be a finite x,y,z vector"
    end
    -- Compose T * pivot * R * S * inverse_pivot directly, avoiding six temporary matrices.
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
    if signature then local_transforms[instance] = { signature = signature, matrix = matrix, values = values } end
    return matrix, nil, values
end

local function world_transform(instance, visited, depth, cache)
    depth = depth or 0
    if type(instance) ~= "table" or (visited and visited[instance]) or depth >= 64 then return nil, "cyclic or excessively deep model hierarchy" end
    if cache and cache[instance] then return cache[instance].matrix, nil, cache[instance].values end
    visited = visited or {}
    visited[instance] = true
    local matrix, reason, values = local_transform(instance)
    if not matrix then return nil, reason end
    local local_matrix, local_values = matrix, values
    local parent_matrix, parent_values
    if instance.parent then
        local parent_reason
        parent_matrix, parent_reason, parent_values = world_transform(instance.parent, visited, depth + 1, cache)
        if not parent_matrix then return nil, parent_reason end
    end
    local previous = world_transforms[instance]
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
        if not finite(value) then return nil, "model transform exceeds renderer range" end
    end
    local result = { matrix = matrix, values = values, local_matrix = local_matrix,
        parent_matrix = parent_matrix, parent_values = parent_values }
    world_transforms[instance] = result
    if cache then cache[instance] = result end
    return matrix, nil, values
end

local function collect_nodes(instance, nodes, seen, skip_pose, transform_cache)
    if type(instance) ~= "table" or seen[instance] then return false, "duplicate or cyclic model part" end
    seen[instance] = true
    transform_cache = transform_cache or {}
    local matrix, reason, values = world_transform(instance, nil, nil, transform_cache)
    if not matrix then return false, reason end
    local asset = assets[instance.key]
    if not asset then return false, "model is not loaded: " .. instance.key end
    if asset.parts and not instance.parts then return false, "assemblies require create_instance" end
    local animation, animation_reason = animation_state(instance, asset)
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
            if not valid_key(name) then return false, "part names must be nonempty strings" end
            names[#names + 1] = name
        end
        table.sort(names)
        for _, name in ipairs(names) do
            local child = instance.parts[name]
            if type(child) ~= "table" or child.parent ~= instance then return false, "part has the wrong parent" end
            local ok, child_reason = collect_nodes(child, nodes, seen, skip_pose, transform_cache)
            if not ok then return false, child_reason end
        end
    end
    return true
end

local function draw_node(node, mesh_index)
    local values = node.values
    return _backend.draw(node.handle, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1,
        values[11], values[12], values[13], values[14], mesh_index, node.matrix.m, node.pose)
end

local function asset_path(directory, relative)
    if not valid_path(relative) or relative:find(":", 1, true) or relative:match("^[/\\]") then
        error("asset references must be relative to their description", 0)
    end
    relative = relative:gsub("\\", "/")
    for part in relative:gmatch("[^/]+") do
        if part == ".." then error("asset reference leaves its description folder", 0) end
    end
    return directory .. "/" .. relative
end

local function intersects_bounds(node, ray, distance)
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

--- @section Model Lifecycle

--- Loads once per key. A conflicting path needs replace=true. Failure preserves the old asset.
--- Returns true, or false and a diagnostic. Paths are relative to the working directory.
--- @access mod
--- @param opts table `{ key, path, replace? }`
--- @return boolean ok True if loaded or already loaded
--- @return string|nil reason Failure description
function m.load(opts)
    if type(opts) ~= "table" or not valid_key(opts.key) or not valid_path(opts.path) then
        return fail("load needs a nonempty key and path")
    end
    local extension = opts.path:match("%.([^./\\]+)$")
    if not extension or not SUPPORTED_FORMATS[extension:lower()] then return fail("unsupported model format") end
    local previous = assets[opts.key]
    if previous and not opts.replace then
        if previous.path == opts.path then return true end
        return fail("key already refers to another asset; use replace=true")
    end
    local ok, handle, reason = pcall(_backend.load, opts.path)
    if not ok then return fail(handle) end
    if not handle then return fail(reason or "could not load model") end
    replace_asset(opts.key, handle, opts.path)
    return true
end

--- Builds/replaces a mesh atomically. Optional indices are 1-based; normals use x,y,z.
--- @access mod
--- @param opts table `{ key, vertices, indices?, uvs?, colours?, normals? }`
--- @return boolean ok True if built
--- @return string|nil reason Failure description
function m.build(opts)
    if type(opts) ~= "table" or not valid_key(opts.key) then return fail("build needs a nonempty key") end
    local valid, reason = validate_mesh(opts)
    if not valid then return fail(reason) end
    local ok, handle, build_reason = pcall(_backend.build, opts.vertices, opts.indices, opts.uvs, opts.colours, opts.normals)
    if not ok then return fail(handle) end
    if not handle then return fail(build_reason or "could not build mesh") end
    replace_asset(opts.key, handle)
    return true
end

--- @section Rendering & Instances

--- Draw options and instances use the same table shape. Transform/tint changes affect this draw only.
--- @access mod
--- @param opts table `{ key, x?, y?, z?, scale?, angle?, axis?, pivot?, tint? }`
--- @return boolean ok True if drawn or skipped by the render pass
--- @return string|nil reason Failure description
function m.draw(opts)
    local nodes = {}
    local ok, reason = collect_nodes(opts, nodes, {})
    if not ok then return fail(reason) end
    for _, node in ipairs(nodes) do
        ok, reason = draw_node(node)
        if not ok then return false, reason end
    end
    return true
end

--- Draws a flat array of simple instances in a few instanced draw calls, bypassing scene-graph overhead.
--- Instances may carry their own `colour`. Each distinct colour costs one draw call.
--- @access mod
--- @param key string Model key
--- @param instances table Array of `{ x, y, z, scale?, colour? }`, one-based
--- @param count number|nil Number of instances to draw (default: all of them)
--- @param camera table|nil Camera object (reserved, currently unused)
--- @param colour table|nil Colour `{ r, g, b, a? }` (0-255) for instances without their own, default white
--- @return boolean ok True if drawn
--- @return string|nil reason Failure description
function m.draw_bulk(key, instances, count, camera, colour, uniform)
    local asset = assets[key]
    if not asset or not asset.handle then return fail("model not loaded or invalid handle") end
    count = count or #instances
    if count == 0 then return true end
    return _backend.draw_bulk_instances(asset.handle, instances, count, camera, colour, uniform)
end

--- Draws opaque meshes first, then blended meshes back-to-front using camera view depth
--- @access mod
--- @param instances table Array of draw options or instances
--- @param camera table Camera with position and target vectors
--- @return boolean ok True if every mesh was drawn
--- @return string|nil reason Failure description
function m.draw_many(instances, camera)
    if type(instances) ~= "table" or type(camera) ~= "table"
        or type(camera.position) ~= "table" or type(camera.target) ~= "table" then
        return fail("draw_many needs instances and a camera with position and target")
    end
    local position, target = camera.position, camera.target
    for _, axis in ipairs({ "x", "y", "z" }) do
        if not finite(position[axis]) or not finite(target[axis]) then return fail("camera vectors must be finite") end
    end
    local forward_x, forward_y, forward_z = target.x - position.x, target.y - position.y, target.z - position.z
    local length = math.sqrt(forward_x ^ 2 + forward_y ^ 2 + forward_z ^ 2)
    if length == 0 then return fail("camera position and target must differ") end
    forward_x, forward_y, forward_z = forward_x / length, forward_y / length, forward_z / length

    local nodes, draws, seen = {}, {}, {}
    for _, instance in ipairs(instances) do
        local ok, reason = collect_nodes(instance, nodes, seen)
        if not ok then return fail(reason) end
    end
    local batches, batch_order = {}, {}
    for _, node in ipairs(nodes) do
        if node.values[14] > 0 then
            for _, part in ipairs(_backend.get_draw_parts(node.handle, node.values[14], node.pose)) do
                if not part.transparent and not node.pose then
                    local groups = batches[node.handle]
                    if not groups then groups = {}; batches[node.handle] = groups end
                    local key = table.concat({ part.mesh_index, node.values[11], node.values[12], node.values[13], node.values[14] }, ":")
                    local group = groups[key]
                    if not group then
                        group = { handle = node.handle, mesh_index = part.mesh_index, nodes = {} }
                        groups[key], batch_order[#batch_order + 1] = group, group
                    end
                    group.nodes[#group.nodes + 1] = node
                else
                    local centre = node.matrix:multiply_vec3(part.centre)
                    draws[#draws + 1] = { node = node, mesh_index = part.mesh_index,
                        transparent = part.transparent, order = #draws + 1,
                        depth = (centre.x - position.x) * forward_x + (centre.y - position.y) * forward_y + (centre.z - position.z) * forward_z }
                end
            end
        end
    end
    for _, group in ipairs(batch_order) do
        if not _backend.draw_instances(group.handle, group.mesh_index, group.nodes) then
            for _, node in ipairs(group.nodes) do
                local ok, reason = draw_node(node, group.mesh_index)
                if not ok then return false, reason end
            end
        end
    end
    table.sort(draws, function(first, second)
        if first.transparent ~= second.transparent then return not first.transparent end
        if first.transparent and first.depth ~= second.depth then return first.depth > second.depth end
        return first.order < second.order
    end)
    for _, draw in ipairs(draws) do
        local ok, reason = draw_node(draw.node, draw.mesh_index)
        if not ok then return false, reason end
    end
    return true
end

--- Returns an independent, editable Lua transform/tint table referencing a shared asset key.
--- @access mod
--- @param opts table Model key and optional transform/tint
--- @return table|nil instance Editable draw options referencing the asset
--- @return string|nil reason Failure description
function m.create_instance(opts)
    if type(opts) ~= "table" or not assets[opts.key] then return nil, "model is not loaded" end
    local asset, combined = assets[opts.key], {}
    for key, value in pairs(asset.defaults or {}) do combined[key] = value end
    for key, value in pairs(opts) do combined[key] = value end
    local matrix, reason, values = local_transform(combined)
    if not matrix then return nil, reason end
    local pivot = combined.pivot or { x = 0, y = 0, z = 0 }
    local instance = {
        pivot = { x = pivot.x, y = pivot.y, z = pivot.z }, parts = {},
        key = opts.key, x = values[1], y = values[2], z = values[3],
        axis = { x = values[4], y = values[5], z = values[6] }, angle = values[7],
        scale = { x = values[8], y = values[9], z = values[10] },
        tint = { r = values[11], g = values[12], b = values[13], a = values[14] },
    }
    for name, key in pairs(asset.parts or {}) do
        local child, child_reason = m.create_instance({ key = key })
        if not child then return nil, child_reason end
        child.parent, instance.parts[name] = instance, child
    end
    return instance
end

--- @section Parts & Playback

--- Attaches a named instance using its existing local transform; detach before reparenting
--- @access mod
--- @param parent table Parent instance
--- @param name string Unique part name within the parent
--- @param child table Child instance
--- @return boolean ok
function m.attach(parent, name, child)
    if type(parent) ~= "table" or type(child) ~= "table" or not valid_key(name) then return fail("attach needs parent, name and child") end
    if child.parent then return fail("detach the part before attaching it elsewhere") end
    if parent.parts ~= nil and type(parent.parts) ~= "table" then return fail("parts must be a table") end
    if parent.parts and parent.parts[name] then return fail("part name is already attached") end
    local ancestor, seen = parent, {}
    while ancestor do
        if type(ancestor) ~= "table" or ancestor == child or seen[ancestor] then return fail("attachment would create a cycle") end
        seen[ancestor], ancestor = true, ancestor.parent
    end
    if not local_transform(parent) or not local_transform(child) then return fail("invalid part transform") end
    parent.parts = parent.parts or {}
    parent.parts[name], child.parent = child, parent
    return true
end

--- Removes a named part, retaining its local transform
--- @access mod
--- @return table|nil child Detached instance
function m.detach(parent, name)
    if type(parent) ~= "table" or type(parent.parts) ~= "table" then return nil, "parent has no parts" end
    local child = parent.parts[name]
    if type(child) ~= "table" or child.parent ~= parent then return nil, "part does not exist or has the wrong parent" end
    parent.parts[name], child.parent = nil, nil
    return child
end

--- Gets an editable child instance by name
--- @access mod
function m.get_part(parent, name)
    if type(parent) ~= "table" or type(parent.parts) ~= "table" then return nil end
    return parent.parts[name]
end

--- Loads clips from a compatible skeletal file (defaults to the model's source path)
--- @access mod
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
    asset_revision = asset_revision + 1
    asset.revision = asset_revision
    return true
end

--- Gets copied clip descriptions (index, name, frame count and optional source fps)
--- @access mod
function m.get_animations(key)
    local asset = assets[key]
    if not asset then return nil, "model is not loaded" end
    return asset.handle and _backend.get_animations(asset.handle) or {}
end

--- Starts independent playback on one instance; clips may be selected by index or name
--- @access mod
--- @param instance table Model instance
--- @param opts table `{ clip?, fps?, speed?, loop? }`
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
--- @access mod
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
--- @access mod
function m.pause(instance, paused)
    if type(instance) ~= "table" or not assets[instance.key] then return fail("model is not loaded") end
    local animation, reason = animation_state(instance, assets[instance.key])
    if not animation then return fail(reason or "instance has no animation") end
    if paused ~= nil and type(paused) ~= "boolean" then return fail("paused must be a boolean") end
    animation.playing = not with_default(paused, true)
    return true
end

--- Returns an instance to its bind pose
--- @access mod
function m.stop(instance)
    if type(instance) ~= "table" then return fail("stop expects an instance") end
    instance.animation = nil
    return true
end

--- Sets an instance frame from seconds; clamps to the clip's last frame
--- @access mod
function m.seek(instance, seconds)
    if type(instance) ~= "table" or not assets[instance.key] then return fail("model is not loaded") end
    local animation, reason, clip = animation_state(instance, assets[instance.key])
    if not animation then return fail(reason or "instance has no animation") end
    if not finite(seconds) or seconds < 0 or not finite(seconds * animation.fps) then return fail("invalid seek time") end
    animation.frame = math.min(seconds * animation.fps, clip.frames - 1)
    return true
end

--- @section Bounds & Materials

--- Returns a copied axis-aligned box. A key gives asset bounds; draw options give world bounds.
--- @access mod
--- @param opts string|table Model key or draw options
--- @return table|nil bounds Copied min/max vectors
--- @return string|nil reason Failure description
function m.get_bounds(opts)
    if type(opts) == "string" then
        local instance, reason = m.create_instance({ key = opts })
        if not instance then return nil, reason end
        opts = instance
    end
    local nodes = {}
    local ok, reason = collect_nodes(opts, nodes, {})
    if not ok then return nil, reason end
    if #nodes == 0 then return nil, "assembly contains no visible geometry" end
    local minimum = { x = math.huge, y = math.huge, z = math.huge }
    local maximum = { x = -math.huge, y = -math.huge, z = -math.huge }
    for _, node in ipairs(nodes) do
        local bounds = _backend.get_bounds(node.handle, node.pose)
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
    end
    return { min = minimum, max = maximum }
end

--- Returns copied, 1-based material descriptions; no GPU handles are exposed.
--- @access mod
--- @param key string Model identifier
--- @return table|nil materials Copied colour, emission and surface settings
--- @return string|nil reason Failure description
function m.get_materials(key)
    local asset = assets[key]
    if not asset then return nil, "model is not loaded" end
    return asset.handle and _backend.get_materials(asset.handle) or {}
end

--- Edits asset-wide colour, emission, alpha and surface settings atomically
--- @access mod
--- @param opts table `{ key, material?, texture?, tint?, emissive?, emissive_texture?, emissive_strength?, alpha_mode?, alpha_cutoff?, smooth?, double_sided?, cast_shadows? }`
--- @return boolean ok True if updated
--- @return string|nil reason Failure description
function m.set_material(opts)
    if type(opts) ~= "table" or not valid_key(opts.key) then return fail("set_material needs a key") end
    local asset = assets[opts.key]
    if not asset then return fail("model is not loaded") end
    if not asset.handle then return fail("group nodes have no materials; edit a mesh part") end
    local index = with_default(opts.material, 1)
    if not finite(index) or index < 1 or index % 1 ~= 0 then return fail("material must be a positive integer") end
    if opts.texture ~= nil and opts.texture ~= false and not valid_path(opts.texture) then
        return fail("texture must be a file path or false")
    end
    local colour, reason
    if opts.tint ~= nil then
        colour, reason = colour_values(opts.tint)
        if not colour then return fail(reason) end
    end
    local settings = {}
    if opts.emissive ~= nil then
        settings.emissive, reason = colour_values(opts.emissive)
        if not settings.emissive then return fail(reason) end
    end
    if opts.emissive_texture ~= nil and opts.emissive_texture ~= false and not valid_path(opts.emissive_texture) then
        return fail("emissive_texture must be a file path or false")
    end
    settings.emissive_texture = opts.emissive_texture
    if opts.alpha_mode ~= nil then
        if opts.alpha_mode ~= "auto" and opts.alpha_mode ~= "opaque" and opts.alpha_mode ~= "mask" and opts.alpha_mode ~= "blend" then
            return fail("alpha_mode must be auto, opaque, mask or blend")
        end
        settings.alpha_mode = opts.alpha_mode
    end
    for _, field in ipairs({ "alpha_cutoff", "emissive_strength" }) do
        if opts[field] ~= nil then
            if not finite(opts[field]) or opts[field] < 0 or (field == "alpha_cutoff" and opts[field] > 1) then
                return fail(field .. " must be nonnegative and finite (alpha_cutoff is at most 1)")
            end
            settings[field] = opts[field]
        end
    end
    for _, field in ipairs({ "smooth", "double_sided", "cast_shadows" }) do
        if opts[field] ~= nil and type(opts[field]) ~= "boolean" then return fail(field .. " must be a boolean") end
        settings[field] = opts[field]
    end
    local ok, result, material_reason = pcall(_backend.set_material, asset.handle, index, colour, opts.texture, settings)
    if not ok then return fail(result) end
    if not result then return fail(material_reason) end
    return true
end

--- @section Picking

local function valid_vector(vector)
    return type(vector) == "table" and finite(vector.x) and finite(vector.y) and finite(vector.z)
end

--- Creates a ray from viewport-local screen pixels (viewport defaults to the window)
--- @access mod
--- @param camera table Engine perspective camera
--- @param x number Screen X
--- @param y number Screen Y
--- @param width number|nil Viewport width
--- @param height number|nil Viewport height
--- @return table|nil ray Plain Lua origin/direction vectors
--- @return string|nil reason
function m.screen_ray(camera, x, y, width, height)
    if type(camera) ~= "table" or not valid_vector(camera.position) or not valid_vector(camera.target)
        or not valid_vector(camera.up) or not finite(camera.fov) or camera.fov <= 0 or camera.fov >= 180
        or not finite(x) or not finite(y) then return nil, "invalid screen ray camera or coordinates" end
    if width ~= nil or height ~= nil then
        if not finite(width) or not finite(height) or width < 1 or height < 1 or width % 1 ~= 0 or height % 1 ~= 0
            or width > 2147483647 or height > 2147483647 then return nil, "viewport needs positive integer width and height" end
    end
    local forward = { x = camera.target.x - camera.position.x, y = camera.target.y - camera.position.y, z = camera.target.z - camera.position.z }
    local up = camera.up
    local cross_x, cross_y, cross_z = forward.y * up.z - forward.z * up.y, forward.z * up.x - forward.x * up.z, forward.x * up.y - forward.y * up.x
    if cross_x * cross_x + cross_y * cross_y + cross_z * cross_z < 1e-20 then return nil, "camera direction and up must form a valid basis" end
    return _backend.screen_ray(camera, x, y, width, height)
end

--- Finds the closest triangle across instances and their parts; a miss returns nil without an error
--- @access mod
--- @param instances table Array of hierarchy roots
--- @param ray table `{ origin = {x,y,z}, direction = {x,y,z} }`; direction is normalized internally
--- @param max_distance number|nil World-distance limit
--- @return table|nil hit `{ instance, key, mesh, distance, position, normal }`
--- @return string|nil reason Validation error, or nil on a miss
function m.raycast(instances, ray, max_distance)
    if type(instances) ~= "table" or type(ray) ~= "table" or not valid_vector(ray.origin) or not valid_vector(ray.direction) then
        return nil, "raycast needs instances and finite origin/direction vectors"
    end
    max_distance = with_default(max_distance, 3.402823466e38)
    if not finite(max_distance) or max_distance < 0 then return nil, "max_distance must be nonnegative and finite" end
    local direction = ray.direction
    local length = math.sqrt(direction.x ^ 2 + direction.y ^ 2 + direction.z ^ 2)
    if length == 0 then return nil, "ray direction must be nonzero" end
    local normalized = { origin = ray.origin, direction = { x = direction.x / length, y = direction.y / length, z = direction.z / length } }
    local nodes, seen, nearest = {}, {}, nil
    for _, instance in ipairs(instances) do
        local ok, reason = collect_nodes(instance, nodes, seen)
        if not ok then return nil, reason end
    end
    for _, node in ipairs(nodes) do
        if intersects_bounds(node, normalized, max_distance) then
            local hit = _backend.raycast(node.handle, normalized, node.matrix.m, node.pose, max_distance)
            if hit and (not nearest or hit.distance < max_distance) then
                hit.instance, hit.key = node.instance, node.instance.key
                nearest, max_distance = hit, hit.distance
            end
        end
    end
    return nearest
end

--- Loads a Lua asset description or complete VOX scene, replacing the whole asset atomically
--- @access mod
--- @param opts table `{ key, path, base_dir?, replace? }`; description references are relative to its folder
--- @return boolean ok
--- @return string|nil reason
function m.load_asset(opts)
    if type(opts) ~= "table" or not valid_key(opts.key) or not valid_path(opts.path) then
        return fail("load_asset needs a key and description/VOX path")
    end
    local path = opts.path
    if opts.base_dir ~= nil then
        if not valid_path(opts.base_dir) then return fail("invalid base_dir") end
        local ok, resolved = pcall(asset_path, opts.base_dir, path)
        if not ok then return fail(resolved) end
        path = resolved
    end
    path = path:gsub("\\", "/")
    local previous = assets[opts.key]
    if previous and not opts.replace then
        if previous.description == path then return true end
        return fail("key already refers to another asset; use replace=true")
    end
    local staged, visiting, mesh_count = {}, {}, 0
    local directory = path:match("^(.*)[/\\]") or "."
    local function stage(definition, depth)
        if type(definition) ~= "table" or getmetatable(definition) or visiting[definition] or depth >= 64 then
            error("invalid, cyclic or excessively deep asset description", 0)
        end
        if #staged >= 4096 then error("asset has too many parts", 0) end
        visiting[definition] = true
        asset_sequence = asset_sequence + 1
        local key = opts.key .. ":asset:" .. asset_sequence
        -- Never replace a separately loaded public key, even if it resembles an internal name.
        while assets[key] do asset_sequence = asset_sequence + 1; key = opts.key .. ":asset:" .. asset_sequence end
        local record = { defaults = {}, parts = {} }
        assets[key], staged[#staged + 1] = record, key
        for _, field in ipairs({ "x", "y", "z", "scale", "axis", "angle", "pivot", "tint" }) do
            record.defaults[field] = definition[field]
        end
        record.defaults.key = key
        local transform, reason = local_transform(record.defaults)
        if not transform then error(reason, 0) end
        record.defaults.key = nil
        if definition.source then
            local source = asset_path(directory, definition.source)
            if source:lower():match("%.vox$") then
                local scene, scene_reason = _backend.read_vox(source, opts.combine_vox_colours == true)
                if not scene then error(scene_reason, 0) end
                record.parts.scene = stage(scene, depth + 1)
            else
                local loaded, load_reason = m.load({ key = key, path = source, replace = true })
                if not loaded then error(load_reason, 0) end
                local handle_record = assets[key]
                handle_record.defaults, handle_record.parts = record.defaults, record.parts
                record = handle_record
                mesh_count = mesh_count + 1
            end
        elseif definition.mesh then
            local mesh = {}
            for field, value in pairs(definition.mesh) do mesh[field] = value end
            mesh.key = key
            local built, build_reason = m.build(mesh)
            if not built then error(build_reason, 0) end
            assets[key].defaults, assets[key].parts = record.defaults, record.parts
            record = assets[key]
            mesh_count = mesh_count + 1
        end
        if definition.materials then
            if type(definition.materials) ~= "table" then error("materials must be indexed by material number", 0) end
            for index, material in pairs(definition.materials) do
                if type(material) ~= "table" then error("material settings must be a table", 0) end
                local settings = { key = key, material = index }
                for field, value in pairs(material) do
                    if field ~= "key" and field ~= "material" then settings[field] = value end
                end
                for _, field in ipairs({ "texture", "emissive_texture" }) do
                    if settings[field] and settings[field] ~= false then settings[field] = asset_path(directory, settings[field]) end
                end
                local applied, material_reason = m.set_material(settings)
                if not applied then error(material_reason, 0) end
            end
        end
        if definition.animations then
            local animation_path
            if definition.animations ~= true then animation_path = asset_path(directory, definition.animations) end
            local loaded, animation_reason = m.load_animations({ key = key, path = animation_path })
            if not loaded then error(animation_reason, 0) end
        end
        if definition.parts then
            if type(definition.parts) ~= "table" then error("parts must be a named table", 0) end
            for name, part in pairs(definition.parts) do
                if not valid_key(name) then error("parts need nonempty names", 0) end
                if record.parts[name] then error("duplicate part name: " .. name, 0) end
                record.parts[name] = stage(part, depth + 1)
            end
        end
        visiting[definition] = nil
        return key
    end
    local ok, root = pcall(function()
        local definition
        if path:lower():match("%.vox$") then
            local reason
            definition, reason = _backend.read_vox(path, opts.combine_vox_colours == true)
            if not definition then error(reason, 0) end
        elseif path:lower():match("%.lua$") then
            local chunk, reason = loadfile(path)
            if not chunk then error(reason, 0) end
            setfenv(chunk, {})
            definition = chunk()
        else
            error("asset descriptions must be .lua or .vox files", 0)
        end
        local key = stage(definition, 0)
        if mesh_count == 0 then error("asset contains no visible geometry", 0) end
        return key
    end)
    if not ok then
        for _, key in ipairs(staged) do m.unload(key) end
        return fail(root)
    end
    local record = assets[root]
    record.owned, record.description = {}, path
    for _, key in ipairs(staged) do
        if key ~= root then record.owned[#record.owned + 1] = key end
    end
    if previous then release_asset(previous) end
    assets[opts.key], assets[root] = record, nil
    return true
end

--- @section Cleanup

--- Unloads a model and its owned textures
--- @access mod
--- @param key string Model identifier
--- @return boolean unloaded True if an asset was released
function m.unload(key)
    local asset = assets[key]
    if not asset then return false end
    release_asset(asset)
    assets[key] = nil
    return true
end

--- Releases public assets. Instances stop drawing until their key is loaded again.
function m.cleanup()
    for key in pairs(assets) do m.unload(key) end
end

return m
