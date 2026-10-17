--- @module physics
--- @file src/sdk/shared/physics.lua
--- @description Rigid body physics in one flat API: world, bodies, shapes, queries and rotation helpers.

--- @default_access game

--- @section Imports

local _backend = require("src.engine.backend")
local _physics3d = _backend.physics3d
local _box3d = require("src.engine.backend.box3d")

--- @section Constants

local BODY_TYPES = { static = true, kinematic = true, dynamic = true }

--- @section Initialisation

local m = {}

--- @section Internal State

local DEFAULT_GRAVITY = { x = 0, y = -9.81, z = 0 }
local DEFAULT_FIXED_DT = 1 / 60
local DEFAULT_SUBSTEPS = 4
local DEFAULT_MAX_STEPS = 5

local _state = {}

_state.DEFAULT_GRAVITY = DEFAULT_GRAVITY
_state.DEFAULT_FIXED_DT = DEFAULT_FIXED_DT
_state.DEFAULT_SUBSTEPS = DEFAULT_SUBSTEPS
_state.DEFAULT_MAX_STEPS = DEFAULT_MAX_STEPS

_state.world = nil
_state.dimensions = 3
_state.fixed_dt = DEFAULT_FIXED_DT
_state.substeps = DEFAULT_SUBSTEPS
_state.max_steps = DEFAULT_MAX_STEPS
_state.accumulator = 0
_state.next_handle = 0
_state.bodies = {}
_state.shapes = {}
_state.joints = {}  
_state.events = {}

-- helpers

--- Empties the event lists
function _state.clear_events()
    _state.events = { touch_begin = {}, touch_end = {}, hit = {}, sensor_begin = {}, sensor_end = {} }
end

_state.clear_events()

--- Allocates a new handle
--- @return number handle Unique handle, never reused
function _state.new_handle()
    _state.next_handle = _state.next_handle + 1
    return _state.next_handle
end

--- Errors unless the physics world exists
function _state.check_world()
    if not _state.world then error("physics is not initialised, call physics.init_world first", 3) end
end

--- Returns the record of a body handle or errors
--- @param handle any Body handle
--- @return table record Body record
function _state.get_body(handle)
    local record = _state.bodies[handle]
    if not record then error("invalid physics body handle: " .. tostring(handle), 3) end
    return record
end

--- Returns the record of a shape handle or errors
--- @param handle any Shape handle
--- @return table record Shape record
function _state.get_shape(handle)
    local record = _state.shapes[handle]
    if not record then error("invalid physics shape handle: " .. tostring(handle), 3) end
    return record
end

--- Registers a shape on a body
--- @param body_handle number Owning body handle
--- @param shape_id cdata Backend shape id
--- @param handle number Shape handle
--- @return number handle Shape handle
function _state.register_shape(body_handle, shape_id, handle)
    _state.shapes[handle] = { id = shape_id, body = body_handle }
    _state.bodies[body_handle].shapes[handle] = true
    return handle
end

--- Clears the world reference, handles and events
function _state.reset()
    _state.world = nil
    _state.accumulator = 0
    _state.bodies = {}
    _state.shapes = {}
    _state.joints = {} 
    _state.clear_events()
end

--- @section Validation

local MAX_COORD = 1e5

local _validate = {}

--- Errors unless the value is a finite number
--- @param value any Value to check
--- @param name string Argument name for the message
function _validate.check_number(value, name)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        error(name .. " must be a finite number", 3)
    end
end

--- Errors unless the value is a finite number inside the supported world range
--- @param value any Value to check
--- @param name string Argument name for the message
function _validate.check_coord(value, name)
    _validate.check_number(value, name)
    if value > MAX_COORD or value < -MAX_COORD then
        error(name .. " is outside the supported range of +-" .. MAX_COORD, 3)
    end
end

--- Reads x, y, z from an optional table, defaulting to zero
--- @param source table|nil Table with x, y, z
--- @param name string Argument name for the message
--- @return number x
--- @return number y
--- @return number z
function _validate.read_vec(source, name)
    if source == nil then return 0, 0, 0 end
    if type(source) ~= "table" then error(name .. " must be a table with x, y, z", 3) end

    local x, y, z = source.x or 0, source.y or 0, source.z or 0
    _validate.check_coord(x, name .. ".x")
    _validate.check_coord(y, name .. ".y")
    _validate.check_coord(z, name .. ".z")
    return x, y, z
end

