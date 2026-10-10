--- @module maths.core
--- @description Core math functions not covered by default Lua math.

local m = {}

--- Rounds a number to the specified number of decimal places.
--- Half-way values round away from zero.
--- @param number number The number to round.
--- @param decimals number The number of decimal places.
--- @return number The rounded number.
function m.round(number, decimals)
    local mult = 10 ^ decimals
    local scaled = number * mult

    if scaled < 0 then
        return math.ceil(scaled - 0.5) / mult
    end

    return math.floor(scaled + 0.5) / mult
end

--- Clamps a value within a specified range.
--- Swaps the bounds if lower is greater than upper.
--- @param val number The value to clamp.
--- @param lower number The lower bound.
--- @param upper number The upper bound.
--- @return number The clamped value.
function m.clamp(val, lower, upper)
    if lower > upper then
        lower, upper = upper, lower
    end

    return math.max(lower, math.min(upper, val))
end

--- Linearly interpolates between two values.
--- Does not clamp t, allowing extrapolation.
--- @param a number The start value.
--- @param b number The end value.
--- @param t number The interpolation factor.
--- @return number The interpolated value.
function m.lerp(a, b, t)
    return a + (b - a) * t
end

--- Calculates the factorial of a non-negative integer.
--- @param n number The integer to compute factorial for.
--- @return number The factorial of n.
function m.factorial(n)
    if n < 0 or n ~= math.floor(n)
        or n == math.huge or n ~= n then
        error("factorial expects a non-negative integer", 2)
    end

    local result = 1.0

    for i = 2, n do
        result = result * i
    end

    return result
end

--- Converts degrees to radians.
--- @param deg number Angle in degrees.
--- @return number Angle in radians.
function m.deg_to_rad(deg)
    return deg * (math.pi / 180)
end

--- Converts radians to degrees.
--- @param rad number Angle in radians.
--- @return number Angle in degrees.
function m.rad_to_deg(rad)
    return rad * (180 / math.pi)
end

return m
