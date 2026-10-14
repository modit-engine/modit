--- @file src/engine/tests/postfx.lua
--- @description Postfx test: every enable option, scene size, disable/reset, custom shader and broken shader fallback.

return function(modit)

    local cam = modit.camera.new({
        x = 0, y = 4, z = 7,
        target_x = 0, target_y = 0.5, target_z = 0,
        fov = 60
    })

    local INVERT_SHADER = [[
#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
out vec4 finalColor;
void main() {
    vec3 col = texture(texture0, fragTexCoord).rgb;
    finalColor = vec4(1.0 - col, 1.0);
}
]]

    local BROKEN_SHADER = "this is not valid glsl"

    local presets = {
        { key = "1", name = "off (disable)", apply = function() modit.postfx.disable() end },
        { key = "2", name = "defaults", apply = function() modit.postfx.enable() end },
        { key = "3", name = "pixel_size 3", apply = function() modit.postfx.enable({ pixel_size = 3 }) end },
        { key = "4", name = "PS1: pixel_size 3, colour_levels 32", apply = function()
            modit.postfx.enable({ pixel_size = 3, colour_levels = 32, dither = 0.8 })
        end },
        { key = "5", name = "vignette 0.8", apply = function() modit.postfx.enable({ vignette = 0.8 }) end },
        { key = "6", name = "saturation 0 (greyscale)", apply = function() modit.postfx.enable({ saturation = 0 }) end },
        { key = "7", name = "saturation 2, contrast 1.5", apply = function()
            modit.postfx.enable({ saturation = 2, contrast = 1.5 })
        end },
        { key = "8", name = "brightness +0.3", apply = function() modit.postfx.enable({ brightness = 0.3 }) end },
        { key = "9", name = "custom shader (invert)", apply = function()
            modit.postfx.enable({ shader = { fragment = INVERT_SHADER } })
        end },
        { key = "0", name = "broken shader (expect warning + default look)", apply = function()
            modit.postfx.enable({ shader = { fragment = BROKEN_SHADER } })
        end },
    }

    local current = nil

    local function select_preset(index)
        current = index
        presets[index].apply()
        modit.log.info("[test] postfx preset: " .. presets[index].name)
    end

    local function draw_scene()
        local draw = modit.draw
        local t = os.clock()

        cam:begin_3d()
            draw.set_colour(255, 255, 255, 255)
            draw.grid(20, 1)

            draw.set_colour(255, 120, 120, 255)
            draw.cube(-3, 0.5, 0, 1, 1, 1)

            draw.set_colour(120, 255, 120, 255)
            draw.sphere(math.sin(t) * 2, 0.5, 0, 0.5)

            draw.set_colour(120, 160, 255, 255)
            draw.cube(3, 0.5 + math.abs(math.sin(t * 2)), 0, 1, 1, 1)

            draw.set_colour(255, 220, 80, 255)
            draw.sphere_wires(0, 1.5, -2, 0.7)
        cam:end_3d()
    end

    local function draw_test()
        local draw = modit.draw

        if not current then select_preset(2) end

        for i, preset in ipairs(presets) do
            if modit.keyboard.pressed(preset.key) then select_preset(i) end
        end

        draw.clear(22, 22, 22, 255)

        modit.postfx.begin_scene(20, 20, 40)
        draw_scene()
        modit.postfx.end_scene()

        -- HUD is drawn after end_scene so it stays sharp
        draw.set_colour(255, 255, 255, 255)
        draw.text("postfx test (HUD must stay sharp)", 20, 20, 24)

        local w, h = modit.postfx.get_size()
        draw.set_colour(160, 160, 180, 255)
        draw.text(("get_size: %dx%d"):format(w, h), 20, 55, 16)
        draw.text("preset: " .. presets[current].name, 20, 78, 16)

        for i, preset in ipairs(presets) do
            draw.set_colour(i == current and 255 or 130, i == current and 220 or 130, i == current and 80 or 150, 255)
            draw.text(("[%s] %s"):format(preset.key, preset.name), 20, 110 + (i - 1) * 20, 16)
        end

        -- reset: restores defaults and turns postfx off
        draw.set_colour(160, 160, 180, 255)
        draw.text("[R] reset (off + defaults), then press 2-0 to enable again", 20, 330, 16)
        if modit.keyboard.pressed("r") then
            modit.postfx.reset()
            current = 1
            modit.log.info("[test] postfx reset")
        end
    end

    return draw_test
end