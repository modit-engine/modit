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
        -- Clear background using draw2d for UI/text pass
        modit.draw2d.clear(22, 22, 22, 255)

        modit.draw2d.set_colour(255, 255, 255, 255)
        modit.draw2d.text("3d drawing & camera test", 20, 20, 24)

        -- Begin 3D Mode
        cam:begin_3d()
            modit.draw3d.set_colour(255, 255, 255, 255)
            modit.draw3d.grid(20, 1)
            modit.draw3d.line(0, 0, 0, 0, 3, 0)
            
            modit.draw3d.cube(-3, 0.5, 0, 1, 1, 1)
            modit.draw3d.cube_wires(-1.5, 0.5, 0, 1, 1, 1)
            
            modit.draw3d.plane(0, 0, 3, 2, 2)
            
            modit.draw3d.sphere(1.5, 0.5, 0, 0.5)
            modit.draw3d.sphere_wires(3, 0.5, 0, 0.5)
            modit.draw3d.sphere_wires(4.5, 0.5, 0) -- defaults
        cam:end_3d()
    end

    return draw_test
end