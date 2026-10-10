--- @module maths.easing
--- @description Common easing functions for animations, tweens, transitions, etc.

local m = {}

-- Epsilon for floating-point comparisons
local EPSILON = 1e-10

--- Linear easing (no curve).
--- @param t number Current time [0–1]
--- @return number Eased value
function m.linear(t)
    return t
end

--- Quadratic ease-in.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.in_quad(t)
    return t * t
end

--- Quadratic ease-out.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.out_quad(t)
    return t * (2 - t)
end

--- Quadratic ease-in-out.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.in_out_quad(t)
    return (t < 0.5)
        and (2 * t * t)
        or (-1 + (4 - 2 * t) * t)
end

--- Cubic ease-in.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.in_cubic(t)
    return t * t * t
end

--- Cubic ease-out.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.out_cubic(t)
    t = t - 1
    return t * t * t + 1
end

--- Cubic ease-in-out.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.in_out_cubic(t)
    return (t < 0.5)
        and (4 * t * t * t)
        or ((t - 1) * (2 * t - 2)^2 + 1)
end

--- Elastic ease-out.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.out_elastic(t)
    if math.abs(t) < EPSILON
        or math.abs(t - 1) < EPSILON then
        return t
    end

    return math.pow(2, -10 * t)
        * math.sin((t - 0.075) * (2 * math.pi) / 0.3)
        + 1
end

return m
