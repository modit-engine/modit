--- @module maths
--- @file src/engine/modules/maths.lua
--- @description Handles math utility functions

--- @section Initialisation

local m = {}

--- @section Functions

--- Clamps a numeric value between a minimum and maximum bound.
--- @param v number The value to clamp
--- @param low number Lower bound (minimum)
--- @param high number Upper bound (maximum)
--- @return number Clamped value within [low, high]
function m.clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

return m