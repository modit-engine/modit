--- @module geometry3d
--- @file src/engine/sdk/shared/geometry3d.lua
--- @description Handles 3D geometry functions and spatial primitives.

--- @section Initialisation

local m = {}

--- @section Helper Functions

local function point3(x, y, z)
    return { x = x, y = y, z = z }
end

local function distance_squared_3d(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

--- @section 3D Functions

--- Calculates the distance between two points.
--- @param a table The first point {x, y, z}.
--- @param b table The second point {x, y, z}.
--- @return number The Euclidean distance.
function m.distance(a, b)
    return math.sqrt(distance_squared_3d(a, b))
end

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

--- Calculates the area of a triangle.
--- @param p1 table First vertex {x, y, z}.
--- @param p2 table Second vertex {x, y, z}.
--- @param p3 table Third vertex {x, y, z}.
--- @return number The triangle area.
function m.triangle_area(p1, p2, p3)
    local ux, uy, uz = p2.x - p1.x, p2.y - p1.y, p2.z - p1.z
    local vx, vy, vz = p3.x - p1.x, p3.y - p1.y, p3.z - p1.z
    local cx, cy, cz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    return 0.5 * math.sqrt(cx * cx + cy * cy + cz * cz)
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