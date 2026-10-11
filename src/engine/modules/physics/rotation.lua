--- @module physics.rotation
--- @file src/engine/modules/physics/rotation.lua
--- @description Quaternion and Euler conversion helpers. Pure Lua, no backend.

--- @section Imports

local _validate = require("src.engine.modules.physics.validate")

--- @section Module

local m = {}

--- Builds a quaternion from Euler angles (Y-up, applied yaw then pitch then roll)
--- @param pitch number Rotation around X in radians
--- @param yaw number Rotation around Y in radians
--- @param roll number Rotation around Z in radians
--- @return number x Quaternion X
--- @return number y Quaternion Y
--- @return number z Quaternion Z
--- @return number w Quaternion W
function m.from_euler(pitch, yaw, roll)
    _validate.check_number(pitch, "pitch")
    _validate.check_number(yaw, "yaw")
    _validate.check_number(roll, "roll")

    local cx, sx = math.cos(pitch * 0.5), math.sin(pitch * 0.5)
    local cy, sy = math.cos(yaw * 0.5), math.sin(yaw * 0.5)
    local cz, sz = math.cos(roll * 0.5), math.sin(roll * 0.5)

    return sx * cy * cz + cx * sy * sz,
        cx * sy * cz - sx * cy * sz,
        cx * cy * sz - sx * sy * cz,
        cx * cy * cz + sx * sy * sz
end

--- Converts a quaternion to Euler angles, the inverse of from_euler
--- @param x number Quaternion X
--- @param y number Quaternion Y
--- @param z number Quaternion Z
--- @param w number Quaternion W
--- @return number pitch Rotation around X in radians
--- @return number yaw Rotation around Y in radians
--- @return number roll Rotation around Z in radians
function m.to_euler(x, y, z, w)
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")
    _validate.check_number(w, "w")

    local sin_pitch = math.max(-1, math.min(1, -2 * (y * z - w * x)))

    return math.asin(sin_pitch),
        math.atan2(2 * (x * z + w * y), 1 - 2 * (x * x + y * y)),
        math.atan2(2 * (x * y + w * z), 1 - 2 * (x * x + z * z))
end

return m