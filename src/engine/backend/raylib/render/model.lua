--- @module model
--- @file src/engine/backend/raylib/render/model.lua
--- @description Raylib model loading, mesh building from vertex data, unloading and transformed drawing.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib, _Color = _raylib.ffi, _raylib.lib, _raylib.Color
local _lighting = require("src.engine.backend.raylib.render.lighting")

--- @section Constants

local MAX_MATERIAL_MAPS = 12
local SHADOW_MAP_SLOT = 10 -- MATERIAL_MAP_BRDF: the slot meshes receive the shadow map in

--- @section Types & State

local _Vector3 = _ffi.typeof("Vector3")

local position_vec = _Vector3()
local axis_vec = _Vector3()
local scale_vec = _Vector3()
local tint = _Color(255, 255, 255, 255)

local default_material = nil

--- @section Helpers

--- Raylib's default material, kept for its shader and texture (needs a live GL context)
local function get_default_material()
    if not default_material then
        default_material = _lib.LoadMaterialDefault()
    end
    return default_material
end

--- Allocates raylib-owned memory, because UnloadMesh frees it with raylib's allocator
local function alloc(ctype, count)
    return _ffi.cast(ctype .. "*", _lib.MemAlloc(count * _ffi.sizeof(ctype)))
end

--- @section Model Lifecycle

--- Loads a model from disk (obj, gltf, glb, iqm, vox, m3d)
--- @param path string File path
--- @return cdata|nil model Model object, or nil if loading failed
local function m_load(path)
    local model = _lib.LoadModel(path)
    if model.meshCount == 0 then return nil end
    return model
end

--- Builds a single-mesh model from vertex data
--- @param vertices table Flat list: x, y, z per vertex
--- @param indices table|nil Triangle list of 1-based vertex numbers
--- @param uvs table|nil Flat list: u, v per vertex
--- @param colours table|nil Flat list: r, g, b, a (0-255) per vertex
--- @return cdata model Model object
local function m_build(vertices, indices, uvs, colours)
    local count = #vertices / 3

    local mesh = _ffi.new("Mesh")
    mesh.vertexCount = count

    local vertex_data = alloc("float", count * 3)
    for index = 1, #vertices do vertex_data[index - 1] = vertices[index] end
    mesh.vertices = vertex_data

    if uvs then
        local uv_data = alloc("float", count * 2)
        for index = 1, #uvs do uv_data[index - 1] = uvs[index] end
        mesh.texcoords = uv_data
    end

    if colours then
        local colour_data = alloc("unsigned char", count * 4)
        for index = 1, #colours do colour_data[index - 1] = colours[index] end
        mesh.colors = colour_data
    end

    if indices then
        local index_data = alloc("unsigned short", #indices)
        for index = 1, #indices do index_data[index - 1] = indices[index] - 1 end
        mesh.indices = index_data
        mesh.triangleCount = #indices / 3
    else
        mesh.triangleCount = count / 3
    end

    _lib.UploadMesh(mesh, false)
    return _lib.LoadModelFromMesh(mesh)
end

--- Unloads a model, its meshes and its textures
--- @param model cdata Model object to release
local function m_free(model)
    local default = get_default_material()
    local default_texture = default.maps[0].texture.id
    local released = {}

    for material_index = 0, model.materialCount - 1 do
        local material = model.materials[material_index]
        material.shader = default.shader
        material.maps[SHADOW_MAP_SLOT].texture.id = 0

        for map_index = 0, MAX_MATERIAL_MAPS - 1 do
            local texture = material.maps[map_index].texture
            if texture.id ~= 0 and texture.id ~= default_texture and not released[texture.id] then
                released[texture.id] = true
                _lib.UnloadTexture(texture)
            end
        end
    end

    _lib.UnloadModel(model)
end

--- @section Rendering

--- Draws a model with a transform and tint. Lit and fogged when drawn between begin_3d and end_3d
--- @param model cdata Model object
--- @param x number Position X
--- @param y number Position Y
--- @param z number Position Z
--- @param ax number Rotation axis X
--- @param ay number Rotation axis Y
--- @param az number Rotation axis Z
--- @param angle number Rotation angle in degrees
--- @param sx number Scale X
--- @param sy number Scale Y
--- @param sz number Scale Z
--- @param r number Tint red (0-255)
--- @param g number Tint green (0-255)
--- @param b number Tint blue (0-255)
--- @param a number Tint alpha (0-255)
local function m_draw(model, x, y, z, ax, ay, az, angle, sx, sy, sz, r, g, b, a)
    local shader = _lighting.mesh_shader()
    if shader == false then return end
    shader = shader or get_default_material().shader

    local shadow_texture = _lighting.shadow_texture()
    for index = 0, model.materialCount - 1 do
        local material = model.materials[index]
        material.shader = shader
        if shadow_texture then
            material.maps[SHADOW_MAP_SLOT].texture = shadow_texture
        else
            material.maps[SHADOW_MAP_SLOT].texture.id = 0
        end
    end

    position_vec.x, position_vec.y, position_vec.z = x, y, z
    axis_vec.x, axis_vec.y, axis_vec.z = ax, ay, az
    scale_vec.x, scale_vec.y, scale_vec.z = sx, sy, sz
    tint.r, tint.g, tint.b, tint.a = r, g, b, a
    _lib.DrawModelEx(model, position_vec, axis_vec, angle, scale_vec, tint)
end

return {
    load = m_load,
    build = m_build,
    free = m_free,
    draw = m_draw,
}