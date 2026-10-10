--- @module maths.vec4
--- @description Minimal Vec4 math module with metamethods.

local vec4 = {}
vec4.__index = vec4

local EPSILON = 1e-10

local function validate_number(v, name)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
        error(name .. " must be a finite number", 3)
    end
end

local function validate_vector(v, name)
    if type(v) ~= "table" then error(name .. " must be a vector", 3) end
    validate_number(v.x, name .. ".x")
    validate_number(v.y, name .. ".y")
    validate_number(v.z, name .. ".z")
    validate_number(v.w, name .. ".w")
end

--- Create a new vec4 instance.
--- @param x number? X component (default 0).
--- @param y number? Y component (default 0).
--- @param z number? Z component (default 0).
--- @param w number? W component (default 0).
function vec4.new(x, y, z, w)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if z == nil then z = 0 end
    if w == nil then w = 0 end
    validate_number(x, "x")
    validate_number(y, "y")
    validate_number(z, "z")
    validate_number(w, "w")
    return setmetatable({ x = x, y = y, z = z, w = w }, vec4)
end

--- Create a copy of a vector.
function vec4.copy(v)
    validate_vector(v, "Vector")
    return vec4.new(v.x, v.y, v.z, v.w)
end

--- Set vector components in-place.
function vec4.set(v, x, y, z, w)
    validate_vector(v, "Vector")
    validate_number(x, "x")
    validate_number(y, "y")
    validate_number(z, "z")
    validate_number(w, "w")
    v.x, v.y, v.z, v.w = x, y, z, w
    return v
end

--- Extract the first three components as a plain table.
function vec4.xyz(v)
    validate_vector(v, "Vector")
    return { x = v.x, y = v.y, z = v.z }
end

--- Add two vectors.
function vec4.add(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return vec4.new(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w)
end

--- Subtract two vectors.
function vec4.sub(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return vec4.new(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w)
end

--- Scale a vector by a scalar.
function vec4.scale(v, s)
    validate_vector(v, "Vector")
    validate_number(s, "Scalar")
    return vec4.new(v.x * s, v.y * s, v.z * s, v.w * s)
end

--- Calculate the dot product.
function vec4.dot(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
end

--- Calculate vector length.
function vec4.length(v)
    validate_vector(v, "Vector")
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w)
end

--- Calculate squared vector length.
function vec4.length_squared(v)
    validate_vector(v, "Vector")
    return v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w
end

--- Normalize a vector. Returns zero for a near-zero vector.
function vec4.normalize(v)
    validate_vector(v, "Vector")
    local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w)
    if len <= EPSILON then return vec4.new() end
    return vec4.new(v.x / len, v.y / len, v.z / len, v.w / len)
end

--- Check whether a vector is effectively zero.
function vec4.is_zero(v)
    validate_vector(v, "Vector")
    return v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w < EPSILON * EPSILON
end

--- Calculate distance between two points.
function vec4.distance(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    local x, y, z, w = a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w
    return math.sqrt(x * x + y * y + z * z + w * w)
end

--- Calculate squared distance between two points.
function vec4.distance_squared(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    local x, y, z, w = a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w
    return x * x + y * y + z * z + w * w
end

--- Linear interpolation. Values outside [0, 1] extrapolate.
function vec4.lerp(a, b, t)
    validate_vector(a, "Start vector")
    validate_vector(b, "End vector")
    validate_number(t, "Interpolation factor")
    return vec4.new(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, a.w + (b.w - a.w) * t)
end

--- Metamethod: Addition.
function vec4.__add(a, b)
    return vec4.add(a, b)
end

--- Metamethod: Subtraction.
function vec4.__sub(a, b)
    return vec4.sub(a, b)
end

--- Metamethod: Scalar multiplication.
function vec4.__mul(a, b)
    if type(a) == "number" then return vec4.scale(b, a) end
    return vec4.scale(a, b)
end

--- Metamethod: Division by scalar.
function vec4.__div(a, b)
    if type(b) ~= "number" then error("Can only divide a vector by a number") end
    validate_number(b, "Divisor")
    if b == 0 then error("Division by zero") end
    return vec4.scale(a, 1 / b)
end

--- Metamethod: String representation.
function vec4.__tostring(v)
    return string.format("vec4(%.3f, %.3f, %.3f, %.3f)", v.x, v.y, v.z, v.w)
end

--- Metamethod: Approximate equality.
function vec4.__eq(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    if type(a.x) ~= "number" or type(a.y) ~= "number" or type(a.z) ~= "number" or type(a.w) ~= "number"
        or type(b.x) ~= "number" or type(b.y) ~= "number" or type(b.z) ~= "number" or type(b.w) ~= "number" then
        return false
    end
    return math.abs(a.x - b.x) < EPSILON and math.abs(a.y - b.y) < EPSILON and math.abs(a.z - b.z) < EPSILON and math.abs(a.w - b.w) < EPSILON
end

--- Callable constructor: vec4(x, y, z, w).
return setmetatable(vec4, {
    __call = function(_, x, y, z, w)
        return vec4.new(x, y, z, w)
    end
})