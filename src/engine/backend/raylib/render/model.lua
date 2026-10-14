--- @module model
--- @file src/engine/backend/raylib/render/model.lua
--- @description Owns native models, animation clips and textures behind the public Lua facade.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib, _Color = _raylib.ffi, _raylib.lib, _raylib.Color
local _mat4 = require("src.engine.sdk.shared.mat4")
local _json = require("src.engine.core.json")
local _lighting = require("src.engine.backend.raylib.render.lighting")

--- @section Constants

local MAX_MATERIAL_MAPS = 12
local EMISSION_MAP_SLOT = 5
local SHADOW_MAP_SLOT = 10 -- MATERIAL_MAP_BRDF: temporarily borrowed for shadow reception

--- @section Types & State

local default_material = nil
local live_assets = {}

local _Vector3 = _ffi.typeof("Vector3")
local position_vec = _Vector3()
local axis_vec = _Vector3()
local scale_vec = _Vector3()
local tint = _Color(255, 255, 255, 255)
local draw_tint = _ffi.new("Color")

local transform_matrix = _ffi.new("Matrix")
local transform_floats = _ffi.cast("float*", transform_matrix)

--- @section Initialisation

local m = {}

--- @section Helpers

local function get_default_material()
    if not default_material then
        default_material = _lib.LoadMaterialDefault()
        if default_material.maps == nil then
            default_material = nil
            error("could not allocate default material")
        end
    end
    return default_material
end

local function finite(value)
    return value == value and math.abs(value) <= 3.402823466e38
end

local function allocate(type_name, count)
    local byte_count = _ffi.sizeof(type_name) * count
    if byte_count > 2147483647 then error("model allocation is too large") end
    local pointer = _lib.MemAlloc(byte_count)
    if pointer == nil then error("could not allocate model " .. type_name .. " data") end
    _ffi.fill(pointer, byte_count)
    return _ffi.cast(type_name .. "*", pointer)
end

-- UnloadModel frees buffers and maps, not textures or shaders. Assets own their textures;
-- the public API never accepts native handles, so assets cannot accidentally share ownership.
local function release_native(native_model)
    local default_texture = get_default_material().maps[0].texture.id
    local released = {}
    if native_model.materials ~= nil then
        for material_index = 0, native_model.materialCount - 1 do
            local material = native_model.materials[material_index]
            if material.maps ~= nil then
                for map_index = 0, MAX_MATERIAL_MAPS - 1 do
                    local texture = material.maps[map_index].texture
                    if texture.id ~= 0 and texture.id ~= default_texture and not released[texture.id] then
                        released[texture.id] = true
                        _lib.UnloadTexture(texture)
                    end
                end
            end
        end
    end
    if native_model.meshes == nil then native_model.meshCount = 0 end
    if native_model.materials == nil then native_model.materialCount = 0 end
    _lib.UnloadModel(native_model)
end

local function inspect_model(native_model)
    if native_model.meshCount <= 0 or native_model.meshes == nil
        or native_model.materialCount <= 0 or native_model.materials == nil
        or native_model.meshMaterial == nil then
        return nil, "model has no usable geometry or materials"
    end

    local minimum = { x = math.huge, y = math.huge, z = math.huge }
    local maximum = { x = -math.huge, y = -math.huge, z = -math.huge }
    local transform = native_model.transform
    for material_index = 0, native_model.materialCount - 1 do
        if native_model.materials[material_index].maps == nil then return nil, "missing material maps" end
    end

    for mesh_index = 0, native_model.meshCount - 1 do
        local mesh = native_model.meshes[mesh_index]
        local material_index = native_model.meshMaterial[mesh_index]
        if mesh.vertexCount <= 0 or mesh.triangleCount <= 0 or mesh.vertices == nil
            or mesh.vboId == nil or mesh.vboId[0] == 0
            or material_index < 0 or material_index >= native_model.materialCount then
            return nil, "model contains an empty, invalid or unuploaded mesh"
        end
        if mesh.indices == nil and mesh.triangleCount * 3 > mesh.vertexCount then
            return nil, "mesh triangle count exceeds its vertices"
        end
        if mesh.indices ~= nil then
            for index = 0, mesh.triangleCount * 3 - 1 do
                if mesh.indices[index] >= mesh.vertexCount then return nil, "mesh index is out of bounds" end
            end
        end
        for index = 0, mesh.vertexCount - 1 do
            local offset = index * 3
            local x, y, z = mesh.vertices[offset], mesh.vertices[offset + 1], mesh.vertices[offset + 2]
            local transformed_x = transform.m0 * x + transform.m4 * y + transform.m8 * z + transform.m12
            local transformed_y = transform.m1 * x + transform.m5 * y + transform.m9 * z + transform.m13
            local transformed_z = transform.m2 * x + transform.m6 * y + transform.m10 * z + transform.m14
            if not finite(transformed_x) or not finite(transformed_y) or not finite(transformed_z) then
                return nil, "model contains non-finite vertex positions"
            end
            minimum.x, maximum.x = math.min(minimum.x, transformed_x), math.max(maximum.x, transformed_x)
            minimum.y, maximum.y = math.min(minimum.y, transformed_y), math.max(maximum.y, transformed_y)
            minimum.z, maximum.z = math.min(minimum.z, transformed_z), math.max(maximum.z, transformed_z)
        end
    end
    return { min = minimum, max = maximum }
end

