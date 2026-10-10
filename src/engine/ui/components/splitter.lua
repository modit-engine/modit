--- @module splitter
--- @file src/editor/ui/components/splitter.lua
--- @description Resizable UI panel divider component supporting mouse drag interactions along horizontal and vertical axes.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.render.draw")

--- Editor
local _input = require("src.engine.ui.modules.input")
local _theme = require("src.engine.ui.modules.theme")

--- @section Variables

local drag_origin = 0
local drag_value = 0

--- @section Component

--- Renders an interactive panel splitter handle and calculates updated panel dimension
--- @param x number X screen coordinate
--- @param y number Y screen coordinate
--- @param w number Width in pixels
--- @param h number Height in pixels
--- @param axis string Drag axis orientation ("x" for horizontal, "y" for vertical)
--- @param value number Current panel dimension value
--- @param dir number Direction multiplier (1 for normal resize, -1 for inverted)
--- @return number value Updated panel dimension value
--- @return boolean dragging True if splitter is actively being dragged
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