--- Validates shape options and returns a backend-safe copy
--- @param opts table|nil Shape options
--- @return table safe Validated options
function _validate.read_shape_opts(opts)
    local safe = {}
    if opts == nil then return safe end
    if type(opts) ~= "table" then error("shape options must be a table", 3) end

    for _, key in ipairs({ "density", "friction", "restitution", "category", "mask", "ox", "oy", "oz" }) do
        if opts[key] ~= nil then
            _validate.check_number(opts[key], key)
            safe[key] = opts[key]
        end
    end

    if safe.density ~= nil and safe.density <= 0 then error("density must be above 0", 3) end

    safe.sensor = opts.sensor and true or nil
    safe.events = opts.events and true or nil
    return safe
end

--- @section World Lifecycle

--- Creates the physics world, replacing any existing one
--- @param opts table|nil Fields: dimensions (3, 2 is not available yet), gravity {x,y,z}, fixed_dt, substeps, max_steps
function m.init_world(opts)
    opts = opts or {}
    if type(opts) ~= "table" then error("physics.init_world expects a table", 2) end

    local dimensions = opts.dimensions or 3
    if dimensions ~= 3 then error("physics.init_world: only dimensions = 3 is available", 2) end

    local defaults = _state.DEFAULT_GRAVITY
    local gx, gy, gz = defaults.x, defaults.y, defaults.z
    if opts.gravity ~= nil then
        if type(opts.gravity) ~= "table" then error("gravity must be a table with x, y, z", 2) end
        gx, gy, gz = opts.gravity.x or 0, opts.gravity.y or 0, opts.gravity.z or 0
        _validate.check_number(gx, "gravity.x")
        _validate.check_number(gy, "gravity.y")
        _validate.check_number(gz, "gravity.z")
    end

    local step_length = opts.fixed_dt or _state.DEFAULT_FIXED_DT
    local step_substeps = opts.substeps or _state.DEFAULT_SUBSTEPS
    local step_max = opts.max_steps or _state.DEFAULT_MAX_STEPS
    _validate.check_number(step_length, "fixed_dt")
    _validate.check_number(step_substeps, "substeps")
    _validate.check_number(step_max, "max_steps")
    if step_length <= 0 then error("fixed_dt must be above 0", 2) end
    if step_substeps < 1 or step_max < 1 then error("substeps and max_steps must be at least 1", 2) end

    m.shutdown_world()

    local created = _physics3d.world.create(gx, gy, gz)
    if not created then error("physics: could not create world", 2) end

    _state.world = created
    _state.dimensions = dimensions
    _state.fixed_dt = step_length
    _state.substeps = math.floor(step_substeps)
    _state.max_steps = math.floor(step_max)
    _state.accumulator = 0
end

--- Destroys the world and invalidates every body and shape handle
function m.shutdown_world()
    if _state.world then _physics3d.world.destroy(_state.world) end
    _state.reset()
end

--- Checks whether the physics world exists
--- @return boolean active True if init has been called
function m.is_world_active()
    return _state.world ~= nil
end

--- @section World Simulation

--- Advances the simulation in fixed steps and collects events
--- @param dt number Frame time in seconds
--- @return number steps Fixed steps taken this call
function m.update_world(dt)
    _state.check_world()
    _validate.check_number(dt, "dt")
    if dt < 0 then error("dt must not be negative", 2) end

    _state.clear_events()
    _state.accumulator = _state.accumulator + dt

    local steps = 0
    while _state.accumulator >= _state.fixed_dt and steps < _state.max_steps do
        _physics3d.world.step(_state.world, _state.fixed_dt, _state.substeps)
        _physics3d.events.collect(_state.world, _state.events)
        _state.accumulator = _state.accumulator - _state.fixed_dt
        steps = steps + 1
    end

    -- drop time we could not simulate instead of spiralling
    if steps == _state.max_steps and _state.accumulator >= _state.fixed_dt then _state.accumulator = 0 end

    return steps
end

--- Returns the events collected by the last update. Handles may refer to bodies destroyed since, check body.is_valid
--- @return table events Lists touch_begin, touch_end, hit, sensor_begin, sensor_end
function m.get_world_events()
    return _state.events
end

--- @section World Gravity

--- Sets world gravity
--- @param x number Gravity X
--- @param y number Gravity Y
--- @param z number Gravity Z
function m.set_world_gravity(x, y, z)
    _state.check_world()
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")
    _physics3d.world.set_gravity(_state.world, x, y, z)
end

