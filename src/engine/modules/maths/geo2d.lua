--- @module maths.geometry_2d
--- @description Handles all 2D geometry functions.

local m = {}

-- Epsilon for floating-point comparisons.
local EPSILON = 1e-10

-- Returns a fresh point table.
local function point(x, y)
    return { x = x, y = y }
end

-- Supports Lua versions exposing either math.atan2 or
-- the two-argument math.atan(y, x).
local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    return math.atan(y, x)
end

-- Normalizes rectangle bounds, including negative dimensions.
local function rect_bounds(rect)
    local x2 = rect.x + rect.width
    local y2 = rect.y + rect.height

    return math.min(rect.x, x2),
           math.min(rect.y, y2),
           math.max(rect.x, x2),
           math.max(rect.y, y2)
end

-- 2D cross product of vectors AB and AC.
local function cross(a, b, c)
    return (b.x - a.x) * (c.y - a.y)
         - (b.y - a.y) * (c.x - a.x)
end

-- Checks whether a point lies within a segment's bounding box.
local function within_bounds(p, a, b, tolerance)
    return p.x >= math.min(a.x, b.x) - tolerance
       and p.x <= math.max(a.x, b.x) + tolerance
       and p.y >= math.min(a.y, b.y) - tolerance
       and p.y <= math.max(a.y, b.y) + tolerance
end

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

--- Calculates the area of a triangle using its 2D vertices.
--- @param p1 table First vertex {x, y}.
--- @param p2 table Second vertex {x, y}.
--- @param p3 table Third vertex {x, y}.
--- @return number The triangle area.
function m.triangle_area(p1, p2, p3)
    return math.abs(cross(p1, p2, p3)) / 2
end

--- Calculates the distance between two 2D points.
--- @param p1 table The first point {x, y}.
--- @param p2 table The second point {x, y}.
--- @return number The Euclidean distance.
function m.distance_2d(p1, p2)
    return math.sqrt(
        (p2.x - p1.x) ^ 2 +
        (p2.y - p1.y) ^ 2
    )
end

--- Determines if a point is inside or on a rectangle.
--- Negative width and height are supported.
--- @param p table The point {x, y}.
--- @param rect table The rectangle {x, y, width, height}.
--- @return boolean
function m.is_point_in_rect(p, rect)
    local min_x, min_y, max_x, max_y = rect_bounds(rect)

    return p.x >= min_x and p.x <= max_x
       and p.y >= min_y and p.y <= max_y
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
        return m.distance_2d(p, line_start) <= tolerance
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

    local t = (
        (p.x - p1.x) * dx +
        (p.y - p1.y) * dy
    ) / length_squared

    return point(
        p1.x + t * dx,
        p1.y + t * dy
    )
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

    return a_min_x <= b_max_x and a_max_x >= b_min_x
       and a_min_y <= b_max_y and a_max_y >= b_min_y
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

    return m.distance_2d(c1_center, c2_center) <= radius_sum
end

--- Determines if a point is inside or on a circle.
--- Negative radius is treated as positive.
--- @param p table Point {x, y}.
--- @param circle_center table Center {x, y}.
--- @param circle_radius number Radius.
--- @return boolean
function m.is_point_in_circle(p, circle_center, circle_radius)
    return m.distance_2d(p, circle_center) <= math.abs(circle_radius)
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

    if math.abs(o1) <= EPSILON
       and within_bounds(c, a, b, EPSILON) then
        return true
    end

    if math.abs(o2) <= EPSILON
       and within_bounds(d, a, b, EPSILON) then
        return true
    end

    if math.abs(o3) <= EPSILON
       and within_bounds(a, c, d, EPSILON) then
        return true
    end

    if math.abs(o4) <= EPSILON
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
    local closest = m.closest_point_on_line_segment(
        circle_center,
        line_start,
        line_end
    )

    return m.distance_2d(closest, circle_center) <= math.abs(circle_radius)
end

--- Determines if a rectangle intersects a line segment.
--- Rectangle edges and corner contact count as intersection.
--- @param rect table Rectangle {x, y, width, height}.
--- @param line_start table Segment start {x, y}.
--- @param line_end table Segment end {x, y}.
--- @return boolean
function m.does_rect_intersect_line(rect, line_start, line_end)
    if m.is_point_in_rect(line_start, rect)
       or m.is_point_in_rect(line_end, rect) then
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

    local t = (
        (p.x - line_start.x) * dx +
        (p.y - line_start.y) * dy
    ) / length_squared

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

    -- Reject a fully degenerate polygon (all vertices collinear).
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
function m.rotate_point_around_point_2d(p, pivot, angle_degrees)
    local angle = math.rad(angle_degrees)
    local sin_angle = math.sin(angle)
    local cos_angle = math.cos(angle)
    local dx = p.x - pivot.x
    local dy = p.y - pivot.y

    return point(
        cos_angle * dx - sin_angle * dy + pivot.x,
        sin_angle * dx + cos_angle * dy + pivot.y
    )
end

return m