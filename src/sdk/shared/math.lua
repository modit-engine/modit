--- @module math
--- @file src/sdk/shared/math.lua
--- @description Core math, statistics, probability and 2D/3D geometry in one flat API.

--- @default_access mod

--- @section Constants

local EPSILON = 1e-10 -- Epsilon for floating-point comparisons

--- @section Initialisation

local m = {}

--- @section Helpers

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

--- @section Geometry Helpers

local function point(x, y)
    return { x = x, y = y }
end

local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    return math.atan(y, x)
end

local function rect_bounds(rect)
    local x2 = rect.x + rect.width
    local y2 = rect.y + rect.height

    return math.min(rect.x, x2), math.min(rect.y, y2), math.max(rect.x, x2), math.max(rect.y, y2)
end

local function cross(a, b, c)
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
end

local function within_bounds(p, a, b, tolerance)
    return p.x >= math.min(a.x, b.x) - tolerance and p.x <= math.max(a.x, b.x) + tolerance and p.y >= math.min(a.y, b.y) - tolerance and p.y <= math.max(a.y, b.y) + tolerance
end

local function point3(x, y, z)
    return { x = x, y = y, z = z }
end

local function distance_squared_3d(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return dx * dx + dy * dy + dz * dz
end

--- @section Geometry

--- Calculates the distance between two points. Uses 3D when either point has a z value.
--- @param a table The first point {x, y} or {x, y, z}.
--- @param b table The second point {x, y} or {x, y, z}.
--- @return number The Euclidean distance.
function m.distance(a, b)
    if a.z ~= nil or b.z ~= nil then
        return math.sqrt(distance_squared_3d(a, b))
    end
    return math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
end

--- Calculates the area of a triangle. Uses 3D when any vertex has a z value.
--- @param p1 table First vertex {x, y} or {x, y, z}.
--- @param p2 table Second vertex {x, y} or {x, y, z}.
--- @param p3 table Third vertex {x, y} or {x, y, z}.
--- @return number The triangle area.
function m.triangle_area(p1, p2, p3)
    if p1.z ~= nil or p2.z ~= nil or p3.z ~= nil then
        local ux, uy, uz = p2.x - p1.x, p2.y - p1.y, (p2.z or 0) - (p1.z or 0)
        local vx, vy, vz = p3.x - p1.x, p3.y - p1.y, (p3.z or 0) - (p1.z or 0)
        local cx, cy, cz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        return 0.5 * math.sqrt(cx * cx + cy * cy + cz * cz)
    end
    return math.abs(cross(p1, p2, p3)) / 2
end

--- @section 2D Geometry

--- Calculates the circumference of a circle.
--- @param radius number The circle radius.
--- @return number The circumference.
function m.circle_circumference(radius)
    return 2 * math.pi * math.abs(radius)
end

--- Calculates the area of a circle.
--- @param radius number The circle radius.
--- @return number The area.
function m.circle_area(radius)
    return math.pi * radius ^ 2
end

--- Determines if a point is inside or on a rectangle.
--- Negative width and height are supported.
--- @param p table The point {x, y}.
--- @param rect table The rectangle {x, y, width, height}.
--- @return boolean
function m.is_point_in_rect(p, rect)
    local min_x, min_y, max_x, max_y = rect_bounds(rect)

    return p.x >= min_x and p.x <= max_x and p.y >= min_y and p.y <= max_y
end

--- Determines if a point lies on a line segment.
--- Tolerance is an absolute distance in coordinate units.
--- @param p table The point {x, y}.
--- @param line_start table Segment start {x, y}.
--- @param line_end table Segment end {x, y}.
--- @param tolerance number|nil Optional distance tolerance.
--- @return boolean
function m.is_point_on_line_segment(p, line_start, line_end, tolerance)
    tolerance = tolerance or EPSILON

    if tolerance < 0 then
        return false
    end

    local dx = line_end.x - line_start.x
    local dy = line_end.y - line_start.y
    local length = math.sqrt(dx * dx + dy * dy)

    if length == 0 then
        return m.distance(p, line_start) <= tolerance
    end

    local area = math.abs(cross(line_start, line_end, p))

    if area > tolerance * length then
        return false
    end

    return within_bounds(p, line_start, line_end, tolerance)
end

--- Projects a point onto an infinite line.
--- Returns the start point if the line has zero length.
--- @param p table Point to project {x, y}.
--- @param p1 table Line start {x, y}.
--- @param p2 table Line end {x, y}.
--- @return table Projected point {x, y}.
function m.project_point_on_line(p, p1, p2)
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    local length_squared = dx * dx + dy * dy

    if length_squared == 0 then
        return point(p1.x, p1.y)
    end

    local t = ((p.x - p1.x) * dx + (p.y - p1.y) * dy) / length_squared

    return point(p1.x + t * dx, p1.y + t * dy)
end

--- Calculates the slope of a line.
--- @param p1 table First point {x, y}.
--- @param p2 table Second point {x, y}.
--- @return number|nil Slope, or nil for a vertical line.
function m.calculate_slope(p1, p2)
    local dx = p2.x - p1.x

    if dx == 0 then
        return nil
    end

    return (p2.y - p1.y) / dx
end

--- Returns the angle from p1 to p2 in degrees.
--- Returns 0 when both points are identical.
--- @param p1 table First point {x, y}.
--- @param p2 table Second point {x, y}.
--- @return number Angle in degrees, in [-180, 180].
function m.angle_between_points(p1, p2)
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y

    if dx == 0 and dy == 0 then
        return 0
    end

    return atan2(dy, dx) * (180 / math.pi)
end

--- Determines if two rectangles overlap or touch.
--- Negative width and height are supported.
--- @param a table First rectangle {x, y, width, height}.
--- @param b table Second rectangle {x, y, width, height}.
--- @return boolean
function m.do_rects_intersect(a, b)
    local a_min_x, a_min_y, a_max_x, a_max_y = rect_bounds(a)
    local b_min_x, b_min_y, b_max_x, b_max_y = rect_bounds(b)

    return a_min_x <= b_max_x and a_max_x >= b_min_x and a_min_y <= b_max_y and a_max_y >= b_min_y
end

--- Determines if two circles intersect or touch.
--- Negative radii are treated as positive.
--- @param c1_center table First center {x, y}.
--- @param c1_radius number First radius.
--- @param c2_center table Second center {x, y}.
--- @param c2_radius number Second radius.
--- @return boolean
function m.do_circles_intersect(c1_center, c1_radius, c2_center, c2_radius)
    local radius_sum = math.abs(c1_radius) + math.abs(c2_radius)
    local dx, dy = c1_center.x - c2_center.x, c1_center.y - c2_center.y
    return dx * dx + dy * dy <= radius_sum * radius_sum
end

--- Determines if a point is inside or on a circle.
--- Negative radius is treated as positive.
--- @param p table Point {x, y}.
--- @param circle_center table Center {x, y}.
--- @param circle_radius number Radius.
--- @return boolean
function m.is_point_in_circle(p, circle_center, circle_radius)
    local dx, dy = p.x - circle_center.x, p.y - circle_center.y
    local radius = math.abs(circle_radius)
    return dx * dx + dy * dy <= radius * radius
end

--- Determines if two line segments intersect or touch.
--- Includes collinear overlaps and endpoint contact.
--- @param a table First segment start.
--- @param b table First segment end.
--- @param c table Second segment start.
--- @param d table Second segment end.
--- @return boolean
function m.do_lines_intersect(a, b, c, d)
    local o1 = cross(a, b, c)
    local o2 = cross(a, b, d)
    local o3 = cross(c, d, a)
    local o4 = cross(c, d, b)

    if ((o1 > 0 and o2 < 0) or (o1 < 0 and o2 > 0))
       and ((o3 > 0 and o4 < 0) or (o3 < 0 and o4 > 0)) then
        return true
    end

    local tolerance_ab = EPSILON * math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
    local tolerance_cd = EPSILON * math.sqrt((d.x - c.x) ^ 2 + (d.y - c.y) ^ 2)

    if math.abs(o1) <= tolerance_ab
       and within_bounds(c, a, b, EPSILON) then
        return true
    end

    if math.abs(o2) <= tolerance_ab
       and within_bounds(d, a, b, EPSILON) then
        return true
    end

    if math.abs(o3) <= tolerance_cd
       and within_bounds(a, c, d, EPSILON) then
        return true
    end

    if math.abs(o4) <= tolerance_cd
       and within_bounds(b, c, d, EPSILON) then
        return true
    end

    return false
end

--- Determines if a line segment intersects or touches a circle.
--- The segment is finite, not an infinite line.
--- @param line_start table Segment start {x, y}.
--- @param line_end table Segment end {x, y}.
--- @param circle_center table Circle center {x, y}.
--- @param circle_radius number Circle radius.
--- @return boolean
function m.line_intersects_circle(line_start, line_end, circle_center, circle_radius)
    local closest = m.closest_point_on_line_segment(circle_center, line_start, line_end)

    return m.distance(closest, circle_center) <= math.abs(circle_radius)
end

--- Determines if a rectangle intersects a line segment.
--- Rectangle edges and corner contact count as intersection.
--- @param rect table Rectangle {x, y, width, height}.
--- @param line_start table Segment start {x, y}.
--- @param line_end table Segment end {x, y}.
--- @return boolean
function m.does_rect_intersect_line(rect, line_start, line_end)
    if m.is_point_in_rect(line_start, rect) or m.is_point_in_rect(line_end, rect) then
        return true
    end

    local min_x, min_y, max_x, max_y = rect_bounds(rect)

    local top_left = point(min_x, min_y)
    local top_right = point(max_x, min_y)
    local bottom_right = point(max_x, max_y)
    local bottom_left = point(min_x, max_y)

    return m.do_lines_intersect(top_left, top_right, line_start, line_end)
        or m.do_lines_intersect(top_right, bottom_right, line_start, line_end)
        or m.do_lines_intersect(bottom_right, bottom_left, line_start, line_end)
        or m.do_lines_intersect(bottom_left, top_left, line_start, line_end)
end

--- Finds the closest point on a segment to a given point.
--- Always returns a new point table.
--- @param p table Point {x, y}.
--- @param line_start table Segment start {x, y}.
--- @param line_end table Segment end {x, y}.
--- @return table Closest point {x, y}.
function m.closest_point_on_line_segment(p, line_start, line_end)
    local dx = line_end.x - line_start.x
    local dy = line_end.y - line_start.y
    local length_squared = dx * dx + dy * dy

    if length_squared == 0 then
        return point(line_start.x, line_start.y)
    end

    local t = ((p.x - line_start.x) * dx + (p.y - line_start.y) * dy) / length_squared

    t = math.max(0, math.min(1, t))

    return point(
        line_start.x + t * dx,
        line_start.y + t * dy
    )
end

--- Determines if a point is inside or on a convex polygon.
--- Vertices must be ordered consistently.
--- @param p table Point {x, y}.
--- @param polygon table Array of points {{x, y}, ...}.
--- @return boolean
function m.is_point_in_convex_polygon(p, polygon)
    local count = #polygon

    if count < 3 then
        return false
    end

    local sign = 0

    for i = 1, count do
        local a = polygon[i]
        local b = polygon[(i % count) + 1]
        local value = cross(a, b, p)

        if math.abs(value) > EPSILON then
            local current_sign = value > 0 and 1 or -1

            if sign ~= 0 and sign ~= current_sign then
                return false
            end

            sign = current_sign
        end
    end

    if sign == 0 then
        return false
    end

    return true
end

--- Rotates a point around a pivot by an angle in degrees.
--- Positive angles rotate counter-clockwise in standard Cartesian coordinates.
--- @param p table Point {x, y}.
--- @param pivot table Pivot {x, y}.
--- @param angle_degrees number Rotation angle in degrees.
--- @return table Rotated point {x, y}.
function m.rotate_point_around_point(p, pivot, angle_degrees)
    local angle = math.rad(angle_degrees)
    local sin_angle = math.sin(angle)
    local cos_angle = math.cos(angle)
    local dx = p.x - pivot.x
    local dy = p.y - pivot.y

    return point(cos_angle * dx - sin_angle * dy + pivot.x, sin_angle * dx + cos_angle * dy + pivot.y)
end

--- @section 3D Geometry

--- Returns the midpoint between two points.
--- @param a table The first point {x, y, z}.
--- @param b table The second point {x, y, z}.
--- @return table The midpoint point {x, y, z}.
function m.midpoint(a, b)
    return point3(a.x + (b.x - a.x) / 2, a.y + (b.y - a.y) / 2, a.z + (b.z - a.z) / 2)
end

--- Determines if a point is inside or on a box. Negative dimensions are supported.
--- @param p table The point {x, y, z}.
--- @param box table The box {x, y, z, width, height, depth}.
--- @return boolean
function m.is_point_in_box(p, box)
    local x2, y2, z2 = box.x + box.width, box.y + box.height, box.z + box.depth
    return p.x >= math.min(box.x, x2) and p.x <= math.max(box.x, x2) and p.y >= math.min(box.y, y2) and p.y <= math.max(box.y, y2) and p.z >= math.min(box.z, z2) and p.z <= math.max(box.z, z2)
end

--- Calculates the angle at the second point in degrees. Returns nil for a zero-length arm.
--- @param p1 table First point {x, y, z}.
--- @param p2 table Vertex/center point {x, y, z}.
--- @param p3 table Third point {x, y, z}.
--- @return number|nil Angle in degrees, or nil.
function m.angle_between_three_points(p1, p2, p3)
    local ax, ay, az = p1.x - p2.x, p1.y - p2.y, p1.z - p2.z
    local bx, by, bz = p3.x - p2.x, p3.y - p2.y, p3.z - p2.z
    local a_length = math.sqrt(ax * ax + ay * ay + az * az)
    local b_length = math.sqrt(bx * bx + by * by + bz * bz)
    if a_length == 0 or b_length == 0 then return nil end
    local cosine = (ax * bx + ay * by + az * bz) / (a_length * b_length)
    return math.deg(math.acos(math.max(-1, math.min(1, cosine))))
end

--- Determines if a point is inside or on a sphere. Negative radii are treated as positive.
--- @param p table Point {x, y, z}.
--- @param sphere_center table Sphere center {x, y, z}.
--- @param sphere_radius number Sphere radius.
--- @return boolean
function m.is_point_in_sphere(p, sphere_center, sphere_radius)
    local radius = math.abs(sphere_radius)
    return distance_squared_3d(p, sphere_center) <= radius * radius
end

--- Determines if two spheres intersect or touch. Negative radii are treated as positive.
--- @param s1_center table First sphere center {x, y, z}.
--- @param s1_radius number First sphere radius.
--- @param s2_center table Second sphere center {x, y, z}.
--- @param s2_radius number Second sphere radius.
--- @return boolean
function m.do_spheres_intersect(s1_center, s1_radius, s2_center, s2_radius)
    local radius_sum = math.abs(s1_radius) + math.abs(s2_radius)
    return distance_squared_3d(s1_center, s2_center) <= radius_sum * radius_sum
end

--- Calculates the shortest distance from a point to a plane; nil for a zero-length normal.
--- @param p table Point {x, y, z}.
--- @param plane_point table Point on the plane {x, y, z}.
--- @param plane_normal table Plane normal vector {x, y, z}.
--- @return number|nil Distance, or nil if normal length is zero.
function m.distance_point_to_plane(p, plane_point, plane_normal)
    local nx, ny, nz = plane_normal.x, plane_normal.y, plane_normal.z
    local normal_length = math.sqrt(nx * nx + ny * ny + nz * nz)
    if normal_length == 0 then return nil end
    local dx, dy, dz = p.x - plane_point.x, p.y - plane_point.y, p.z - plane_point.z
    return math.abs(dx * nx + dy * ny + dz * nz) / normal_length
end

--- Normalizes a vector. A zero-length vector returns a zero vector.
--- @param v table Vector {x, y, z}.
--- @return table Normalized vector {x, y, z}.
function m.normalize_vector(v)
    local length = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if length == 0 then return point3(0, 0, 0) end
    return point3(v.x / length, v.y / length, v.z / length)
end

return m