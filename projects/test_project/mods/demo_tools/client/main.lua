local show_help = true
local spawned = 0

hooks.listen("update", function()
    if keyboard.pressed("f1") then show_help = not show_help end

    if keyboard.pressed("f") then
        local player = exports.default_world.get_player()
        local look_x, _, look_z = exports.default_world.get_look()
        local length = math.sqrt(look_x * look_x + look_z * look_z)
        if length > 0.001 then
            spawned = spawned + 1
            exports.default_world.add_box(player.x + look_x / length * 4, 0.5, player.z + look_z / length * 4, 1, 1, 1, { 80 + (spawned * 53) % 160, 120 + (spawned * 31) % 100, 90 + (spawned * 17) % 150, 255 })
        end
    end
end)

hooks.listen("draw", function()
    if not show_help then return end
    draw.set_colour(235, 235, 235, 255)
    draw.text("F  spawn a box in front of you", 16, 64, 16)
    draw.text("F1 toggle this help", 16, 86, 16)
    draw.set_colour(160, 165, 175, 255)
    draw.text(("boxes spawned: %d   (demo_tools)"):format(spawned), 16, 110, 16)
end)

commands.register("hello", function()
    return "hi from " .. mod.name end
)