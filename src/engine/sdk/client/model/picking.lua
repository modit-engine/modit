--- @module model.picking
--- @file src/engine/sdk/client/model/picking.lua
--- @description Screen ray generation and triangle raycasting for model instances.

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

--- Creates a ray from viewport-local screen pixels (viewport defaults to the window)
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

return m