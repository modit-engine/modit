--- @module panel
--- @file src/editor/ui/components/panel.lua
--- @description Dock panel container component with background, borders, and optional title header.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")

--- Editor
local _theme = require("src.engine.ui.style.theme")
local _label = require("src.engine.ui.components.label")

--- @section Constants

local TITLE_H = 30

--- @section Component

--- Draws a panel container with optional title header bar and section divider
--- Content inside the panel should start rendering at y + 31 (y + TITLE_H + 1)
--- @param x number X screen coordinate
--- @param y number Y screen coordinate
--- @param w number Panel width in pixels
--- @param h number Panel height in pixels
--- @param title string|nil Optional title string rendered in the header bar
return function(x, y, w, h, title)
    if w <= 0 or h <= 0 then return end
    local t = _theme.get()

    _draw.set_colour(t.bg_panel)
    _draw.rect(x, y, w, h)
    _draw.set_colour(t.border_dark.color)
    _draw.rect_lines(x, y, w, h)

    if title then
        _label(title, x + 10, y + 8, 16, t.text_secondary)
        _draw.set_colour(t.border_light.color)
        _draw.line(x, y + TITLE_H, x + w, y + TITLE_H)
    end
end