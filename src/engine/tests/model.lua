--- @file src/engine/tests/model.lua
--- @description Model test: obj, gltf/glb, iqm, m3d and vox loading, animation, bounds, picking, materials, parts, draw_many and unload safety.

return function(modit)
    local lighting = modit.lighting
    local sky = modit.sky
    local keyboard = modit.keyboard
    local mouse = modit.mouse
    local draw = modit.draw
    local model = modit.model

    local ROOT = "src/engine/assets/models/"
    local TARGET_SIZE = 3
    local MANY_COLUMNS = 5

    local ENTRIES = {
        { key = "1", id = "test_obj", label = "obj", dirs = { "obj" },
          files = { "castle.obj", "house.obj", "bridge.obj", "cube.obj", "plane.obj", "turret.obj" } },
        { key = "2", id = "test_glb", label = "gltf/glb", dirs = { "gltf", "glb" }, animated = true,
          files = { "robot.glb", "greenman.glb", "silly_dancing.glb", "GolfballDraco.glb" } },
        { key = "3", id = "test_iqm", label = "iqm", dirs = { "iqm" }, animated = true,
          files = { "guy.iqm" }, anim_files = { "guyanim.iqm" } },
        { key = "4", id = "test_m3d", label = "m3d", dirs = { "m3d" }, animated = true,
          files = { "cesium_man.m3d", "seagull.m3d" } },
        { key = "5", id = "test_vox", label = "vox (model.load)", dirs = { "vox" },
          files = { "chr_knight.vox", "chr_sword.vox", "monu9.vox", "fez.vox" } },
        { key = "6", id = "test_vox_asset", label = "vox (model.load_asset, named parts)", dirs = { "vox" }, asset = true,
          files = { "chr_knight.vox", "chr_sword.vox", "monu9.vox", "fez.vox" } }, -- @todo FIX: doesnt seem to work? not sure why will look when not tired..
        { key = "7", id = "test_cube", label = "model.build + assembly", procedural = true },
        { key = "8", id = "test_many", label = "draw_many (25 copies of the last loaded model)", many = true },
    }

    local TINTS = {
        { r = 255, g = 255, b = 255, a = 255 },
        { r = 255, g = 120, b = 120, a = 255 },
        { r = 120, g = 255, b = 120, a = 255 },
        { r = 120, g = 160, b = 255, a = 255 },
    }

    --- @section State

    local cam_angle, cam_dist, spin_angle = 0, 9, 0
    local cam = modit.camera.new({
        x = 0, y = 3.5, z = cam_dist,
        target_x = 0, target_y = 1.2, target_z = 0,
        fov = 60
    })

    cam:on("begin_3d", function(camera) lighting.begin(camera) end)
    cam:on("end_3d", function() lighting.finish() end)

    sky.set(70, 120, 210, 190, 215, 240)
    lighting.set_sun(-0.4, -1, -0.3, 240, 230, 200)
    lighting.set_ambient(90, 95, 110)
    lighting.set_shadows("off")
    lighting.set_fog(25, 140)

    local current = nil
    local last_loaded = nil
    local many_list = nil
    local status = "press 1-8 to load a model"
    local show_bounds, spin, paused = true, true, false
    local clip_index, tint_index = 1, 1
    local detached = nil
    local check_text = nil
    local pick_text = "pick: none"

    --- @section Helpers

    local function set_status(text)
        status = text
        modit.log.info("[test] model: " .. text)
    end

    local function find_file(entry, names)
        for _, dir in ipairs(entry.dirs) do
            for _, name in ipairs(names) do
                local path = ROOT .. dir .. "/" .. name
                local file = io.open(path, "rb")
                if file then file:close() return path end
            end
        end
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
        local order = { 1, 2, 3, 1, 3, 4 }
        local vertices = {}
        for _, face in ipairs(faces) do
            for _, index in ipairs(order) do
                local corner = corners[index]
                for axis = 1, 3 do
                    vertices[#vertices + 1] = (face[1][axis] + face[2][axis] * corner[1] + face[3][axis] * corner[2]) * 0.5
                end
            end
        end
        return vertices
    end

    local function fit_for(key)
        local bounds, reason = model.get_bounds(key)
        if not bounds then return nil, reason end

        local size_x, size_y, size_z = bounds.max.x - bounds.min.x, bounds.max.y - bounds.min.y, bounds.max.z - bounds.min.z
        local largest = math.max(size_x, size_y, size_z, 1e-6)

        return {
            cx = (bounds.min.x + bounds.max.x) / 2,
            cy = (bounds.min.y + bounds.max.y) / 2,
            cz = (bounds.min.z + bounds.max.z) / 2,
            size_y = size_y,
            scale = TARGET_SIZE / largest,
        }
    end

    local function fitted_instance(key, fit, factor, ox, oz)
        local scale = fit.scale * factor
        return model.create_instance({
            key = key,
            x = ox - fit.cx,
            y = (fit.size_y * scale) / 2 - fit.cy,
            z = oz - fit.cz,
            pivot = { x = fit.cx, y = fit.cy, z = fit.cz },
            scale = scale,
        })
    end

    local function sorted_parts(instance)
        local names = {}
        for name in pairs(instance.parts or {}) do names[#names + 1] = name end
        table.sort(names)
        return names
    end

    local function reset_view_state()
        paused, clip_index, tint_index, detached, check_text = false, 1, 1, nil, nil
        many_list = nil
    end

    --- @section Loading

    local function activate_many()
        if not last_loaded then return set_status("load a model first (1-7)") end

        reset_view_state()
        many_list = {}
        local fit = last_loaded.fit
        for index = 0, MANY_COLUMNS * MANY_COLUMNS - 1 do
            local ox = (index % MANY_COLUMNS - (MANY_COLUMNS - 1) / 2) * 3
            local oz = (math.floor(index / MANY_COLUMNS) - (MANY_COLUMNS - 1) / 2) * 3
            local instance, reason = fitted_instance(last_loaded.key, fit, 0.4, ox, oz)
            if not instance then many_list = nil return set_status("draw_many instance failed: " .. tostring(reason)) end
            if last_loaded.clips > 0 then model.play(instance, { clip = 1, loop = true, speed = 0.5 + (index % 5) * 0.25 }) end
            many_list[#many_list + 1] = instance
        end

        current = { entry = last_loaded.entry, key = last_loaded.key, many = true, fit = fit, clips = last_loaded.clips }
        set_status(("draw_many: %d instances of %s"):format(#many_list, last_loaded.entry.label))
    end

    local function activate(entry)
        if entry.many then return activate_many() end

        reset_view_state()
        local path, ok, reason

        if entry.procedural then
            path = "(built in code)"
            ok, reason = model.build({ key = entry.id, vertices = cube_vertices() })
        else
            path = find_file(entry, entry.files)
            if not path then
                current = nil
                return set_status(("%s: no file found. Searched %s%s/ for %s"):format(
                    entry.label, ROOT, table.concat(entry.dirs, "|"), table.concat(entry.files, ", ")))
            end
            if entry.asset then
                ok, reason = model.load_asset({ key = entry.id, path = path })
            else
                ok, reason = model.load({ key = entry.id, path = path })
            end
        end

        if not ok then
            current = nil
            return set_status(("%s failed to load: %s"):format(entry.label, tostring(reason)))
        end

        local fit, fit_reason = fit_for(entry.id)
        if not fit then
            current = nil
            return set_status(("%s bounds failed: %s"):format(entry.label, tostring(fit_reason)))
        end

        local instance, instance_reason = fitted_instance(entry.id, fit, 1, 0, 0)
        if not instance then
            current = nil
            return set_status(("%s instance failed: %s"):format(entry.label, tostring(instance_reason)))
        end

        if entry.procedural then
            instance.tint = { r = 220, g = 70, b = 70, a = 255 }
            local arm = model.create_instance({ key = entry.id, x = 1.6, y = 0, scale = 0.5, tint = { r = 70, g = 130, b = 220, a = 255 } })
            model.attach(instance, "arm", arm)
        end

        local clips, note = 0, ""
        if entry.animated then
            local anim_path = entry.anim_files and find_file(entry, entry.anim_files) or nil
            local anim_ok, anim_reason = model.load_animations({ key = entry.id, path = anim_path })
            local list = model.get_animations(entry.id) or {}
            clips = #list
            if clips > 0 then
                model.play(instance, { clip = 1, loop = true })
            else
                note = " | no clips: " .. tostring(anim_ok and "file has none" or anim_reason)
            end
        end

        current = { entry = entry, key = entry.id, path = path, instance = instance, fit = fit, clips = clips }
        if not entry.procedural then last_loaded = current end
        set_status(("%s loaded: %s%s"):format(entry.label, path, note))
    end

    --- @section Actions

    local function clip_list()
        return current and current.clips > 0 and model.get_animations(current.key) or {}
    end

    local function next_clip()
        local clips = clip_list()
        if #clips == 0 or not current.instance then return set_status("no animation clips on this model") end
        clip_index = clip_index % #clips + 1
        model.play(current.instance, { clip = clip_index, loop = true })
        paused = false
        set_status(("clip %d/%d: %s"):format(clip_index, #clips, tostring(clips[clip_index].name)))
    end

    local function toggle_pause()
        if not current or not current.instance or not current.instance.animation then return set_status("nothing is playing") end
        paused = not paused
        model.pause(current.instance, paused)
        set_status(paused and "paused" or "resumed")
    end

    local function stop_animation()
        if not current or not current.instance then return end
        model.stop(current.instance)
        set_status("stopped (bind pose)")
    end

    local function seek_animation()
        if not current or not current.instance then return end
        local ok, reason = model.seek(current.instance, 0.5)
        set_status(ok and "seeked to 0.5s" or ("seek failed: " .. tostring(reason)))
    end

    local function toggle_part()
        if not current or not current.instance then return end
        local instance = current.instance

        if detached then
            local ok = model.attach(instance, detached.name, detached.child)
            set_status(ok and ("re-attached part " .. detached.name) or "attach failed")
            detached = nil
            return
        end

        local names = sorted_parts(instance)
        if #names == 0 then return set_status("this model has no named parts (try 6 or 7)") end

        local child, reason = model.detach(instance, names[1])
        if not child then return set_status("detach failed: " .. tostring(reason)) end
        detached = { name = names[1], child = child }
        set_status("detached part " .. names[1] .. " (it stops drawing)")
    end

    local function cycle_material()
        if not current or current.many then return end
        tint_index = tint_index % #TINTS + 1
        local ok, reason = model.set_material({ key = current.key, material = 1, tint = TINTS[tint_index] })
        set_status(ok and ("material 1 tint " .. tint_index) or ("set_material failed: " .. tostring(reason)))
    end

    local function unload_current()
        if not current then return end
        local key = current.key
        local freed = model.unload(key)
        local ok, reason = true, nil
        if current.instance then ok, reason = model.draw(current.instance) end
        current.dead = true
        check_text = ("unload(%s) = %s; draw after unload = %s%s"):format(key, tostring(freed), tostring(ok), reason and (" (" .. reason .. ")") or "")
        set_status("unloaded: drawing is now skipped, press a number key to reload")
    end

    local function cleanup_all()
        model.cleanup()
        local ok, reason = true, nil
        if current and current.instance then ok, reason = model.draw(current.instance) end
        if current then current.dead = true end
        many_list, last_loaded = nil, nil
        check_text = ("cleanup(); draw after cleanup = %s%s"):format(tostring(ok), reason and (" (" .. reason .. ")") or "")
        set_status("cleanup: every asset released")
    end

    --- @section Update

    local function update_pick()
        pick_text = "pick: none"
        if not current or current.dead then return end

        local list = many_list or { current.instance }
        local mx, my = mouse.get_position()
        local ray = model.screen_ray(cam, mx, my)
        if not ray then return end

        local hit = model.raycast(list, ray)
        if hit then
            pick_text = ("pick: %s mesh %s at %.2f"):format(tostring(hit.key), tostring(hit.mesh), hit.distance)
        end
    end

    local function update_test(dt)
        if keyboard.down("a") or keyboard.down("arrowleft") then cam_angle = cam_angle - 1.2 * dt end
        if keyboard.down("d") or keyboard.down("arrowright") then cam_angle = cam_angle + 1.2 * dt end
        if keyboard.down("w") or keyboard.down("arrowup") then cam_dist = math.max(4, cam_dist - 6 * dt) end
        if keyboard.down("s") or keyboard.down("arrowdown") then cam_dist = math.min(30, cam_dist + 6 * dt) end

        for _, entry in ipairs(ENTRIES) do
            if keyboard.pressed(entry.key) then activate(entry) end
        end

        if keyboard.pressed("space") then toggle_pause() end
        if keyboard.pressed("n") then next_clip() end
        if keyboard.pressed("x") then stop_animation() end
        if keyboard.pressed("z") then seek_animation() end
        if keyboard.pressed("h") then toggle_part() end
        if keyboard.pressed("t") then cycle_material() end
        if keyboard.pressed("g") then show_bounds = not show_bounds end
        if keyboard.pressed("r") then spin = not spin end
        if keyboard.pressed("u") then unload_current() end
        if keyboard.pressed("c") then cleanup_all() end

        if spin then spin_angle = (spin_angle + 40 * dt) % 360 end

        if current and not current.dead then
            local list = many_list or { current.instance }
            for _, instance in ipairs(list) do
                instance.angle = spin_angle
                model.update(instance, dt)
            end
        end

        update_pick()

        cam:set_position(math.sin(cam_angle) * cam_dist, 3.5, math.cos(cam_angle) * cam_dist)
        cam:set_target(0, 1.2, 0)
    end

    --- @section Draw

    local function draw_scene(over)
        draw.set_colour(100, 100, 100, 255)
        draw.grid(20, 1)
        draw.set_colour(90, 100, 110, 255)
        draw.plane(0, 0, 0, 24, 24)

        if not current or current.dead then return end

        local ok, reason
        if many_list then
            ok, reason = model.draw_many(many_list, cam)
        else
            ok, reason = model.draw(current.instance)
        end
        if not ok then over.draw_error = reason end

        if show_bounds and not many_list then
            local bounds = model.get_bounds(current.instance)
            if bounds then
                if pick_text ~= "pick: none" then draw.set_colour(255, 220, 80, 255) else draw.set_colour(80, 255, 120, 255) end
                draw.cube_wires((bounds.min.x + bounds.max.x) / 2, (bounds.min.y + bounds.max.y) / 2, (bounds.min.z + bounds.max.z) / 2, bounds.max.x - bounds.min.x, bounds.max.y - bounds.min.y, bounds.max.z - bounds.min.z)
            end
        end
    end

    local function draw_test()
        local w, h = modit.window.get_size()
        local over = {}

        draw.clear(22, 22, 22, 255)
        

        cam:begin_3d()
            draw_scene(over)
        cam:end_3d()

        draw.set_colour(255, 255, 255, 255)
        draw.text("Model Test", 20, 20, 24)
        draw.set_colour(255, 220, 80, 255)
        draw.text(status, 20, 52, 16)

        local y = 78
        local function line(text, r, g, b)
            draw.set_colour(r or 160, g or 160, b or 180, 255)
            draw.text(text, 20, y, 16)
            y = y + 20
        end

        if current and not current.dead and current.instance then
            local instance = current.instance
            line("file: " .. tostring(current.path or current.key))

            local materials = model.get_materials(current.key)
            line(("materials: %s | parts: %s"):format(materials and tostring(#materials) or "n/a", table.concat(sorted_parts(instance), ", ")))

            local clips = clip_list()
            local animation = instance.animation
            if #clips > 0 then
                line(("clip %d/%d %s | frame %.1f | %s"):format(
                    clip_index, #clips, tostring(clips[clip_index] and clips[clip_index].name),
                    animation and animation.frame or 0, animation and (animation.playing and "playing" or "paused") or "stopped"))
            end
            if detached then line("detached part: " .. detached.name, 255, 180, 120) end
        end

        line(pick_text)
        if check_text then line(check_text, 255, 180, 120) end
        if over.draw_error then line("draw failed: " .. tostring(over.draw_error), 255, 120, 120) end

        y = h - 220
        for _, entry in ipairs(ENTRIES) do
            local active = current and current.entry == entry
            local r, g, b = unpack(active and {255, 230, 80} or {255, 255, 255})
            line(("[%s] %s"):format(entry.key, entry.label), r, g, b)
        end

        line("[SPACE] pause [N] next clip [X] stop [Z] seek 0.5s [H] detach/attach part [T] tint [G] bounds [R] spin [U] unload [C] cleanup", 100, 220, 255)
        line("[A/D] Orbit | [W/S] Zoom | hover the model to test raycast", 220, 220, 240)
    end

    return {
        update = update_test,
        draw = draw_test
    }
end