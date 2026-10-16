--- @module ui.components.toggle
--- @file src/sdk/ui/components/toggle.lua
--- @description Square on/off switch component that returns true when clicked.

--- @section Imports

local _draw = require("src.sdk.client.draw2d")
local _input = require("src.sdk.ui.input")
local _theme = require("src.sdk.ui.theme")

--- @section Constants

local KNOB_INSET = 3

--- @section Component

--- Draws an on/off switch and returns true on the frame it is clicked
--- @param value boolean Current switch state
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @param opts table|nil Configuration table: { passive }
--- @return boolean clicked True when clicked (always false if passive)
return function(value, x, y, w, h, opts)
    opts = opts or {}
    local t = _theme.get()

    local clicked = false
    if not opts.passive then
        local _, was_clicked = _input.interact(x, y, w, h)
        clicked = was_clicked
    end

    _draw.set_colour(value and t.accent or t.border_dark.color)
    _draw.rect(x, y, w, h)

    local knob = h - KNOB_INSET * 2
    local knob_x = value and (x + w - knob - KNOB_INSET) or (x + KNOB_INSET)
    _draw.set_colour(t.text_primary)
    _draw.rect(knob_x, y + KNOB_INSET, knob, knob)

    return clicked
end