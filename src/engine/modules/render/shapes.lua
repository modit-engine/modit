--- @module shapes
--- @file src/engine/modules/render/shapes.lua
--- @description Built-in low-poly shapes (cube, sphere, cylinder, cone, wedge) with a transform stack for rotated and nested parts. Lit, fogged and shadowed like models.

--- @section Imports

local _backend = require("src.engine.backend").model

--- @section Constants

local SIDES = 12 -- sides of round shapes
local RINGS = 8 -- latitude rings of the sphere
local MAX_DEPTH = 32
local TWO_PI = math.pi * 2

-- Cube faces: n is the normal, u and v span the face (u x v = n keeps triangles counter-clockwise)
local FACES = {
    { { 1, 0, 0 }, { 0, 0, -1 }, { 0, 1, 0 } },
    { { -1, 0, 0 }, { 0, 0, 1 }, { 0, 1, 0 } },
    { { 0, 1, 0 }, { 1, 0, 0 }, { 0, 0, -1 } },
    { { 0, -1, 0 }, { 1, 0, 0 }, { 0, 0, 1 } },
    { { 0, 0, 1 }, { 1, 0, 0 }, { 0, 1, 0 } },
    { { 0, 0, -1 }, { -1, 0, 0 }, { 0, 1, 0 } },
}
local CORNERS = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }

--- @section State

local handles = {} -- shape name -> model
local stack = { { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 } }
local depth = 1
local scratch = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }

--- @section Initialisation

local m = {}

--- @section Shape Builders

local function tri(vertices, a, b, c)
    local n = #vertices
    vertices[n + 1], vertices[n + 2], vertices[n + 3] = a[1], a[2], a[3]
    vertices[n + 4], vertices[n + 5], vertices[n + 6] = b[1], b[2], b[3]
    vertices[n + 7], vertices[n + 8], vertices[n + 9] = c[1], c[2], c[3]
end

local function ring_point(index, y, radius)
    local angle = TWO_PI * index / SIDES
    return { math.cos(angle) * radius, y, math.sin(angle) * radius }
end

local function build_cube()
    local vertices = {}
    for _, face in ipairs(FACES) do
        local n, u, v = face[1], face[2], face[3]
        local points = {}
        for index, corner in ipairs(CORNERS) do
            points[index] = {
                (n[1] + u[1] * corner[1] + v[1] * corner[2]) * 0.5,
                (n[2] + u[2] * corner[1] + v[2] * corner[2]) * 0.5,
                (n[3] + u[3] * corner[1] + v[3] * corner[2]) * 0.5,
            }
        end
        tri(vertices, points[1], points[2], points[3])
        tri(vertices, points[1], points[3], points[4])
    end
    return vertices
end

local function build_cylinder()
    local vertices = {}
    local top, bottom = { 0, 0.5, 0 }, { 0, -0.5, 0 }
    for index = 0, SIDES - 1 do
        local b0, b1 = ring_point(index, -0.5, 0.5), ring_point(index + 1, -0.5, 0.5)
        local t0, t1 = ring_point(index, 0.5, 0.5), ring_point(index + 1, 0.5, 0.5)
        tri(vertices, b1, b0, t0)
        tri(vertices, b1, t0, t1)
        tri(vertices, top, t1, t0)
        tri(vertices, bottom, b0, b1)
    end
    return vertices
end

local function build_cone()
    local vertices = {}
    local apex, bottom = { 0, 0.5, 0 }, { 0, -0.5, 0 }
    for index = 0, SIDES - 1 do
        local b0, b1 = ring_point(index, -0.5, 0.5), ring_point(index + 1, -0.5, 0.5)
        tri(vertices, b1, b0, apex)
        tri(vertices, bottom, b0, b1)
    end
    return vertices
end

local function build_sphere()
    local vertices = {}

    local function point(ring, index)
        local latitude = -math.pi / 2 + math.pi * ring / RINGS
        local longitude = TWO_PI * index / SIDES
        local flat = math.cos(latitude) * 0.5
        return { flat * math.cos(longitude), math.sin(latitude) * 0.5, flat * math.sin(longitude) }
    end

    for ring = 0, RINGS - 1 do
        for index = 0, SIDES - 1 do
            local bl, br = point(ring, index + 1), point(ring, index)
            local tr, tl = point(ring + 1, index), point(ring + 1, index + 1)
            if ring > 0 then tri(vertices, bl, br, tr) end
            if ring < RINGS - 1 then tri(vertices, bl, tr, tl) end
        end
    end
    return vertices
end

-- Ramp: low edge at -z, high edge at +z
local function build_wedge()
    local vertices = {}
    local a, b, c = { -0.5, -0.5, -0.5 }, { 0.5, -0.5, -0.5 }, { 0.5, -0.5, 0.5 }
    local d, e, f = { -0.5, -0.5, 0.5 }, { -0.5, 0.5, 0.5 }, { 0.5, 0.5, 0.5 }

    tri(vertices, a, b, c); tri(vertices, a, c, d) -- bottom
    tri(vertices, d, c, f); tri(vertices, d, f, e) -- back
    tri(vertices, a, f, b); tri(vertices, a, e, f) -- slope
    tri(vertices, a, d, e) -- left side
    tri(vertices, b, f, c) -- right side
    return vertices
