--- @module maths.geometry_3d
--- @description Handles all 3D geometry functions.

local m = {}

--- Calculates the distance between two 3D points.
--- @param start_coords table {x, y, z} Starting coordinates.
--- @param end_coords table {x, y, z} Ending coordinates.
--- @return number Euclidean distance.
function m.distance_3d(start_coords, end_coords)
    local dx = end_coords.x - start_coords.x
    local dy = end_coords.y - start_coords.y
    local dz = end_coords.z - start_coords.z

    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- Returns the midpoint between two 3D points.
--- @param p1 table First point {x, y, z}.
--- @param p2 table Second point {x, y, z}.
--- @return table Midpoint {x, y, z}.
function m.midpoint(p1, p2)
    return {
        x = p1.x + (p2.x - p1.x) / 2,
        y = p1.y + (p2.y - p1.y) / 2,
        z = p1.z + (p2.z - p1.z) / 2
    }
end

--- Determines if a point is inside or on a 3D box.
--- Negative dimensions are supported.
--- @param p table Point {x, y, z}.
--- @param box table Box {x, y, z, width, height, depth}.
--- @return boolean
function m.is_point_in_box(p, box)
    local x1 = box.x
    local y1 = box.y
    local z1 = box.z

    local x2 = x1 + box.width
    local y2 = y1 + box.height
    local z2 = z1 + box.depth

    return p.x >= math.min(x1, x2)
       and p.x <= math.max(x1, x2)
       and p.y >= math.min(y1, y2)
       and p.y <= math.max(y1, y2)
       and p.z >= math.min(z1, z2)
       and p.z <= math.max(z1, z2)
end

--- Calculates the angle between three 3D points.
--- p2 is the vertex of the angle.
--- Returns nil if either arm has zero length.
--- @param p1 table First point {x, y, z}.
--- @param p2 table Vertex point {x, y, z}.
--- @param p3 table Third point {x, y, z}.
--- @return number|nil Angle in degrees [0, 180], or nil.
function m.angle_between_3_points(p1, p2, p3)
    local ax = p1.x - p2.x
    local ay = p1.y - p2.y
    local az = p1.z - p2.z

    local bx = p3.x - p2.x
    local by = p3.y - p2.y
    local bz = p3.z - p2.z

    local a_length = math.sqrt(ax * ax + ay * ay + az * az)
    local b_length = math.sqrt(bx * bx + by * by + bz * bz)

    if a_length == 0 or b_length == 0 then
        return nil
    end

    local dot = ax * bx + ay * by + az * bz
    local cosine = dot / (a_length * b_length)

    -- Protect acos against floating-point rounding errors.
    cosine = math.max(-1, math.min(1, cosine))

    return math.deg(math.acos(cosine))
end

--- Calculates the area of a triangle in 3D space.
--- @param p1 table First vertex {x, y, z}.
--- @param p2 table Second vertex {x, y, z}.
--- @param p3 table Third vertex {x, y, z}.
--- @return number Triangle area.
function m.triangle_area_3d(p1, p2, p3)
    local ux = p2.x - p1.x
    local uy = p2.y - p1.y
    local uz = p2.z - p1.z

    local vx = p3.x - p1.x
    local vy = p3.y - p1.y
    local vz = p3.z - p1.z

    local cx = uy * vz - uz * vy
    local cy = uz * vx - ux * vz
    local cz = ux * vy - uy * vx

    return 0.5 * math.sqrt(cx * cx + cy * cy + cz * cz)
end

--- Determines if a point is inside or on a sphere.
--- Negative radii are treated as positive.
--- @param p table Point {x, y, z}.
--- @param sphere_center table Sphere center {x, y, z}.
--- @param sphere_radius number Sphere radius.
--- @return boolean
function m.is_point_in_sphere(p, sphere_center, sphere_radius)
    local dx = p.x - sphere_center.x
    local dy = p.y - sphere_center.y
    local dz = p.z - sphere_center.z
    local radius = math.abs(sphere_radius)

    return dx * dx + dy * dy + dz * dz <= radius * radius
end

--- Determines if two spheres intersect or touch.
--- Negative radii are treated as positive.
--- @param s1_center table First center {x, y, z}.
--- @param s1_radius number First radius.
--- @param s2_center table Second center {x, y, z}.
--- @param s2_radius number Second radius.
--- @return boolean
function m.do_spheres_intersect(
    s1_center, s1_radius,
    s2_center, s2_radius
)
    local dx = s2_center.x - s1_center.x
    local dy = s2_center.y - s1_center.y
    local dz = s2_center.z - s1_center.z

    local radius_sum = math.abs(s1_radius) + math.abs(s2_radius)

    return dx * dx + dy * dy + dz * dz <= radius_sum * radius_sum
end

--- Calculates the shortest distance from a point to a plane.
--- The plane normal does not need to be normalized.
--- Returns nil if the normal has zero length.
--- @param p table Point {x, y, z}.
--- @param plane_point table Point on the plane {x, y, z}.
--- @param plane_normal table Plane normal {x, y, z}.
--- @return number|nil Absolute distance, or nil for invalid normal.
function m.distance_point_to_plane(p, plane_point, plane_normal)
    local nx = plane_normal.x
    local ny = plane_normal.y
    local nz = plane_normal.z

    local normal_length = math.sqrt(nx * nx + ny * ny + nz * nz)

    if normal_length == 0 then
        return nil
    end

    local dx = p.x - plane_point.x
    local dy = p.y - plane_point.y
    local dz = p.z - plane_point.z

    local signed_distance = dx * nx + dy * ny + dz * nz

    return math.abs(signed_distance) / normal_length
end

--- Normalizes a 3D vector.
--- A zero-length vector returns a zero vector.
--- @param v table Vector {x, y, z}.
--- @return table Normalized vector {x, y, z}.
function m.normalize_vector(v)
    local length = math.sqrt(
        v.x * v.x +
        v.y * v.y +
        v.z * v.z
    )

    if length == 0 then
        return { x = 0, y = 0, z = 0 }
    end

    return {
        x = v.x / length,
        y = v.y / length,
        z = v.z / length
    }
end

return m