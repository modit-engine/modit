--- @module math
--- @file src/engine/sdk/shared/math.lua
--- @description Provides maths functions not covered by lua math.

--- @section Constants

local EPSILON = 1e-10 -- Epsilon for floating-point comparisons

--- @section Initialisation

local m = {}

--- @section Helper Functions

local function validate_finite(value, name)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        error(name .. " must be a finite number", 3)
    end
end

local function validate_numbers(numbers)
    if type(numbers) ~= "table" or #numbers == 0 then
        error("Input must be a non-empty array of numbers")
    end

    for i = 1, #numbers do
        validate_finite(numbers[i], "Element at index " .. i)
    end
end

local function validate_paired(x, y)
    validate_numbers(x)
    validate_numbers(y)

    if #x ~= #y then
        error("Datasets must have equal lengths")
    end
end

local function get_random(rand_func)
    rand_func = rand_func or math.random

    if type(rand_func) ~= "function" then
        error("RNG must be a function", 3)
    end

    local value = rand_func()

    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 or value >= 1 then
        error("RNG must return a number in [0, 1)", 3)
    end

    return value
end

--- @section Core Maths

--- Rounds a number to the specified number of decimal places.
--- Half-way values round away from zero.
--- @param number number The number to round.
--- @param decimals number The number of decimal places.
--- @return number The rounded number.
function m.round(number, decimals)
    decimals = decimals or 0
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

--- @section Easing

--- Linear easing (no curve).
--- @param t number Current time [0–1]
--- @return number Eased value
function m.ease_linear(t)
    return t
end

--- Quadratic ease-in.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.ease_in_quad(t)
    return t * t
end

--- Quadratic ease-out.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.ease_out_quad(t)
    return t * (2 - t)
end

--- Quadratic ease-in-out.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.ease_in_out_quad(t)
    return (t < 0.5) and (2 * t * t) or (-1 + (4 - 2 * t) * t)
end

--- Cubic ease-in.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.ease_in_cubic(t)
    return t * t * t
end

--- Cubic ease-out.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.ease_out_cubic(t)
    t = t - 1
    return t * t * t + 1
end

--- Cubic ease-in-out.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.ease_in_out_cubic(t)
    return (t < 0.5) and (4 * t * t * t) or ((t - 1) * (2 * t - 2)^2 + 1)
end

--- Elastic ease-out.
--- @param t number Current time [0–1]
--- @return number Eased value
function m.ease_out_elastic(t)
    if math.abs(t) < EPSILON
        or math.abs(t - 1) < EPSILON then
        return t
    end

    return math.pow(2, -10 * t) * math.sin((t - 0.075) * (2 * math.pi) / 0.3) + 1
end

--- @section Statistics

--- Calculates the mean (average) of a list of numbers.
--- @param numbers table The dataset.
--- @return number The mean value.
function m.mean(numbers)
    validate_numbers(numbers)

    local mean = 0
    for i = 1, #numbers do
        mean = mean + numbers[i] / #numbers
    end

    return mean
end

--- Calculates the median of a list of numbers.
--- @param numbers table The dataset.
--- @return number The median value.
function m.median(numbers)
    validate_numbers(numbers)

    local sorted = {}
    for i = 1, #numbers do sorted[i] = numbers[i] end
    table.sort(sorted)

    local n = #sorted
    local mid = math.floor(n / 2)

    if n % 2 == 0 then
        return sorted[mid] / 2 + sorted[mid + 1] / 2
    end

    return sorted[mid + 1]
end

--- Calculates the mode (most frequent value).
--- Returns nil if multiple values tie for the highest frequency.
--- @param numbers table The dataset.
--- @return number|nil The unique mode, or nil if there is a tie.
function m.mode(numbers)
    validate_numbers(numbers)

    local counts = {}
    local mode_val, max_count, tied = nil, 0, false

    for i = 1, #numbers do
        local value = numbers[i]
        counts[value] = (counts[value] or 0) + 1
    end

    for value, count in pairs(counts) do
        if count > max_count then
            mode_val, max_count, tied = value, count, false
        elseif count == max_count then
            tied = true
        end
    end

    if tied then return nil end
    return mode_val
end

--- Calculates the variance of a dataset.
--- @param numbers table The dataset.
--- @param population boolean? True for population variance; false or nil for sample variance.
--- @return number The variance.
function m.variance(numbers, population)
    validate_numbers(numbers)

    local n = #numbers
    if not population and n < 2 then
        error("Sample variance requires at least two values")
    end

    local avg = m.mean(numbers)
    local sum = 0

    for i = 1, n do
        local delta = numbers[i] - avg
        sum = sum + delta * delta
    end

    return sum / (population and n or n - 1)
end

--- Calculates the standard deviation of a dataset.
--- @param numbers table The dataset.
--- @param population boolean? True for population; false or nil for sample.
--- @return number The standard deviation.
function m.std_dev(numbers, population)
    return math.sqrt(m.variance(numbers, population))
end

