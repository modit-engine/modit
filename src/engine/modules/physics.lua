--- @module physics
--- @file src/engine/modules/physics.lua
--- @description Rigid body physics on top of the Box3D backend. One world, fixed timestep, integer handles instead of raw ids. Runs on both client and dedicated server.

--- @section Imports

local _box3d = require("src.engine.backend.box3d")

--- @section Constants

local DEFAULT_GRAVITY = { x = 0, y = -9.81, z = 0 }
local DEFAULT_FIXED_DT = 1 / 60
local DEFAULT_SUBSTEPS = 4
local DEFAULT_MAX_STEPS = 5
local MAX_COORD = 1e5
local BODY_TYPES = { static = true, kinematic = true, dynamic = true }

--- @section Initialisation

local m = {}

local world
local fixed_dt = DEFAULT_FIXED_DT
local substeps = DEFAULT_SUBSTEPS
local max_steps = DEFAULT_MAX_STEPS
local accumulator = 0
local next_handle = 0

local bodies = {}
local shapes = {}
local events = {}

--- @section Helpers

--- Errors unless the value is a finite number
--- @param value any Value to check
--- @param name string Argument name for the message
local function check_number(value, name)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        error(name .. " must be a finite number", 3)
    end
end

--- Errors unless the value is a finite number inside the supported world range
--- @param value any Value to check
--- @param name string Argument name for the message
local function check_coord(value, name)
    check_number(value, name)
    if value > MAX_COORD or value < -MAX_COORD then
        error(name .. " is outside the supported range of +-" .. MAX_COORD, 3)
    end
end

--- Errors unless the physics world exists
local function check_world()
    if not world then error("physics is not initialised, call physics.init first", 3) end
end

--- Returns the record of a body handle or errors
--- @param handle any Body handle
--- @return table record Body record
local function get_body(handle)
    local record = bodies[handle]
    if not record then error("invalid physics body handle: " .. tostring(handle), 3) end
    return record
end

--- Returns the record of a shape handle or errors
--- @param handle any Shape handle
--- @return table record Shape record
local function get_shape(handle)
    local record = shapes[handle]
    if not record then error("invalid physics shape handle: " .. tostring(handle), 3) end
    return record
end

--- Reads x, y, z from an optional table, defaulting to zero
--- @param source table|nil Table with x, y, z
--- @param name string Argument name for the message
--- @return number x
--- @return number y
--- @return number z
local function read_vec(source, name)
    if source == nil then return 0, 0, 0 end
    if type(source) ~= "table" then error(name .. " must be a table with x, y, z", 3) end

    local x, y, z = source.x or 0, source.y or 0, source.z or 0
    check_coord(x, name .. ".x")
    check_coord(y, name .. ".y")
    check_coord(z, name .. ".z")
    return x, y, z
end

--- Validates shape options and returns a backend-safe copy
--- @param opts table|nil Shape options
--- @return table safe Validated options
local function read_shape_opts(opts)
    local safe = {}
    if opts == nil then return safe end
    if type(opts) ~= "table" then error("shape options must be a table", 3) end

    for _, key in ipairs({ "density", "friction", "restitution", "category", "mask", "ox", "oy", "oz" }) do
        if opts[key] ~= nil then
            check_number(opts[key], key)
            safe[key] = opts[key]
        end
    end

    if safe.density ~= nil and safe.density <= 0 then error("density must be above 0", 3) end

    safe.sensor = opts.sensor and true or nil
    safe.events = opts.events and true or nil
    return safe
end

--- Allocates a new handle
--- @return number handle Unique handle, never reused
local function new_handle()
    next_handle = next_handle + 1
    return next_handle
end

--- Registers a shape on a body
--- @param body_handle number Owning body handle
--- @param shape_id cdata Backend shape id
--- @param handle number Shape handle
--- @return number handle Shape handle
local function register_shape(body_handle, shape_id, handle)
    shapes[handle] = { id = shape_id, body = body_handle }
    bodies[body_handle].shapes[handle] = true
    return handle
end

--- Empties the event lists
local function clear_events()
    events = { touch_begin = {}, touch_end = {}, hit = {}, sensor_begin = {}, sensor_end = {} }
end

clear_events()

--- @section Lifecycle

