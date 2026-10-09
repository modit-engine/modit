--- @module world
--- @file src/planetlua/shared/world.lua
--- @description Placeholder world: boxes used for both rendering and collision. Pure Lua.

local boxes = {}

--- Adds a box. Bounds are indices 1-6: min x/y/z, max x/y/z
local function add(x, y, z, w, h, l, colour)
    boxes[#boxes + 1] = {
        x - w / 2, y - h / 2, z - l / 2, x + w / 2, y + h / 2, z + l / 2,
        x = x, y = y, z = z, w = w, h = h, l = l, colour = colour,
    }
end

add(0, 5, 40, 82, 10, 2, { 150, 80, 80, 255 })
add(0, 5, -40, 82, 10, 2, { 150, 80, 80, 255 })
add(40, 5, 0, 2, 10, 80, { 80, 150, 80, 255 })
add(-40, 5, 0, 2, 10, 80, { 80, 150, 80, 255 })

for index = 1, 16 do
    local angle = (index / 16) * math.pi * 2
    local height = 1 + (index % 4)
    add(math.cos(angle) * 12, height / 2, math.sin(angle) * 12, 2, height, 2,
        { 80 + (index * 11) % 140, 110, 200 - (index * 9) % 120, 255 })
end

return { size = 80, boxes = boxes, add = add }