--- Calculates the range (maximum minus minimum).
--- @param numbers table The dataset.
--- @return number The range.
function m.range(numbers)
    validate_numbers(numbers)

    local min_val, max_val = numbers[1], numbers[1]
    for i = 2, #numbers do
        local value = numbers[i]
        if value < min_val then min_val = value end
        if value > max_val then max_val = value end
    end

    return max_val - min_val
end

--- Calculates the minimum value.
--- @param numbers table The dataset.
--- @return number The minimum value.
function m.min(numbers)
    validate_numbers(numbers)

    local result = numbers[1]
    for i = 2, #numbers do
        if numbers[i] < result then result = numbers[i] end
    end

    return result
end

--- Calculates the maximum value.
--- @param numbers table The dataset.
--- @return number The maximum value.
function m.max(numbers)
    validate_numbers(numbers)

    local result = numbers[1]
    for i = 2, #numbers do
        if numbers[i] > result then result = numbers[i] end
    end

    return result
end

--- Calculates the sum of a dataset.
--- @param numbers table The dataset.
--- @return number The sum.
function m.sum(numbers)
    validate_numbers(numbers)

    local sum = 0
    for i = 1, #numbers do sum = sum + numbers[i] end
    return sum
end

--- Calculates a quantile using linear interpolation between sorted values.
--- @param numbers table The dataset.
--- @param q number Quantile in the range [0, 1].
--- @return number The quantile value.
function m.quantile(numbers, q)
    validate_numbers(numbers)
    validate_finite(q, "Quantile")

    if q < 0 or q > 1 then
        error("Quantile must be between 0 and 1")
    end

    local sorted = {}
    for i = 1, #numbers do sorted[i] = numbers[i] end
    table.sort(sorted)

    local index = q * (#sorted - 1) + 1
    local lower = math.floor(index)
    local upper = math.ceil(index)

    if lower == upper then return sorted[lower] end

    local fraction = index - lower
    return sorted[lower] * (1 - fraction) + sorted[upper] * fraction
end

--- Performs ordinary least-squares linear regression on 2D points.
--- @param points table Array of points with finite x and y fields.
--- @return table Result containing slope, intercept, and r_squared.
function m.linear_regression(points)
    if type(points) ~= "table" or #points < 2 then
        error("Regression requires at least two points")
    end

    local sum_x, sum_y = 0, 0
    for i = 1, #points do
        local p = points[i]
        if type(p) ~= "table" then error("Point at index " .. i .. " must be a table") end
        validate_finite(p.x, "Point x at index " .. i)
        validate_finite(p.y, "Point y at index " .. i)
        sum_x, sum_y = sum_x + p.x / #points, sum_y + p.y / #points
    end

    local sxx, syy, sxy = 0, 0, 0
    for i = 1, #points do
        local dx, dy = points[i].x - sum_x, points[i].y - sum_y
        sxx, syy, sxy = sxx + dx * dx, syy + dy * dy, sxy + dx * dy
    end

    if sxx == 0 then
        error("Cannot perform linear regression when all x values are equal")
    end

    local slope = sxy / sxx
    local intercept = sum_y - slope * sum_x
    local r_squared = syy == 0 and 1 or (sxy * sxy) / (sxx * syy)

    return { slope = slope, intercept = intercept, r_squared = math.max(0, math.min(1, r_squared)) }
end

--- Calculates the Pearson correlation coefficient between two datasets.
--- Returns 0 if either dataset has zero variance.
--- @param x table First dataset.
--- @param y table Second dataset.
--- @return number Correlation coefficient in [-1, 1].
function m.correlation(x, y)
    validate_paired(x, y)

    local mean_x, mean_y = m.mean(x), m.mean(y)
    local cov, var_x, var_y = 0, 0, 0

    for i = 1, #x do
        local dx, dy = x[i] - mean_x, y[i] - mean_y
        cov, var_x, var_y = cov + dx * dy, var_x + dx * dx, var_y + dy * dy
    end

    if var_x == 0 or var_y == 0 then return 0 end
    return math.max(-1, math.min(1, cov / math.sqrt(var_x * var_y)))
end

--- Calculates covariance between two datasets.
--- @param x table First dataset.
--- @param y table Second dataset.
--- @param population boolean? True for population covariance; false or nil for sample covariance.
--- @return number The covariance.
function m.covariance(x, y, population)
    validate_paired(x, y)

    local n = #x
    if not population and n < 2 then
        error("Sample covariance requires at least two values")
    end

    local mean_x, mean_y = m.mean(x), m.mean(y)
    local sum = 0

    for i = 1, n do
        sum = sum + (x[i] - mean_x) * (y[i] - mean_y)
    end

    return sum / (population and n or n - 1)
end

--- @section Probability

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
function m.random_chance(probability, rand_func)
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
function m.random_percent_chance(percentage, rand_func)
    validate_finite(percentage, "Percentage")

    if percentage < 0 or percentage > 100 then
        error("Percentage must be between 0 and 100")
    end

    return m.random_chance(percentage / 100, rand_func)
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
function m.random_weighted_choice(map, rand_func)
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
function m.random_shuffle(tbl, rand_func)
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

    local u1 = math.max(get_random(rand_func), 2 ^ -53)
    local u2 = get_random(rand_func)

    local z0 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)

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