--- Returns world gravity
--- @return number x Gravity X
--- @return number y Gravity Y
--- @return number z Gravity Z
function m.get_world_gravity()
    _state.check_world()
    return _physics3d.world.get_gravity(_state.world)
end

--- @section Body Lifecycle

--- Creates a body
--- @param opts table|nil Fields: type ("static"|"kinematic"|"dynamic"), position {x,y,z}, rotation {x,y,z,w}, linear_damping, angular_damping, gravity_scale, bullet, fixed_rotation
--- @return number handle Body handle
function m.create_body(opts)
    _state.check_world()
    opts = opts or {}
    if type(opts) ~= "table" then error("physics.create_body expects a table", 2) end

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
    for joint_handle, joint in pairs(_state.joints) do
        if joint.a == body or joint.b == body then _state.joints[joint_handle] = nil end
    end
    _state.bodies[body] = nil
    return count
end

--- Checks whether a body handle is still valid
--- @param body number Body handle
--- @return boolean valid True if it exists
function m.is_body_valid(body)
    return _state.bodies[body] ~= nil
end

--- @section Body Transform

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

--- @section Body Velocity

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

--- @section Body Forces

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

--- @section Body Properties

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

--- @section Joints

--- Validates an optional joint frame quaternion and returns a normalised copy
--- @param q table|nil Quaternion {x,y,z,w}
--- @param name string Argument name for the message
--- @return table|nil frame Normalised quaternion, nil when omitted
local function read_frame(q, name)
    if q == nil then return nil end
    if type(q) ~= "table" then error(name .. " must be a table with x, y, z, w", 4) end

    local x, y, z, w = q.x or 0, q.y or 0, q.z or 0, q.w or 1
    _validate.check_number(x, name .. ".x")
    _validate.check_number(y, name .. ".y")
    _validate.check_number(z, name .. ".z")
    _validate.check_number(w, name .. ".w")

    local length = math.sqrt(x * x + y * y + z * z + w * w)
    if length < 1e-6 then error(name .. " must not be zero", 4) end
    return { x = x / length, y = y / length, z = z / length, w = w / length }
end

--- Validates the options shared by every joint type
--- @param opts table|nil Joint options
--- @return table safe Backend-safe options
local function read_joint_opts(opts)
    opts = opts or {}
    if type(opts) ~= "table" then error("joint options must be a table", 3) end

    local ax, ay, az = _validate.read_vec(opts.anchor_a, "anchor_a")
    local bx, by, bz = _validate.read_vec(opts.anchor_b, "anchor_b")

    local safe = {
        ax = ax, ay = ay, az = az,
        bx = bx, by = by, bz = bz,
        frame_a = read_frame(opts.frame_a, "frame_a"),
        frame_b = read_frame(opts.frame_b, "frame_b"),
        collide_connected = opts.collide_connected and true or nil,
    }

    for _, key in ipairs({ "spring_hertz", "spring_damping" }) do
        if opts[key] ~= nil then
            _validate.check_number(opts[key], key)
            safe[key] = opts[key]
        end
    end

    return safe
end

--- Registers a joint between two bodies
--- @param joint_id cdata Backend joint id
--- @param body_a number First body handle
--- @param body_b number Second body handle
--- @param handle number Joint handle
--- @return number handle Joint handle
local function register_joint(joint_id, body_a, body_b, handle)
    _state.joints[handle] = { id = joint_id, a = body_a, b = body_b }
    return handle
end

--- Creates a ball and socket joint. Bodies it connects do not collide with each other unless collide_connected is set
--- @param body_a number First body handle
--- @param body_b number Second body handle
--- @param opts table|nil Fields: anchor_a {x,y,z} and anchor_b {x,y,z} in each body's local space, frame_a and frame_b {x,y,z,w} local frame rotations, cone_angle, twist_lower, twist_upper (radians), spring_hertz, spring_damping, collide_connected
--- @return number handle Joint handle
function m.create_spherical_joint(body_a, body_b, opts)
    _state.check_world()
    if body_a == body_b then error("a joint needs two different bodies", 2) end

    local record_a, record_b = _state.get_body(body_a), _state.get_body(body_b)
    local safe = read_joint_opts(opts)

    for _, key in ipairs({ "cone_angle", "twist_lower", "twist_upper" }) do
        if opts and opts[key] ~= nil then
            _validate.check_number(opts[key], key)
            safe[key] = opts[key]
        end
    end

    if (safe.twist_lower == nil) ~= (safe.twist_upper == nil) then
        error("twist_lower and twist_upper must be given together", 2)
    end

    local handle = _state.new_handle()
    safe.user_id = handle
    return register_joint(_box3d.joint.create_spherical(_state.world, record_a.id, record_b.id, safe), body_a, body_b, handle)