--- Creates the physics world, replacing any existing one
--- @param opts table|nil Fields: gravity {x,y,z}, fixed_dt, substeps, max_steps
function m.init(opts)
    opts = opts or {}
    if type(opts) ~= "table" then error("physics.init expects a table", 2) end

    local gx, gy, gz = DEFAULT_GRAVITY.x, DEFAULT_GRAVITY.y, DEFAULT_GRAVITY.z
    if opts.gravity ~= nil then
        if type(opts.gravity) ~= "table" then error("gravity must be a table with x, y, z", 2) end
        gx, gy, gz = opts.gravity.x or 0, opts.gravity.y or 0, opts.gravity.z or 0
        check_number(gx, "gravity.x")
        check_number(gy, "gravity.y")
        check_number(gz, "gravity.z")
    end

    local step_length = opts.fixed_dt or DEFAULT_FIXED_DT
    local step_substeps = opts.substeps or DEFAULT_SUBSTEPS
    local step_max = opts.max_steps or DEFAULT_MAX_STEPS
    check_number(step_length, "fixed_dt")
    check_number(step_substeps, "substeps")
    check_number(step_max, "max_steps")
    if step_length <= 0 then error("fixed_dt must be above 0", 2) end
    if step_substeps < 1 or step_max < 1 then error("substeps and max_steps must be at least 1", 2) end

    m.shutdown()

    local created = _box3d.world.create(gx, gy, gz)
    if not created then error("physics: could not create world", 2) end

    world = created
    fixed_dt = step_length
    substeps = math.floor(step_substeps)
    max_steps = math.floor(step_max)
    accumulator = 0
end

--- Destroys the world and invalidates every body and shape handle
function m.shutdown()
    if world then _box3d.world.destroy(world) end

    world = nil
    accumulator = 0
    bodies = {}
    shapes = {}
    clear_events()
end

--- Checks whether the physics world exists
--- @return boolean active True if init has been called
function m.is_active()
    return world ~= nil
end

--- @section Simulation

--- Advances the simulation in fixed steps and collects events
--- @param dt number Frame time in seconds
--- @return number steps Fixed steps taken this call
function m.update(dt)
    check_world()
    check_number(dt, "dt")
    if dt < 0 then error("dt must not be negative", 2) end

    clear_events()
    accumulator = accumulator + dt

    local steps = 0
    while accumulator >= fixed_dt and steps < max_steps do
        _box3d.world.step(world, fixed_dt, substeps)
        _box3d.events.collect(world, events)
        accumulator = accumulator - fixed_dt
        steps = steps + 1
    end

    -- drop time we could not simulate instead of spiralling
    if steps == max_steps and accumulator >= fixed_dt then accumulator = 0 end

    return steps
end

--- Returns the events collected by the last update. Handles may refer to bodies destroyed since, check is_valid
--- @return table events Lists touch_begin, touch_end, hit, sensor_begin, sensor_end
function m.get_events()
    return events
end

--- Sets world gravity
--- @param x number Gravity X
--- @param y number Gravity Y
--- @param z number Gravity Z
function m.set_gravity(x, y, z)
    check_world()
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")
    _box3d.world.set_gravity(world, x, y, z)
end

--- Returns world gravity
--- @return number x Gravity X
--- @return number y Gravity Y
--- @return number z Gravity Z
function m.get_gravity()
    check_world()
    return _box3d.world.get_gravity(world)
end

--- @section Bodies

--- Creates a body
--- @param opts table|nil Fields: type ("static"|"kinematic"|"dynamic"), position {x,y,z}, rotation {x,y,z,w}, linear_damping, angular_damping, gravity_scale, bullet, fixed_rotation
--- @return number handle Body handle
function m.create_body(opts)
    check_world()
    opts = opts or {}
    if type(opts) ~= "table" then error("physics.create_body expects a table", 2) end

    local body_type = opts.type or "static"
    if not BODY_TYPES[body_type] then error("invalid body type: " .. tostring(body_type), 2) end

    local x, y, z = read_vec(opts.position, "position")
    local def = { type = body_type, x = x, y = y, z = z }

    if opts.rotation ~= nil then
        local q = opts.rotation
        if type(q) ~= "table" then error("rotation must be a table with x, y, z, w", 2) end
        local qx, qy, qz, qw = q.x or 0, q.y or 0, q.z or 0, q.w or 1
        check_number(qx, "rotation.x")
        check_number(qy, "rotation.y")
        check_number(qz, "rotation.z")
        check_number(qw, "rotation.w")

        local length = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
        if length < 1e-6 then error("rotation must not be zero", 2) end
        def.qx, def.qy, def.qz, def.qw = qx / length, qy / length, qz / length, qw / length
    end

    for _, key in ipairs({ "linear_damping", "angular_damping", "gravity_scale" }) do
        if opts[key] ~= nil then
            check_number(opts[key], key)
            def[key] = opts[key]
        end
    end

    def.bullet = opts.bullet and true or nil
    def.fixed_rotation = opts.fixed_rotation and true or nil

    local handle = new_handle()
    def.user_id = handle
    bodies[handle] = { id = _box3d.body.create(world, def), shapes = {} }
    return handle
