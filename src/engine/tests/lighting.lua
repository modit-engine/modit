--- @file src/engine/tests/lighting.lua
--- @description Lighting, sky, and shadow test module for the Modit engine test harness.

return function(modit)
    local lighting = modit.lighting
    local sky = modit.sky
    local keyboard = modit.keyboard
    local draw = modit.draw
    local model = modit.model

    local angle = 0
    local cam_dist = 9
    local cam = modit.camera.new({
        x = 0, y = 3.5, z = cam_dist,
        target_x = 0, target_y = 1, target_z = 0,
        fov = 60
    })

    cam:on("begin_3d", function(camera)
        lighting.begin(camera)
    end)
    cam:on("end_3d", function()
        lighting.finish()
    end)

    local shadow_modes = { "off", "blob", "projected", "map" }
    local mode_idx = 3
    local shadow_strength = 0.7
    local lighting_on = true
    local sky_on = true
    local map_models_available = type(model) == "table"
        and type(model.build) == "function"
        and type(model.draw) == "function"
        and type(model.set_material) == "function"
    local map_model_built = false

    local function ground_vertices()
        return {
            -6, 0, -6,  -6, 0, 6,   6, 0, 6,
            -6, 0, -6,   6, 0, 6,   6, 0, -6,
        }
    end

    local function cube_vertices()
        local faces = {
            { { 1, 0, 0 }, { 0, 0, -1 }, { 0, 1, 0 } },
            { { -1, 0, 0 }, { 0, 0, 1 }, { 0, 1, 0 } },
            { { 0, 1, 0 }, { 1, 0, 0 }, { 0, 0, -1 } },
            { { 0, -1, 0 }, { 1, 0, 0 }, { 0, 0, 1 } },
            { { 0, 0, 1 }, { 1, 0, 0 }, { 0, 1, 0 } },
            { { 0, 0, -1 }, { -1, 0, 0 }, { 0, 1, 0 } },
        }
        local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
        local triangle_corners = { 1, 2, 3, 1, 3, 4 }
        local vertices = {}

        for _, face in ipairs(faces) do
            local normal, u, v = face[1], face[2], face[3]
            for _, corner_index in ipairs(triangle_corners) do
                local corner = corners[corner_index]
                for component = 1, 3 do
                    vertices[#vertices + 1] =
                        (normal[component] + u[component] * corner[1] + v[component] * corner[2]) * 0.5
                end
            end
        end

        return vertices
    end

    local function ensure_map_model()
        if not map_models_available or map_model_built then return end

        local built, reason = model.build({ key = "lighting_test_cube", vertices = cube_vertices() })
        if not built then
            map_models_available = false
            modit.log.info("[test] could not build map-shadow cube: " .. tostring(reason))
            return
        end

        built, reason = model.build({ key = "lighting_test_ground", vertices = ground_vertices() })
        if not built then
            map_models_available = false
            modit.log.info("[test] could not build map-shadow receiver: " .. tostring(reason))
            return
        end

        built, reason = model.set_material({ key = "lighting_test_ground", cast_shadows = false })
        if not built then
            map_models_available = false
            modit.log.info("[test] could not configure map-shadow receiver: " .. tostring(reason))
            return
        end

        map_model_built = true
    end

    sky.set(70, 120, 210, 190, 215, 240)

    local function apply_lighting()
        if lighting_on then
            lighting.set_sun(-0.4, -1, -0.3, 240, 230, 200)
            lighting.set_ambient(80, 85, 100)
            lighting.set_shadows(shadow_modes[mode_idx], shadow_strength)
            if sky_on then
                lighting.set_fog(15, 140)
            else
                lighting.set_fog(15, 140, 22, 22, 22)
            end
        else
            lighting.set_sun(-0.4, -1, -0.3, 0, 0, 0)
            lighting.set_ambient(255, 255, 255)
            lighting.set_shadows("off")
            lighting.set_fog(1000000, 2000000)
        end
    end

    local function set_shadow_mode(index)
        mode_idx = index
        apply_lighting()
        local mode = shadow_modes[mode_idx]
        if mode == "map" and not map_models_available then
            modit.log.info("[test] map shadows need the model mesh API")
        end
        modit.log.info(("shadows: %s (%.1f)"):format(mode, shadow_strength))
    end

    local function draw_projected_casters()
        draw.set_colour(220, 70, 70, 255)
        draw.cube(-1.5, 0.5, 0, 1, 1, 1)
        draw.set_colour(70, 130, 220, 255)
        draw.cube(1.5, 0.5, 0, 1, 1, 1)
    end

    local function draw_map_casters()
        model.draw({
            key = "lighting_test_cube",
            x = -1.5, y = 0.5, z = 0,
            scale = { x = 1, y = 1, z = 1 },
            tint = { 220, 70, 70, 255 },
        })
        model.draw({
            key = "lighting_test_cube",
            x = 1.5, y = 0.5, z = 0,
            scale = { x = 1, y = 1, z = 1 },
            tint = { 70, 130, 220, 255 },
        })
    end

    local function draw_map_ground()
        model.draw({
            key = "lighting_test_ground",
            tint = { 90, 100, 110, 255 },
        })
    end

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
            cam_dist = math.min(20, cam_dist + 6 * dt)
        end

        if keyboard.pressed("j") then
            set_shadow_mode(mode_idx % #shadow_modes + 1)
        end
        if keyboard.pressed("u") then
            shadow_strength = math.max(0, shadow_strength - 0.1)
            apply_lighting()
            modit.log.info(("shadows: %s (%.1f)"):format(shadow_modes[mode_idx], shadow_strength))
        end
        if keyboard.pressed("i") then
            shadow_strength = math.min(1, shadow_strength + 0.1)
            apply_lighting()
            modit.log.info(("shadows: %s (%.1f)"):format(shadow_modes[mode_idx], shadow_strength))
        end
        if keyboard.pressed("l") then
            lighting_on = not lighting_on
            apply_lighting()
            modit.log.info(lighting_on and "lighting on" or "lighting off")
        end
        if keyboard.pressed("k") then
            sky_on = not sky_on
            apply_lighting()
            modit.log.info(sky_on and "sky on" or "sky off")
        end

        cam:set_position(math.sin(angle) * cam_dist, 3.5, math.cos(angle) * cam_dist)
        cam:set_target(0, 1, 0)
    end

    local function draw_test()
        local w, h = modit.window.get_size()
        local mode = shadow_modes[mode_idx]

        if mode == "map" then
            ensure_map_model()
        end

        draw.clear(22, 22, 22, 255)
        if sky_on then
            sky.draw(cam, w, h)
        end

        if lighting_on and mode == "map" and map_models_available then
            lighting.shadow_map_pass(cam, draw_map_casters)
        end

        cam:begin_3d()
            draw.set_colour(100, 100, 100, 255)
            draw.grid(20, 1)

            if mode == "map" and map_models_available then
                draw_map_ground()
            else
                draw.set_colour(90, 100, 110, 255)
                draw.plane(0, 0, 0, 12, 12)
            end

            if mode == "map" and map_models_available then
                draw_map_casters()
            else
                draw_projected_casters()
            end

            if lighting_on and mode == "projected" then
                lighting.shadow_pass(draw_projected_casters, 0)
            elseif lighting_on and mode == "blob" then
                lighting.blob(-1.5, 0, 0, 0.8)
                lighting.blob(1.5, 0, 0, 0.8)
            end
        cam:end_3d()

        draw.set_colour(255, 255, 255, 255)
        draw.text("Lighting, Sky & Shadows Test", 20, 20, 24)
        draw.text(
            ("[J] Mode: %s (%.1f) | [U/I] Strength | [L] Lighting: %s | [K] Sky: %s")
                :format(string.upper(mode), shadow_strength, lighting_on and "ON" or "OFF", sky_on and "ON" or "OFF"),
            20, 60, 16)
        draw.text("[A/D] Orbit | [W/S] Zoom", 20, 84, 16)
        if mode == "map" and not map_models_available then
            draw.text("Map shadows need modit.model.build/draw (mesh API)", 20, 108, 16)
        end
    end

    apply_lighting()

    return {
        update = update_test,
        draw = draw_test
    }
end