end

--- Creates a hinge joint. Bodies it connects do not collide with each other unless collide_connected is set
--- @param body_a number First body handle
--- @param body_b number Second body handle
--- @param opts table|nil Fields: anchor_a, anchor_b, frame_a, frame_b, lower, upper (radians), spring_hertz, spring_damping, collide_connected
--- @return number handle Joint handle
function m.create_revolute_joint(body_a, body_b, opts)
    _state.check_world()
    if body_a == body_b then error("a joint needs two different bodies", 2) end

    local record_a, record_b = _state.get_body(body_a), _state.get_body(body_b)
    local safe = read_joint_opts(opts)

    for _, key in ipairs({ "lower", "upper" }) do
        if opts and opts[key] ~= nil then
            _validate.check_number(opts[key], key)
            safe[key] = opts[key]
        end
    end

    if (safe.lower == nil) ~= (safe.upper == nil) then error("lower and upper must be given together", 2) end

    local handle = _state.new_handle()
    safe.user_id = handle
    return register_joint(_box3d.joint.create_revolute(_state.world, record_a.id, record_b.id, safe), body_a, body_b, handle)
end

--- Destroys a joint
--- @param joint number Joint handle
function m.destroy_joint(joint)
    local record = _state.joints[joint]
    if not record then error("invalid physics joint handle: " .. tostring(joint), 2) end

    _box3d.joint.destroy(record.id)
    _state.joints[joint] = nil
end

--- Checks whether a joint handle is still valid
--- @param joint number Joint handle
--- @return boolean valid True if it exists
function m.is_joint_valid(joint)
    local record = _state.joints[joint]
    return record ~= nil and _box3d.joint.is_valid(record.id)
end

--- @section Shape Creation

--- Attaches a box shape
--- @param body number Body handle
--- @param half_x number Half extent X
--- @param half_y number Half extent Y
--- @param half_z number Half extent Z
--- @param opts table|nil Fields: density, friction, restitution, sensor, events, category, mask, ox, oy, oz
--- @return number handle Shape handle
function m.add_box_shape(body, half_x, half_y, half_z, opts)
    local record = _state.get_body(body)
    _validate.check_number(half_x, "half_x")
    _validate.check_number(half_y, "half_y")
    _validate.check_number(half_z, "half_z")
    if half_x <= 0 or half_y <= 0 or half_z <= 0 then error("box extents must be above 0", 2) end

    local safe = _validate.read_shape_opts(opts)
    local handle = _state.new_handle()
    safe.user_id = handle
    return _state.register_shape(body, _box3d.shape.create_box(record.id, half_x, half_y, half_z, safe), handle)
end

--- Attaches a sphere shape
--- @param body number Body handle
--- @param radius number Sphere radius
--- @param opts table|nil Same fields as add_box_shape
--- @return number handle Shape handle
function m.add_sphere_shape(body, radius, opts)
    local record = _state.get_body(body)
    _validate.check_number(radius, "radius")
    if radius <= 0 then error("radius must be above 0", 2) end

    local safe = _validate.read_shape_opts(opts)
    local handle = _state.new_handle()
    safe.user_id = handle
    return _state.register_shape(body, _box3d.shape.create_sphere(record.id, radius, safe), handle)
end

--- Attaches a capsule shape standing along the Y axis
--- @param body number Body handle
--- @param radius number Capsule radius
--- @param half_height number Half length of the center segment
--- @param opts table|nil Same fields as add_box_shape
--- @return number handle Shape handle
function m.add_capsule_shape(body, radius, half_height, opts)
    local record = _state.get_body(body)
    _validate.check_number(radius, "radius")
    _validate.check_number(half_height, "half_height")
    if radius <= 0 or half_height <= 0 then error("capsule radius and half_height must be above 0", 2) end

    local safe = _validate.read_shape_opts(opts)
    local handle = _state.new_handle()
    safe.user_id = handle
    return _state.register_shape(body, _box3d.shape.create_capsule(record.id, radius, half_height, safe), handle)
end

--- @section Shape Management