--- Detects texture alpha once per asset/update, so auto mode preserves textured transparency
local function texture_has_alpha(texture)
    if texture.id == 0 or texture.id == get_default_material().maps[0].texture.id then return false end
    local image = _lib.LoadImageFromTexture(texture)
    if image.data == nil then return true end -- Unknown formats are treated conservatively.
    local colours = _lib.LoadImageColors(image)
    local transparent = colours == nil
    if colours ~= nil then
        for index = 0, image.width * image.height - 1 do
            if colours[index].a < 255 then
                transparent = true
                break
            end
        end
        _lib.UnloadImageColors(colours)
    end
    _lib.UnloadImage(image)
    return transparent
end

local function adopt(native_model)
    local ok, asset, reason = pcall(function()
        local bounds, validation_reason = inspect_model(native_model)
        if not bounds then return nil, validation_reason end
        local materials, centres, texture_alpha = {}, {}, {}
        for index = 0, native_model.materialCount - 1 do
            local texture = native_model.materials[index].maps[0].texture
            if texture_alpha[texture.id] == nil then texture_alpha[texture.id] = texture_has_alpha(texture) end
            materials[index + 1] = {
                texture_alpha = texture_alpha[texture.id], vertex_alpha = false,
                alpha_mode = "auto", alpha_cutoff = 0.5, emissive_strength = 1,
                smooth = true, double_sided = false, cast_shadows = true,
            }
        end
        local transform = native_model.transform
        for index = 0, native_model.meshCount - 1 do
            local mesh = native_model.meshes[index]
            if mesh.colors ~= nil then
                for vertex_index = 0, mesh.vertexCount - 1 do
                    if mesh.colors[vertex_index * 4 + 3] < 255 then
                        materials[native_model.meshMaterial[index] + 1].vertex_alpha = true
                        break
                    end
                end
            end
            local mesh_bounds = _lib.GetMeshBoundingBox(mesh)
            local x = (mesh_bounds.min.x + mesh_bounds.max.x) / 2
            local y = (mesh_bounds.min.y + mesh_bounds.max.y) / 2
            local z = (mesh_bounds.min.z + mesh_bounds.max.z) / 2
            centres[index + 1] = {
                x = transform.m0 * x + transform.m4 * y + transform.m8 * z + transform.m12,
                y = transform.m1 * x + transform.m5 * y + transform.m9 * z + transform.m13,
                z = transform.m2 * x + transform.m6 * y + transform.m10 * z + transform.m14,
            }
        end
        return {
            native = native_model,
            poses = setmetatable({}, { __mode = "k" }),
            materials = materials,
            centres = centres,
            draw_model = _ffi.new("Model", native_model),
            bounds = bounds,
            saved_shaders = _ffi.new("Shader[?]", native_model.materialCount),
            saved_maps = _ffi.new("Texture2D[?]", native_model.materialCount),
        }
    end)
    if not ok or not asset then
        release_native(native_model)
        return nil, ok and reason or tostring(asset)
    end
    live_assets[asset] = true
    return asset
end

local function texture_is_used(native_model, texture_id)
    for index = 0, native_model.materialCount - 1 do
        for map_index = 0, MAX_MATERIAL_MAPS - 1 do
            if native_model.materials[index].maps[map_index].texture.id == texture_id then return true end
        end
    end
    return false
end

--- Reads VOX authoring data through the Lua scene importer, retaining named parts
--- @param path string VOX file path
--- @return table|nil definition Portable asset description
--- @return string|nil reason
function m.read_vox(path, combine_colours)
    local file, reason = io.open(path, "rb")
    if not file then return nil, reason end
    local size = file:seek("end")
    if not size or size > 268435456 then file:close(); return nil, "VOX file exceeds size limit" end
    file:seek("set", 0)
    local source = file:read("*a")
    file:close()
    return require("src.engine.core.internal.vox").decode(source, combine_colours)
end

--- @section Model Lifecycle

-- Check containers before calling native parsers. This is not a hostile-file sandbox.
local function check_model_file(path)
    local file, reason = io.open(path, "rb")
    if not file then return false, reason end
    local length = file:seek("end")
    file:seek("set", 0)
    if not length or length == 0 or length > 268435456 then file:close(); return false, "empty or oversized model file" end
    local header = file:read(math.min(124, length))
    local extension = path:match("%.([^./\\]+)$"):lower()
    local function uint32(offset)
        if offset + 3 > #header then error("truncated model header", 0) end
        local a, b, c, d = header:byte(offset, offset + 3)
        return a + b * 256 + c * 65536 + d * 16777216
    end
    local ok, failure = pcall(function()
        if extension == "glb" then
            if header:sub(1, 4) ~= "glTF" or uint32(5) ~= 2 or uint32(9) ~= length
                or header:sub(17, 20) ~= "JSON" or uint32(13) < 2 or uint32(13) > length - 20 then error("invalid GLB container", 0) end
            file:seek("set", 20)
            local document = _json.decode(file:read(uint32(13)))
            if type(document) ~= "table" or type(document.asset) ~= "table" or document.asset.version ~= "2.0" then
                error("invalid GLB JSON document", 0)
            end
        elseif extension == "gltf" then
            file:seek("set", 0)
            local document = _json.decode(file:read("*a"))
            if type(document) ~= "table" or type(document.asset) ~= "table" or document.asset.version ~= "2.0" then
                error("invalid glTF 2.0 document", 0)
            end
        elseif extension == "vox" then
            if header:sub(1, 4) ~= "VOX " or (uint32(5) ~= 150 and uint32(5) ~= 200)
                or header:sub(9, 12) ~= "MAIN" or uint32(13) ~= 0 or uint32(17) ~= length - 20 then error("invalid VOX container", 0) end
        elseif extension == "m3d" then
            if header:sub(1, 4) == "3DMO" then
                if uint32(5) ~= length then error("invalid M3D container length", 0) end
            elseif header:sub(1, 4) ~= "3dmo" then error("invalid M3D signature", 0) end
        elseif extension == "iqm" then
            if #header < 124 or header:sub(1, 16) ~= "INTERQUAKEMODEL\0" or uint32(17) ~= 2 or uint32(21) ~= length then
                error("invalid IQM 2 container", 0)
            end
            local function span(offset, count, stride)
                if count > 0 and (offset < 124 or offset + count * stride > length) then error("IQM data exceeds file bounds", 0) end
            end
            for _, entry in ipairs({ { 33, 29, 1 }, { 41, 37, 24 }, { 53, 45, 20 }, { 61, 57, 12 },
                { 73, 69, 48 }, { 81, 77, 88 }, { 89, 85, 20 }, { 113, 109, 1 } }) do
                span(uint32(entry[1]), uint32(entry[2]), entry[3])
            end
            span(uint32(101), uint32(93) * uint32(97), 2)
        end
    end)
    file:close()
    if not ok then return false, tostring(failure) end
    return true
