--- @module maths.vec2
--- @description Minimal Vec2 math module with metamethods.

local vec2 = {}
vec2.__index = vec2

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
end

--- Create a new vec2 instance.
--- @param x number? X component (default 0).
--- @param y number? Y component (default 0).
--- @return table New vec2 instance.
function vec2.new(x, y)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    validate_number(x, "x")
    validate_number(y, "y")
    return setmetatable({ x = x, y = y }, vec2)
end

--- Create a copy of a vector.
function vec2.copy(v)
    validate_vector(v, "Vector")
    return vec2.new(v.x, v.y)
end

--- Set vector components in-place.
function vec2.set(v, x, y)
    validate_vector(v, "Vector")
    validate_number(x, "x")
    validate_number(y, "y")
    v.x, v.y = x, y
    return v
end

--- Add two vectors.
function vec2.add(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return vec2.new(a.x + b.x, a.y + b.y)
end

--- Subtract two vectors.
function vec2.sub(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return vec2.new(a.x - b.x, a.y - b.y)
end

--- Scale a vector by a scalar.
function vec2.scale(v, s)
    validate_vector(v, "Vector")
    validate_number(s, "Scalar")
    return vec2.new(v.x * s, v.y * s)
end

--- Calculate the dot product.
function vec2.dot(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return a.x * b.x + a.y * b.y
end

--- Calculate the 2D scalar cross product.
function vec2.cross(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    return a.x * b.y - a.y * b.x
end

--- Calculate vector length.
function vec2.length(v)
    validate_vector(v, "Vector")
    return math.sqrt(v.x * v.x + v.y * v.y)
end

--- Calculate squared vector length.
function vec2.length_squared(v)
    validate_vector(v, "Vector")
    return v.x * v.x + v.y * v.y
end

--- Normalize a vector. Returns zero for a near-zero vector.
function vec2.normalize(v)
    validate_vector(v, "Vector")
    local len = math.sqrt(v.x * v.x + v.y * v.y)
    if len <= EPSILON then return vec2.new() end
    return vec2.new(v.x / len, v.y / len)
end

--- Check whether a vector is effectively zero.
function vec2.is_zero(v)
    validate_vector(v, "Vector")
    return v.x * v.x + v.y * v.y < EPSILON * EPSILON
end

--- Calculate distance between two points.
function vec2.distance(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    local x, y = a.x - b.x, a.y - b.y
    return math.sqrt(x * x + y * y)
end

--- Calculate squared distance between two points.
function vec2.distance_squared(a, b)
    validate_vector(a, "First vector")
    validate_vector(b, "Second vector")
    local x, y = a.x - b.x, a.y - b.y
    return x * x + y * y
end

--- Linear interpolation. Values outside [0, 1] extrapolate.
function vec2.lerp(a, b, t)
    validate_vector(a, "Start vector")
    validate_vector(b, "End vector")
    validate_number(t, "Interpolation factor")
    return vec2.new(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
end

--- Rotate a vector by an angle in radians.
function vec2.rotate(v, angle)
    validate_vector(v, "Vector")
    validate_number(angle, "Angle")
    local c, s = math.cos(angle), math.sin(angle)
    return vec2.new(v.x * c - v.y * s, v.x * s + v.y * c)
end

--- Return a perpendicular vector rotated 90 degrees counterclockwise.
function vec2.perpendicular(v)
    validate_vector(v, "Vector")
    return vec2.new(-v.y, v.x)
end

--- Return the angle of the vector in radians.
--- Returns 0 for the zero vector.
function vec2.angle(v)
    validate_vector(v, "Vector")
    return math.atan2 and math.atan2(v.y, v.x) or math.atan(v.y, v.x)
end

--- Metamethod: Addition.
function vec2.__add(a, b)
    return vec2.add(a, b)
end

--- Metamethod: Subtraction.
function vec2.__sub(a, b)
    return vec2.sub(a, b)
end

--- Metamethod: Scalar multiplication.
function vec2.__mul(a, b)
    if type(a) == "number" then return vec2.scale(b, a) end
    return vec2.scale(a, b)
end

--- Metamethod: Division by scalar.
function vec2.__div(a, b)
    if type(b) ~= "number" then error("Can only divide a vector by a number") end
    validate_number(b, "Divisor")
    if b == 0 then error("Division by zero") end
    return vec2.scale(a, 1 / b)
end

--- Metamethod: String representation.
function vec2.__tostring(v)
    return string.format("vec2(%.3f, %.3f)", v.x, v.y)
end

--- Metamethod: Approximate equality.
function vec2.__eq(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    if type(a.x) ~= "number" or type(a.y) ~= "number" or type(b.x) ~= "number" or type(b.y) ~= "number" then return false end
    return math.abs(a.x - b.x) < EPSILON and math.abs(a.y - b.y) < EPSILON
end

--- Callable constructor: vec2(x, y).
return setmetatable(vec2, {
    __call = function(_, x, y)
        return vec2.new(x, y)
    end
})