end

--- Destroys a body and all of its shapes
--- @param body number Body handle
--- @return number count Shapes destroyed with the body
function m.destroy_body(body)
    local record = get_body(body)
    local count = 0

    for shape_handle in pairs(record.shapes) do
        shapes[shape_handle] = nil
        count = count + 1
    end

    _box3d.body.destroy(record.id)
    bodies[body] = nil
    return count
end

--- Checks whether a body or shape handle is still valid
--- @param handle number Body or shape handle
--- @return boolean valid True if it exists
function m.is_valid(handle)
    return bodies[handle] ~= nil or shapes[handle] ~= nil
end

--- Returns the body position
--- @param body number Body handle
--- @return number x World X
--- @return number y World Y
--- @return number z World Z
function m.get_position(body)
    return _box3d.body.get_position(get_body(body).id)
end

--- Returns the body rotation as a quaternion
--- @param body number Body handle
--- @return number x Quaternion X
--- @return number y Quaternion Y
--- @return number z Quaternion Z
--- @return number w Quaternion W
function m.get_rotation(body)
    return _box3d.body.get_rotation(get_body(body).id)
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
function m.get_transform(body)
    return _box3d.body.get_transform(get_body(body).id)
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
function m.set_transform(body, x, y, z, qx, qy, qz, qw)
    local record = get_body(body)
    check_coord(x, "x")
    check_coord(y, "y")
    check_coord(z, "z")

    if qx == nil then
        qx, qy, qz, qw = _box3d.body.get_rotation(record.id)
    else
        check_number(qx, "qx")
        check_number(qy, "qy")
        check_number(qz, "qz")
        check_number(qw, "qw")
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
function m.get_world_point(body, x, y, z)
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")
    return _box3d.body.get_world_point(get_body(body).id, x, y, z)
end

--- Converts a world point to local space
--- @param body number Body handle
--- @param x number World X
--- @param y number World Y
--- @param z number World Z
--- @return number x Local X
--- @return number y Local Y
--- @return number z Local Z
function m.get_local_point(body, x, y, z)
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")
    return _box3d.body.get_local_point(get_body(body).id, x, y, z)
end

--- Rotates a local direction into world space
--- @param body number Body handle
--- @param x number Local X
--- @param y number Local Y
--- @param z number Local Z
--- @return number x World X
--- @return number y World Y
--- @return number z World Z
function m.get_world_vector(body, x, y, z)
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")
    return _box3d.body.get_world_vector(get_body(body).id, x, y, z)
end

--- Returns linear velocity
--- @param body number Body handle
--- @return number x Velocity X
--- @return number y Velocity Y
--- @return number z Velocity Z
function m.get_linear_velocity(body)
    return _box3d.body.get_linear_velocity(get_body(body).id)
end

--- Sets linear velocity
--- @param body number Body handle
--- @param x number Velocity X
--- @param y number Velocity Y
--- @param z number Velocity Z
function m.set_linear_velocity(body, x, y, z)
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")
    _box3d.body.set_linear_velocity(get_body(body).id, x, y, z)
end

--- Returns angular velocity in radians per second
--- @param body number Body handle
--- @return number x Angular velocity X
--- @return number y Angular velocity Y
--- @return number z Angular velocity Z
function m.get_angular_velocity(body)
    return _box3d.body.get_angular_velocity(get_body(body).id)
end

--- Sets angular velocity in radians per second
--- @param body number Body handle
--- @param x number Angular velocity X
--- @param y number Angular velocity Y
--- @param z number Angular velocity Z
function m.set_angular_velocity(body, x, y, z)
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")
    _box3d.body.set_angular_velocity(get_body(body).id, x, y, z)
end

--- Applies a force for the next step. With a point it is applied at that world position
--- @param body number Body handle
--- @param x number Force X
--- @param y number Force Y
--- @param z number Force Z
--- @param px number|nil Point X
--- @param py number|nil Point Y
--- @param pz number|nil Point Z
function m.apply_force(body, x, y, z, px, py, pz)
    local record = get_body(body)
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")

    if px == nil then
        _box3d.body.apply_force(record.id, x, y, z)
        return
    end

    check_number(px, "px")
    check_number(py, "py")
    check_number(pz, "pz")
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
function m.apply_impulse(body, x, y, z, px, py, pz)
    local record = get_body(body)
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")

    if px == nil then
        _box3d.body.apply_impulse(record.id, x, y, z)
        return
    end

    check_number(px, "px")
    check_number(py, "py")
    check_number(pz, "pz")
    _box3d.body.apply_impulse_at(record.id, x, y, z, px, py, pz)
