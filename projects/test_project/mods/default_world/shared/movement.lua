--- @module movement
--- @file src/planetlua/shared/movement.lua
--- @description Player movement simulation. Pure Lua with no engine dependencies.

local GRAVITY = 19.6
local JUMP_SPEED = 8
local WALK_SPEED = 8
local SPRINT_SPEED = 12
local RADIUS = 0.4
local HEIGHT = 1.8
local MAX_PITCH = math.pi / 2 - 0.01
local SENSITIVITY = 0.002

local m = { EYE_HEIGHT = 1.7 }

--- Creates a player state at the origin
function m.new()
    return { x = 0, y = 0, z = 0, vy = 0, yaw = 0, pitch = 0, grounded = true }
end

--- Returns the unit look direction for a state
--- @return number dx, number dy, number dz
function m.look_direction(state)
    local cos_pitch = math.cos(state.pitch)
    return cos_pitch * math.cos(state.yaw), math.sin(state.pitch), -cos_pitch * math.sin(state.yaw)
end

local function hits_box(boxes, x, y, z)
    for i = 1, #boxes do
        local b = boxes[i]
        if x + RADIUS > b[1] and x - RADIUS < b[4]
            and y + HEIGHT > b[2] and y < b[5]
            and z + RADIUS > b[3] and z - RADIUS < b[6] then
            return true
        end
    end
    return false
end

--- Advances a player one step
--- @param state table Player state from m.new
--- @param input table { forward, right, look_x, look_y, jump, sprint }
--- @param delta_time number Seconds
--- @param boxes table World boxes
function m.step(state, input, delta_time, boxes)
    state.yaw = state.yaw - (input.look_x or 0) * SENSITIVITY
    state.pitch = math.max(-MAX_PITCH, math.min(MAX_PITCH, state.pitch - (input.look_y or 0) * SENSITIVITY))

    local forward, right = input.forward or 0, input.right or 0
    local length = math.sqrt(forward * forward + right * right)
    if length > 1 then forward, right = forward / length, right / length end

    local speed = input.sprint and SPRINT_SPEED or WALK_SPEED
    local cos_yaw, sin_yaw = math.cos(state.yaw), math.sin(state.yaw)
    local vx = (forward * cos_yaw + right * sin_yaw) * speed
    local vz = (-forward * sin_yaw + right * cos_yaw) * speed

    local next_x = state.x + vx * delta_time
    if not hits_box(boxes, next_x, state.y, state.z) then state.x = next_x end
    local next_z = state.z + vz * delta_time
    if not hits_box(boxes, state.x, state.y, next_z) then state.z = next_z end

    if input.jump and state.grounded then state.vy = JUMP_SPEED end
    state.vy = state.vy - GRAVITY * delta_time

    local previous_y = state.y
    local next_y = previous_y + state.vy * delta_time
    local floor_y = 0
    for i = 1, #boxes do
        local b = boxes[i]
        if state.x + RADIUS > b[1] and state.x - RADIUS < b[4]
            and state.z + RADIUS > b[3] and state.z - RADIUS < b[6]
            and previous_y >= b[5] - 0.001 and b[5] > floor_y then
            floor_y = b[5]
        end
    end

    state.grounded = false
    if next_y <= floor_y and state.vy <= 0 then
        next_y, state.vy, state.grounded = floor_y, 0, true
    end
    state.y = next_y
end

return m