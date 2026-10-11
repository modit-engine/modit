--- @module physics.world
--- @file src/engine/modules/physics/world.lua
--- @description World lifecycle, fixed timestep simulation, events and gravity.

--- @section Imports

local _box3d = require("src.engine.backend.box3d")
local _state = require("src.engine.modules.physics.state")
local _validate = require("src.engine.modules.physics.validate")

--- @section Module

local m = {}

--- @section Lifecycle

--- Creates the physics world, replacing any existing one
--- @param opts table|nil Fields: gravity {x,y,z}, fixed_dt, substeps, max_steps
function m.init(opts)
    opts = opts or {}
    if type(opts) ~= "table" then error("physics.world.init expects a table", 2) end

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

    m.shutdown()

    local created = _box3d.world.create(gx, gy, gz)
    if not created then error("physics: could not create world", 2) end

    _state.world = created
    _state.fixed_dt = step_length
    _state.substeps = math.floor(step_substeps)
    _state.max_steps = math.floor(step_max)
    _state.accumulator = 0
end

--- Destroys the world and invalidates every body and shape handle
function m.shutdown()
    if _state.world then _box3d.world.destroy(_state.world) end
    _state.reset()
end

--- Checks whether the physics world exists
--- @return boolean active True if init has been called
function m.is_active()
    return _state.world ~= nil
end

--- @section Simulation

--- Advances the simulation in fixed steps and collects events
--- @param dt number Frame time in seconds
--- @return number steps Fixed steps taken this call
function m.update(dt)
    _state.check_world()
    _validate.check_number(dt, "dt")
    if dt < 0 then error("dt must not be negative", 2) end

    _state.clear_events()
    _state.accumulator = _state.accumulator + dt

    local steps = 0
    while _state.accumulator >= _state.fixed_dt and steps < _state.max_steps do
        _box3d.world.step(_state.world, _state.fixed_dt, _state.substeps)
        _box3d.events.collect(_state.world, _state.events)
        _state.accumulator = _state.accumulator - _state.fixed_dt
        steps = steps + 1
    end

    -- drop time we could not simulate instead of spiralling
    if steps == _state.max_steps and _state.accumulator >= _state.fixed_dt then _state.accumulator = 0 end

    return steps
end

--- Returns the events collected by the last update. Handles may refer to bodies destroyed since, check body.is_valid
--- @return table events Lists touch_begin, touch_end, hit, sensor_begin, sensor_end
function m.get_events()
    return _state.events
end

--- @section Gravity

--- Sets world gravity
--- @param x number Gravity X
--- @param y number Gravity Y
--- @param z number Gravity Z
function m.set_gravity(x, y, z)
    _state.check_world()
    _validate.check_number(x, "x")
    _validate.check_number(y, "y")
    _validate.check_number(z, "z")
    _box3d.world.set_gravity(_state.world, x, y, z)
end

--- Returns world gravity
--- @return number x Gravity X
--- @return number y Gravity Y
--- @return number z Gravity Z
function m.get_gravity()
    _state.check_world()
    return _box3d.world.get_gravity(_state.world)
end

return m