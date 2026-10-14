--- @file src/engine/tests/draw2d.lua
--- @description 2D drawing, shapes, clipping, object-oriented fonts, images, and 2D camera test with a clean grid layout.

return function(modit)

    --- @section Camera Setup

    -- Create a 2D camera instance
    local cam2d = modit.camera.new()
    cam2d:set_offset(50, 20)
    cam2d:set_zoom(1.0)

    --- @section Asset State (Lazy initialized on first frame when GL context is active)
    local static_image = nil
    local char_sprite = nil
    local assets_loaded = false

    --- @section Draw Test

    --- Draws a small caption under a test shape
    --- @param str string Caption text
    --- @param x number X position
    --- @param y number Y position
    local function caption(str, x, y)
        modit.draw.set_colour(160, 160, 180, 255)
        modit.draw.text(str, x, y, 14)
    end

    --- Exercises every 2D draw function, clipping, text measuring, OO custom fonts, images, sprites, and 2D camera
    local function draw_test()
        local draw = modit.draw

        -- Lazy load assets on the first frame (guarantees a live OpenGL context)
        if not assets_loaded and modit.image then
            assets_loaded = true
            static_image = modit.image.load("src/engine/assets/branding/modit_icon_200x200.png")
            char_sprite = modit.image.load({
                path = "src/engine/assets/sprites/rpg_base_character_16.png",
                type = "sprite",
                frame_width = 16,
                frame_height = 16,
                animations = {
                    idle = { x = 0, y = 0, frames = 2 },
                    walk = { x = 0, y = 4, frames = 4 }
                }
            })
        end

        -- clear background
        draw.clear(22, 22, 22, 255)

        draw.set_colour(255, 255, 255, 255)
        draw.text("2d drawing, cam, font & image test", 20, 20, 24)

        -- ==========================================
        -- 1. WORLD-SPACE OBJECTS (Affected by 2D Camera)
        -- ==========================================
        cam2d:begin_2d()

            -- row 1: lines and rectangles (y = 80)
            draw.set_colour(255, 255, 255, 255)
            draw.line(40, 80, 140, 140)
            caption("line", 40, 150)

            draw.set_colour({ 255, 120, 120 })
            draw.rect(200, 80, 100, 60)
            caption("rect", 200, 150)

            draw.set_color(120, 255, 120, 255)
            draw.rect_lines(360, 80, 100, 60)
            caption("rect_lines", 360, 150)

            draw.set_colour(120, 160, 255, 255)
            draw.rect_lines_ex(520, 80, 100, 60, 4)
            caption("rect_lines_ex", 520, 150)

            draw.set_colour(255, 200, 80, 255)
            draw.rect_rounded(680, 80, 100, 60, 0.4, 8)
            caption("rect_rounded", 680, 150)

            draw.set_colour(255, 200, 80, 255)
            draw.rect_rounded_lines(840, 80, 100, 60, 0.4, 8, 3)
            caption("rect_rounded_lines", 840, 150)

            draw.set_colour(255, 255, 255, 128)
            draw.rect(1000, 80, 60, 60)
            draw.set_colour({ 255, 0, 0 }, 128)
            draw.rect(1030, 100, 60, 60)
            caption("alpha", 1000, 170)

            -- row 2: circles, triangles, ellipse, polygon (y = 230)
            draw.set_colour(255, 120, 255, 255)
            draw.circle(90, 280, 40)
            caption("circle", 60, 330)

            draw.circle_lines(250, 280, 40)
            caption("circle_lines", 205, 330)

            draw.set_colour(120, 255, 255, 255)
            draw.triangle(360, 320, 410, 240, 460, 320)
            caption("triangle", 370, 330)

            draw.triangle_lines(520, 320, 570, 240, 620, 320)
            caption("triangle_lines", 520, 330)

            draw.set_colour(255, 255, 120, 255)
            draw.ellipse(730, 280, 60, 30)
            caption("ellipse", 705, 330)

            draw.polygon(880, 280, 6, 40, 0)
            caption("polygon 6", 850, 330)

            draw.polygon(1000, 280)
            caption("polygon default", 960, 330)

            draw.polygon(1120, 280, 5, 40, 36)
            caption("polygon 5 rot", 1085, 330)

            -- row 3: text and measuring (y = 400)
            draw.set_colour(255, 255, 255, 255)
            draw.text("default size", 40, 400)
            draw.text("size 32", 40, 430, 32)

            local label = "measured"
            local width, height = draw.measure_text(label, 24)
            draw.set_colour(80, 80, 120, 255)
            draw.rect(300, 400, width, height)
            draw.set_colour(255, 255, 255, 255)
            draw.text(label, 300, 400, 24)
            caption(("measure_text: %dx%d"):format(width, height), 300, 435)

            -- row 4: OO Custom Font Test (y = 500)
            if modit.font then
                local custom_font = modit.font.get(22)
                if custom_font then
                    draw.set_colour(100, 220, 255, 255)
                    custom_font:draw("OO Font Render (JetBrainsMono)", 40, 500)
                    
                    local fwidth = custom_font:measure("OO Font Render (JetBrainsMono)")
                    caption(("font measure width: %dpx"):format(fwidth), 40, 530)
                end
            end

            -- row 5: OO Image & Sprite Sheet Test (y = 580)
            if static_image then
                draw.set_colour(255, 255, 255, 255)
                static_image:draw(40, 580, 0.4)
                caption("static image draw", 40, 675)
            end

            if char_sprite then
                draw.set_colour(255, 255, 255, 255)
                char_sprite:draw_sprite("idle", 1, 160, 580, 3.0)
                caption("sprite sheet frame", 160, 675)
            end

        cam2d:end_2d()

        -- ==========================================
        -- 2. SCREEN-SPACE UI & CLIPPING (Right Column Area, X >= 680)
        -- ==========================================
        
        caption("clip: nothing should leak outside boxes", 680, 400)

        draw.push_clip(680, 430, 150, 80)
        draw.set_colour(255, 80, 80, 255)
        draw.rect(660, 410, 400, 200)
        draw.pop_clip()

        draw.push_clip(870, 430, 200, 100)
        draw.set_colour(80, 255, 80, 255)
        draw.rect(850, 410, 400, 200)
        draw.push_clip(930, 460, 150, 80)
        draw.set_colour(80, 80, 255, 255)
        draw.rect(910, 440, 400, 200)
        local cx, cy, cw, ch = draw.get_clip()
        draw.pop_clip()
        draw.pop_clip()

        draw.set_colour(255, 255, 255, 255)
        draw.text(("get_clip (nested): %s %s %s %s"):format(cx, cy, cw, ch), 680, 550, 14)

        draw.push_clip(680, 590, 120, 60)
        draw.push_clip(700, 600, 120, 60)
        draw.reset_clip()
        draw.set_colour(255, 255, 80, 255)
        draw.rect(680, 670, 120, 20)
        caption("reset_clip: yellow bar fully visible", 680, 695)
        caption("get_clip after reset: " .. tostring(draw.get_clip()), 680, 715)
    end

    return draw_test
end