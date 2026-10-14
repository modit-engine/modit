--- @module model.materials
--- @file src/engine/sdk/client/model/materials.lua
--- @description Bounds calculations and material configuration for models.

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

--- Returns a copied axis-aligned box. A key gives asset bounds; draw options give world bounds.
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
--- @param key string Model identifier
--- @return table|nil materials Copied colour, emission and surface settings
--- @return string|nil reason Failure description
function m.get_materials(key)
    local asset = assets[key]
    if not asset then return nil, "model is not loaded" end
    return asset.handle and _backend.get_materials(asset.handle) or {}
end

--- Edits asset-wide colour, emission, alpha and surface settings atomically
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

return m