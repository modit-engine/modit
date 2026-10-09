local world = require("shared.world")
local movement = require("shared.movement")

local ticks = 0

hooks.listen("update", function()
    ticks = ticks + 1
end)

commands.register("status", function()
    return ("default_world: %d boxes, %d ticks"):format(#world.boxes, ticks)
end, "Show world status")

exports("get_box_count", function() return #world.boxes end)

print(("server realm online: %d boxes from shared/world.lua, eye height %.1f"):format(#world.boxes, movement.EYE_HEIGHT))