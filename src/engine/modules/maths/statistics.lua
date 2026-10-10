--- @module maths.statistics
--- @description Statistical analysis functions for datasets.

local m = {}

--- Validates a finite number.
--- @param value number Value to validate.
--- @param name string Parameter name.
local function validate_finite(value, name)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        error(name .. " must be a finite number", 3)
    end
end

--- Validates a non-empty dense array of finite numbers.
--- @param numbers table Dataset to validate.
local function validate_numbers(numbers)
    if type(numbers) ~= "table" or #numbers == 0 then
        error("Input must be a non-empty array of numbers")
    end

    for i = 1, #numbers do
        validate_finite(numbers[i], "Element at index " .. i)
    end
end

--- Validates two non-empty datasets of equal length.
--- @param x table First dataset.
--- @param y table Second dataset.
local function validate_paired(x, y)
    validate_numbers(x)
    validate_numbers(y)

    if #x ~= #y then
        error("Datasets must have equal lengths")
    end
end

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
function m.standard_deviation(numbers, population)
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

return m