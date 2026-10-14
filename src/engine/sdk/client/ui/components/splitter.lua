--- @module splitter
--- @file src/engine/sdk/client/ui/components/splitter.lua
--- @description Resizable UI panel divider component supporting mouse drag interactions along horizontal and vertical axes.

--- @section Imports

local _draw = require("src.engine.sdk.client.draw")
local _input = require("src.engine.sdk.client.ui.input")
local _theme = require("src.engine.sdk.client.ui.theme")

--- @section Variables

local drag_origin = 0
local drag_value = 0

--- @section Component

--- Renders an interactive panel splitter handle and calculates updated panel dimension[cite: 15]
--- @param x number X screen coordinate[cite: 15]
--- @param y number Y screen coordinate[cite: 15]
--- @param w number Width in pixels[cite: 15]
--- @param h number Height in pixels[cite: 15]
--- @param axis string Drag axis orientation ("x" for horizontal, "y" for vertical)[cite: 15]
--- @param value number Current panel dimension value[cite: 15]
--- @param dir number Direction multiplier (1 for normal resize, -1 for inverted)[cite: 15]
--- @return number value Updated panel dimension value[cite: 15]
--- @return boolean dragging True if splitter is actively being dragged[cite: 15]
return function(x, y, w, h, axis, value, dir)
    local t = _theme.get()
    local id = _input.new_id()
    local mx, my = _input.mouse()

    local over = _input.in_rect(x, y, w, h)
    if over then
        _input.set_hot(id)
        if _input.pressed() then
            _input.set_active(id)
            drag_origin = axis == "x" and mx or my
            drag_value = value
        end
    end

    local dragging = _input.is_active(id) and _input.down()

    if over or dragging then
        _input.set_cursor(axis == "x" and "resize_h" or "resize_v")
        _draw.set_colour(dragging and t.accent or t.accent2)
        if axis == "x" then
            _draw.rect(x + w / 2 - 1, y, 2, h)
        else
            _draw.rect(x, y + h / 2 - 1, w, 2)
        end
    end

    if dragging then
        local pos = axis == "x" and mx or my
        return drag_value + (pos - drag_origin) * dir, true
    end
    return value, false
end