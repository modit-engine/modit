--- @module physics.query
--- @file src/engine/modules/physics/query.lua
--- @description Spatial queries: raycasts and box overlaps.

--- @section Imports

local _box3d = require("src.engine.backend.box3d")
local _state = require("src.engine.sdk.shared.physics3d.state")
local _validate = require("src.engine.sdk.shared.physics3d.validate")

--- @section Module

local m = {}

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

return m