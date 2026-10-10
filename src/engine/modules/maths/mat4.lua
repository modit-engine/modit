--- @module maths.mat4
--- @description 4x4 matrix utilities for 3D transformations.
---
--- Convention:
--- - Column-major storage.
--- - Column vectors.
--- - Translation at indices 13, 14, 15.
--- - OpenGL-style perspective projection (NDC depth -1 to 1).

local mat4 = {}
mat4.__index = mat4

local EPSILON = 1e-10

local function is_number(v)
    return type(v) == "number"
       and v == v
       and v ~= math.huge
       and v ~= -math.huge
end

local function vec3(x, y, z)
    return { x = x, y = y, z = z }
end

local function dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local function subtract(a, b)
    return vec3(a.x - b.x, a.y - b.y, a.z - b.z)
end

local function cross(a, b)
    return vec3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
end

local function length(v)
    return math.sqrt(dot(v, v))
end

local function normalize(v)
    local len = length(v)

    if len <= EPSILON then
        return nil
    end

    return vec3(v.x / len, v.y / len, v.z / len)
end

local function validate_vec3(v, name)
    if type(v) ~= "table"
        or not is_number(v.x)
        or not is_number(v.y)
        or not is_number(v.z) then
        error((name or "vector") .. " must contain numeric x, y, z", 3)
    end
end

--- Creates a new identity matrix.
--- @param values table|nil Optional 16-element column-major array.
--- @return mat4
function mat4.new(values)
    local self = setmetatable({}, mat4)

    self.m = {}

    if values ~= nil then
        if type(values) ~= "table" then
            error("Matrix values must be a table", 2)
        end

        for i = 1, 16 do
            if not is_number(values[i]) then
                error("Matrix requires 16 finite numeric values", 2)
            end

            self.m[i] = values[i]
        end
    else
        for i = 1, 16 do
            self.m[i] = (i == 1 or i == 6 or i == 11 or i == 16)
                and 1 or 0
        end
    end

    return self
end

--- Creates a translation matrix.
function mat4.translate(x, y, z)
    return mat4.new({
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        x, y, z, 1
    })
end

--- Creates a rotation matrix from Euler angles.
--- Rotations are applied X, then Y, then Z to column vectors.
--- @param rx number X rotation in degrees.
--- @param ry number Y rotation in degrees.
--- @param rz number Z rotation in degrees.
--- @return mat4
function mat4.rotate_euler(rx, ry, rz)
    local x = math.rad(rx)
    local y = math.rad(ry)
    local z = math.rad(rz)

    local sx, cx = math.sin(x), math.cos(x)
    local sy, cy = math.sin(y), math.cos(y)
    local sz, cz = math.sin(z), math.cos(z)

    local rx_mat = mat4.new({
        1, 0, 0, 0,
        0, cx, sx, 0,
        0, -sx, cx, 0,
        0, 0, 0, 1
    })

    local ry_mat = mat4.new({
        cy, 0, -sy, 0,
        0, 1, 0, 0,
        sy, 0, cy, 0,
        0, 0, 0, 1
    })

    local rz_mat = mat4.new({
        cz, sz, 0, 0,
        -sz, cz, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    })

    return rz_mat:multiply(ry_mat):multiply(rx_mat)
end

--- Creates a rotation matrix around an arbitrary axis.
--- The axis is normalized internally.
--- @param axis table Axis vector {x, y, z}.
--- @param angle number Rotation angle in degrees.
--- @return mat4
function mat4.rotate_axis(axis, angle)
    validate_vec3(axis, "axis")

    local n = normalize(axis)

    if not n then
        error("Rotation axis must have non-zero length", 2)
    end

    local x, y, z = n.x, n.y, n.z
    local a = math.rad(angle)
    local s, c = math.sin(a), math.cos(a)
    local t = 1 - c

    return mat4.new({
        c + x*x*t,     y*x*t + z*s, x*z*t - y*s, 0,
        x*y*t - z*s,   c + y*y*t,   z*y*t + x*s, 0,
        x*z*t + y*s,   y*z*t - x*s, c + z*z*t,   0,
        0, 0, 0, 1
    })
end

--- Creates a scale matrix.
function mat4.scale(sx, sy, sz)
    return mat4.new({
        sx, 0, 0, 0,
        0, sy, 0, 0,
        0, 0, sz, 0,
        0, 0, 0, 1
    })
end

--- Creates an OpenGL-style perspective projection matrix.
--- @param fov number Vertical field of view in degrees.
--- @param aspect number Width divided by height.
--- @param near number Positive near clipping distance.
--- @param far number Far clipping distance, greater than near.
--- @return mat4
function mat4.perspective(fov, aspect, near, far)
    if not is_number(fov) or fov <= 0 or fov >= 180 then
        error("FOV must be between 0 and 180 degrees", 2)
    end

    if not is_number(aspect) or aspect <= 0 then
        error("Aspect ratio must be positive", 2)
    end

    if not is_number(near) or not is_number(far)
        or near <= 0 or far <= near then
        error("Invalid near/far clipping planes", 2)
    end

    local f = 1 / math.tan(math.rad(fov) / 2)

    return mat4.new({
        f / aspect, 0, 0, 0,
        0, f, 0, 0,
        0, 0, (far + near) / (near - far), -1,
        0, 0, (2 * far * near) / (near - far), 0
    })
end