end

local BUILDERS = {
    cube = build_cube,
    sphere = build_sphere,
    cylinder = build_cylinder,
    cone = build_cone,
    wedge = build_wedge,
}

--- @section Helpers

local function tint_values(tint)
    if not tint then return 255, 255, 255, 255 end
    return tint.r or tint[1] or 255, tint.g or tint[2] or 255, tint.b or tint[3] or 255, tint.a or tint[4] or 255
end

local function get_handle(name)
    local handle = handles[name]
    if not handle then
        handle = _backend.build(BUILDERS[name](), nil, nil, nil)
        handles[name] = handle
    end
    return handle
end

--- @section Functions

--- Saves the current transform. Pair every push with a pop
function m.push()
    if depth >= MAX_DEPTH then
        error("shapes.push: stack is full (" .. MAX_DEPTH .. ")", 2)
    end

    local top = stack[depth]
    depth = depth + 1
    local copy = stack[depth]
    if not copy then
        copy = {}
        stack[depth] = copy
    end
    for index = 1, 16 do copy[index] = top[index] end
end

--- Restores the transform saved by the last push
function m.pop()
    if depth <= 1 then
        error("shapes.pop: nothing to pop", 2)
    end
    depth = depth - 1
end

--- Moves everything drawn after this, in the current local space
--- @param x number X offset
--- @param y number Y offset
--- @param z number Z offset
function m.translate(x, y, z)
    local t = stack[depth]
    x, y, z = tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
    for row = 0, 3 do
        local i = row * 4
        t[i + 4] = t[i + 1] * x + t[i + 2] * y + t[i + 3] * z + t[i + 4]
    end
end

--- Rotates everything drawn after this around an axis through the current origin
--- @param angle number Angle in degrees (counter-clockwise looking down the axis)
--- @param ax number|nil Axis X (default: 0)
--- @param ay number|nil Axis Y (default: 1, so a plain rotate(angle) turns left/right)
--- @param az number|nil Axis Z (default: 0)
function m.rotate(angle, ax, ay, az)
    ax, ay, az = tonumber(ax) or 0, tonumber(ay) or 1, tonumber(az) or 0
    local length = math.sqrt(ax * ax + ay * ay + az * az)
    if length < 1e-9 then return end
    ax, ay, az = ax / length, ay / length, az / length

    local radians = math.rad(tonumber(angle) or 0)
    local c, s = math.cos(radians), math.sin(radians)
    local k = 1 - c

    local r00, r01, r02 = k * ax * ax + c, k * ax * ay - s * az, k * ax * az + s * ay
    local r10, r11, r12 = k * ax * ay + s * az, k * ay * ay + c, k * ay * az - s * ax
    local r20, r21, r22 = k * ax * az - s * ay, k * ay * az + s * ax, k * az * az + c

    local t = stack[depth]
    for row = 0, 3 do
        local i = row * 4
        local m0, m1, m2 = t[i + 1], t[i + 2], t[i + 3]
        t[i + 1] = m0 * r00 + m1 * r10 + m2 * r20
        t[i + 2] = m0 * r01 + m1 * r11 + m2 * r21
        t[i + 3] = m0 * r02 + m1 * r12 + m2 * r22
    end
end

--- Scales everything drawn after this
--- @param x number X scale
--- @param y number|nil Y scale (default: x)
--- @param z number|nil Z scale (default: x)
function m.scale(x, y, z)
    x = tonumber(x) or 1
    y, z = tonumber(y) or x, tonumber(z) or x

    local t = stack[depth]
    for row = 0, 3 do
        local i = row * 4
        t[i + 1], t[i + 2], t[i + 3] = t[i + 1] * x, t[i + 2] * y, t[i + 3] * z
    end
end

--- Clears the transform stack. Called at the start of every 3D pass
function m.reset()
    depth = 1
    local t = stack[1]
    for index = 1, 16 do t[index] = (index % 5 == 1) and 1 or 0 end
end

--- Draws a shape at the current transform. Call inside camera begin_3d/end_3d
--- @param opts table `{ shape, x?, y?, z?, size?, tint? }` shape is "cube", "sphere", "cylinder", "cone" or "wedge" (all 1 unit big, wedge rises toward +z), x/y/z offset it in the current space, size is a number or `{ x, y, z }`
function m.draw(opts)
    local name = opts.shape
    if not BUILDERS[name] then return end

    local size = opts.size
    local sx, sy, sz
    if type(size) == "table" then
        sx, sy, sz = size.x or size[1] or 1, size.y or size[2] or 1, size.z or size[3] or 1
    else
        sx = size or 1
        sy, sz = sx, sx
    end

    local x, y, z = opts.x or 0, opts.y or 0, opts.z or 0
    local t = stack[depth]
    for row = 0, 3 do
        local i = row * 4
        local m0, m1, m2, m3 = t[i + 1], t[i + 2], t[i + 3], t[i + 4]
        scratch[i + 1], scratch[i + 2], scratch[i + 3] = m0 * sx, m1 * sy, m2 * sz
        scratch[i + 4] = m0 * x + m1 * y + m2 * z + m3
    end

    _backend.draw_matrix(get_handle(name), scratch, tint_values(opts.tint))
end

return m