--- @module physics.state
--- @file src/engine/modules/physics/state.lua
--- @description Shared physics state and handle lookups. Pure Lua, no backend.

--- @section Constants

local DEFAULT_GRAVITY = { x = 0, y = -9.81, z = 0 }
local DEFAULT_FIXED_DT = 1 / 60
local DEFAULT_SUBSTEPS = 4
local DEFAULT_MAX_STEPS = 5

--- @section Module

local m = {}

m.DEFAULT_GRAVITY = DEFAULT_GRAVITY
m.DEFAULT_FIXED_DT = DEFAULT_FIXED_DT
m.DEFAULT_SUBSTEPS = DEFAULT_SUBSTEPS
m.DEFAULT_MAX_STEPS = DEFAULT_MAX_STEPS

m.world = nil
m.fixed_dt = DEFAULT_FIXED_DT
m.substeps = DEFAULT_SUBSTEPS
m.max_steps = DEFAULT_MAX_STEPS
m.accumulator = 0
m.next_handle = 0
m.bodies = {}
m.shapes = {}
m.events = {}

--- @section Helpers

--- Empties the event lists
function m.clear_events()
    m.events = { touch_begin = {}, touch_end = {}, hit = {}, sensor_begin = {}, sensor_end = {} }
end

m.clear_events()

--- Allocates a new handle
--- @return number handle Unique handle, never reused
function m.new_handle()
    m.next_handle = m.next_handle + 1
    return m.next_handle
end

--- Errors unless the physics world exists
function m.check_world()
    if not m.world then error("physics is not initialised, call physics.world.init first", 3) end
end

--- Returns the record of a body handle or errors
--- @param handle any Body handle
--- @return table record Body record
function m.get_body(handle)
    local record = m.bodies[handle]
    if not record then error("invalid physics body handle: " .. tostring(handle), 3) end
    return record
end

--- Returns the record of a shape handle or errors
--- @param handle any Shape handle
--- @return table record Shape record
function m.get_shape(handle)
    local record = m.shapes[handle]
    if not record then error("invalid physics shape handle: " .. tostring(handle), 3) end
    return record
end

--- Registers a shape on a body
--- @param body_handle number Owning body handle
--- @param shape_id cdata Backend shape id
--- @param handle number Shape handle
--- @return number handle Shape handle
function m.register_shape(body_handle, shape_id, handle)
    m.shapes[handle] = { id = shape_id, body = body_handle }
    m.bodies[body_handle].shapes[handle] = true
    return handle
end

--- Clears the world reference, handles and events
function m.reset()
    m.world = nil
    m.accumulator = 0
    m.bodies = {}
    m.shapes = {}
    m.clear_events()
end

return m