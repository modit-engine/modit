--- @file src/engine/tests/draw3d.lua
--- @description 3D drawing and camera test.

return function(modit)

    --- @section Camera Setup

    local cam = modit.camera.new({
        x = 0, y = 4, z = 5,
        target_x = 0, target_y = 0, target_z = 0,
        fov = 60
    })

    --- @section Draw Test

    local function draw_test()
        local draw = modit.draw

        -- Clear background
        draw.clear(22, 22, 22, 255)

        draw.set_colour(255, 255, 255, 255)
        draw.text("3d drawing & camera test", 20, 20, 24)

        -- Begin 3D Mode
        cam:begin_3d()
            draw.set_colour(255, 255, 255, 255)
            draw.grid(20, 1)
            draw.line_3d(0, 0, 0, 0, 3, 0)
            
            draw.cube(-3, 0.5, 0, 1, 1, 1)
            draw.cube_wires(-1.5, 0.5, 0, 1, 1, 1)
            
            draw.plane(0, 0, 3, 2, 2)
            
            draw.sphere(1.5, 0.5, 0, 0.5)
            draw.sphere_wires(3, 0.5, 0, 0.5)
            draw.sphere_wires(4.5, 0.5, 0) -- defaults
        cam:end_3d()
    end

    return draw_test
end