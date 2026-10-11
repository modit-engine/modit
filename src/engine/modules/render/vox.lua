--- @module vox
--- @file src/engine/modules/render/vox.lua
--- @description Internal Lua VOX scene reader. Returns mesh/assembly data without native handles.
--- Format: https://github.com/ephtracy/voxel-model

--- @section Constants & Initialisation

local MAX_VOXELS = 16000000
local MAX_FACES = 1000000
local MAX_NODES = 4096
local m = {}

--- @section Binary Reader

local function reader(source, first, last)
    local position = first or 1
    last = last or #source
    local read = {}

    function read.bytes(count)
        if count < 0 or position + count - 1 > last then error("truncated VOX chunk", 0) end
        local result = source:sub(position, position + count - 1)
        position = position + count
        return result
    end

    function read.integer()
        local a, b, c, d = read.bytes(4):byte(1, 4)
        local value = a + b * 256 + c * 65536 + d * 16777216
        return value >= 2147483648 and value - 4294967296 or value
    end

    function read.count(limit)
        local count = read.integer()
        if count < 0 or count > limit then error("invalid VOX count", 0) end
        return count
    end

    function read.dictionary()
        local result = {}
        for index = 1, read.count(4096) do
            local key = read.bytes(read.count(1048576))
            result[key] = read.bytes(read.count(1048576))
        end
        return result
    end

    return read
end