end

--- Applies a torque for the next step
--- @param body number Body handle
--- @param x number Torque X
--- @param y number Torque Y
--- @param z number Torque Z
function m.apply_torque(body, x, y, z)
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")
    _box3d.body.apply_torque(get_body(body).id, x, y, z)
end

--- Applies an instant angular impulse
--- @param body number Body handle
--- @param x number Impulse X
--- @param y number Impulse Y
--- @param z number Impulse Z
function m.apply_angular_impulse(body, x, y, z)
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")
    _box3d.body.apply_angular_impulse(get_body(body).id, x, y, z)
end

--- Returns the body mass
--- @param body number Body handle
--- @return number mass Mass in kg
function m.get_mass(body)
    return _box3d.body.get_mass(get_body(body).id)
end

--- Sets the gravity scale
--- @param body number Body handle
--- @param scale number Gravity multiplier
function m.set_gravity_scale(body, scale)
    check_number(scale, "scale")
    _box3d.body.set_gravity_scale(get_body(body).id, scale)
end

--- Sets linear and angular damping
--- @param body number Body handle
--- @param linear number Linear damping
--- @param angular number Angular damping
function m.set_damping(body, linear, angular)
    check_number(linear, "linear")
    check_number(angular, "angular")
    _box3d.body.set_damping(get_body(body).id, linear, angular)
end

--- Checks whether a body is awake
--- @param body number Body handle
--- @return boolean awake True if awake
function m.is_awake(body)
    return _box3d.body.is_awake(get_body(body).id)
end

--- Wakes or sleeps a body
--- @param body number Body handle
--- @param awake boolean Target state
function m.set_awake(body, awake)
    _box3d.body.set_awake(get_body(body).id, awake and true or false)
end

--- Enables or disables a body in the simulation
--- @param body number Body handle
--- @param enabled boolean Target state
function m.set_enabled(body, enabled)
    _box3d.body.set_enabled(get_body(body).id, enabled and true or false)
end

--- @section Shapes

--- Attaches a box shape
--- @param body number Body handle
--- @param half_x number Half extent X
--- @param half_y number Half extent Y
--- @param half_z number Half extent Z
--- @param opts table|nil Fields: density, friction, restitution, sensor, events, category, mask, ox, oy, oz
--- @return number handle Shape handle
function m.add_box(body, half_x, half_y, half_z, opts)
    local record = get_body(body)
    check_number(half_x, "half_x")
    check_number(half_y, "half_y")
    check_number(half_z, "half_z")
    if half_x <= 0 or half_y <= 0 or half_z <= 0 then error("box extents must be above 0", 2) end

    local safe = read_shape_opts(opts)
    local handle = new_handle()
    safe.user_id = handle
    return register_shape(body, _box3d.shape.create_box(record.id, half_x, half_y, half_z, safe), handle)
end

--- Attaches a sphere shape
--- @param body number Body handle
--- @param radius number Sphere radius
--- @param opts table|nil Same fields as add_box
--- @return number handle Shape handle
function m.add_sphere(body, radius, opts)
    local record = get_body(body)
    check_number(radius, "radius")
    if radius <= 0 then error("radius must be above 0", 2) end

    local safe = read_shape_opts(opts)
    local handle = new_handle()
    safe.user_id = handle
    return register_shape(body, _box3d.shape.create_sphere(record.id, radius, safe), handle)
end

--- Attaches a capsule shape standing along the Y axis
--- @param body number Body handle
--- @param radius number Capsule radius
--- @param half_height number Half length of the center segment
--- @param opts table|nil Same fields as add_box
--- @return number handle Shape handle
function m.add_capsule(body, radius, half_height, opts)
    local record = get_body(body)
    check_number(radius, "radius")
    check_number(half_height, "half_height")
    if radius <= 0 or half_height <= 0 then error("capsule radius and half_height must be above 0", 2) end

    local safe = read_shape_opts(opts)
    local handle = new_handle()
    safe.user_id = handle
    return register_shape(body, _box3d.shape.create_capsule(record.id, radius, half_height, safe), handle)
end

--- Destroys a shape
--- @param shape number Shape handle
function m.destroy_shape(shape)
    local record = get_shape(shape)

    _box3d.shape.destroy(record.id)
    if bodies[record.body] then bodies[record.body].shapes[shape] = nil end
    shapes[shape] = nil
