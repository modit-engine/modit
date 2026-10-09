local world = require("shared.world")
local movement = require("shared.movement")

local GROUND = { 80, 100, 120, 255 }
local WIRE = { 15, 15, 15, 255 }
local TEXT = { 235, 235, 235, 255 }
local TEXT_DIM = { 160, 165, 175, 255 }

local player = movement.new()
local view = camera.new({ fov = 70 })
local locked, skip_look, started = false, true, false

local function set_locked(value)
    locked, skip_look = value, true
    if value then mouse.lock() else mouse.unlock() end
end

local function axis(positive, negative)
    return (keyboard.down(positive) and 1 or 0) - (keyboard.down(negative) and 1 or 0)
end

hooks.listen("console_toggled", function(open)
    if open then
        mouse.unlock()
    elseif locked then
        skip_look = true
        mouse.lock()
    end
end)

hooks.listen("update", function(delta_time)
    if not started then
        started = true
        set_locked(true)
    end

    if keyboard.pressed("tab") then set_locked(not locked) end
    if keyboard.pressed("escape") then
        if locked then set_locked(false) else game.leave() return end
    end

    local look_x, look_y = 0, 0
    if locked then
        look_x, look_y = mouse.get_delta()
        if skip_look then look_x, look_y, skip_look = 0, 0, false end
    end

    movement.step(player, {
        forward = locked and axis("w", "s") or 0,
        right = locked and axis("d", "a") or 0,
        jump = locked and keyboard.pressed("space"),
        sprint = locked and keyboard.down("leftshift"),
        look_x = look_x,
        look_y = look_y,
    }, delta_time, world.boxes)

    local eye_y = player.y + movement.EYE_HEIGHT
    local dx, dy, dz = movement.look_direction(player)
    view:set_position(player.x, eye_y, player.z)
    view:set_target(player.x + dx, eye_y + dy, player.z + dz)
end)

hooks.listen("draw", function()
    local window_w, window_h = window.get_size()

    view:begin_3d()
    draw.set_colour(GROUND)
    draw3d.plane(0, -0.01, 0, world.size, world.size)
    draw3d.grid(world.size, 1)
    for _, box in ipairs(world.boxes) do
        draw.set_colour(box.colour)
        draw3d.cube(box.x, box.y, box.z, box.w, box.h, box.l)
        draw.set_colour(WIRE)
        draw3d.cube_wires(box.x, box.y, box.z, box.w, box.h, box.l)
    end
    view:end_3d()
end)

hooks.listen("hud", function()
    local window_w, window_h = window.get_size()
    local center_x, center_y = window_w / 2, window_h / 2
    draw.set_colour(0, 255, 0, 255)
    draw.line(center_x - 10, center_y, center_x + 10, center_y)
    draw.line(center_x, center_y - 10, center_x, center_y + 10)

    draw.set_colour(TEXT)
    draw.text("WASD move   Shift sprint   Space jump   Tab free mouse   Esc leave", 16, 12, 16)
    draw.set_colour(TEXT_DIM)
    draw.text(("x %.1f   y %.1f   z %.1f"):format(player.x, player.y, player.z), 16, 36, 16)
end)

exports("get_player", function()
    return { x = player.x, y = player.y, z = player.z, yaw = player.yaw, pitch = player.pitch }
end)

exports("get_look", function()
    return movement.look_direction(player)
end)

exports("add_box", function(x, y, z, w, h, l, colour)
    world.add(x, y, z, w, h, l, colour or { 200, 200, 200, 255 })
end)