local function default_palette()
    local palette = {}
    for red = 255, 0, -51 do
        for green = 255, 0, -51 do
            for blue = 255, 0, -51 do
                if red + green + blue > 0 then palette[#palette + 1] = { red, green, blue, 255 } end
            end
        end
    end
    local shades = { 238, 221, 187, 170, 136, 119, 85, 68, 34, 17 }
    for channel = 1, 4 do
        for _, shade in ipairs(shades) do
            local colour = { 0, 0, 0, 255 }
            if channel == 4 then colour[1], colour[2], colour[3] = shade, shade, shade else colour[channel] = shade end
            palette[#palette + 1] = colour
        end
    end
    return palette
end

--- @section Scene Transforms

-- Change MagicaVoxel Z-up coordinates to engine Y-up: (x, y, z) -> (x, z, -y).
local function coordinates(vector)
    return vector[1], vector[3], -vector[2]
end

local function rotation(encoded)
    local value = tonumber(encoded or "4")
    if not value or value % 1 ~= 0 or value < 0 or value > 127 then error("invalid VOX rotation", 0) end
    local first, second = value % 4, math.floor(value / 4) % 4
    if first > 2 or second > 2 or first == second then error("invalid VOX rotation axes", 0) end
    local source = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
    source[1][first + 1] = math.floor(value / 16) % 2 == 0 and 1 or -1
    source[2][second + 1] = math.floor(value / 32) % 2 == 0 and 1 or -1
    source[3][4 - first - second] = math.floor(value / 64) % 2 == 0 and 1 or -1
    local order, signs, matrix = { 1, 3, 2 }, { 1, 1, -1 }, { {}, {}, {} }
    for row = 1, 3 do
        for column = 1, 3 do matrix[row][column] = signs[row] * signs[column] * source[order[row]][order[column]] end
    end
    local determinant = matrix[1][1] * (matrix[2][2] * matrix[3][3] - matrix[2][3] * matrix[3][2])
        - matrix[1][2] * (matrix[2][1] * matrix[3][3] - matrix[2][3] * matrix[3][1])
        + matrix[1][3] * (matrix[2][1] * matrix[3][2] - matrix[2][2] * matrix[3][1])
    if determinant < 0 then for row = 1, 3 do matrix[row][1] = -matrix[row][1] end end
    local cosine = math.max(-1, math.min(1, (matrix[1][1] + matrix[2][2] + matrix[3][3] - 1) / 2))
    local angle = math.acos(cosine)
    local axis = { 0, 1, 0 }
    if angle > 0.00001 then
        if math.abs(angle - math.pi) < 0.00001 then
            local largest = 1
            for index = 2, 3 do if matrix[index][index] > matrix[largest][largest] then largest = index end end
            axis[largest] = math.sqrt((matrix[largest][largest] + 1) / 2)
            for index = 1, 3 do
                if index ~= largest then axis[index] = matrix[index][largest] / (2 * axis[largest]) end
            end
        else
            axis = { matrix[3][2] - matrix[2][3], matrix[1][3] - matrix[3][1], matrix[2][1] - matrix[1][2] }
        end
    end
    return { x = axis[1], y = axis[2], z = axis[3] }, angle * 180 / math.pi, { x = determinant, y = 1, z = 1 }
end

--- @section Exposed Faces

local function voxel_key(x, y, z)
    return x + y * 256 + z * 65536
end

local function make_meshes(model, palette, materials, budget, combine_colours)
    local parts, buckets = {}, {}
    local centre = { math.floor(model.size[1] / 2), math.floor(model.size[2] / 2), math.floor(model.size[3] / 2) }
    local strides = { 1, 256, 65536 }
    local function face(colour_index, normal_axis, direction, slice, u_axis, v_axis, u, v, width, height)
        budget.faces = budget.faces + 1
        if budget.faces > MAX_FACES then error("VOX scene exceeds merged-face budget", 0) end
        local colour = palette[colour_index]
        local properties = materials[colour_index] or {}
        local combined = combine_colours and colour[4] == 255 and properties._type ~= "_emit"
        local bucket_key = combined and "opaque" or colour_index
        local bucket = buckets[bucket_key]
        if not bucket or #bucket.mesh.vertices >= 180000 then
            local material = { tint = combined and {255, 255, 255, 255} or colour, smooth = false }
            if properties._type == "_emit" then
                local strength = tonumber(properties._emit or properties._weight) or 1
                material.emissive, material.emissive_strength = { colour[1], colour[2], colour[3] }, math.max(0, strength)
            end
            bucket = { mesh = { vertices = {}, normals = {}, colours = combined and {} or nil }, materials = { material } }
            local sequence, name = 1, combined and "opaque" or "palette_" .. colour_index
            while parts[name] do sequence = sequence + 1; name = "palette_" .. colour_index .. "_" .. sequence end
            parts[name], buckets[bucket_key] = bucket, bucket
        end
        local corners = {}
        for index, offset in ipairs({ { 0, 0 }, { width, 0 }, { width, height }, { 0, height } }) do
            local point = { -centre[1], -centre[2], -centre[3] }
            point[normal_axis] = point[normal_axis] + slice + (direction == 1 and 1 or 0)
            point[u_axis], point[v_axis] = point[u_axis] + u + offset[1], point[v_axis] + v + offset[2]
            corners[index] = { coordinates(point) }
        end
        local normal = { 0, 0, 0 }
        normal[normal_axis] = direction
        normal = { coordinates(normal) }
        local triangles = direction == 1 and { 1, 2, 3, 1, 3, 4 } or { 1, 3, 2, 1, 4, 3 }
        for _, corner in ipairs(triangles) do
            if combined then
                for channel = 1, 4 do bucket.mesh.colours[#bucket.mesh.colours + 1] = colour[channel] end
            end
            for axis = 1, 3 do
                bucket.mesh.vertices[#bucket.mesh.vertices + 1] = corners[corner][axis]
                bucket.mesh.normals[#bucket.mesh.normals + 1] = normal[axis]
            end
        end
    end
    -- Greedy rectangles retain palette boundaries but avoid a quad for every surface voxel.
    for normal_axis = 1, 3 do
        local u_axis, v_axis = normal_axis % 3 + 1, (normal_axis + 1) % 3 + 1
        local u_size, v_size = model.size[u_axis], model.size[v_axis]
        for direction = -1, 1, 2 do
            for slice = 0, model.size[normal_axis] - 1 do
                local mask = {}
                local inside = slice + direction >= 0 and slice + direction < model.size[normal_axis]
                for v = 0, v_size - 1 do
                    for u = 0, u_size - 1 do
                        local key = slice * strides[normal_axis] + u * strides[u_axis] + v * strides[v_axis]
                        local colour = model.occupied[key]
                        if colour then
                            local adjacent = inside and model.occupied[key + direction * strides[normal_axis]]
                            if not adjacent or (adjacent ~= colour and palette[adjacent][4] < 255) then mask[v * u_size + u] = colour end
                        end
                    end
                end
                for v = 0, v_size - 1 do
                    local u = 0
                    while u < u_size do
                        local colour = mask[v * u_size + u]
                        if not colour then
                            u = u + 1
                        else
                            local width, height = 1, 1
                            while u + width < u_size and mask[v * u_size + u + width] == colour do width = width + 1 end
                            local extend = true
                            while v + height < v_size and extend do
                                for offset = 0, width - 1 do
                                    if mask[(v + height) * u_size + u + offset] ~= colour then extend = false; break end
                                end
                                if extend then height = height + 1 end
                            end
                            for row = v, v + height - 1 do
                                for column = u, u + width - 1 do mask[row * u_size + column] = nil end
                            end
                            face(colour, normal_axis, direction, slice, u_axis, v_axis, u, v, width, height)
                            u = u + width
                        end
                    end
                end
            end
        end
    end
    if combine_colours then
        local first_name, only = next(parts)
        if only and next(parts, first_name) == nil then return only end
    end
    return { parts = parts }
end

--- @section Import

--- Reads static scene nodes, shared palette, emission, hidden layers and signed rotations
--- @param source string Complete VOX bytes
--- @return table|nil definition Asset description usable by model.load_asset
--- @return string|nil reason
function m.decode(source, combine_colours)
    local ok, result = pcall(function()
        if type(source) ~= "string" or #source < 20 or #source > 268435456 then error("invalid VOX file size", 0) end
        local header = reader(source)
        if header.bytes(4) ~= "VOX " then error("invalid VOX signature", 0) end
        local version = header.integer()
        if version ~= 150 and version ~= 200 then error("unsupported VOX version", 0) end
        if header.bytes(4) ~= "MAIN" or header.integer() ~= 0 then error("invalid VOX root", 0) end
        local children_size = header.count(#source)
        if children_size ~= #source - 20 then error("invalid VOX root length", 0) end
        local models, nodes, layers, materials = {}, {}, {}, {}
        local palette, pending_size, total_voxels, node_count = default_palette(), nil, 0, 0
        local position = 21
        while position <= #source do
            local chunk = reader(source, position)
            local kind = chunk.bytes(4)
            local size, children = chunk.count(#source), chunk.count(#source)
            local last = position + 11 + size
            if last + children > #source then error("VOX chunk exceeds file", 0) end
            local content = reader(source, position + 12, last)
            if kind == "SIZE" then
                pending_size = { content.count(256), content.count(256), content.count(256) }
                for _, dimension in ipairs(pending_size) do if dimension < 1 then error("invalid voxel dimensions", 0) end end
            elseif kind == "XYZI" then
                if not pending_size or #models >= MAX_NODES then error("missing VOX dimensions or too many models", 0) end
                local model = { size = pending_size, occupied = {} }
                local count = content.count(MAX_VOXELS)
                total_voxels = total_voxels + count
                if total_voxels > MAX_VOXELS then error("VOX scene exceeds voxel budget", 0) end
                for index = 1, count do
                    local voxel = { content.bytes(4):byte(1, 4) }
                    for axis = 1, 3 do if voxel[axis] >= pending_size[axis] then error("voxel is outside SIZE bounds", 0) end end
                    if voxel[4] == 0 then error("voxel uses reserved palette index zero", 0) end
                    local key = voxel_key(voxel[1], voxel[2], voxel[3])
                    if model.occupied[key] then error("duplicate voxel coordinate", 0) end
                    model.occupied[key] = voxel[4]
                end
                models[#models + 1], pending_size = model, nil
            elseif kind == "RGBA" then
                for index = 1, 255 do palette[index] = { content.bytes(4):byte(1, 4) } end
                content.bytes(4)
            elseif kind == "MATL" then
                -- MagicaVoxel saves all 256 material slots, although XYZI can only
                -- reference colours 1..255. Keep the unused final slot as metadata.
                local index = content.integer()
                if index < 1 or index > 256 then error("invalid VOX material id", 0) end
                materials[index] = content.dictionary()
            elseif kind == "LAYR" then
                local index = content.integer()
                layers[index] = content.dictionary()
            elseif kind == "nTRN" or kind == "nGRP" or kind == "nSHP" then
                local id = content.count(2147483647)
                if nodes[id] then error("duplicate VOX scene node", 0) end
                local node = { kind = kind, attributes = content.dictionary() }
                node_count = node_count + 1
                if node_count > MAX_NODES then error("too many VOX scene nodes", 0) end
                if kind == "nTRN" then
                    node.child = content.count(2147483647)
                    content.integer()
                    node.layer = content.integer()
                    if content.count(100000) ~= 1 then error("VOX keyframe animation is not supported; export a static assembly", 0) end
                    node.frame = content.dictionary()
                elseif kind == "nGRP" then
                    node.children = {}
                    for index = 1, content.count(MAX_NODES) do node.children[index] = content.count(2147483647) end
                else
                    if content.count(MAX_NODES) ~= 1 then error("VOX shape animation is not supported", 0) end
                    node.model = content.count(MAX_NODES) + 1
                    content.dictionary()
                end
                nodes[id] = node
            end
            -- Scene chunks have no nested children. Unknown extension chunks are safely skipped.
            position = last + children + 1
        end
        if #models == 0 then error("VOX contains no models", 0) end
        local budget, meshes = { faces = 0 }, {}
        local function geometry(index)
            if not models[index] then error("VOX shape references a missing model", 0) end
            if not meshes[index] then meshes[index] = make_meshes(models[index], palette, materials, budget, combine_colours) end
            return meshes[index]
        end
        if node_count == 0 then
            if #models ~= 1 then error("multiple VOX models need a scene graph for placement", 0) end
            return geometry(1)
        end
        local referenced, visiting, visited = {}, {}, {}
        for _, node in pairs(nodes) do
            if node.child then referenced[node.child] = true end
            for _, child in ipairs(node.children or {}) do referenced[child] = true end
        end
        local function scene(id, depth)
            if visiting[id] or depth >= 60 then error("cyclic or excessively deep VOX scene", 0) end
            local node = nodes[id]
            if not node then error("missing VOX scene node", 0) end
            visiting[id], visited[id] = true, true
            local definition = { parts = {} }
            if node.attributes._hidden == "1" or (layers[node.layer] and layers[node.layer]._hidden == "1") then
                visiting[id] = nil
                return definition
            end
            local function child(child_id)
                local part = scene(child_id, depth + 1)
                local name = nodes[child_id].attributes._name or "node_" .. child_id
                if name == "" or name:find("\0", 1, true) then name = "node_" .. child_id end
                while definition.parts[name] do name = name .. "_" .. child_id end
                definition.parts[name] = part
            end
            if node.kind == "nTRN" then
                local translation = {}
                for number in (node.frame._t or "0 0 0"):gmatch("%S+") do
                    local value = tonumber(number)
                    if not value or value % 1 ~= 0 or math.abs(value) > 2147483647 then error("invalid VOX translation", 0) end
                    translation[#translation + 1] = value
                end
                if #translation ~= 3 then error("invalid VOX translation", 0) end
                definition.x, definition.y, definition.z = coordinates(translation)
                definition.axis, definition.angle, definition.scale = rotation(node.frame._r)
                local next_node = nodes[node.child]
                if combine_colours and next_node and not next_node.attributes._name
                    and (next_node.kind == "nSHP" or next_node.kind == "nGRP") then
                    -- These unnamed containers have no transform of their own. Keep
                    -- the authored transform/part name, without an extra runtime node.
                    local geometry = scene(node.child, depth + 1)
                    definition.mesh, definition.materials = geometry.mesh, geometry.materials
                    definition.parts = geometry.parts or {}
                else
                    child(node.child)
                end
            elseif node.kind == "nGRP" then
                for _, child_id in ipairs(node.children) do child(child_id) end
            else
                definition = geometry(node.model)
            end
            visiting[id] = nil
            return definition
        end
        local root = { parts = {} }
        for id, node in pairs(nodes) do
            if not referenced[id] then
                local name = node.attributes._name or "node_" .. id
                if name == "" or name:find("\0", 1, true) then name = "node_" .. id end
                while root.parts[name] do name = name .. "_" .. id end
                root.parts[name] = scene(id, 0)
            end
        end
        -- Rootless cycles must not disappear silently.
        for id in pairs(nodes) do if not visited[id] then scene(id, 0) end end
        return root
    end)
    if not ok then return nil, tostring(result) end
    return result
end

return m
