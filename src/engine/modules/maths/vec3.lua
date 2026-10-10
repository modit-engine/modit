--- @module maths.vec3
--- @description Minimal Vec3 math module with metamethods.

local vec3 = {}
vec3.__index = vec3

local EPSILON = 1e-10

--- Validate a finite number.
local function validate_number(value, name)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        error(name .. " must be a finite number", 3)
    end
end

--- Validate a vector-like table.
local function validate_vector(v, name)
    if type(v) ~= "table" then error(name .. " must be a vector", 3) end
    validate_number(v.x, name .. ".x")
    validate_number(v.y, name .. ".y")
    validate_number(v.z, name .. ".z")
end

--- Create a new vec3 instance.
--- @param x number? X component (default 0).
--- @param y number? Y component (default 0).
--- @param z number? Z component (default 0).
--- @return table New vec3 instance.
function vec3.new(x, y, z)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if z == nil then z = 0 end
    validate_number(x, "x")
    validate_number(y, "y")
    validate_number(z, "z")
    return setmetatable({ x = x, y = y, z = z }, vec3)
end

--- Create a copy of a vector.
--- @param v table Vector to copy.
--- @return table New vec3 copy.
function vec3.copy(v)
    validate_vector(v, "Vector")
    return vec3.new(v.x, v.y, v.z)
end

--- Set vector components in-place.
--- @param v table Vector to modify.
--- @param x number X component.
--- @param y number Y component.
--- @param z number Z component.
--- @return table The modified vector.
function vec3.set(v, x, y, z)
    validate_vector(v, "Vector")
    validate_number(x, "x")
    validate_number(y, "y")
    validate_number(z, "z")
    v.x, v.y, v.z = x, y, z
    return v
end

--- Add two vectors.
--- @param a table First vector.
--- @param b table Second vector.
--- @return table Result vector.
function vec3.add(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return vec3.new(a.x + b.x, a.y + b.y, a.z + b.z)
end

--- Subtract two vectors.
--- @param a table First vector.
--- @param b table Second vector.
--- @return table Result vector.
function vec3.sub(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return vec3.new(a.x - b.x, a.y - b.y, a.z - b.z)
end

--- Scale a vector by a scalar.
--- @param v table Vector to scale.
--- @param s number Scalar value.
--- @return table Scaled vector.
function vec3.scale(v, s)
    validate_vector(v, "Vector")
    validate_number(s, "Scalar")
    return vec3.new(v.x * s, v.y * s, v.z * s)
end

--- Calculate the dot product of two vectors.
--- @param a table First vector.
--- @param b table Second vector.
--- @return number Dot product.
function vec3.dot(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return a.x * b.x + a.y * b.y + a.z * b.z
end

--- Calculate the cross product of two vectors.
--- @param a table First vector.
--- @param b table Second vector.
--- @return table Cross product vector.
function vec3.cross(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return vec3.new(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

--- Calculate the length (magnitude) of a vector.
--- @param v table Vector.
--- @return number Vector length.
function vec3.length(v)
    validate_vector(v, "Vector")
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

--- Calculate squared length (faster for comparisons).
--- @param v table Vector.
--- @return number Squared length.
function vec3.length_squared(v)
    validate_vector(v, "Vector")
    return v.x * v.x + v.y * v.y + v.z * v.z
end

--- Normalize a vector. A zero-length vector returns a zero vector.
--- @param v table Vector to normalize.
--- @return table Normalized vector.
function vec3.normalize(v)
    validate_vector(v, "Vector")
    local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if len <= EPSILON then return vec3.new() end
    return vec3.new(v.x / len, v.y / len, v.z / len)
end

--- Check if a vector is effectively zero.
--- @param v table Vector to check.
--- @return boolean True if the vector is within epsilon of zero.
function vec3.is_zero(v)
    validate_vector(v, "Vector")
    return v.x * v.x + v.y * v.y + v.z * v.z < EPSILON * EPSILON
end

--- Calculate distance between two points.
--- @param a table First point.
--- @param b table Second point.
--- @return number Distance between points.
function vec3.distance(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(x * x + y * y + z * z)
end

--- Calculate squared distance (faster for comparisons).
--- @param a table First point.
--- @param b table Second point.
--- @return number Squared distance.
function vec3.distance_squared(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return x * x + y * y + z * z
end

--- Linear interpolation between two vectors.
--- t is not clamped, so values outside [0, 1] extrapolate.
--- @param a table Start vector.
--- @param b table End vector.
--- @param t number Interpolation factor.
--- @return table Interpolated vector.
function vec3.lerp(a, b, t)
    validate_vector(a, "Start vector")
    validate_vector(b, "End vector")
    validate_number(t, "Interpolation factor")
    return vec3.new(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
end

--- Metamethod: Addition.
function vec3.__add(a, b)
    return vec3.add(a, b)
end

--- Metamethod: Subtraction.
function vec3.__sub(a, b)
    return vec3.sub(a, b)
end

--- Metamethod: Scalar multiplication (vec * scalar or scalar * vec).
function vec3.__mul(a, b)
    if type(a) == "number" then return vec3.scale(b, a) end
    return vec3.scale(a, b)
end

--- Metamethod: Division by scalar.
function vec3.__div(a, b)
    if type(b) ~= "number" then error("Can only divide a vector by a number") end
    validate_number(b, "Divisor")
    if b == 0 then error("Division by zero") end
    return vec3.scale(a, 1 / b)
end

--- Metamethod: String representation.
function vec3.__tostring(v)
    return string.format("vec3(%.3f, %.3f, %.3f)", v.x, v.y, v.z)
end

--- Metamethod: Approximate equality.
function vec3.__eq(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    if type(a.x) ~= "number" or type(a.y) ~= "number" or type(a.z) ~= "number"
        or type(b.x) ~= "number" or type(b.y) ~= "number" or type(b.z) ~= "number" then
        return false
    end
    return math.abs(a.x - b.x) < EPSILON and math.abs(a.y - b.y) < EPSILON and math.abs(a.z - b.z) < EPSILON
end

--- Callable constructor: vec3(x, y, z).
return setmetatable(vec3, {
    __call = function(_, x, y, z)
        return vec3.new(x, y, z)
    end
})