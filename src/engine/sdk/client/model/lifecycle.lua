--- @module model.lifecycle
--- @file src/engine/sdk/client/model/lifecycle.lua
--- @description Lifecycle management: loading, building, unloading, and cleaning up model assets.

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

--- Loads once per key. A conflicting path needs replace=true. Failure preserves the old asset.
--- Returns true, or false and a diagnostic. Paths are relative to the working directory.
--- @param opts table `{ key, path, replace? }`
--- @return boolean ok True if loaded or already loaded
--- @return string|nil reason Failure description
function m.load(opts)
    if type(opts) ~= "table" or not valid_key(opts.key) or not valid_path(opts.path) then
        return fail("load needs a nonempty key and path")
    end
    local extension = opts.path:match("%.([^./\\]+)$")
    if not extension or not supported_formats[extension:lower()] then return fail("unsupported model format") end
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

--- Unloads a model and its owned textures
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