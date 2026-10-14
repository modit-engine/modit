--- @file src/engine/tests/maths.lua
--- @description Maths test: maths, geometry, vector and mat4. Results are shown on screen and logged to the console.

return function(modit)

    local maths, geometry, vector, mat4 = modit.maths, modit.geometry, modit.vector, modit.mat4

    if not (maths and geometry and vector and mat4) then
        error("maths test: wire engine.maths, engine.geometry, engine.vector and engine.mat4 in engine/init.lua")
    end

    local vec2, vec3, vec4 = vector.vec2, vector.vec3, vector.vec4

    --- @section Harness

    local sections, failures = {}, {}
    local current

    local function section(name)
        current = { name = name, pass = 0, fail = 0 }
        sections[#sections + 1] = current
    end

    local function record(name, ok, detail)
        if ok then
            current.pass = current.pass + 1
        else
            current.fail = current.fail + 1
            failures[#failures + 1] = { section = current.name, name = name, detail = detail or "" }
        end
    end

    local function near(a, b, tol)
        return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1e-6)
    end

    local function first_line(err)
        return tostring(err):match("[^\n]+") or ""
    end

    local function eq(name, fn, want, tol)
        local ok, got = pcall(fn)
        if not ok then return record(name, false, "error: " .. first_line(got)) end
        record(name, near(got, want, tol), ("got %s, want %s"):format(tostring(got), tostring(want)))
    end

    local function is_true(name, fn)
        local ok, got = pcall(fn)
        if not ok then return record(name, false, "error: " .. first_line(got)) end
        record(name, got == true, "got " .. tostring(got))
    end

    local function is_false(name, fn)
        local ok, got = pcall(fn)
        if not ok then return record(name, false, "error: " .. first_line(got)) end
        record(name, got == false, "got " .. tostring(got))
    end

    local function is_nil(name, fn)
        local ok, got = pcall(fn)
        if not ok then return record(name, false, "error: " .. first_line(got)) end
        record(name, got == nil, "got " .. tostring(got))
    end

    local function throws(name, fn)
        local ok = pcall(fn)
        record(name, not ok, "expected an error, none raised")
    end

    local function comp(t, key, index)
        if type(t) ~= "table" then return nil end
        local value = t[key]
        if value == nil then value = t[index] end
        return value
    end

    local function pt(name, fn, x, y, z, w)
        local ok, got = pcall(fn)
        if not ok then return record(name, false, "error: " .. first_line(got)) end
        if type(got) ~= "table" then return record(name, false, "got " .. tostring(got)) end

        local gx, gy, gz, gw = comp(got, "x", 1), comp(got, "y", 2), comp(got, "z", 3), comp(got, "w", 4)
        local good = near(gx, x) and near(gy, y) and (z == nil or near(gz, z)) and (w == nil or near(gw, w))
        record(name, good, ("got %s, %s, %s, %s"):format(tostring(gx), tostring(gy), tostring(gz), tostring(gw)))
    end

    --- @section Shape Helpers (both named and indexed fields, so either geometry format works)

    local function p2(x, y) return { x = x, y = y, [1] = x, [2] = y } end
    local function p3(x, y, z) return { x = x, y = y, z = z, [1] = x, [2] = y, [3] = z } end
    local function rect(x, y, w, h) return { x = x, y = y, w = w, h = h, width = w, height = h } end

    local function box(x, y, z, w, h, d)
        return { x = x, y = y, z = z, width = w, height = h, depth = d }
    end

    local function matrix_near(a, b)
        local ra, rb = a:raw(), b:raw()
        for i = 1, 16 do
            if not near(ra[i], rb[i], 1e-6) then return false end
        end
        return true
    end

    --- @section maths: core

    section("maths core")

    eq("round(3.14159, 2)", function() return maths.round(3.14159, 2) end, 3.14)
    eq("round(2.6)", function() return maths.round(2.6) end, 3)
    eq("clamp above", function() return maths.clamp(5, 0, 3) end, 3)
    eq("clamp below", function() return maths.clamp(-1, 0, 3) end, 0)
    eq("clamp inside", function() return maths.clamp(2, 0, 3) end, 2)
    eq("clamp swapped bounds", function() return maths.clamp(5, 3, 0) end, 3)
    eq("lerp half", function() return maths.lerp(0, 10, 0.5) end, 5)
    eq("lerp unclamped", function() return maths.lerp(0, 10, 2) end, 20)
    eq("factorial(5)", function() return maths.factorial(5) end, 120)
    eq("factorial(0)", function() return maths.factorial(0) end, 1)
    eq("deg_to_rad(180)", function() return maths.deg_to_rad(180) end, math.pi)
    eq("rad_to_deg(pi)", function() return maths.rad_to_deg(math.pi) end, 180)

    --- @section maths: easing

    section("maths easing")

    for _, name in ipairs({ "linear", "in_quad", "out_quad", "in_out_quad", "in_cubic", "out_cubic", "in_out_cubic", "out_elastic" }) do
        local fn_name = "ease_" .. name
        eq(fn_name .. "(0) = 0", function() return maths[fn_name](0) end, 0)
        eq(fn_name .. "(1) = 1", function() return maths[fn_name](1) end, 1)
    end

    eq("ease_linear(0.3)", function() return maths.ease_linear(0.3) end, 0.3)
    eq("ease_in_quad(0.5)", function() return maths.ease_in_quad(0.5) end, 0.25)
    eq("ease_out_quad(0.5)", function() return maths.ease_out_quad(0.5) end, 0.75)
    eq("ease_in_out_quad(0.5)", function() return maths.ease_in_out_quad(0.5) end, 0.5)
    eq("ease_in_cubic(0.5)", function() return maths.ease_in_cubic(0.5) end, 0.125)
    eq("ease_out_cubic(0.5)", function() return maths.ease_out_cubic(0.5) end, 0.875)
    eq("ease_in_out_cubic(0.5)", function() return maths.ease_in_out_cubic(0.5) end, 0.5)

    --- @section maths: statistics

    section("maths statistics")

    local data = { 2, 4, 4, 4, 5, 5, 7, 9 }

    eq("mean", function() return maths.mean(data) end, 5)
    eq("median", function() return maths.median(data) end, 4.5)
    eq("mode", function() return maths.mode(data) end, 4)
    is_nil("mode tie returns nil", function() return maths.mode({ 1, 2 }) end)
    eq("variance population", function() return maths.variance(data, true) end, 4)
    eq("variance sample", function() return maths.variance(data) end, 32 / 7, 1e-5)
    eq("std_dev population", function() return maths.std_dev(data, true) end, 2)
    eq("std_dev sample", function() return maths.std_dev(data) end, math.sqrt(32 / 7), 1e-5)
    eq("range", function() return maths.range(data) end, 7)
    eq("min", function() return maths.min(data) end, 2)
    eq("max", function() return maths.max(data) end, 9)
    eq("sum", function() return maths.sum(data) end, 40)
    eq("quantile 0", function() return maths.quantile(data, 0) end, 2)
    eq("quantile 0.5", function() return maths.quantile(data, 0.5) end, 4.5)
    eq("quantile 1", function() return maths.quantile(data, 1) end, 9)
    eq("quantile 0.25 of 1..5", function() return maths.quantile({ 1, 2, 3, 4, 5 }, 0.25) end, 2)
    eq("correlation +1", function() return maths.correlation({ 1, 2, 3 }, { 2, 4, 6 }) end, 1)
    eq("correlation -1", function() return maths.correlation({ 1, 2, 3 }, { 6, 4, 2 }) end, -1)
    eq("covariance population", function() return maths.covariance({ 1, 2, 3 }, { 2, 4, 6 }, true) end, 4 / 3, 1e-5)
    eq("covariance sample", function() return maths.covariance({ 1, 2, 3 }, { 2, 4, 6 }) end, 2)

    do
        local points = { p2(0, 1), p2(1, 3), p2(2, 5), p2(3, 7) } -- y = 2x + 1
        local ok, a, b = pcall(maths.linear_regression, points)
        local slope = type(a) == "table" and (a.slope or a.m or a[1]) or a
        local intercept = type(a) == "table" and (a.intercept or a.b or a[2]) or b
        record("linear_regression slope", ok and near(slope, 2), ok and ("got " .. tostring(slope)) or first_line(a))
        record("linear_regression intercept", ok and near(intercept, 1), ok and ("got " .. tostring(intercept)) or first_line(a))
    end

    --- @section maths: random

    section("maths random")

    do
        maths.set_seed(123)
        local first = {}
        for i = 1, 5 do first[i] = maths.random_between(0, 1) end
        maths.set_seed(123)
        local same = true
        for i = 1, 5 do
            if not near(first[i], maths.random_between(0, 1), 0) then same = false end
        end
        record("set_seed is reproducible", same, "sequences differ after reseed")
    end

    is_true("random_between in range", function()
        for _ = 1, 200 do
            local v = maths.random_between(5, 6)
            if v < 5 or v > 6 then return false end
        end
        return true
    end)

    is_true("random_int inclusive and whole", function()
        local seen_min, seen_max = false, false
        for _ = 1, 500 do
            local v = maths.random_int(1, 3)
            if v ~= math.floor(v) or v < 1 or v > 3 then return false end
            if v == 1 then seen_min = true end
            if v == 3 then seen_max = true end
        end
        return seen_min and seen_max
    end)

    eq("random_between custom rand_func", function()
        return maths.random_between(0, 10, function() return 0.5 end)
    end, 5)

    is_true("random_chance(1) always", function() return maths.random_chance(1) == true end)
    is_true("random_chance(0) never", function() return maths.random_chance(0) == false end)
    is_true("random_percent_chance(100)", function() return maths.random_percent_chance(100) == true end)
    is_true("random_percent_chance(0)", function() return maths.random_percent_chance(0) == false end)
    eq("random_choice single item", function() return maths.random_choice({ 7 }) end, 7)

    is_true("random_weighted_choice honours weights", function()
        for _ = 1, 50 do
            if maths.random_weighted_choice({ a = 1, b = 0 }) ~= "a" then return false end
        end
        return true
    end)

    is_true("random_shuffle keeps every item", function()
        local list = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
        maths.random_shuffle(list)
        local sum = 0
        for _, v in ipairs(list) do sum = sum + v end
        return #list == 10 and sum == 55
    end)

    eq("random_normal mean near 0", function()
        local sum = 0
        for _ = 1, 2000 do sum = sum + maths.random_normal(0, 1) end
        return sum / 2000
    end, 0, 0.15)

    eq("random_exponential(2) mean near 0.5", function()
        local sum = 0
        for _ = 1, 2000 do sum = sum + maths.random_exponential(2) end
        return sum / 2000
    end, 0.5, 0.1)

    is_true("random_uniform in range", function()
        for _ = 1, 200 do
            local v = maths.random_uniform(2, 3)
            if v < 2 or v > 3 then return false end
        end
        return true
    end)

    --- @section geometry: 2D

    section("geometry 2D")

    eq("circle_circumference(1)", function() return geometry.circle_circumference(1) end, 2 * math.pi)
    eq("circle_area(2)", function() return geometry.circle_area(2) end, 4 * math.pi)
    eq("triangle_area 3-4-5", function() return geometry.triangle_area(p2(0, 0), p2(4, 0), p2(0, 3)) end, 6)
    eq("distance_2d 3-4-5", function() return geometry.distance_2d(p2(0, 0), p2(3, 4)) end, 5)
    is_true("is_point_in_rect inside", function() return geometry.is_point_in_rect(p2(5, 5), rect(0, 0, 10, 10)) end)
    is_true("is_point_in_rect on edge", function() return geometry.is_point_in_rect(p2(10, 5), rect(0, 0, 10, 10)) end)
    is_false("is_point_in_rect outside", function() return geometry.is_point_in_rect(p2(15, 5), rect(0, 0, 10, 10)) end)
    is_true("is_point_on_line_segment on", function() return geometry.is_point_on_line_segment(p2(5, 5), p2(0, 0), p2(10, 10), 0.001) end)
    is_false("is_point_on_line_segment off", function() return geometry.is_point_on_line_segment(p2(5, 6), p2(0, 0), p2(10, 10), 0.001) end)
    pt("project_point_on_line", function() return geometry.project_point_on_line(p2(5, 0), p2(0, 0), p2(10, 10)) end, 2.5, 2.5)
    eq("calculate_slope", function() return geometry.calculate_slope(p2(0, 0), p2(2, 4)) end, 2)
    is_nil("calculate_slope vertical is nil", function() return geometry.calculate_slope(p2(1, 0), p2(1, 5)) end)
    eq("angle_between_points up", function() return geometry.angle_between_points(p2(0, 0), p2(0, 1)) end, 90)
    eq("angle_between_points right", function() return geometry.angle_between_points(p2(0, 0), p2(1, 0)) end, 0)
    is_true("do_rects_intersect overlap", function() return geometry.do_rects_intersect(rect(0, 0, 10, 10), rect(5, 5, 10, 10)) end)
    is_true("do_rects_intersect touching", function() return geometry.do_rects_intersect(rect(0, 0, 10, 10), rect(10, 0, 10, 10)) end)
    is_false("do_rects_intersect apart", function() return geometry.do_rects_intersect(rect(0, 0, 10, 10), rect(20, 20, 5, 5)) end)
    is_true("do_circles_intersect overlap", function() return geometry.do_circles_intersect(p2(0, 0), 1, p2(1.5, 0), 1) end)
    is_true("do_circles_intersect touching", function() return geometry.do_circles_intersect(p2(0, 0), 1, p2(2, 0), 1) end)
    is_false("do_circles_intersect apart", function() return geometry.do_circles_intersect(p2(0, 0), 1, p2(5, 0), 1) end)
    is_true("is_point_in_circle inside", function() return geometry.is_point_in_circle(p2(0.5, 0.5), p2(0, 0), 1) end)
    is_false("is_point_in_circle outside", function() return geometry.is_point_in_circle(p2(2, 0), p2(0, 0), 1) end)
    is_true("do_lines_intersect cross", function() return geometry.do_lines_intersect(p2(0, 0), p2(10, 10), p2(0, 10), p2(10, 0)) end)
    is_false("do_lines_intersect parallel", function() return geometry.do_lines_intersect(p2(0, 0), p2(10, 0), p2(0, 1), p2(10, 1)) end)
    is_true("line_intersects_circle through", function() return geometry.line_intersects_circle(p2(-5, 0), p2(5, 0), p2(0, 0), 1) end)
    is_false("line_intersects_circle miss", function() return geometry.line_intersects_circle(p2(-5, 3), p2(5, 3), p2(0, 0), 1) end)
    is_true("does_rect_intersect_line through", function() return geometry.does_rect_intersect_line(rect(0, 0, 10, 10), p2(-5, 5), p2(15, 5)) end)
    is_false("does_rect_intersect_line miss", function() return geometry.does_rect_intersect_line(rect(0, 0, 10, 10), p2(-5, 20), p2(15, 20)) end)
    pt("closest_point_on_line_segment middle", function() return geometry.closest_point_on_line_segment(p2(5, 5), p2(0, 0), p2(10, 0)) end, 5, 0)
    pt("closest_point_on_line_segment clamped", function() return geometry.closest_point_on_line_segment(p2(15, 3), p2(0, 0), p2(10, 0)) end, 10, 0)

    do
        local square = { p2(0, 0), p2(4, 0), p2(4, 4), p2(0, 4) }
        is_true("is_point_in_convex_polygon inside", function() return geometry.is_point_in_convex_polygon(p2(1, 1), square) end)
        is_false("is_point_in_convex_polygon outside", function() return geometry.is_point_in_convex_polygon(p2(5, 5), square) end)
    end

    pt("rotate_point_around_point_2d", function() return geometry.rotate_point_around_point_2d(p2(2, 0), p2(1, 0), 90) end, 1, 1)

    --- @section geometry: 3D

    section("geometry 3D")

    eq("distance_3d", function() return geometry.distance_3d(p3(0, 0, 0), p3(1, 2, 2)) end, 3)
    pt("midpoint_3d", function() return geometry.midpoint_3d(p3(0, 0, 0), p3(2, 4, 6)) end, 1, 2, 3)
    is_true("is_point_in_box_3d inside", function() return geometry.is_point_in_box_3d(p3(1, 1, 1), box(0, 0, 0, 2, 2, 2)) end)
    is_false("is_point_in_box_3d outside", function() return geometry.is_point_in_box_3d(p3(3, 1, 1), box(0, 0, 0, 2, 2, 2)) end)
    is_true("is_point_in_box_3d negative size", function() return geometry.is_point_in_box_3d(p3(-1, -1, -1), box(0, 0, 0, -2, -2, -2)) end)
    eq("angle_between_three_points_3d", function() return geometry.angle_between_three_points_3d(p3(1, 0, 0), p3(0, 0, 0), p3(0, 1, 0)) end, 90)
    eq("triangle_area_3d", function() return geometry.triangle_area_3d(p3(0, 0, 0), p3(4, 0, 0), p3(0, 3, 0)) end, 6)
    is_true("is_point_in_sphere inside", function() return geometry.is_point_in_sphere(p3(1, 0, 0), p3(0, 0, 0), 2) end)
    is_false("is_point_in_sphere outside", function() return geometry.is_point_in_sphere(p3(3, 0, 0), p3(0, 0, 0), 2) end)
    is_true("do_spheres_intersect overlap", function() return geometry.do_spheres_intersect(p3(0, 0, 0), 1, p3(1.5, 0, 0), 1) end)
    is_false("do_spheres_intersect apart", function() return geometry.do_spheres_intersect(p3(0, 0, 0), 1, p3(5, 0, 0), 1) end)
    eq("distance_point_to_plane_3d", function() return math.abs(geometry.distance_point_to_plane_3d(p3(0, 5, 0), p3(0, 0, 0), p3(0, 1, 0))) end, 5)
    pt("normalize_vector_3d", function() return geometry.normalize_vector_3d(p3(0, 0, 5)) end, 0, 0, 1)

    --- @section vector

    section("vector")

    is_true("vector2 is vec2 alias", function() return vector.vector2 == vector.vec2 end)
    is_true("vector3 is vec3 alias", function() return vector.vector3 == vector.vec3 end)
    is_true("vector4 is vec4 alias", function() return vector.vector4 == vector.vec4 end)

    pt("vec2 defaults", function() return vec2() end, 0, 0)
    pt("vec3 defaults", function() return vec3() end, 0, 0, 0)
    pt("vec4 defaults", function() return vec4() end, 0, 0, 0, 0)
    pt("vec3.new", function() return vec3.new(1, 2, 3) end, 1, 2, 3)

    pt("add", function() return vec3(1, 2, 3):add(vec3(4, 5, 6)) end, 5, 7, 9)
    pt("sub", function() return vec3(4, 5, 6):sub(vec3(1, 2, 3)) end, 3, 3, 3)
    pt("scale", function() return vec2(1, 2):scale(3) end, 3, 6)
    eq("dot", function() return vec3(1, 2, 3):dot(vec3(4, 5, 6)) end, 32)
    eq("cross 2D", function() return vec2(1, 0):cross(vec2(0, 1)) end, 1)
    pt("cross 3D", function() return vec3(1, 0, 0):cross(vec3(0, 1, 0)) end, 0, 0, 1)
    eq("length", function() return vec2(3, 4):length() end, 5)
    eq("length_squared", function() return vec3(1, 2, 2):length_squared() end, 9)
    eq("distance", function() return vec3(0, 0, 0):distance(vec3(2, 3, 6)) end, 7)
    eq("distance_squared", function() return vec3(0, 0, 0):distance_squared(vec3(2, 3, 6)) end, 49)
    pt("normalize", function() return vec2(0, 5):normalize() end, 0, 1)
    pt("normalize vec4", function() return vec4(0, 0, 0, 2):normalize() end, 0, 0, 0, 1)
    is_true("normalize zero gives zero", function() return vec3(0, 0, 0):normalize():is_zero() end)
    is_true("is_zero true", function() return vec2(0, 0):is_zero() end)
    is_false("is_zero false", function() return vec2(1, 0):is_zero() end)
    pt("lerp", function() return vec2(0, 0):lerp(vec2(10, 20), 0.5) end, 5, 10)
    eq("angle", function() return vec2(0, 1):angle() end, math.pi / 2)
    pt("rotate", function() return vec2(1, 0):rotate(math.pi / 2) end, 0, 1)
    pt("perpendicular", function() return vec2(1, 0):perpendicular() end, 0, 1)
    pt("vec4:xyz", function() return vec4(1, 2, 3, 4):xyz() end, 1, 2, 3)

    is_true("clone is independent", function()
        local a = vec2(1, 2)
        local c = a:clone()
        c.x = 99
        return a.x == 1
    end)

    is_true("set is in place and returns self", function()
        local a = vec2(1, 2)
        return a:set(7, 8) == a and a.x == 7 and a.y == 8
    end)

    pt("operator +", function() return vec2(1, 2) + vec2(3, 4) end, 4, 6)
    pt("operator -", function() return vec2(3, 4) - vec2(1, 2) end, 2, 2)
    pt("operator vec * n", function() return vec2(1, 2) * 3 end, 3, 6)
    pt("operator n * vec", function() return 3 * vec2(1, 2) end, 3, 6)
    pt("operator /", function() return vec2(4, 8) / 2 end, 2, 4)
    pt("operator unary -", function() return -vec3(1, 2, 3) end, -1, -2, -3)
    is_true("operator == equal", function() return vec3(1, 2, 3) == vec3(1, 2, 3) end)
    is_false("operator == different", function() return vec3(1, 2, 3) == vec3(1, 2, 4) end)
    is_true("tostring", function() return tostring(vec2(1, 2)) == "vec2(1.000, 2.000)" end)

    throws("vec2 rejects a string", function() return vec2("a", 1) end)
    throws("vec2 rejects NaN", function() return vec2(0 / 0, 1) end)
    throws("vec2 rejects infinity", function() return vec2(math.huge, 1) end)
    throws("add rejects a plain table", function() return vec2(1, 2):add({ x = 1, y = 2 }) end)
    throws("add rejects mixed dimensions", function() return vec2(1, 2) + vec3(1, 2, 3) end)
    throws("divide by zero", function() return vec2(1, 2) / 0 end)
    throws("vec3 set needs every component", function() return vec3(1, 2, 3):set(1, 2) end)

    --- @section mat4

    section("mat4")

    do
        local identity = mat4.new()
        local raw = identity:raw()
        is_true("identity diagonal", function() return raw[1] == 1 and raw[6] == 1 and raw[11] == 1 and raw[16] == 1 end)
        is_true("identity off-diagonal", function() return raw[2] == 0 and raw[5] == 0 and raw[13] == 0 end)
        eq("identity has 16 values", function() return #raw end, 16)
    end

    pt("translate", function() return mat4.translate(10, 20, 30):multiply_vec3(vec3(1, 2, 3)) end, 11, 22, 33)
    pt("translate accepts plain table", function() return mat4.translate(1, 1, 1):multiply_vec3({ x = 1, y = 2, z = 3 }) end, 2, 3, 4)
    pt("scale", function() return mat4.scale(2, 3, 4):multiply_vec3(vec3(1, 1, 1)) end, 2, 3, 4)
    pt("get_translation", function() return mat4.translate(5, 6, 7):get_translation() end, 5, 6, 7)
    pt("get_scale", function() return mat4.scale(2, 3, 4):get_scale() end, 2, 3, 4)

    pt("multiply applies right matrix first", function()
        return mat4.translate(1, 0, 0):multiply(mat4.scale(2, 2, 2)):multiply_vec3(vec3(1, 0, 0))
    end, 3, 0, 0)

    is_true("operator * matches multiply", function()
        local a, b = mat4.translate(1, 2, 3), mat4.rotate_euler(10, 20, 30)
        return matrix_near(a * b, a:multiply(b))
    end)

    pt("rotate_euler z 90", function() return mat4.rotate_euler(0, 0, 90):multiply_vec3(vec3(1, 0, 0)) end, 0, 1, 0)
    pt("rotate_euler x 90", function() return mat4.rotate_euler(90, 0, 0):multiply_vec3(vec3(0, 1, 0)) end, 0, 0, 1)
    pt("rotate_euler y 90", function() return mat4.rotate_euler(0, 90, 0):multiply_vec3(vec3(0, 0, 1)) end, 1, 0, 0)
    pt("rotate_axis z 90", function() return mat4.rotate_axis(vec3(0, 0, 1), 90):multiply_vec3(vec3(1, 0, 0)) end, 0, 1, 0)
    pt("rotate_axis accepts plain table", function() return mat4.rotate_axis({ x = 0, y = 0, z = 1 }, 90):multiply_vec3(vec3(1, 0, 0)) end, 0, 1, 0)
    throws("rotate_axis zero axis", function() return mat4.rotate_axis(vec3(0, 0, 0), 90) end)

    is_true("transpose moves translation", function()
        local raw = mat4.translate(1, 2, 3):transpose():raw()
        return raw[4] == 1 and raw[8] == 2 and raw[12] == 3
    end)

    is_true("transpose twice is original", function()
        local m = mat4.translate(1, 2, 3) * mat4.rotate_euler(10, 20, 30)
        return matrix_near(m:transpose():transpose(), m)
    end)

    is_true("invert times original is identity", function()
        local m = mat4.translate(1, 2, 3) * mat4.rotate_euler(10, 20, 30) * mat4.scale(2, 2, 2)
        return matrix_near(m * m:invert(), mat4.new())
    end)

    is_nil("invert singular is nil", function() return mat4.scale(0, 1, 1):invert() end)

    pt("look_at puts the target in front", function()
        return mat4.look_at(vec3(0, 0, 5), vec3(0, 0, 0), vec3(0, 1, 0)):multiply_vec3(vec3(0, 0, 0))
    end, 0, 0, -5)

    pt("look_at puts the eye at the origin", function()
        return mat4.look_at(vec3(1, 2, 3), vec3(0, 0, 0), vec3(0, 1, 0)):multiply_vec3(vec3(1, 2, 3))
    end, 0, 0, 0)

    pt("look_at accepts plain tables", function()
        return mat4.look_at({ x = 0, y = 0, z = 5 }, { x = 0, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }):multiply_vec3(vec3(0, 0, 0))
    end, 0, 0, -5)

    throws("look_at same eye and target", function() return mat4.look_at(vec3(1, 1, 1), vec3(1, 1, 1), vec3(0, 1, 0)) end)
    throws("look_at up parallel to view", function() return mat4.look_at(vec3(0, 5, 0), vec3(0, 0, 0), vec3(0, 1, 0)) end)

    do
        local raw = mat4.perspective(90, 1, 0.1, 100):raw()
        is_true("perspective values", function() return near(raw[1], 1) and near(raw[6], 1) and near(raw[12], -1) and near(raw[16], 0) end)
        throws("perspective bad fov", function() return mat4.perspective(0, 1, 0.1, 100) end)
        throws("perspective bad planes", function() return mat4.perspective(60, 1, 10, 1) end)
    end

    do
        local raw = mat4.orthographic(-1, 1, -1, 1, 0, 2):raw()
        is_true("orthographic values", function()
            return near(raw[1], 1) and near(raw[6], 1) and near(raw[11], -1) and near(raw[15], -1) and near(raw[16], 1)
        end)
    end

    is_nil("multiply_vec3 at infinity is nil", function()
        local zeros = {}
        for i = 1, 16 do zeros[i] = 0 end
        return mat4.new(zeros):multiply_vec3(vec3(1, 2, 3))
    end)

    throws("new rejects too few values", function() return mat4.new({ 1, 2, 3 }) end)
    throws("new rejects a non-table", function() return mat4.new("x") end)
    throws("multiply rejects a non-matrix", function() return mat4.new():multiply({}) end)

    --- @section Report

    local total_pass, total_fail = 0, 0
    for _, s in ipairs(sections) do
        total_pass = total_pass + s.pass
        total_fail = total_fail + s.fail
    end

    for _, f in ipairs(failures) do
        modit.log.error(("[test] %s: %s (%s)"):format(f.section, f.name, f.detail))
    end

    if total_fail == 0 then
        modit.log.success(("[test] maths: all %d checks passed"):format(total_pass))
    else
        modit.log.warn(("[test] maths: %d passed, %d failed"):format(total_pass, total_fail))
    end

    --- @section Draw Test

    local function draw_test()
        local draw = modit.draw
        local _, height = modit.window.get_size()

        draw.clear(22, 22, 22, 255)

        draw.set_colour(255, 255, 255, 255)
        draw.text("maths test", 20, 20, 24)

        if total_fail == 0 then
            draw.set_colour(120, 255, 120, 255)
        else
            draw.set_colour(255, 120, 120, 255)
        end
        draw.text(("%d passed, %d failed"):format(total_pass, total_fail), 20, 55, 20)

        local y = 95
        for _, s in ipairs(sections) do
            if s.fail == 0 then draw.set_colour(120, 255, 120, 255) else draw.set_colour(255, 120, 120, 255) end
            draw.text(("%-16s %d/%d"):format(s.name, s.pass, s.pass + s.fail), 20, y, 16)
            y = y + 22
        end

        draw.set_colour(160, 160, 180, 255)
        draw.text(total_fail == 0 and "no failures" or "failures:", 420, 95, 16)

        local fy = 120
        for _, f in ipairs(failures) do
            if fy > height - 24 then
                draw.set_colour(160, 160, 180, 255)
                draw.text("... see console for the rest", 420, fy, 14)
                break
            end
            draw.set_colour(255, 160, 160, 255)
            local line = ("[%s] %s: %s"):format(f.section, f.name, f.detail)
            draw.text(line:sub(1, 120), 420, fy, 14)
            fy = fy + 18
        end
    end

    return draw_test
end