--- Creates an OpenGL-style orthographic projection matrix.
function mat4.orthographic(left, right, bottom, top, near, far)
    if not is_number(left) or not is_number(right)
        or not is_number(bottom) or not is_number(top)
        or not is_number(near) or not is_number(far) then
        error("Orthographic bounds must be finite numbers", 2)
    end

    if left == right or bottom == top or near == far then
        error("Orthographic bounds must not be equal", 2)
    end

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
--- @param eye table Camera position.
--- @param target table Look-at position.
--- @param up table Approximate up direction.
--- @return mat4
function mat4.look_at(eye, target, up)
    validate_vec3(eye, "eye")
    validate_vec3(target, "target")
    validate_vec3(up, "up")

    local z = normalize(subtract(eye, target))

    if not z then
        error("Eye and target must be different", 2)
    end

    local x = normalize(cross(up, z))

    if not x then
        error("Up vector must not be parallel to viewing direction", 2)
    end

    local y = cross(z, x)

    return mat4.new({
        x.x, y.x, z.x, 0,
        x.y, y.y, z.y, 0,
        x.z, y.z, z.z, 0,
        -dot(x, eye), -dot(y, eye), -dot(z, eye), 1
    })
end

--- Multiplies this matrix by another matrix.
--- Returns self * other; other is applied first to column vectors.
--- @param other mat4
--- @return mat4
function mat4:multiply(other)
    if getmetatable(other) ~= mat4 then
        error("Expected a mat4 instance", 2)
    end

    local a, b = self.m, other.m
    local r = {}

    for col = 0, 3 do
        for row = 0, 3 do
            local sum = 0

            for k = 0, 3 do
                sum = sum
                    + a[k * 4 + row + 1]
                    * b[col * 4 + k + 1]
            end

            r[col * 4 + row + 1] = sum
        end
    end

    return mat4.new(r)
end

--- Transforms a position using homogeneous coordinates (w = 1).
--- Performs perspective division when w is non-zero.
--- Returns nil if the result lies at infinity (w approximately zero).
--- @param v table Position {x, y, z}.
--- @return table|nil Transformed position.
function mat4:multiply_vec3(v)
    validate_vec3(v, "vector")

    local a = self.m
    local x, y, z = v.x, v.y, v.z

    local rx = a[1]*x + a[5]*y + a[9]*z + a[13]
    local ry = a[2]*x + a[6]*y + a[10]*z + a[14]
    local rz = a[3]*x + a[7]*y + a[11]*z + a[15]
    local rw = a[4]*x + a[8]*y + a[12]*z + a[16]

    if math.abs(rw) <= EPSILON then
        return nil
    end

    return {
        x = rx / rw,
        y = ry / rw,
        z = rz / rw
    }
end

--- Transposes the matrix.
--- @return mat4
function mat4:transpose()
    local a = self.m
    local r = {}

    for row = 0, 3 do
        for col = 0, 3 do
            r[col * 4 + row + 1] = a[row * 4 + col + 1]
        end
    end

    return mat4.new(r)
end

--- Inverts the matrix using Gauss-Jordan elimination.
--- @return mat4|nil Inverse, or nil if singular.
function mat4:invert()
    local a = self.m
    local rows = {}

    -- Convert column-major storage into augmented row arrays.
    for row = 1, 4 do
        rows[row] = {}

        for col = 1, 4 do
            rows[row][col] = a[(col - 1) * 4 + row]
            rows[row][col + 4] = (row == col) and 1 or 0
        end
    end

    for col = 1, 4 do
        local pivot_row = col
        local pivot_size = math.abs(rows[col][col])

        for row = col + 1, 4 do
            local size = math.abs(rows[row][col])

            if size > pivot_size then
                pivot_size = size
                pivot_row = row
            end
        end

        if pivot_size <= EPSILON then
            return nil
        end

        rows[col], rows[pivot_row] = rows[pivot_row], rows[col]

        local pivot = rows[col][col]

        for j = 1, 8 do
            rows[col][j] = rows[col][j] / pivot
        end

        for row = 1, 4 do
            if row ~= col then
                local factor = rows[row][col]

                for j = 1, 8 do
                    rows[row][j] =
                        rows[row][j] - factor * rows[col][j]
                end
            end
        end
    end

    local result = {}

    for row = 1, 4 do
        for col = 1, 4 do
            result[(col - 1) * 4 + row] = rows[row][col + 4]
        end
    end

    return mat4.new(result)
end

--- Extracts translation from the matrix.
--- @return table Position {x, y, z}.
function mat4:get_translation()
    return {
        x = self.m[13],
        y = self.m[14],
        z = self.m[15]
    }
end

--- Extracts the magnitudes of the three basis vectors.
--- Note: this does not recover signed scale or remove shear.
--- @return table Scale magnitudes {x, y, z}.
function mat4:get_scale()
    local a = self.m

    return {
        x = math.sqrt(a[1]^2 + a[2]^2 + a[3]^2),
        y = math.sqrt(a[5]^2 + a[6]^2 + a[7]^2),
        z = math.sqrt(a[9]^2 + a[10]^2 + a[11]^2)
    }
end

--- Returns the underlying 16-element matrix table.
--- The returned table is mutable.
--- @return table
function mat4:raw()
    return self.m
end

--- Supports matrix multiplication using the * operator.
function mat4.__mul(a, b)
    if type(a) == "number" or type(b) == "number" then
        error("Scalar-matrix multiplication is not supported", 2)
    end

    if getmetatable(a) ~= mat4 then
        error("Left operand must be a mat4 instance", 2)
    end

    return a:multiply(b)
end

return mat4