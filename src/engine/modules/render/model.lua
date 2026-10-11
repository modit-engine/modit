--- @module model
--- @file src/engine/modules/render/model.lua
--- @description Model and mesh registry: load files, build meshes from vertex data, draw with transform and tint.

--- @section Imports

local _backend = require("src.engine.backend").model
local _log = require("src.engine.core.log")

--- @section Constants

local MAX_INDEXED_VERTICES = 65535
local AXIS_Y = { x = 0, y = 1, z = 0 }

--- @section Initialisation

local m = {}

local models = {} -- key -> model

--- @section Helpers

local function tint_values(tint)
    if not tint then return 255, 255, 255, 255 end
    return tint.r or tint[1] or 255, tint.g or tint[2] or 255, tint.b or tint[3] or 255, tint.a or tint[4] or 255
end

local function scale_values(scale)
    if type(scale) == "table" then
        return scale.x or 1, scale.y or 1, scale.z or 1
    end
    scale = scale or 1
    return scale, scale, scale
end

local function is_index(value, limit)
    return type(value) == "number" and value >= 1 and value <= limit and value % 1 == 0
end

--- Checks mesh data and returns the vertex count, or nil and a reason
local function validate_mesh(opts)
    local vertices = opts.vertices
    if type(vertices) ~= "table" or #vertices == 0 or #vertices % 9 ~= 0 and not opts.indices then
        return nil, "vertices must be a flat x,y,z list (a multiple of 9 numbers without indices)"
    end
    if #vertices % 3 ~= 0 then
        return nil, "vertices must be a flat x,y,z list"
    end

    local count = #vertices / 3

    if opts.indices then
        local indices = opts.indices
        if type(indices) ~= "table" or #indices == 0 or #indices % 3 ~= 0 then
            return nil, "indices must be a list of triangles (multiple of 3)"
        end
        if count > MAX_INDEXED_VERTICES then
            return nil, "indexed meshes support at most 65535 vertices"
        end
        for index = 1, #indices do
            if not is_index(indices[index], count) then
                return nil, "indices must be whole vertex numbers from 1 to " .. count
            end
        end
    end

    if opts.uvs and (type(opts.uvs) ~= "table" or #opts.uvs ~= count * 2) then
        return nil, "uvs needs 2 numbers per vertex"
    end
    if opts.colours and (type(opts.colours) ~= "table" or #opts.colours ~= count * 4) then
        return nil, "colours needs 4 numbers (r, g, b, a) per vertex"
    end

    return count
end

--- @section Functions

--- Loads a model file
--- @param opts table `{ key, path }`
--- @return boolean ok True if loaded (or already loaded)
function m.load(opts)
    opts = opts or {}
    if not opts.key or not opts.path then
        _log.warn("model.load needs key and path")
        return false
    end
    if models[opts.key] then return true end

    local model = _backend.load(opts.path)
    if not model then
        _log.warn("model failed to load: " .. tostring(opts.path))
        return false
    end
    models[opts.key] = model
    return true
end

--- Builds a mesh from vertex data. A voxel chunk is one mesh, so one draw call.
--- Triangles wind counter-clockwise when seen from outside. Rebuilding an existing key replaces it.
--- @param opts table `{ key, vertices, indices?, uvs?, colours? }` vertices is a flat x,y,z list, indices are 1-based triangle vertex numbers, uvs is u,v per vertex, colours is r,g,b,a (0-255) per vertex
--- @return boolean ok True if built
function m.build(opts)
    opts = opts or {}
    if not opts.key then
        _log.warn("model.build needs a key")
        return false
    end

    local count, reason = validate_mesh(opts)
    if not count then
        _log.warn("model.build '" .. tostring(opts.key) .. "': " .. reason)
        return false
    end

    m.unload(opts.key)
    models[opts.key] = _backend.build(opts.vertices, opts.indices, opts.uvs, opts.colours)
    return true
end

--- Draws a model
--- @param opts table `{ key, x, y, z, scale?, angle?, axis?, tint? }` scale is a number or `{ x, y, z }`, angle is degrees around axis (default: Y)
function m.draw(opts)
    local model = models[opts.key]
    if not model then return end

    local axis = opts.axis or AXIS_Y
    local sx, sy, sz = scale_values(opts.scale)
    _backend.draw(model, opts.x or 0, opts.y or 0, opts.z or 0,
        axis.x or 0, axis.y or 1, axis.z or 0, opts.angle or 0,
        sx, sy, sz, tint_values(opts.tint))
end

--- Unloads a model
--- @param key string Model identifier
function m.unload(key)
    local model = models[key]
    if not model then return end
    _backend.free(model)
    models[key] = nil
end

--- Unloads every model
function m.cleanup()
    for key in pairs(models) do m.unload(key) end
end

return m