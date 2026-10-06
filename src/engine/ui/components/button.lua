--- @module button
--- @file src/editor/ui/components/button.lua
--- @description Reusable button component

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")
local _font = require("src.engine.modules.font")

--- Editor
local _theme = require("src.engine.ui.style.theme")
local _input = require("src.engine.ui.input")

--- @section Function

--- Draws an interactive button and returns true if clicked.
--- @param label string: Button display text
--- @param x number: X position
--- @param y number: Y position
--- @param width number: Width
--- @param height number: Height
--- @param size? number: Optional font size override (default: 16)
--- @param colour? table: Optional text RGBA color table override
--- @param style? table: Optional styles
--- @return boolean: True on the frame released while hovered
return function(label, x, y, width, height, size, colour, style)
    local theme = _theme.get()
    local over, clicked, held = _input.interact(x, y, width, height)

    local bg = theme.bg_panel
    if style == "primary" then bg = theme.accent
    elseif style == "danger" then bg = theme.accent3 end

    if held then
        bg = theme.accent2
    elseif over then
        bg = theme.bg_hover
    end

    _draw.set_colour(bg)
    _draw.rect(x, y, width, height)

    if style then
        _draw.set_colour(theme.border_dark.color)
        _draw.rect_lines(x, y, width, height, 1)
    end

    local font_size = size or 16
    local text_width = _font.width(font_size, label)
    _draw.set_colour(colour or theme.text_primary)
    _input.text(label, x + (width - text_width) / 2, y + (height - font_size) / 2, font_size)

    return clicked
end