--- Destroys a shape
--- @param shape number Shape handle
function m.destroy_shape(shape)
    local record = _state.get_shape(shape)

    _box3d.shape.destroy(record.id)
    if _state.bodies[record.body] then _state.bodies[record.body].shapes[shape] = nil end
    _state.shapes[shape] = nil
end

--- Returns the body a shape is attached to
--- @param shape number Shape handle
--- @return number body Body handle
function m.get_shape_body(shape)
    return _state.get_shape(shape).body
end

--- @section Shape Properties

--- Sets surface friction
--- @param shape number Shape handle
--- @param friction number Friction coefficient
function m.set_shape_friction(shape, friction)
    _validate.check_number(friction, "friction")
    _box3d.shape.set_friction(_state.get_shape(shape).id, friction)
end

--- Sets surface restitution
--- @param shape number Shape handle
--- @param restitution number Bounciness
function m.set_shape_restitution(shape, restitution)
    _validate.check_number(restitution, "restitution")
    _box3d.shape.set_restitution(_state.get_shape(shape).id, restitution)
end

--- Sets collision category and mask bits
--- @param shape number Shape handle
--- @param category number Category bits
--- @param mask number Mask bits
function m.set_shape_filter(shape, category, mask)
    _validate.check_number(category, "category")
    _validate.check_number(mask, "mask")
    _box3d.shape.set_filter(_state.get_shape(shape).id, category, mask)
end

--- @section Queries

--- Casts a ray and returns the closest hit
--- @param ox number Origin X
--- @param oy number Origin Y
--- @param oz number Origin Z
--- @param dx number Direction X, does not need to be normalised
--- @param dy number Direction Y
--- @param dz number Direction Z
--- @param max_distance number Maximum ray length
--- @param opts table|nil Fields: category, mask
--- @return table|nil hit Fields: body, shape, x, y, z, nx, ny, nz, distance, fraction. Nil on a miss
function m.raycast(ox, oy, oz, dx, dy, dz, max_distance, opts)
    _state.check_world()
    _validate.check_coord(ox, "ox")
    _validate.check_coord(oy, "oy")
    _validate.check_coord(oz, "oz")
    _validate.check_number(dx, "dx")
    _validate.check_number(dy, "dy")
    _validate.check_number(dz, "dz")
    _validate.check_number(max_distance, "max_distance")
    if max_distance <= 0 then error("max_distance must be above 0", 2) end

    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 1e-9 then error("direction must not be zero", 2) end

    local scale = max_distance / length
    local category, mask = opts and opts.category, opts and opts.mask
    if category ~= nil then _validate.check_number(category, "category") end
    if mask ~= nil then _validate.check_number(mask, "mask") end

    local shape_id, px, py, pz, nx, ny, nz, fraction =
        _box3d.query.raycast_closest(_state.world, ox, oy, oz, dx * scale, dy * scale, dz * scale, category, mask)
    if not shape_id then return nil end

    return {
        body = _box3d.shape.get_body_user_id(shape_id),
        shape = _box3d.shape.get_user_id(shape_id),
        x = px, y = py, z = pz,
        nx = nx, ny = ny, nz = nz,
        distance = fraction * max_distance,
        fraction = fraction,
    }
end

--- Lists the bodies whose shapes overlap a box
--- @param min_x number Lower bound X
--- @param min_y number Lower bound Y
--- @param min_z number Lower bound Z
--- @param max_x number Upper bound X
--- @param max_y number Upper bound Y
--- @param max_z number Upper bound Z
--- @param opts table|nil Fields: category, mask
--- @return table bodies Array of unique body handles
function m.overlap_box(min_x, min_y, min_z, max_x, max_y, max_z, opts)
    _state.check_world()
    _validate.check_coord(min_x, "min_x")
    _validate.check_coord(min_y, "min_y")
    _validate.check_coord(min_z, "min_z")
    _validate.check_coord(max_x, "max_x")
    _validate.check_coord(max_y, "max_y")
    _validate.check_coord(max_z, "max_z")

    local category, mask = opts and opts.category, opts and opts.mask
    if category ~= nil then _validate.check_number(category, "category") end
    if mask ~= nil then _validate.check_number(mask, "mask") end

    local found, seen = {}, {}

    _box3d.query.overlap_aabb(_state.world, min_x, min_y, min_z, max_x, max_y, max_z, category, mask, function(shape_id)
        local body_handle = _box3d.shape.get_body_user_id(shape_id)
        if not seen[body_handle] then
            seen[body_handle] = true
            found[#found + 1] = body_handle
        end
    end)

    return found
end

--- @section Rotation

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