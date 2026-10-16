--- @module panel
--- @file src/engine/sdk/client/ui/components/panel.lua
--- @description Dock panel container component with background, borders, and optional title header.

--- @section Imports

local _draw = require("src.sdk.client.draw2d")
local _font = require("src.sdk.client.font")
local _theme = require("src.sdk.ui.theme")

--- @section Constants

local TITLE_H = 30

--- @section Component

--- Draws a panel container with optional title header bar and section divider
--- Content inside the panel should start rendering at y + 31 (y + TITLE_H + 1)
--- @param x number|table X screen coordinate (or configuration opts table)
--- @param y number Y screen coordinate
--- @param w number Panel width in pixels
--- @param h number Panel height in pixels
--- @param title string|nil Optional title string rendered in the header bar
--- @param opts table|nil Optional configuration table: { radius, colour, border_colour, title }
return function(x, y, w, h, title, opts)
    if type(x) == "table" then
        opts = x
        title = opts.title or title
        x = opts.x or 0
        y = opts.y or 0
        w = opts.width or opts.w or 0
        h = opts.height or opts.h or 0
    else
        opts = opts or {}
    end

    if w <= 0 or h <= 0 then return end
    local t = _theme.get()

    -- Background rendering
    local bg = opts.colour or opts.color or t.bg_panel
    _draw.set_colour(bg)

    local radius = opts.radius or 0
    if radius > 0 then
        _draw.rect_rounded(x, y, w, h, radius)
    else
        _draw.rect(x, y, w, h)
    end

    -- Border rendering
    local border_color = opts.border_colour or opts.border_color or t.border_dark.color
    _draw.set_colour(border_color)
    if radius > 0 then
        _draw.rect_rounded_lines(x, y, w, h, radius, 0, opts.border_thick or 1)
    else
        _draw.rect_lines(x, y, w, h)
    end

    -- Optional Title Header
    if title then
        _draw.set_colour(t.text_secondary)
        local font_16 = _font.get(16)
        if font_16 then
            font_16:draw(title, x + 10, y + 8)
        else
            _draw.text(title, x + 10, y + 8, 16)
        end
        _draw.set_colour(t.border_light.color)
        _draw.line(x, y + TITLE_H, x + w, y + TITLE_H)
    end
end