--- @module label
--- @file src/sdk/ui/components/label.lua
--- @description Simple UI text label component with font handle and color override support.

--- @section Imports

local _draw = require("src.sdk.client.draw2d")
local _font = require("src.sdk.client.font")
local _theme = require("src.sdk.ui.theme")

--- @section Component

--- Renders a text label string with optional font sizing, font handle, and color overriding
--- @param str string|table Text string to render (or configuration opts table)
--- @param x number X screen coordinate
--- @param y number Y screen coordinate
--- @param size number|nil Font size in pixels (defaults to 16)
--- @param c table|number|nil RGBA color table or hex value (defaults to primary text theme color)
return function(str, x, y, size, c)
    local opts = {}
    if type(str) == "table" then
        opts = str
        str = opts.label or opts.text
        x = opts.x or x
        y = opts.y or y
        size = opts.size or size
        c = opts.colour or opts.color or opts.text_colour or c
    end

    _draw.set_colour(c or _theme.get().text_primary)
    local font_size = size or 16

    local font_obj = opts.font
    if not (font_obj and type(font_obj) == "table" and font_obj.draw) then
        font_obj = _font.get(font_size)
    end

    if font_obj then
        font_obj:draw(str, x, y)
    else
        _draw.text(str, x, y, font_size)
    end
end