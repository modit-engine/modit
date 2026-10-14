--- @module physics3d.body
--- @file src/engine/sdk/shared/physics3d/body.lua
--- @description Rigid body creation, transforms, velocities, forces and flags.

--- @section Imports

local _box3d = require("src.engine.backend.box3d")
local _state = require("src.engine.sdk.shared.physics3d.state")
local _validate = require("src.engine.sdk.shared.physics3d.validate")

--- @section Constants

local BODY_TYPES = { static = true, kinematic = true, dynamic = true }

--- @section Module

local m = {}

--- @section Lifecycle

--- Creates a body
--- @param opts table|nil Fields: type ("static"|"kinematic"|"dynamic"), position {x,y,z}, rotation {x,y,z,w}, linear_damping, angular_damping, gravity_scale, bullet, fixed_rotation
--- @return number handle Body handle
function m.create_body(opts)
    _state.check_world()
    opts = opts or {}
    if type(opts) ~= "table" then error("physics3d.create_body expects a table", 2) end

    local body_type = opts.type or "static"
    if not BODY_TYPES[body_type] then error("invalid body type: " .. tostring(body_type), 2) end

    local x, y, z = _validate.read_vec(opts.position, "position")
    local def = { type = body_type, x = x, y = y, z = z }

    if opts.rotation ~= nil then
        local q = opts.rotation
        if type(q) ~= "table" then error("rotation must be a table with x, y, z, w", 2) end
        local qx, qy, qz, qw = q.x or 0, q.y or 0, q.z or 0, q.w or 1
        _validate.check_number(qx, "rotation.x")
        _validate.check_number(qy, "rotation.y")
        _validate.check_number(qz, "rotation.z")
        _validate.check_number(qw, "rotation.w")

        local length = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
        if length < 1e-6 then error("rotation must not be zero", 2) end
        def.qx, def.qy, def.qz, def.qw = qx / length, qy / length, qz / length, qw / length
    end

    for _, key in ipairs({ "linear_damping", "angular_damping", "gravity_scale" }) do
        if opts[key] ~= nil then
            _validate.check_number(opts[key], key)
            def[key] = opts[key]
        end
    end

    def.bullet = opts.bullet and true or nil
    def.fixed_rotation = opts.fixed_rotation and true or nil

    local handle = _state.new_handle()
    def.user_id = handle
    _state.bodies[handle] = { id = _box3d.body.create(_state.world, def), shapes = {} }
    return handle
end

--- Destroys a body and all of its shapes
--- @param body number Body handle
--- @return number count Shapes destroyed with the body
function m.destroy_body(body)
    local record = _state.get_body(body)
    local count = 0

    for shape_handle in pairs(record.shapes) do
        _state.shapes[shape_handle] = nil
        count = count + 1
    end

    _box3d.body.destroy(record.id)
    _state.bodies[body] = nil
    return count
end

--- Checks whether a body handle is still valid
--- @param body number Body handle
--- @return boolean valid True if it exists
function m.is_body_valid(body)
    return _state.bodies[body] ~= nil
end

--- @section Transform

--- Returns the body position
--- @param body number Body handle
--- @return number x World X
--- @return number y World Y
--- @return number z World Z
function m.get_body_position(body)
    return _box3d.body.get_position(_state.get_body(body).id)
end

--- Returns the body rotation as a quaternion
--- @param body number Body handle
--- @return number x Quaternion X
--- @return number y Quaternion Y
--- @return number z Quaternion Z
--- @return number w Quaternion W
function m.get_body_rotation(body)
    return _box3d.body.get_rotation(_state.get_body(body).id)
end

--- Returns position and rotation in one call
--- @param body number Body handle
--- @return number x World X
--- @return number y World Y
--- @return number z World Z
--- @return number qx Quaternion X
--- @return number qy Quaternion Y
--- @return number qz Quaternion Z
--- @return number qw Quaternion W
function m.get_body_transform(body)
    return _box3d.body.get_transform(_state.get_body(body).id)
end

--- Teleports a body
--- @param body number Body handle
--- @param x number World X
--- @param y number World Y
--- @param z number World Z
--- @param qx number|nil Quaternion X, keeps the current rotation when omitted
--- @param qy number|nil Quaternion Y
--- @param qz number|nil Quaternion Z
--- @param qw number|nil Quaternion W
function m.set_body_transform(body, x, y, z, qx, qy, qz, qw)
    local record = _state.get_body(body)
    _validate.check_coord(x, "x")
    _validate.check_coord(y, "y")
    _validate.check_coord(z, "z")

    if qx == nil then
        qx, qy, qz, qw = _box3d.body.get_rotation(record.id)
    else
        _validate.check_number(qx, "qx")
        _validate.check_number(qy, "qy")
        _validate.check_number(qz, "qz")
        _validate.check_number(qw, "qw")
        local length = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
        if length < 1e-6 then error("rotation must not be zero", 2) end
        qx, qy, qz, qw = qx / length, qy / length, qz / length, qw / length
    end

    _box3d.body.set_transform(record.id, x, y, z, qx, qy, qz, qw)
end

--- Converts a local point to world space
--- @param body number Body handle
--- @param x number Local X
--- @param y number Local Y
--- @param z number Local Z
--- @return number x World X
--- @return number y World Y
--- @return number z World Z
function m.get_body_world_point(body, x, y, z)
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")
    return _box3d.body.get_world_point(_state.get_body(body).id, x, y, z)
end

