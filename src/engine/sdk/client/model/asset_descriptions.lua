--- @module model.asset_descriptions
--- @file src/engine/sdk/client/model/asset_descriptions.lua
--- @description Asset descriptions module for loading Lua and VOX asset hierarchies.

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

--- Loads a Lua asset description or complete VOX scene, replacing the whole asset atomically
--- @param opts table `{ key, path, base_dir?, replace? }`
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
        c.state.asset_sequence = c.state.asset_sequence + 1
        local key = opts.key .. ":asset:" .. c.state.asset_sequence
        while assets[key] do c.state.asset_sequence = c.state.asset_sequence + 1; key = opts.key .. ":asset:" .. c.state.asset_sequence end
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

return m