end

--- Loads and validates a static model from disk
--- @param path string Model file path
--- @return table|nil asset Backend-owned model asset
--- @return string|nil reason Failure description
function m.load(path)
    if not _lib.IsWindowReady() then return nil, "model loading needs an open window" end
    if not _lib.FileExists(path) then return nil, "model file does not exist: " .. path end
    local valid, reason = check_model_file(path)
    if not valid then return nil, reason end
    get_default_material()
    return adopt(_lib.LoadModel(path))
end

--- Builds a validated mesh with allocation rollback
--- @param vertices table Flat x,y,z vertex list
--- @param indices table|nil Triangle indices (1-based)
--- @param uvs table|nil Flat u,v texture coordinates
--- @param colours table|nil Flat RGBA bytes
--- @param normals table|nil Flat x,y,z normal list
--- @return table|nil asset Backend-owned model asset
--- @return string|nil reason Failure description
function m.build(vertices, indices, uvs, colours, normals)
    if not _lib.IsWindowReady() then return nil, "mesh building needs an open window" end
    get_default_material()
    local mesh = _ffi.new("Mesh")
    mesh.vertexCount = #vertices / 3

    local function fill(field, type_name, values, adjustment)
        if not values then return end
        mesh[field] = allocate(type_name, #values)
        for index = 1, #values do mesh[field][index - 1] = values[index] + (adjustment or 0) end
    end

    local ok, reason = pcall(function()
        fill("vertices", "float", vertices)
        fill("texcoords", "float", uvs)
        fill("colors", "unsigned char", colours)
        fill("normals", "float", normals)
        fill("indices", "unsigned short", indices, -1)
        mesh.triangleCount = indices and #indices / 3 or #vertices / 9
        _lib.UploadMesh(mesh, false)
    end)
    if not ok then
        _lib.UnloadMesh(mesh)
        return nil, tostring(reason)
    end

    -- Assemble the container in Lua so every engine-owned allocation can be checked and
    -- rolled back. LoadModelFromMesh internally allocates unchecked native arrays.
    local native_model = _ffi.new("Model")
    native_model.transform.m0, native_model.transform.m5 = 1, 1
    native_model.transform.m10, native_model.transform.m15 = 1, 1
    ok, reason = pcall(function()
        native_model.meshes = allocate("Mesh", 1)
        native_model.meshes[0] = mesh
        native_model.meshCount = 1 -- Ownership of mesh buffers has transferred.
        native_model.materials = allocate("Material", 1)
        native_model.materialCount = 1
        native_model.materials[0].shader = get_default_material().shader
        native_model.materials[0].maps = allocate("MaterialMap", MAX_MATERIAL_MAPS)
        _ffi.copy(native_model.materials[0].maps, get_default_material().maps, _ffi.sizeof("MaterialMap") * MAX_MATERIAL_MAPS)
        native_model.meshMaterial = allocate("int", 1)
    end)
    if not ok then
        if native_model.meshCount == 0 then _lib.UnloadMesh(mesh) end
        release_native(native_model)
        return nil, tostring(reason)
    end
    return adopt(native_model)
end

--- Releases an asset and its owned textures; repeated calls are safe
--- @param asset table Backend-owned model asset
function m.free(asset)
    if not live_assets[asset] then return end
    if asset.animations then _lib.UnloadModelAnimations(asset.animations, asset.animation_count) end
    asset.animations, asset.poses = nil, nil
    release_native(asset.native)
    live_assets[asset] = nil
    asset.native = nil
end

--- Releases remaining assets and the cached default material before context shutdown
function m.cleanup()
    for asset in pairs(live_assets) do m.free(asset) end
    if default_material then
        -- Shader/white texture belong to Raylib. Only the maps array belongs to us.
        _lib.MemFree(default_material.maps)
        default_material = nil
    end
end

--- @section Animation Assets & Poses

local function matrix_values(matrix)
    local values = {}
    for index = 0, 15 do values[index + 1] = tonumber(matrix["m" .. index]) end
    return values
end

local function transform_point(matrix, x, y, z)
    return matrix.m0 * x + matrix.m4 * y + matrix.m8 * z + matrix.m12,
        matrix.m1 * x + matrix.m5 * y + matrix.m9 * z + matrix.m13,
        matrix.m2 * x + matrix.m6 * y + matrix.m10 * z + matrix.m14
end

--- Copies animation descriptions; frame timing is supplied by the caller
--- @param asset table Backend-owned asset
--- @return table clips Animation names, indices and frame counts
function m.get_animations(asset)
    local clips = {}
    for index = 0, (asset.animation_count or 0) - 1 do
        local animation = asset.animations[index]
        clips[index + 1] = {
            index = index + 1, name = _ffi.string(animation.name, 32):match("^[^%z]*"),
            frames = tonumber(animation.keyframeCount), fps = asset.animation_fps,
        }
    end
    return clips
end

local function valid_transform(transform)
    for _, field in ipairs({ "translation", "scale" }) do
        local vector = transform[field]
        if not finite(vector.x) or not finite(vector.y) or not finite(vector.z) then return false end
    end
    local rotation = transform.rotation
    return finite(rotation.x) and finite(rotation.y) and finite(rotation.z) and finite(rotation.w)
        and rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z + rotation.w * rotation.w > 0
        and transform.scale.x ~= 0 and transform.scale.y ~= 0 and transform.scale.z ~= 0
end

-- The bundled Raylib glTF animation loader dereferences the first joint's parent.
-- Reject parentless skeleton roots before entering native code (also applies to GLB).
local function check_animation_root(path)
    local extension = path:match("%.([^./\\]+)$")
    if not extension or (extension:lower() ~= "gltf" and extension:lower() ~= "glb") then return true end
    local file, reason = io.open(path, "rb")
    if not file then return false, reason end
    local source
    if extension:lower() == "glb" then
        local header = file:read(20)
        local function uint32(offset)
            local a, b, c, d = header:byte(offset, offset + 3)
            return a + b * 256 + c * 65536 + d * 16777216
        end
        if not header or #header ~= 20 or header:sub(1, 4) ~= "glTF" or header:sub(17, 20) ~= "JSON"
            or uint32(5) ~= 2 or uint32(13) > uint32(9) - 20 then
            file:close()
            return false, "invalid GLB animation header"
        end
        source = file:read(uint32(13))
    else
        source = file:read("*a")
    end
    file:close()
    local ok, document = pcall(_json.decode, source)
    if not ok or type(document) ~= "table" then return false, "invalid glTF animation JSON" end
    local skin = type(document.skins) == "table" and document.skins[1]
    local root = type(skin) == "table" and type(skin.joints) == "table" and skin.joints[1]
    if type(root) ~= "number" or type(document.nodes) ~= "table" or not document.nodes[root + 1] then
        return false, "glTF animation needs a skeleton"
    end
    for _, node in ipairs(document.nodes) do
        if type(node) == "table" and type(node.children) == "table" then
            for _, child in ipairs(node.children) do
                if child == root then return true end
            end
        end
    end
    return false, "bundled Raylib requires the skeleton root beneath an armature/parent node; re-export with that parent"
end

--- Loads compatible animation data atomically; a failed load preserves existing clips
--- @param asset table Backend-owned asset
--- @param path string Animation file path
--- @return boolean ok
--- @return string|nil reason
function m.load_animations(asset, path)
    local native_model = asset.native
    local skeleton = native_model.skeleton
    if skeleton.boneCount < 1 or skeleton.boneCount > 256 or skeleton.bones == nil or skeleton.bindPose == nil then
        return false, "model needs a valid skeleton with 1 to 256 bones"
    end
    if not _lib.FileExists(path) then return false, "animation file does not exist: " .. path end
    local valid, reason = check_model_file(path)
    if not valid then return false, reason end
    valid, reason = check_animation_root(path)
    if not valid then return false, reason end
    local count = _ffi.new("int[1]")
    local animations = _lib.LoadModelAnimations(path, count)
    local function reject(reason)
        if animations ~= nil then _lib.UnloadModelAnimations(animations, math.max(0, count[0])) end
        return false, reason
    end
    if animations == nil or count[0] <= 0 then return reject("file contains no skeletal animations") end
    for bone = 0, skeleton.boneCount - 1 do
        if not valid_transform(skeleton.bindPose[bone]) then return reject("invalid bind pose") end
    end
    for index = 0, count[0] - 1 do
        local animation = animations[index]
        if not _lib.IsModelAnimationValid(native_model, animation) or animation.keyframeCount < 1 or animation.keyframePoses == nil then
            return reject("animation does not match the model skeleton")
        end
        for frame = 0, animation.keyframeCount - 1 do
            if animation.keyframePoses[frame] == nil then return reject("missing animation pose") end
            for bone = 0, skeleton.boneCount - 1 do
                if not valid_transform(animation.keyframePoses[frame][bone]) then return reject("invalid animation transform") end
            end
        end
    end
    for index = 0, native_model.meshCount - 1 do
        local mesh = native_model.meshes[index]
        if mesh.boneIndices ~= nil and mesh.boneWeights ~= nil then
            for influence = 0, mesh.vertexCount * 4 - 1 do
                local weight = mesh.boneWeights[influence]
                if not finite(weight) or weight < 0 or (weight > 0 and mesh.boneIndices[influence] >= skeleton.boneCount) then
                    return reject("invalid mesh bone indices or weights")
                end
            end
        end
    end
    if asset.animations then _lib.UnloadModelAnimations(asset.animations, asset.animation_count) end
    asset.animations, asset.animation_count = animations, tonumber(count[0])
    local extension = path:match("%.([^./\\]+)$"):lower()
    asset.animation_fps = (extension == "gltf" or extension == "glb") and 60 or nil
    asset.poses = setmetatable({}, { __mode = "k" })
    return true
end

--- Evaluates an instance pose without changing the shared model or its GPU buffers
--- @param asset table Backend-owned asset
--- @param animation table|nil Validated instance clip/frame state
--- @return table|nil pose CPU-skinned buffers and bounds, or nil for bind pose
--- @return string|nil reason
function m.prepare_pose(asset, animation)
    if not animation then return nil end
    if not asset.animations or type(animation.clip) ~= "number" or animation.clip % 1 ~= 0
        or animation.clip < 1 or animation.clip > asset.animation_count then return nil, "animation clip is not loaded" end
    if type(animation.frame) ~= "number" or not finite(animation.frame) or animation.frame < 0
        or animation.frame >= asset.animations[animation.clip - 1].keyframeCount then return nil, "invalid animation frame" end
    local pose = asset.poses[animation]
    if pose and pose.clip == animation.clip and pose.frame == animation.frame then return pose end
    local native_model = asset.native
    local bone_count = native_model.skeleton.boneCount
    pose = pose or {
        model = _ffi.new("Model", native_model),
        transforms = _ffi.new("Transform[?]", bone_count),
        matrices = _ffi.new("Matrix[?]", bone_count), meshes = {},
    }
    pose.model.currentPose, pose.model.boneMatrices = pose.transforms, pose.matrices
    pose.model.meshCount = 0 -- Raylib evaluates bones only; never uploads shared mesh buffers.
    _lib.UpdateModelAnimation(pose.model, asset.animations[animation.clip - 1], animation.frame)
    local normal_matrices = {}
    for bone = 0, bone_count - 1 do
        local values = matrix_values(pose.matrices[bone])
        for _, value in ipairs(values) do
            if not finite(value) then return nil, "animation contains a nonfinite bone transform" end
        end
        local inverse = _mat4.new(values):invert()
        if not inverse then return nil, "animation contains a singular bone transform" end
        normal_matrices[bone] = inverse:transpose().m
    end
    local minimum = { x = math.huge, y = math.huge, z = math.huge }
    local maximum = { x = -math.huge, y = -math.huge, z = -math.huge }
    for index = 0, native_model.meshCount - 1 do
        local mesh = native_model.meshes[index]
        local buffers = pose.meshes[index + 1] or {
            vertices = _ffi.new("float[?]", mesh.vertexCount * 3),
            normals = mesh.normals ~= nil and _ffi.new("float[?]", mesh.vertexCount * 3) or nil,
        }
        local low = { x = math.huge, y = math.huge, z = math.huge }
        local high = { x = -math.huge, y = -math.huge, z = -math.huge }
        for vertex = 0, mesh.vertexCount - 1 do
            local offset = vertex * 3
            local x, y, z = mesh.vertices[offset], mesh.vertices[offset + 1], mesh.vertices[offset + 2]
            local normal_x, normal_y, normal_z = 0, 0, 0
            if buffers.normals then normal_x, normal_y, normal_z = mesh.normals[offset], mesh.normals[offset + 1], mesh.normals[offset + 2] end
            local moved_x, moved_y, moved_z, moved_normal_x, moved_normal_y, moved_normal_z, total = 0, 0, 0, 0, 0, 0, 0
            if mesh.boneIndices ~= nil and mesh.boneWeights ~= nil then
                for influence = 0, 3 do
                    local weight = mesh.boneWeights[vertex * 4 + influence]
                    if weight > 0 then
                        local bone = mesh.boneIndices[vertex * 4 + influence]
                        local bone_x, bone_y, bone_z = transform_point(pose.matrices[bone], x, y, z)
                        moved_x, moved_y, moved_z = moved_x + bone_x * weight, moved_y + bone_y * weight, moved_z + bone_z * weight
                        local normal = normal_matrices[bone]
                        moved_normal_x = moved_normal_x + (normal[1] * normal_x + normal[5] * normal_y + normal[9] * normal_z) * weight
                        moved_normal_y = moved_normal_y + (normal[2] * normal_x + normal[6] * normal_y + normal[10] * normal_z) * weight
                        moved_normal_z = moved_normal_z + (normal[3] * normal_x + normal[7] * normal_y + normal[11] * normal_z) * weight
                        total = total + weight
                    end
                end
            end
            if total > 0 then
                x, y, z = moved_x / total, moved_y / total, moved_z / total
                normal_x, normal_y, normal_z = moved_normal_x / total, moved_normal_y / total, moved_normal_z / total
            end
            buffers.vertices[offset], buffers.vertices[offset + 1], buffers.vertices[offset + 2] = x, y, z
            if buffers.normals then buffers.normals[offset], buffers.normals[offset + 1], buffers.normals[offset + 2] = normal_x, normal_y, normal_z end
            x, y, z = transform_point(native_model.transform, x, y, z)
            low.x, high.x = math.min(low.x, x), math.max(high.x, x)
            low.y, high.y = math.min(low.y, y), math.max(high.y, y)
            low.z, high.z = math.min(low.z, z), math.max(high.z, z)
        end
        buffers.centre = { x = (low.x + high.x) / 2, y = (low.y + high.y) / 2, z = (low.z + high.z) / 2 }
        for _, axis in ipairs({ "x", "y", "z" }) do
            minimum[axis], maximum[axis] = math.min(minimum[axis], low[axis]), math.max(maximum[axis], high[axis])
        end
        pose.meshes[index + 1] = buffers
    end
    pose.bounds, pose.clip, pose.frame = { min = minimum, max = maximum }, animation.clip, animation.frame
    asset.poses[animation] = pose
    return pose
end

--- @section Bounds & Materials

--- Copies the cached asset-space bounds
--- @param asset table Backend-owned asset
--- @return table bounds Min/max vectors
function m.get_bounds(asset, pose)
    local bounds = pose and pose.bounds or asset.bounds
    return {
        min = { x = bounds.min.x, y = bounds.min.y, z = bounds.min.z },
        max = { x = bounds.max.x, y = bounds.max.y, z = bounds.max.z },
    }
end

--- Copies colour, emission and surface settings without exposing native handles
--- @param asset table Backend-owned asset
--- @return table materials Material descriptions (1-based)
function m.get_materials(asset)
    local result = {}
    for index = 0, asset.native.materialCount - 1 do
        local map = asset.native.materials[index].maps[0]
        local emission = asset.native.materials[index].maps[EMISSION_MAP_SLOT]
        local settings = asset.materials[index + 1]
        result[index + 1] = {
            emissive = { r = tonumber(emission.color.r), g = tonumber(emission.color.g), b = tonumber(emission.color.b) },
            emissive_texture = emission.texture.id ~= 0 and { width = tonumber(emission.texture.width), height = tonumber(emission.texture.height) } or nil,
            emissive_strength = settings.emissive_strength,
            alpha_mode = settings.alpha_mode, alpha_cutoff = settings.alpha_cutoff,
            smooth = settings.smooth, double_sided = settings.double_sided, cast_shadows = settings.cast_shadows,
            tint = { r = tonumber(map.color.r), g = tonumber(map.color.g), b = tonumber(map.color.b), a = tonumber(map.color.a) },
            texture = { width = tonumber(map.texture.width), height = tonumber(map.texture.height) },
        }
    end
    return result
end

--- Updates material settings, preserving them if either texture fails to load
--- @param asset table Backend-owned asset
--- @param index number Material index (1-based)
--- @param colour table|nil RGBA colour
--- @param texture_path string|boolean|nil File path, false for white, or nil to keep
--- @param opts table|nil Validated emission, alpha and surface settings
--- @return boolean ok True if updated
--- @return string|nil reason Failure description
function m.set_material(asset, index, colour, texture_path, opts)
    local native_model = asset.native
    if index < 1 or index > native_model.materialCount then return false, "material index is out of bounds" end
    opts = opts or {}
    local replacements, previous = {}, {}
    for _, entry in ipairs({ { slot = 0, path = texture_path }, { slot = EMISSION_MAP_SLOT, path = opts.emissive_texture } }) do
        if entry.path ~= nil then
            local texture
            if entry.path == false then
                texture = entry.slot == 0 and get_default_material().maps[0].texture or _ffi.new("Texture2D")
            else
                texture = _lib.LoadTexture(entry.path)
                if texture.id == 0 then
                    for _, replacement in ipairs(replacements) do
                        if replacement.owned then _lib.UnloadTexture(replacement.texture) end
                    end
                    return false, "could not load material texture: " .. entry.path
                end
            end
            replacements[#replacements + 1] = { slot = entry.slot, texture = texture, owned = entry.path ~= false }
        end
    end

    local material = native_model.materials[index - 1]
    for _, replacement in ipairs(replacements) do
        local map = material.maps[replacement.slot]
        previous[tonumber(map.texture.id)] = _ffi.new("Texture2D", map.texture)
        map.texture = replacement.texture
    end
    for texture_id, texture in pairs(previous) do
        if texture_id ~= 0 and texture_id ~= get_default_material().maps[0].texture.id
            and not texture_is_used(native_model, texture_id) then
            _lib.UnloadTexture(texture)
        end
    end
    if colour then material.maps[0].color = _raylib.Color(colour.r, colour.g, colour.b, colour.a) end
    if opts.emissive then
        material.maps[EMISSION_MAP_SLOT].color = _raylib.Color(opts.emissive.r, opts.emissive.g, opts.emissive.b, 255)
    end
    local settings = asset.materials[index]
    if texture_path ~= nil then settings.texture_alpha = texture_has_alpha(material.maps[0].texture) end
    for _, key in ipairs({ "alpha_mode", "alpha_cutoff", "emissive_strength", "smooth", "double_sided", "cast_shadows" }) do
        if opts[key] ~= nil then settings[key] = opts[key] end
    end
    return true
end

--- Returns the effective alpha mode, including per-instance tint
local function alpha_mode(asset, material_index, alpha)
    local settings = asset.materials[material_index + 1]
    local mode = settings.alpha_mode
    if mode == "mask" then return 1 end
    if mode == "blend" then return 2 end
    if mode == "auto" and (alpha < 255 or asset.native.materials[material_index].maps[0].color.a < 255
        or settings.texture_alpha or settings.vertex_alpha) then return 2 end
    return 0
end

--- Gets mesh centres and transparency for ordering a set of instances
--- @param asset table Backend-owned asset
--- @param alpha number Instance alpha (0-255)
--- @return table parts Mesh draw descriptors
function m.get_draw_parts(asset, alpha, pose)
    local parts = {}
    for index = 0, asset.native.meshCount - 1 do
        parts[index + 1] = {
            mesh_index = index,
            centre = pose and pose.meshes[index + 1].centre or asset.centres[index + 1],
            transparent = alpha_mode(asset, asset.native.meshMaterial[index], alpha) == 2,
        }
    end
    return parts
end

--- @section Picking

--- Creates a perspective screen ray using the same camera convention as begin_3d
function m.screen_ray(camera, x, y, width, height)
    if not _lib.IsWindowReady() then return nil, "screen rays need an open window" end
    local native_camera = _ffi.new("Camera3D")
    for _, field in ipairs({ "position", "target", "up" }) do
        for _, axis in ipairs({ "x", "y", "z" }) do native_camera[field][axis] = camera[field][axis] end
    end
    native_camera.fovy = camera.fov
    width, height = width or _lib.GetScreenWidth(), height or _lib.GetScreenHeight()
    if width < 1 or height < 1 then return nil, "screen ray viewport is empty" end
    local ray = _lib.GetScreenToWorldRayEx(_ffi.new("Vector2", x, y), native_camera, width, height)
    return {
        origin = { x = tonumber(ray.position.x), y = tonumber(ray.position.y), z = tonumber(ray.position.z) },
        direction = { x = tonumber(ray.direction.x), y = tonumber(ray.direction.y), z = tonumber(ray.direction.z) },
    }
end

--- Tests posed mesh triangles without changing shared CPU/GPU geometry
--- @return table|nil hit Copied world distance, position, normal and 1-based mesh index
function m.raycast(asset, ray, world_matrix, pose, max_distance)
    local native_ray = _ffi.new("Ray")
    for _, axis in ipairs({ "x", "y", "z" }) do
        native_ray.position[axis], native_ray.direction[axis] = ray.origin[axis], ray.direction[axis]
    end
    local combined = _mat4.new(world_matrix):multiply(_mat4.new(matrix_values(asset.native.transform)))
    local transform = _ffi.new("Matrix")
    for index = 0, 15 do transform["m" .. index] = combined.m[index + 1] end
    local nearest
    for index = 0, asset.native.meshCount - 1 do
        local mesh = _ffi.new("Mesh", asset.native.meshes[index])
        if pose then mesh.vertices = pose.meshes[index + 1].vertices end
        local collision = _lib.GetRayCollisionMesh(native_ray, mesh, transform)
        if collision.hit and collision.distance >= 0 and collision.distance <= max_distance then
            max_distance = tonumber(collision.distance)
            nearest = {
                distance = max_distance, mesh = index + 1,
                position = { x = tonumber(collision.point.x), y = tonumber(collision.point.y), z = tonumber(collision.point.z) },
                normal = { x = tonumber(collision.normal.x), y = tonumber(collision.normal.y), z = tonumber(collision.normal.z) },
            }
        end
    end
    return nearest
end

--- @section Rendering

--- Batches matching opaque meshes. Returns false when the current pass needs individual draws.
--- @param asset table Backend-owned model asset
--- @param mesh_index number Zero-based mesh index
--- @param nodes table World transforms sharing this mesh and tint
--- @return boolean drawn True if the batch was drawn
function m.draw_instances(asset, mesh_index, nodes)
    local shader = _lighting.instance_shader()
    if not shader or #nodes < 2 then return false end
    local material_index = asset.native.meshMaterial[mesh_index]
    local values = nodes[1].values
    if alpha_mode(asset, material_index, values[14]) == 2 then return false end
    local transforms = _ffi.new("Matrix[?]", #nodes)
    local base_values = matrix_values(asset.native.transform)
    local identity = true
    for index = 1, 16 do
        if base_values[index] ~= ((index == 1 or index == 6 or index == 11 or index == 16) and 1 or 0) then identity = false; break end
    end
    local base = not identity and _mat4.new(base_values)
    local mirrored = false
    for index, node in ipairs(nodes) do
        local matrix = identity and node.matrix.m or node.matrix:multiply(base).m
        local transform = transforms[index - 1]
        transform.m0, transform.m1, transform.m2, transform.m3 = matrix[1], matrix[2], matrix[3], matrix[4]
        transform.m4, transform.m5, transform.m6, transform.m7 = matrix[5], matrix[6], matrix[7], matrix[8]
        transform.m8, transform.m9, transform.m10, transform.m11 = matrix[9], matrix[10], matrix[11], matrix[12]
        transform.m12, transform.m13, transform.m14, transform.m15 = matrix[13], matrix[14], matrix[15], matrix[16]
        local determinant = transform.m0 * (transform.m5 * transform.m10 - transform.m9 * transform.m6)
            - transform.m4 * (transform.m1 * transform.m10 - transform.m9 * transform.m2)
            + transform.m8 * (transform.m1 * transform.m6 - transform.m5 * transform.m2)
        mirrored = mirrored or determinant < 0
    end
    local mesh = asset.native.meshes[mesh_index]
    local material = asset.native.materials[material_index]
    local settings = asset.materials[material_index + 1]
    local previous_shader = material.shader
    local previous_colour = _ffi.new("Color", material.maps[0].color)
    local emission = material.maps[EMISSION_MAP_SLOT]
    _lib.rlDrawRenderBatchActive()
    _lighting.set_model_material(settings.smooth and mesh.normals ~= nil,
        alpha_mode(asset, material_index, values[14]), settings.alpha_cutoff,
        emission.color, settings.emissive_strength, emission.texture.id ~= 0, true)
    material.shader = shader
    material.maps[0].color = _Color(math.floor(previous_colour.r * values[11] / 255),
        math.floor(previous_colour.g * values[12] / 255), math.floor(previous_colour.b * values[13] / 255), previous_colour.a)
    if settings.double_sided or mirrored then _lib.rlDisableBackfaceCulling() end
    local ok, reason = pcall(_lib.DrawMeshInstanced, mesh, material, transforms, #nodes)
    if settings.double_sided or mirrored then _lib.rlEnableBackfaceCulling() end
    material.shader, material.maps[0].color = previous_shader, previous_colour
    if not ok then error(reason, 0) end
    return true
end

--- Draws an asset with a transform and tint, restoring borrowed material bindings
--- @param asset table Backend-owned model asset
--- @param x number Position X
--- @param y number Position Y
--- @param z number Position Z
--- @param axis_x number Rotation axis X
--- @param axis_y number Rotation axis Y
--- @param axis_z number Rotation axis Z
--- @param angle number Rotation angle in degrees
--- @param scale_x number Scale X
--- @param scale_y number Scale Y
--- @param scale_z number Scale Z
--- @param red number Tint red (0-255)
--- @param green number Tint green (0-255)
--- @param blue number Tint blue (0-255)
--- @param alpha number Tint alpha (0-255)
--- @param mesh_index number|nil Draw one mesh (0-based) or the whole asset
--- @param world_matrix table|nil Full parent/local matrix in column-major order
--- @param pose table|nil Instance-specific CPU-skinned buffers
--- @return boolean ok True if drawn or skipped
--- @return string|nil reason Failure description
function m.draw(asset, x, y, z, axis_x, axis_y, axis_z, angle, scale_x, scale_y, scale_z, red, green, blue, alpha, mesh_index, world_matrix, pose)
    local shader = _lighting.mesh_shader()
    if shader == false then return true end
    local native_model = asset.native
    local shadow_texture = _lighting.shadow_texture()
    local shadow_pass = _lighting.is_shadow_pass()
    position_vec.x, position_vec.y, position_vec.z = x, y, z
    axis_vec.x, axis_vec.y, axis_vec.z = axis_x, axis_y, axis_z
    scale_vec.x, scale_vec.y, scale_vec.z = scale_x, scale_y, scale_z
    draw_tint.r, draw_tint.g, draw_tint.b, draw_tint.a = red, green, blue, alpha

    if world_matrix then
        local combined = _mat4.new(world_matrix):multiply(_mat4.new(matrix_values(native_model.transform)))
        for index = 0, 15 do asset.draw_model.transform["m" .. index] = combined.m[index + 1] end
        position_vec.x, position_vec.y, position_vec.z = 0, 0, 0
        axis_vec.x, axis_vec.y, axis_vec.z = 0, 1, 0
        scale_vec.x, scale_vec.y, scale_vec.z, angle = 1, 1, 1, 0
    else
        asset.draw_model.transform = native_model.transform
    end

    local transform = asset.draw_model.transform
    local determinant = transform.m0 * (transform.m5 * transform.m10 - transform.m9 * transform.m6)
        - transform.m4 * (transform.m1 * transform.m10 - transform.m9 * transform.m2)
        + transform.m8 * (transform.m1 * transform.m6 - transform.m5 * transform.m2)
    local mirrored = determinant * scale_vec.x * scale_vec.y * scale_vec.z < 0

    local first, last = mesh_index or 0, mesh_index or native_model.meshCount - 1
    _lib.rlDrawRenderBatchActive()
    for index = first, last do
        local material_index = native_model.meshMaterial[index]
        local material = native_model.materials[material_index]
        local settings = asset.materials[material_index + 1]
        local mode = alpha_mode(asset, material_index, alpha)
        -- Blended surfaces do not cast solid shadows. Cutouts keep their texture silhouette.
        if not shadow_pass or (settings.cast_shadows and mode ~= 2) then
            local emission = material.maps[EMISSION_MAP_SLOT]
            _lighting.set_model_material(settings.smooth and native_model.meshes[index].normals ~= nil,
                mode, settings.alpha_cutoff, emission.color, settings.emissive_strength, emission.texture.id ~= 0)
            asset.saved_shaders[material_index] = material.shader
            asset.saved_maps[material_index] = material.maps[SHADOW_MAP_SLOT].texture
            if shader then material.shader = shader end
            if shadow_texture then material.maps[SHADOW_MAP_SLOT].texture = shadow_texture end
            if mode == 2 and not shadow_pass then _lib.rlDisableDepthMask() end
            if settings.double_sided or mirrored then _lib.rlDisableBackfaceCulling() end

            -- A non-owning single-mesh view lets each material receive its own uniforms.
            local draw_model = asset.draw_model
            draw_model.meshCount = 1
            draw_model.meshes = native_model.meshes + index
            draw_model.meshMaterial = native_model.meshMaterial + index
            local mesh = native_model.meshes[index]
            local buffers = pose and pose.meshes[index + 1]
            local ok, reason = pcall(function()
                if buffers then
                    _lib.UpdateMeshBuffer(mesh, 0, buffers.vertices, mesh.vertexCount * 3 * _ffi.sizeof("float"), 0)
                    if buffers.normals then _lib.UpdateMeshBuffer(mesh, 2, buffers.normals, mesh.vertexCount * 3 * _ffi.sizeof("float"), 0) end
                end
                _lib.DrawModelEx(draw_model, position_vec, axis_vec, angle, scale_vec, draw_tint)
            end)
            if buffers then
                _lib.UpdateMeshBuffer(mesh, 0, mesh.vertices, mesh.vertexCount * 3 * _ffi.sizeof("float"), 0)
                if buffers.normals then _lib.UpdateMeshBuffer(mesh, 2, mesh.normals, mesh.vertexCount * 3 * _ffi.sizeof("float"), 0) end
            end

            if settings.double_sided or mirrored then _lib.rlEnableBackfaceCulling() end
            if mode == 2 and not shadow_pass then _lib.rlEnableDepthMask() end
            material.shader = asset.saved_shaders[material_index]
            material.maps[SHADOW_MAP_SLOT].texture = asset.saved_maps[material_index]
            if not ok then return false, tostring(reason) end
        end
    end
    return true
end

--- Points every material at the right shader and shadow map for the current pass
--- @param model cdata Model object
--- @return boolean ready False when the current pass must skip this model
local function bind_materials(model)
    local shader = _lighting.mesh_shader()
    if shader == false then return false end
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
    return true
end

--- Draws a model with a full 4x4 transform.
--- @param asset table Backend-owned model asset
--- @param rows table 16 numbers, row-major
--- @param r number Tint red
--- @param g number Tint green
--- @param b number Tint blue
--- @param a number Tint alpha
function m.draw_matrix(asset, rows, r, g, b, a)
    local model = asset.native or asset

    if not bind_materials(model) then return end

    for index = 0, 15 do
        transform_floats[index] = rows[index + 1]
    end

    model.transform = transform_matrix

    position_vec.x, position_vec.y, position_vec.z = 0, 0, 0
    axis_vec.x, axis_vec.y, axis_vec.z = 0, 1, 0
    scale_vec.x, scale_vec.y, scale_vec.z = 1, 1, 1
    tint.r, tint.g, tint.b, tint.a = r, g, b, a

    _lib.DrawModelEx(model, position_vec, axis_vec, 0, scale_vec, tint)
end

return m