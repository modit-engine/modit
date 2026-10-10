--- @module maths.probability
--- @description Probability and random helpers.

local m = {}

-- Small epsilon for numerical calculations.
local EPSILON = 1e-10

--- Validate a finite number.
--- @param value number Value to validate.
--- @param name string Parameter name for error messages.
local function validate_finite(value, name)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge then
        error(name .. " must be a finite number", 3)
    end
end

--- Get a random value in the range [0, 1).
--- @param rand_func? function Optional RNG function.
--- @return number Random value in [0, 1).
local function get_random(rand_func)
    rand_func = rand_func or math.random

    if type(rand_func) ~= "function" then
        error("RNG must be a function", 3)
    end

    local value = rand_func()

    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge
        or value < 0
        or value >= 1 then
        error("RNG must return a number in [0, 1)", 3)
    end

    return value
end

--- Set the global random seed for reproducibility.
--- @param seed number Integer seed value.
function m.set_seed(seed)
    validate_finite(seed, "Seed")

    if seed % 1 ~= 0 then
        error("Seed must be an integer")
    end

    math.randomseed(seed)
end

--- Returns a random float between min and max.
--- @param min number Lower bound.
--- @param max number Upper bound.
--- @param rand_func? function Optional RNG function returning 0.0–1.0.
--- @return number Random float in the range [min, max).
function m.random_between(min, max, rand_func)
    validate_finite(min, "Minimum")
    validate_finite(max, "Maximum")

    if min > max then
        min, max = max, min
    end

    if min == max then
        return min
    end

    return min + get_random(rand_func) * (max - min)
end

--- Returns a random integer between min and max (inclusive).
--- Bounds must be integers.
--- @param min number Lower bound.
--- @param max number Upper bound.
--- @param rand_func? function Optional RNG function returning 0.0–1.0.
--- @return number Random integer in the range [min, max].
function m.random_int(min, max, rand_func)
    validate_finite(min, "Minimum")
    validate_finite(max, "Maximum")

    if min % 1 ~= 0 or max % 1 ~= 0 then
        error("Bounds must be integers")
    end

    if min > max then
        min, max = max, min
    end

    if min == max then
        return min
    end

    local value = get_random(rand_func)
    return min + math.floor(value * (max - min + 1))
end

--- Check if something happens with a given probability.
--- @param probability number Chance of success (0.0 to 1.0).
--- @param rand_func? function Optional RNG function returning 0.0–1.0.
--- @return boolean True if the event occurs.
function m.chance(probability, rand_func)
    validate_finite(probability, "Probability")

    if probability < 0 or probability > 1 then
        error("Probability must be between 0.0 and 1.0")
    end

    if probability == 0 then
        return false
    elseif probability == 1 then
        return true
    end

    return get_random(rand_func) < probability
end

--- Check if something happens with a given percentage chance.
--- @param percentage number Chance of success (0 to 100).
--- @param rand_func? function Optional RNG function returning 0.0–1.0.
--- @return boolean True if the event occurs.
function m.percent_chance(percentage, rand_func)
    validate_finite(percentage, "Percentage")

    if percentage < 0 or percentage > 100 then
        error("Percentage must be between 0 and 100")
    end

    return m.chance(percentage / 100, rand_func)
end

--- Select a random element from a dense array.
--- @param tbl table Array to select from.
--- @param rand_func? function Optional RNG function returning 0.0–1.0.
--- @return any|nil Random element, or nil if the array is empty.
function m.random_choice(tbl, rand_func)
    if type(tbl) ~= "table" then
        error("Input must be a table")
    end

    local count = #tbl

    if count == 0 then
        return nil
    end

    local index = math.floor(get_random(rand_func) * count) + 1
    return tbl[index]
end

--- Select a random key from a table of weighted options.
--- Weights must be finite, non-negative numbers.
--- @param map table Table of weighted options { option = weight, ... }.
--- @param rand_func? function Optional RNG function returning 0.0–1.0.
--- @return any|nil Chosen option key, or nil if all weights are zero.
function m.weighted_choice(map, rand_func)
    if type(map) ~= "table" then
        error("Map must be a table")
    end

    local total = 0

    for _, weight in pairs(map) do
        validate_finite(weight, "Weight")

        if weight < 0 then
            error("Weights must be non-negative")
        end

        total = total + weight

        if total == math.huge then
            error("Total weight is too large")
        end
    end

    if total <= 0 then
        return nil
    end

    local threshold = get_random(rand_func) * total
    local cumulative = 0
    local last_key

    for key, weight in pairs(map) do
        if weight > 0 then
            last_key = key
            cumulative = cumulative + weight

            if threshold < cumulative then
                return key
            end
        end
    end

    -- Protect against floating-point rounding at the upper boundary.
    return last_key
end

--- Shuffle a dense array in-place using Fisher-Yates.
--- @param tbl table Array to shuffle.
--- @param rand_func? function Optional RNG function returning 0.0–1.0.
--- @return table The shuffled table (same reference).
function m.shuffle(tbl, rand_func)
    if type(tbl) ~= "table" then
        error("Input must be a table")
    end

    for i = #tbl, 2, -1 do
        local j = math.floor(get_random(rand_func) * i) + 1
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end

    return tbl
end

--- Generate a random value from a normal (Gaussian) distribution.
--- Uses the Box-Muller transform.
--- @param mean number? Mean of the distribution (default 0).
--- @param stddev number? Standard deviation (default 1).
--- @param rand_func? function Optional RNG function returning 0.0–1.0.
--- @return number Random value from the normal distribution.
function m.random_normal(mean, stddev, rand_func)
    if mean == nil then
        mean = 0
    end

    if stddev == nil then
        stddev = 1
    end

    validate_finite(mean, "Mean")
    validate_finite(stddev, "Standard deviation")

    if stddev <= 0 then
        error("Standard deviation must be positive")
    end

    -- Avoid log(0) while preserving a uniform sample to practical precision.
    local u1 = math.max(get_random(rand_func), 2 ^ -53)
    local u2 = get_random(rand_func)

    local z0 = math.sqrt(-2 * math.log(u1))
        * math.cos(2 * math.pi * u2)

    return mean + z0 * stddev
end

--- Generate a random value from an exponential distribution.
--- @param lambda number Positive rate parameter.
--- @param rand_func? function Optional RNG function returning 0.0–1.0.
--- @return number Random value from the exponential distribution.
function m.random_exponential(lambda, rand_func)
    validate_finite(lambda, "Lambda")

    if lambda <= 0 then
        error("Lambda must be positive")
    end

    local u = get_random(rand_func)

    return -math.log(1 - u) / lambda
end

--- Generate a random value from a uniform distribution.
--- Alias for random_between.
--- @param min number Lower bound.
--- @param max number Upper bound.
--- @param rand_func? function Optional RNG function returning 0.0–1.0.
--- @return number Random float in the range [min, max).
function m.random_uniform(min, max, rand_func)
    return m.random_between(min, max, rand_func)
end

return m