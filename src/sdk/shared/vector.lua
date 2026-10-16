--- @module vector
--- @file src/engine/sdk/shared/vector
--- @description Strict, instance-oriented vector math for Vec2, Vec3, and Vec4.

--- @default_access mod

--- @section Constants

local EPSILON = 1e-10 -- Epsilon for floating-point comparisons

--- @section Initialisation

local m = {}

--- @section Helper Functions

local function finite_number(value, name, level)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge
    then
        error((name or "value") .. " must be a finite number", (level or 1) + 1)
    end
    return value
end

local function check_scalar(value, name, level)
    return finite_number(value, name or "scalar", (level or 1) + 1)
end

local function make_class(dim, type_name)
    local class = {}
    class.__index = class
    class._dimension = dim
    class._type_name = type_name

    local function assert_vector(value, name, level)
        if type(value) ~= "table" or getmetatable(value) ~= class then
            error((name or "value") .. " must be a " .. type_name, (level or 1) + 1)
        end

        finite_number(value.x, type_name .. ".x", (level or 1) + 1)
        finite_number(value.y, type_name .. ".y", (level or 1) + 1)
        if dim >= 3 then
            finite_number(value.z, type_name .. ".z", (level or 1) + 1)
        end
        if dim >= 4 then
            finite_number(value.w, type_name .. ".w", (level or 1) + 1)
        end
        return value
    end

    local function new(x, y, z, w)
        x = x == nil and 0 or finite_number(x, "x", 2)
        y = y == nil and 0 or finite_number(y, "y", 2)
        if dim >= 3 then z = z == nil and 0 or finite_number(z, "z", 2) end
        if dim >= 4 then w = w == nil and 0 or finite_number(w, "w", 2) end

        if dim == 2 then
            return setmetatable({ x = x, y = y }, class)
        elseif dim == 3 then
            return setmetatable({ x = x, y = y, z = z }, class)
        end
        return setmetatable({ x = x, y = y, z = z, w = w }, class)
    end

    class.new = new

    function class:clone()
        assert_vector(self, "self", 2)
        return new(self.x, self.y, self.z, self.w)
    end

    function class:set(x, y, z, w)
        assert_vector(self, "self", 2)
        x = finite_number(x, "x", 2)
        y = finite_number(y, "y", 2)
        if dim >= 3 then z = finite_number(z, "z", 2) end
        if dim >= 4 then w = finite_number(w, "w", 2) end

        self.x, self.y = x, y
        if dim >= 3 then self.z = z end
        if dim >= 4 then self.w = w end
        return self
    end

    function class:add(other)
        assert_vector(self, "self", 2)
        assert_vector(other, "other", 2)
        if dim == 2 then return new(self.x + other.x, self.y + other.y) end
        if dim == 3 then return new(self.x + other.x, self.y + other.y, self.z + other.z) end
        return new(self.x + other.x, self.y + other.y, self.z + other.z, self.w + other.w)
    end

    function class:sub(other)
        assert_vector(self, "self", 2)
        assert_vector(other, "other", 2)
        if dim == 2 then return new(self.x - other.x, self.y - other.y) end
        if dim == 3 then return new(self.x - other.x, self.y - other.y, self.z - other.z) end
        return new(self.x - other.x, self.y - other.y, self.z - other.z, self.w - other.w)
    end

    function class:scale(scalar)
        assert_vector(self, "self", 2)
        scalar = check_scalar(scalar, "scalar", 2)
        if dim == 2 then return new(self.x * scalar, self.y * scalar) end
        if dim == 3 then return new(self.x * scalar, self.y * scalar, self.z * scalar) end
        return new(self.x * scalar, self.y * scalar, self.z * scalar, self.w * scalar)
    end

    function class:dot(other)
        assert_vector(self, "self", 2)
        assert_vector(other, "other", 2)
        local result = self.x * other.x + self.y * other.y
        if dim >= 3 then result = result + self.z * other.z end
        if dim >= 4 then result = result + self.w * other.w end
        return result
    end

    function class:length_squared()
        assert_vector(self, "self", 2)
        return self:dot(self)
    end

    function class:length()
        return math.sqrt(self:length_squared())
    end

    function class:distance_squared(other)
        return self:sub(other):length_squared()
    end

    function class:distance(other)
        return math.sqrt(self:distance_squared(other))
    end

    function class:normalize()
        assert_vector(self, "self", 2)
        local length = self:length()
        if length <= EPSILON then return new() end
        return self:scale(1 / length)
    end

    function class:is_zero()
        assert_vector(self, "self", 2)
        return self:length_squared() <= EPSILON * EPSILON
    end

    function class:lerp(other, t)
        assert_vector(self, "self", 2)
        assert_vector(other, "other", 2)
        t = check_scalar(t, "t", 2)
        if dim == 2 then
            return new(self.x + (other.x - self.x) * t,
                       self.y + (other.y - self.y) * t)
        elseif dim == 3 then
            return new(self.x + (other.x - self.x) * t,
                       self.y + (other.y - self.y) * t,
                       self.z + (other.z - self.z) * t)
        end
        return new(self.x + (other.x - self.x) * t,
                   self.y + (other.y - self.y) * t,
                   self.z + (other.z - self.z) * t,
                   self.w + (other.w - self.w) * t)
    end

    if dim == 2 then
        function class:cross(other)
            assert_vector(self, "self", 2)
            assert_vector(other, "other", 2)
            return self.x * other.y - self.y * other.x
        end

        function class:angle()
            assert_vector(self, "self", 2)
            if math.atan2 then return math.atan2(self.y, self.x) end
            if self.x > 0 then return math.atan(self.y / self.x) end
            if self.x < 0 and self.y >= 0 then return math.atan(self.y / self.x) + math.pi end
            if self.x < 0 and self.y < 0 then return math.atan(self.y / self.x) - math.pi end
            if self.x == 0 and self.y > 0 then return math.pi / 2 end
            if self.x == 0 and self.y < 0 then return -math.pi / 2 end
            return 0
        end

        function class:rotate(angle)
            assert_vector(self, "self", 2)
            angle = check_scalar(angle, "angle", 2)
            local c, s = math.cos(angle), math.sin(angle)
            return new(self.x * c - self.y * s, self.x * s + self.y * c)
        end

        function class:perpendicular()
            assert_vector(self, "self", 2)
            return new(-self.y, self.x)
        end
    elseif dim == 3 then
        function class:cross(other)
            assert_vector(self, "self", 2)
            assert_vector(other, "other", 2)
            return new(
                self.y * other.z - self.z * other.y,
                self.z * other.x - self.x * other.z,
                self.x * other.y - self.y * other.x
            )
        end
    elseif dim == 4 then
        function class:xyz()
            assert_vector(self, "self", 2)
            return m.vec3(self.x, self.y, self.z)
        end
    end

    function class.__add(a, b) return a:add(b) end
    function class.__sub(a, b) return a:sub(b) end

    function class.__mul(a, b)
        if type(a) == "number" then
            if type(b) ~= "table" or getmetatable(b) ~= class then
                error("right operand must be a " .. type_name, 2)
            end
            return b:scale(a)
        end
        if type(b) ~= "number" then
            error("one operand of vector multiplication must be a scalar", 2)
        end
        return a:scale(b)
    end

    function class.__div(a, b)
        if type(b) ~= "number" then error("divisor must be a number", 2) end
        finite_number(b, "divisor", 2)
        if b == 0 then error("division by zero", 2) end
        return a:scale(1 / b)
    end

    function class.__unm(a)
        return a:scale(-1)
    end

    function class.__eq(a, b)
        if getmetatable(a) ~= class or getmetatable(b) ~= class then return false end
        return math.abs(a.x - b.x) <= EPSILON and math.abs(a.y - b.y) <= EPSILON and (dim < 3 or math.abs(a.z - b.z) <= EPSILON) and (dim < 4 or math.abs(a.w - b.w) <= EPSILON)
    end

    function class.__tostring(v)
        assert_vector(v, "value", 2)
        if dim == 2 then return string.format("vec2(%.3f, %.3f)", v.x, v.y) end
        if dim == 3 then return string.format("vec3(%.3f, %.3f, %.3f)", v.x, v.y, v.z) end
        return string.format("vec4(%.3f, %.3f, %.3f, %.3f)", v.x, v.y, v.z, v.w)
    end

    return setmetatable(class, {
        __call = function(_, ...) return new(...) end,
        __metatable = type_name .. " type"
    })
end

m.vec2 = make_class(2, "Vec2")
m.vector2 = m.vec2
m.vec3 = make_class(3, "Vec3")
m.vector3 = m.vec3
m.vec4 = make_class(4, "Vec4")
m.vector4 = m.vec4

return m