--- @module maths.mat4
--- @description Streamlined 4x4 matrix utilities for 3D transformations, built on top of the vector module.

local vector = require("src.engine.sdk.shared.vector")

--- @class mat4
--- @field m table The internal 16-element column-major array.
local mat4 = {}
mat4.__index = mat4

local EPSILON = 1e-10

--- Checks if a value is a valid finite number.
--- @param v any The value to check.
--- @return boolean True if valid and finite.
local function is_number(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

--- Validates that a table is a valid 3D vector.
--- @param v table The vector table to check.
--- @param name string|nil The name for error messaging.
local function validate_vec3(v, name)
    if type(v) ~= "table" or not is_number(v.x) or not is_number(v.y) or not is_number(v.z) then
        error((name or "vector") .. " must contain numeric x, y, z", 3)
    end
end

--- @section Initialisation & Factories

--- Creates a new 4x4 matrix (defaults to an identity matrix).
--- @param values table|nil Optional 16-element column-major array.
--- @return mat4 self The new matrix instance.
function mat4.new(values)
    local self = setmetatable({ m = {} }, mat4)
    if values then
        assert(type(values) == "table", "Matrix values must be a table", 2)
        for i = 1, 16 do
            assert(is_number(values[i]), "Matrix requires 16 finite numeric values", 2)
            self.m[i] = values[i]
        end
    else
        for i = 1, 16 do
            self.m[i] = (i == 1 or i == 6 or i == 11 or i == 16) and 1 or 0
        end
    end
    return self
end

--- Creates a translation matrix.
--- @param x number X offset translation.
--- @param y number Y offset translation.
--- @param z number Z offset translation.
--- @return mat4 The translation matrix.
function mat4.translate(x, y, z)
    return mat4.new({ 1,0,0,0, 0,1,0,0, 0,0,1,0, x,y,z, 1 })
end

--- Creates a scale matrix.
--- @param sx number X scale factor.
--- @param sy number Y scale factor.
--- @param sz number Z scale factor.
--- @return mat4 The scale matrix.
function mat4.scale(sx, sy, sz)
    return mat4.new({ sx,0,0,0, 0,sy,0,0, 0,0,sz,0, 0,0,0,1 })
end

--- Creates a rotation matrix from Euler angles (XYZ order).
--- @param rx number X rotation in degrees.
--- @param ry number Y rotation in degrees.
--- @param rz number Z rotation in degrees.
--- @return mat4 The combined rotation matrix.
function mat4.rotate_euler(rx, ry, rz)
    local x, y, z = math.rad(rx), math.rad(ry), math.rad(rz)
    local sx, cx = math.sin(x), math.cos(x)
    local sy, cy = math.sin(y), math.cos(y)
    local sz, cz = math.sin(z), math.cos(z)

    local rx_m = mat4.new({ 1,0,0,0, 0,cx,sx,0, 0,-sx,cx,0, 0,0,0,1 })
    local ry_m = mat4.new({ cy,0,-sy,0, 0,1,0,0, sy,0,cy,0, 0,0,0,1 })
    local rz_m = mat4.new({ cz,sz,0,0, -sz,cz,0,0, 0,0,1,0, 0,0,0,1 })
    return rz_m * ry_m * rx_m
end

--- Creates a rotation matrix around an arbitrary axis.
--- @param axis table Axis vector {x, y, z}.
--- @param angle number Rotation angle in degrees.
--- @return mat4 The axis rotation matrix.
function mat4.rotate_axis(axis, angle)
    validate_vec3(axis, "axis")
    axis = vector.vec3.new(axis.x, axis.y, axis.z)
    local len = vector.vec3.length(axis)
    assert(len > EPSILON, "Rotation axis must have non-zero length", 2)
    local n = vector.vec3.normalize(axis)
    local x, y, z = n.x, n.y, n.z
    local a = math.rad(angle)
    local s, c = math.sin(a), math.cos(a)
    local t = 1 - c

    return mat4.new({
        c + x*x*t,   y*x*t + z*s, x*z*t - y*s, 0,
        x*y*t - z*s, c + y*y*t,   z*y*t + x*s, 0,
        x*z*t + y*s, y*z*t - x*s, c + z*z*t,   0,
        0, 0, 0, 1
    })
end

--- Creates an OpenGL-style perspective projection matrix.
--- @param fov number Vertical field of view in degrees.
--- @param aspect number Width divided by height aspect ratio.
--- @param near number Positive near clipping distance.
--- @param far number Far clipping distance, greater than near.
--- @return mat4 The perspective projection matrix.
function mat4.perspective(fov, aspect, near, far)
    assert(is_number(fov) and fov > 0 and fov < 180, "FOV must be between 0 and 180", 2)
    assert(is_number(aspect) and aspect > 0, "Aspect must be positive", 2)
    assert(is_number(near) and is_number(far) and near > 0 and far > near, "Invalid near/far planes", 2)

    local f = 1 / math.tan(math.rad(fov) / 2)
    return mat4.new({
        f / aspect, 0, 0, 0,
        0, f, 0, 0,
        0, 0, (far + near) / (near - far), -1,
        0, 0, (2 * far * near) / (near - far), 0
    })
end

--- Creates an OpenGL-style orthographic projection matrix.
--- @param left number Left clipping plane.
--- @param right number Right clipping plane.
--- @param bottom number Bottom clipping plane.
--- @param top number Top clipping plane.
--- @param near number Near clipping plane.
--- @param far number Far clipping plane.
--- @return mat4 The orthographic projection matrix.
function mat4.orthographic(left, right, bottom, top, near, far)
    return mat4.new({
        2 / (right - left), 0, 0, 0,
        0, 2 / (top - bottom), 0, 0,
        0, 0, -2 / (far - near), 0,
        -(right + left) / (right - left),
        -(top + bottom) / (top - bottom),
        -(far + near) / (far - near),
        1
    })
end

--- Creates a right-handed look-at view matrix.
--- @param eye table Camera position vector {x, y, z}.
--- @param target table Look-at target position vector {x, y, z}.
--- @param up table Approximate up direction vector {x, y, z}.
--- @return mat4 The look-at view matrix.
function mat4.look_at(eye, target, up)
    validate_vec3(eye, "eye")
    validate_vec3(target, "target")
    validate_vec3(up, "up")

    eye = vector.vec3.new(eye.x, eye.y, eye.z)
    target = vector.vec3.new(target.x, target.y, target.z)
    up = vector.vec3.new(up.x, up.y, up.z)

    local ez = vector.vec3.sub(eye, target)
    local z = vector.vec3.normalize(ez)
    assert(not vector.vec3.is_zero(z), "Eye and target must be different", 2)

    local ex = vector.vec3.cross(up, z)
    local x = vector.vec3.normalize(ex)
    assert(not vector.vec3.is_zero(x), "Up vector parallel to view direction", 2)

    local y = vector.vec3.cross(z, x)

    return mat4.new({
        x.x, y.x, z.x, 0,
        x.y, y.y, z.y, 0,
        x.z, y.z, z.z, 0,
        -vector.vec3.dot(x, eye), -vector.vec3.dot(y, eye), -vector.vec3.dot(z, eye),
        1
    })
end

--- @section Methods

--- Multiplies this matrix by another matrix instance.
--- @param other mat4 The other matrix to multiply with.
--- @return mat4 result The resulting multiplied matrix product.
function mat4:multiply(other)
    assert(getmetatable(other) == mat4, "Expected a mat4 instance", 2)
    local a, b, r = self.m, other.m, {}
    for col = 0, 3 do
        for row = 0, 3 do
            local sum = 0
            for k = 0, 3 do
                sum = sum + a[k * 4 + row + 1] * b[col * 4 + k + 1]
            end
            r[col * 4 + row + 1] = sum
        end
    end
    return mat4.new(r)
end

--- Transforms a 3D position vector using homogeneous coordinates (w = 1).
--- @param v table Position vector {x, y, z}.
--- @return table|nil transformed_vec vec3 instance, or nil if at infinity.
function mat4:multiply_vec3(v)
    validate_vec3(v, "vector")
    local a, x, y, z = self.m, v.x, v.y, v.z
    local rx = a[1]*x + a[5]*y + a[9]*z + a[13]
    local ry = a[2]*x + a[6]*y + a[10]*z + a[14]
    local rz = a[3]*x + a[7]*y + a[11]*z + a[15]
    local rw = a[4]*x + a[8]*y + a[12]*z + a[16]

    if math.abs(rw) <= EPSILON then return nil end
    return vector.vec3.new(rx / rw, ry / rw, rz / rw)
end

--- Transposes the matrix rows and columns.
--- @return mat4 transposed_matrix The transposed matrix instance.
function mat4:transpose()
    local a, r = self.m, {}
    for row = 0, 3 do
        for col = 0, 3 do
            r[col * 4 + row + 1] = a[row * 4 + col + 1]
        end
    end
    return mat4.new(r)
end

--- Inverts the matrix using Gauss-Jordan elimination.
--- @return mat4|nil inverse_matrix The inverted matrix, or nil if singular.
function mat4:invert()
    local a = self.m
    local rows = {}
    for r = 1, 4 do
        rows[r] = {}
        for c = 1, 4 do
            rows[r][c] = a[(c - 1) * 4 + r]
            rows[r][c + 4] = (r == c) and 1 or 0
        end
    end

    for col = 1, 4 do
        local pivot, pivot_row = math.abs(rows[col][col]), col
        for row = col + 1, 4 do
            if math.abs(rows[row][col]) > pivot then
                pivot, pivot_row = math.abs(rows[row][col]), row
            end
        end
        if pivot <= EPSILON then return nil end
        rows[col], rows[pivot_row] = rows[pivot_row], rows[col]

        local p_val = rows[col][col]
        for j = 1, 8 do rows[col][j] = rows[col][j] / p_val end

        for row = 1, 4 do
            if row ~= col then
                local f = rows[row][col]
                for j = 1, 8 do rows[row][j] = rows[row][j] - f * rows[col][j] end
            end
        end
    end

    local result = {}
    for r = 1, 4 do
        for c = 1, 4 do
            result[(c - 1) * 4 + r] = rows[r][c + 4]
        end
    end
    return mat4.new(result)
end

--- Extracts translation components from the matrix.
--- @return table translation_vec vec3 instance of the translation.
function mat4:get_translation()
    return vector.vec3.new(self.m[13], self.m[14], self.m[15])
end

--- Extracts scale magnitudes from the transformation basis.
--- @return table scale_vec vec3 instance of the scale magnitudes.
function mat4:get_scale()
    local a = self.m
    return vector.vec3.new(
        math.sqrt(a[1]^2 + a[2]^2 + a[3]^2),
        math.sqrt(a[5]^2 + a[6]^2 + a[7]^2),
        math.sqrt(a[9]^2 + a[10]^2 + a[11]^2)
    )
end

--- Returns the underlying raw 16-element column-major array.
--- @return table raw_array The mutable 16-element array table.
function mat4:raw()
    return self.m
end

--- @section Metamethods

--- Metamethod supporting matrix multiplication using the * operator.
--- @param a mat4|any Left operand.
--- @param b mat4|any Right operand.
--- @return mat4 The resulting matrix product.
function mat4.__mul(a, b)
    assert(getmetatable(a) == mat4 and getmetatable(b) == mat4, "Multiplication requires two mat4 instances", 2)
    return a:multiply(b)
end

return mat4