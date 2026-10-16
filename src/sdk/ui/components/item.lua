--- @module ui.components.item
--- @file src/sdk/ui/components/item.lua
--- @description Interactive UI list item component with primary label, optional subtext, icon support, and custom styling.

--- @section Imports

local _draw = require("src.sdk.client.draw2d")
local _font = require("src.sdk.client.font")
local _input = require("src.sdk.ui.input")
local _theme = require("src.sdk.ui.theme")
local _icons = require("src.sdk.ui.icons")

--- @section Component

--- Renders a clickable row component with a main label, optional subtext, and optional icon.
--- @param label string|table Primary display text (or configuration opts table)
--- @param sub string|nil Optional secondary subtext string
--- @param x number X screen coordinate
--- @param y number Y screen coordinate
--- @param w number Width in pixels
--- @param h number Height in pixels
--- @param opts table|nil Configuration table: { radius, font, size, icon, icon_colour, colour, text_colour, sub_colour }
--- @return boolean clicked True if the row item was clicked during the current frame
return function(label, sub, x, y, w, h, opts)
    if type(label) == "table" then
        opts = label
        label = opts.label
        sub = opts.sub
        x = opts.x or x
        y = opts.y or y
        w = opts.width or opts.w or w
        h = opts.height or opts.h or h
    else
        opts = opts or {}
    end

    local t = _theme.get()
    local over, clicked, held = _input.interact(x, y, w, h)

    local bg = t.bg_panel
    if held then 
        bg = t.accent2
    elseif over then 
        bg = t.bg_hover 
    end

    if opts.colour or opts.color then
        bg = opts.colour or opts.color
    end

    _draw.set_colour(bg)
    local radius = opts.radius or 0
    if radius > 0 then
        _draw.rect_rounded(x, y, w, h, radius)
    else
        _draw.rect(x, y, w, h)
    end

    local size = opts.size or 16
    local ty = y + (h - size) / 2
    local icon_size = opts.icon_size or size
    local offset_x = 12

    local font_obj = opts.font
    if not (font_obj and type(font_obj) == "table" and font_obj.draw) then
        font_obj = _font.get(size)
    end

    _draw.push_clip(x, y, w, h)

    if opts.icon then
        _draw.set_colour(opts.icon_colour or opts.icon_color or t.text_secondary)
        _icons.draw(opts.icon, x + offset_x, y + (h - icon_size) / 2, icon_size, icon_size, icon_size)
        offset_x = offset_x + icon_size + 8
    end

    _draw.set_colour(opts.text_colour or opts.text_color or t.text_primary)
    if font_obj then
        font_obj:draw(label, x + offset_x, ty)
    else
        _draw.text(label, x + offset_x, ty, size)
    end

    if sub then
        local tw = font_obj and font_obj:measure(label) or _font.width(size, label)
        _draw.set_colour(opts.sub_colour or opts.sub_color or t.text_tertiary)
        local sub_x = x + offset_x + tw + 14
        if font_obj then
            font_obj:draw(sub, sub_x, ty)
        else
            _draw.text(sub, sub_x, ty, size)
        end
    end

    _draw.pop_clip()

    return clicked
end