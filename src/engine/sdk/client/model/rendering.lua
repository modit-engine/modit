--- @module model.rendering
--- @file src/engine/sdk/client/model/rendering.lua
--- @description Rendering passes, batching, and instance hierarchy management.

--- @section Imports

local c = require("src.engine.sdk.client.model.core")

--- @section Initialisation

local m, assets = c.m, c.assets
local _backend, _mat4, _log = c._backend, c._mat4, c._log
local supported_formats = c.supported_formats
local fail, finite, valid_key, valid_path = c.fail, c.finite, c.valid_key, c.valid_path
local with_default, colour_values, transform_values = c.with_default, c.colour_values, c.transform_values
local validate_array, validate_mesh = c.validate_array, c.validate_mesh
local release_asset, replace_asset, animation_state = c.release_asset, c.replace_asset, c.animation_state
local scale_component, local_transform, world_transform = c.scale_component, c.local_transform, c.world_transform
local collect_nodes, draw_node = c.collect_nodes, c.draw_node
local valid_vector, intersects_bounds, asset_path = c.valid_vector, c.intersects_bounds, c.asset_path

--- @section Functions

--- Draw options and instances use the same table shape. Transform/tint changes affect this draw only.
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

--- Draws opaque meshes first, then blended meshes back-to-front using camera view depth
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
--- @param parent table Parent instance
--- @param name string Part name
--- @return table|nil child Detached instance
function m.detach(parent, name)
    if type(parent) ~= "table" or type(parent.parts) ~= "table" then return nil, "parent has no parts" end
    local child = parent.parts[name]
    if type(child) ~= "table" or child.parent ~= parent then return nil, "part does not exist or has the wrong parent" end
    parent.parts[name], child.parent = nil, nil
    return child
end

--- Gets an editable child instance by name
--- @param parent table Parent instance
--- @param name string Part name
--- @return table|nil child Child instance
function m.get_part(parent, name)
    if type(parent) ~= "table" or type(parent.parts) ~= "table" then return nil end
    return parent.parts[name]
end

return m