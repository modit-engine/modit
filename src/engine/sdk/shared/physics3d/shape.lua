--- @module physics3d.shape
--- @file src/engine/sdk/shared/physics3d/shape.lua
--- @description Collision shapes attached to bodies and their surface settings.

--- @section Imports

local _box3d = require("src.engine.backend.box3d")
local _state = require("src.engine.sdk.shared.physics3d.state")
local _validate = require("src.engine.sdk.shared.physics3d.validate")

--- @section Module

local m = {}

--- @section Creation

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

--- @section Management

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

--- @section Properties

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

return m