--- @file src/engine/tests/canvas.lua
--- @description Canvas test: minimap, fixed-resolution letterbox, mouse mapping, free and recreate.

return function(modit)

    local minimap = nil
    local fixed = nil
    local created = 0
    local freed = 0

    local function caption(str, x, y)
        modit.draw.set_colour(160, 160, 180, 255)
        modit.draw.text(str, x, y, 14)
    end

    local function draw_test()
        local draw = modit.draw

        if not minimap then
            minimap = modit.canvas.new(160, 160)
            created = created + 1
        end
        fixed = fixed or modit.canvas.new(320, 180)

        draw.clear(22, 22, 22, 255)
        draw.set_colour(255, 255, 255, 255)
        draw.text("canvas test", 20, 20, 24)

        -- 1. minimap drawn into a canvas, shown 1:1 and stretched
        local t = os.clock()
        minimap:begin(20, 20, 40, 255)
            draw.set_colour(60, 60, 90, 255)
            draw.rect_lines(0, 0, 160, 160)
            draw.set_colour(255, 120, 120, 255)
            draw.circle(80 + math.cos(t) * 50, 80 + math.sin(t) * 50, 6)
            draw.set_colour(120, 255, 120, 255)
            draw.circle(80, 80, 3)
        minimap:finish()

        minimap:draw(20, 80, 160, 160)
        caption("minimap 160x160 (1:1)", 20, 250)

        minimap:draw(220, 80, 320, 320)
        caption("same canvas stretched 2x", 220, 410)

        local mw, mh = minimap:get_size()
        caption(("get_size: %dx%d"):format(mw, mh), 20, 270)

        -- 2. fixed resolution, letterboxed
        fixed:begin(30, 30, 60, 255)
            draw.set_colour(255, 200, 80, 255)
            draw.text("320x180", 10, 10, 20)
            draw.set_colour(80, 200, 255, 255)
            draw.rect(10, 50, 100, 60)
            draw.circle(240, 100, 40)
        fixed:finish()

        local bx, by, bw, bh = 600, 80, 500, 400
        draw.set_colour(60, 30, 30, 255)
        draw.rect(bx, by, bw, bh)
        fixed:draw_fit(bx, by, bw, bh)
        caption("draw_fit: letterboxed inside the red box", bx, by + bh + 10)

        -- 3. to_canvas: hover the fixed canvas
        local mx, my = modit.mouse.get_position()
        local cx, cy = fixed:to_canvas(mx, my)
        local inside = cx >= 0 and cy >= 0 and cx < 320 and cy < 180

        draw.set_colour(255, 255, 255, 255)
        draw.text(
            inside and ("canvas mouse: %d, %d"):format(cx, cy) or "canvas mouse: outside",
            bx, by + bh + 40, 18
        )

        if inside then
            draw.set_colour(255, 255, 0, 255)
            draw.circle_lines(mx, my, 8)
        end

        if modit.keyboard.pressed("f") then
            minimap:free()
            minimap = nil
            freed = freed + 1
        end

        caption(("press F to free the minimap | created: %d  freed: %d"):format(created, freed), 20, 450)
    end

    return draw_test
end