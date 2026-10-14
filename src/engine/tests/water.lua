--- @file src/engine/tests/water.lua
--- @description Water test: presets, toggle, reset, height_at with a floating cube, and an outside-the-water check.

return function(modit)
    local lighting = modit.lighting
    local sky = modit.sky
    local keyboard = modit.keyboard
    local draw = modit.draw
    local water = modit.water

    local angle = 0.6
    local cam_dist = 14
    local cam = modit.camera.new({
        x = 0, y = 6, z = cam_dist,
        target_x = 0, target_y = 0, target_z = 0,
        fov = 60
    })

    -- water only draws inside a lit 3D pass
    cam:on("begin_3d", function(camera)
        lighting.begin(camera)
    end)
    cam:on("end_3d", function()
        lighting.finish()
    end)

    local presets = {
        { key = "1", name = "defaults", opts = {} },
        { key = "2", name = "big and tall waves", opts = { size = 120, amplitude = 0.6, frequency = 0.4, speed = 1.5 } },
        { key = "3", name = "fine mesh, calm", opts = { cell = 0.5, amplitude = 0.05, frequency = 1.2, speed = 0.6 } },
        { key = "4", name = "murky green, opaque", opts = { colour = { 40, 110, 60 }, opacity = 0.9 } },
        { key = "5", name = "raised y = 1, small", opts = { y = 1, size = 20 } },
    }

    local current = 0

    sky.set(70, 120, 210, 190, 215, 240)
    lighting.set_sun(-0.4, -1, -0.3, 240, 230, 200)
    lighting.set_ambient(80, 85, 100)
    lighting.set_shadows("off")
    lighting.set_fog(30, 200)

    local function select_preset(index)
        water.reset()
        current = index
        water.set(presets[index].opts)
        modit.log.info("[test] water preset: " .. presets[index].name)
    end

    select_preset(1)

    local function update_test(dt)
        if keyboard.down("a") or keyboard.down("arrowleft") then
            angle = angle - 1.2 * dt
        end
        if keyboard.down("d") or keyboard.down("arrowright") then
            angle = angle + 1.2 * dt
        end
        if keyboard.down("w") or keyboard.down("arrowup") then
            cam_dist = math.max(4, cam_dist - 6 * dt)
        end
        if keyboard.down("s") or keyboard.down("arrowdown") then
            cam_dist = math.min(40, cam_dist + 6 * dt)
        end

        for i, preset in ipairs(presets) do
            if keyboard.pressed(preset.key) then select_preset(i) end
        end

        if keyboard.pressed("o") then
            water.set_enabled(water.height_at(0, 0) == nil)
            modit.log.info("[test] water toggled")
        end

        if keyboard.pressed("r") then
            water.reset()
            current = 0
            modit.log.info("[test] water reset (off, defaults)")
        end

        cam:set_position(math.sin(angle) * cam_dist, 6, math.cos(angle) * cam_dist)
        cam:set_target(0, 0, 0)
    end

    local function draw_test()
        local w, h = modit.window.get_size()
        local surface = water.height_at(0, 0)

        draw.clear(22, 22, 22, 255)
        sky.draw(cam, w, h)

        cam:begin_3d()
            -- opaque scene first
            draw.set_colour(120, 100, 70, 255)
            draw.plane(0, -1.5, 0, 60, 60)

            draw.set_colour(200, 200, 200, 255)
            draw.cube(6, 0, 6, 1, 3, 1)
            draw.cube(-6, 0, -4, 1, 3, 1)
            draw.cube(-5, 0, 7, 1, 3, 1)

            -- floating cube rides the surface
            draw.set_colour(255, 120, 120, 255)
            draw.cube(0, (surface or 0) + 0.2, 0, 1, 1, 1)

            -- water last
            water.draw()
        cam:end_3d()

        draw.set_colour(255, 255, 255, 255)
        draw.text("water test", 20, 20, 24)

        draw.set_colour(160, 160, 180, 255)
        draw.text("preset: " .. (presets[current] and presets[current].name or "reset (off)"), 20, 55, 16)
        draw.text("height_at(0, 0): " .. (surface and ("%.3f"):format(surface) or "nil (off)"), 20, 77, 16)
        draw.text("height_at far outside: " .. tostring(water.height_at(100000, 100000)) .. " (must be nil)", 20, 99, 16)

        for i, preset in ipairs(presets) do
            if i == current then draw.set_colour(255, 220, 80, 255) else draw.set_colour(130, 130, 150, 255) end
            draw.text(("[%s] %s"):format(preset.key, preset.name), 20, 135 + (i - 1) * 20, 16)
        end

        draw.set_colour(130, 130, 150, 255)
        draw.text("[O] toggle on/off | [R] reset (off + defaults) | [A/D] Orbit | [W/S] Zoom", 20, 250, 16)
    end

    return {
        update = update_test,
        draw = draw_test
    }
end