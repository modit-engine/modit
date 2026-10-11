--- @module physics.validate
--- @file src/engine/modules/physics/validate.lua
--- @description Argument validation helpers for physics. Pure Lua, no backend.

--- @section Constants

local MAX_COORD = 1e5

--- @section Module

local m = {}

--- Errors unless the value is a finite number
--- @param value any Value to check
--- @param name string Argument name for the message
function m.check_number(value, name)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        error(name .. " must be a finite number", 3)
    end
end

--- Errors unless the value is a finite number inside the supported world range
--- @param value any Value to check
--- @param name string Argument name for the message
function m.check_coord(value, name)
    m.check_number(value, name)
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
function m.read_vec(source, name)
    if source == nil then return 0, 0, 0 end
    if type(source) ~= "table" then error(name .. " must be a table with x, y, z", 3) end

    local x, y, z = source.x or 0, source.y or 0, source.z or 0
    m.check_coord(x, name .. ".x")
    m.check_coord(y, name .. ".y")
    m.check_coord(z, name .. ".z")
    return x, y, z
end

--- Validates shape options and returns a backend-safe copy
--- @param opts table|nil Shape options
--- @return table safe Validated options
function m.read_shape_opts(opts)
    local safe = {}
    if opts == nil then return safe end
    if type(opts) ~= "table" then error("shape options must be a table", 3) end

    for _, key in ipairs({ "density", "friction", "restitution", "category", "mask", "ox", "oy", "oz" }) do
        if opts[key] ~= nil then
            m.check_number(opts[key], key)
            safe[key] = opts[key]
        end
    end

    if safe.density ~= nil and safe.density <= 0 then error("density must be above 0", 3) end

    safe.sensor = opts.sensor and true or nil
    safe.events = opts.events and true or nil
    return safe
end

return m