--- Converts a world point to local space
--- @param body number Body handle
--- @param x number World X
--- @param y number World Y
--- @param z number World Z
--- @return number x Local X
--- @return number y Local Y
--- @return number z Local Z
function m.get_body_local_point(body, x, y, z)
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")
    return _box3d.body.get_local_point(_state.get_body(body).id, x, y, z)
end

--- Rotates a local direction into world space
--- @param body number Body handle
--- @param x number Local X
--- @param y number Local Y
--- @param z number Local Z
--- @return number x World X
--- @return number y World Y
--- @return number z World Z
function m.get_body_world_vector(body, x, y, z)
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")
    return _box3d.body.get_world_vector(_state.get_body(body).id, x, y, z)
end

--- @section Velocity

--- Returns linear velocity
--- @param body number Body handle
--- @return number x Velocity X
--- @return number y Velocity Y
--- @return number z Velocity Z
function m.get_body_linear_velocity(body)
    return _box3d.body.get_linear_velocity(_state.get_body(body).id)
end

--- Sets linear velocity
--- @param body number Body handle
--- @param x number Velocity X
--- @param y number Velocity Y
--- @param z number Velocity Z
function m.set_body_linear_velocity(body, x, y, z)
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")
    _box3d.body.set_linear_velocity(_state.get_body(body).id, x, y, z)
end

--- Returns angular velocity in radians per second
--- @param body number Body handle
--- @return number x Angular velocity X
--- @return number y Angular velocity Y
--- @return number z Angular velocity Z
function m.get_body_angular_velocity(body)
    return _box3d.body.get_angular_velocity(_state.get_body(body).id)
end

--- Sets angular velocity in radians per second
--- @param body number Body handle
--- @param x number Angular velocity X
--- @param y number Angular velocity Y
--- @param z number Angular velocity Z
function m.set_body_angular_velocity(body, x, y, z)
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")
    _box3d.body.set_angular_velocity(_state.get_body(body).id, x, y, z)
end

--- @section Forces

--- Applies a force for the next step. With a point it is applied at that world position
--- @param body number Body handle
--- @param x number Force X
--- @param y number Force Y
--- @param z number Force Z
--- @param px number|nil Point X
--- @param py number|nil Point Y
--- @param pz number|nil Point Z
function m.apply_body_force(body, x, y, z, px, py, pz)
    local record = _state.get_body(body)
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")

    if px == nil then
        _box3d.body.apply_force(record.id, x, y, z)
        return
    end

    _validate.check_number(px, "px")
    _validate.check_number(py, "py")
    _validate.check_number(pz, "pz")
    _box3d.body.apply_force_at(record.id, x, y, z, px, py, pz)
end

--- Applies an instant impulse. With a point it is applied at that world position
--- @param body number Body handle
--- @param x number Impulse X
--- @param y number Impulse Y
--- @param z number Impulse Z
--- @param px number|nil Point X
--- @param py number|nil Point Y
--- @param pz number|nil Point Z
function m.apply_body_impulse(body, x, y, z, px, py, pz)
    local record = _state.get_body(body)
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")

    if px == nil then
        _box3d.body.apply_impulse(record.id, x, y, z)
        return
    end

    _validate.check_number(px, "px")
    _validate.check_number(py, "py")
    _validate.check_number(pz, "pz")
    _box3d.body.apply_impulse_at(record.id, x, y, z, px, py, pz)
end

--- Applies a torque for the next step
--- @param body number Body handle
--- @param x number Torque X
--- @param y number Torque Y
--- @param z number Torque Z
function m.apply_body_torque(body, x, y, z)
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")
    _box3d.body.apply_torque(_state.get_body(body).id, x, y, z)
end

--- Applies an instant angular impulse
--- @param body number Body handle
--- @param x number Impulse X
--- @param y number Impulse Y
--- @param z number Impulse Z
function m.apply_body_angular_impulse(body, x, y, z)
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")
    _box3d.body.apply_angular_impulse(_state.get_body(body).id, x, y, z)
end

--- @section Properties

--- Returns the body mass
--- @param body number Body handle
--- @return number mass Mass in kg
function m.get_body_mass(body)
    return _box3d.body.get_mass(_state.get_body(body).id)
end

--- Sets the gravity scale
--- @param body number Body handle
--- @param scale number Gravity multiplier
function m.set_body_gravity_scale(body, scale)
    _validate.check_number(scale, "scale")
    _box3d.body.set_gravity_scale(_state.get_body(body).id, scale)
end

--- Sets linear and angular damping
--- @param body number Body handle
--- @param linear number Linear damping
--- @param angular number Angular damping
function m.set_body_damping(body, linear, angular)
    _validate.check_number(linear, "linear")
    _validate.check_number(angular, "angular")
    _box3d.body.set_damping(_state.get_body(body).id, linear, angular)
end

--- Checks whether a body is awake
--- @param body number Body handle
--- @return boolean awake True if awake
function m.is_body_awake(body)
    return _box3d.body.is_awake(_state.get_body(body).id)
end

--- Wakes or sleeps a body
--- @param body number Body handle
--- @param awake boolean Target state
function m.set_body_awake(body, awake)
    _box3d.body.set_awake(_state.get_body(body).id, awake and true or false)
end

--- Enables or disables a body in the simulation
--- @param body number Body handle
--- @param enabled boolean Target state
function m.set_body_enabled(body, enabled)
    _box3d.body.set_enabled(_state.get_body(body).id, enabled and true or false)
end

return m