end

--- Returns the body a shape is attached to
--- @param shape number Shape handle
--- @return number body Body handle
function m.get_shape_body(shape)
    return get_shape(shape).body
end

--- Sets surface friction
--- @param shape number Shape handle
--- @param friction number Friction coefficient
function m.set_friction(shape, friction)
    check_number(friction, "friction")
    _box3d.shape.set_friction(get_shape(shape).id, friction)
end

--- Sets surface restitution
--- @param shape number Shape handle
--- @param restitution number Bounciness
function m.set_restitution(shape, restitution)
    check_number(restitution, "restitution")
    _box3d.shape.set_restitution(get_shape(shape).id, restitution)
end

--- Sets collision category and mask bits
--- @param shape number Shape handle
--- @param category number Category bits
--- @param mask number Mask bits
function m.set_filter(shape, category, mask)
    check_number(category, "category")
    check_number(mask, "mask")
    _box3d.shape.set_filter(get_shape(shape).id, category, mask)
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
    check_world()
    check_coord(ox, "ox")
    check_coord(oy, "oy")
    check_coord(oz, "oz")
    check_number(dx, "dx")
    check_number(dy, "dy")
    check_number(dz, "dz")
    check_number(max_distance, "max_distance")
    if max_distance <= 0 then error("max_distance must be above 0", 2) end

    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 1e-9 then error("direction must not be zero", 2) end

    local scale = max_distance / length
    local category, mask = opts and opts.category, opts and opts.mask
    if category ~= nil then check_number(category, "category") end
    if mask ~= nil then check_number(mask, "mask") end

    local shape_id, px, py, pz, nx, ny, nz, fraction =
        _box3d.query.raycast_closest(world, ox, oy, oz, dx * scale, dy * scale, dz * scale, category, mask)
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
    check_world()
    check_coord(min_x, "min_x")
    check_coord(min_y, "min_y")
    check_coord(min_z, "min_z")
    check_coord(max_x, "max_x")
    check_coord(max_y, "max_y")
    check_coord(max_z, "max_z")

    local category, mask = opts and opts.category, opts and opts.mask
    if category ~= nil then check_number(category, "category") end
    if mask ~= nil then check_number(mask, "mask") end

    local found, seen = {}, {}

    _box3d.query.overlap_aabb(world, min_x, min_y, min_z, max_x, max_y, max_z, category, mask, function(shape_id)
        local body_handle = _box3d.shape.get_body_user_id(shape_id)
        if not seen[body_handle] then
            seen[body_handle] = true
            found[#found + 1] = body_handle
        end
    end)

    return found
end

--- @section Rotation Helpers

--- Builds a quaternion from Euler angles (Y-up, applied yaw then pitch then roll)
--- @param pitch number Rotation around X in radians
--- @param yaw number Rotation around Y in radians
--- @param roll number Rotation around Z in radians
--- @return number x Quaternion X
--- @return number y Quaternion Y
--- @return number z Quaternion Z
--- @return number w Quaternion W
function m.quat_from_euler(pitch, yaw, roll)
    check_number(pitch, "pitch")
    check_number(yaw, "yaw")
    check_number(roll, "roll")

    local cx, sx = math.cos(pitch * 0.5), math.sin(pitch * 0.5)
    local cy, sy = math.cos(yaw * 0.5), math.sin(yaw * 0.5)
    local cz, sz = math.cos(roll * 0.5), math.sin(roll * 0.5)

    return sx * cy * cz + cx * sy * sz,
        cx * sy * cz - sx * cy * sz,
        cx * cy * sz - sx * sy * cz,
        cx * cy * cz + sx * sy * sz
end

--- Converts a quaternion to Euler angles, the inverse of quat_from_euler
--- @param x number Quaternion X
--- @param y number Quaternion Y
--- @param z number Quaternion Z
--- @param w number Quaternion W
--- @return number pitch Rotation around X in radians
--- @return number yaw Rotation around Y in radians
--- @return number roll Rotation around Z in radians
function m.quat_to_euler(x, y, z, w)
    check_number(x, "x")
    check_number(y, "y")
    check_number(z, "z")
    check_number(w, "w")

    local sin_pitch = math.max(-1, math.min(1, -2 * (y * z - w * x)))

    return math.asin(sin_pitch),
        math.atan2(2 * (x * z + w * y), 1 - 2 * (x * x + y * y)),
        math.atan2(2 * (x * y + w * z), 1 - 2 * (x * x + z * z))
end

return m