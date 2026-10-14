--- @file src/engine/tests/physics3d.lua
--- @description 3D physics simulation test: world initialization, rigid bodies, shapes, gravity, stepping, and 3D debug rendering.

return function(modit)
    local p3d = modit.physics3d

    --- @section Physics World & Body Setup

    -- Initialize the physics world with standard Earth gravity
    p3d.init_world({
        gravity = { x = 0, y = -9.81, z = 0 },
        fixed_dt = 1 / 60,
        substeps = 4
    })

    -- Create static ground body
    local ground = p3d.create_body({
        type = "static",
        position = { x = 0, y = -1, z = 0 }
    })
    p3d.add_box_shape(ground, 10, 1, 10, { friction = 0.4, restitution = 0.2 })

    -- Create dynamic falling box
    local box = p3d.create_body({
        type = "dynamic",
        position = { x = 0, y = 6, z = 0 },
        linear_damping = 0.05
    })
    p3d.add_box_shape(box, 0.5, 0.5, 0.5, { density = 1.0, friction = 0.5, restitution = 0.4 })

    -- Create dynamic bouncing sphere
    local sphere = p3d.create_body({
        type = "dynamic",
        position = { x = 1.5, y = 9, z = 0 }
    })
    p3d.add_sphere_shape(sphere, 0.6, { density = 1.0, friction = 0.3, restitution = 0.8 })

    --- @section Camera Setup

    local cam = modit.camera.new({
        x = 0, y = 5, z = 12,
        target_x = 0, target_y = 2, target_z = 0,
        fov = 60
    })

    --- @section Update & Draw Loop

    local function update_test(dt)
        -- Step the physics simulation forward using fixed delta time
        p3d.update_world(dt)
    end

    local function draw_test()
        -- Clear background using 2D draw for UI pass
        modit.draw2d.clear(22, 22, 22, 255)

        modit.draw2d.set_colour(255, 255, 255, 255)
        modit.draw2d.text("3d physics simulation test", 20, 20, 24)

        -- Fetch current rigid body positions from simulation state
        local bx, by, bz = p3d.get_body_position(box)
        local sx, sy, sz = p3d.get_body_position(sphere)

        -- Display telemetry data on screen
        modit.draw2d.set_colour(160, 160, 180, 255)
        modit.draw2d.text(("Box Position:    X: %.2f, Y: %.2f, Z: %.2f"):format(bx, by, bz), 20, 60, 16)
        modit.draw2d.text(("Sphere Position: X: %.2f, Y: %.2f, Z: %.2f"):format(sx, sy, sz), 20, 85, 16)

        -- Begin 3D Rendering Mode
        cam:begin_3d()
            -- Draw ground grid & visual ground box
            modit.draw3d.set_colour(100, 100, 100, 255)
            modit.draw3d.grid(20, 1)

            modit.draw3d.set_colour(70, 80, 90, 255)
            modit.draw3d.cube(0, -1, 0, 20, 2, 20)

            -- Draw dynamic box body
            modit.draw3d.set_colour(100, 200, 255, 255)
            modit.draw3d.cube(bx, by, bz, 1, 1, 1)

            -- Draw dynamic sphere body
            modit.draw3d.set_colour(255, 140, 90, 255)
            modit.draw3d.sphere(sx, sy, sz, 0.6)
        cam:end_3d()
    end

    return {
        update = update_test,
        draw = draw_test
    }
end