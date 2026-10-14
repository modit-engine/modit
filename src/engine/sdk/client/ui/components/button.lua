--- @module ui.components.button
--- @file src/engine/sdk/client/ui/components/button.lua
--- @description Unified interactive button component supporting text, icons, custom radii, and styling.

--- @section Imports

local _draw = require("src.engine.sdk.client.render.draw2d")
local _font = require("src.engine.sdk.client.render.font")
local _theme = require("src.engine.sdk.client.ui.theme")
local _input = require("src.engine.sdk.client.ui.input")
local _icons = require("src.engine.sdk.client.ui.icons")

--- @section Function

--- Draws an interactive button (supporting text, icon, or both) and returns true if clicked.
--- @param label string|nil Button display text (optional if using opts.label or opts.icon)
--- @param x number X position
--- @param y number Y position
--- @param width number Width
--- @param height number Height
--- @param opts table|nil Configuration table: { icon, label, radius, font, size, colour, text_colour, icon_colour, style, border, border_thick }
--- @return boolean clicked True on the frame released while hovered
return function(label, x, y, width, height, opts)
    -- Support passing opts as the first argument or positional arguments
    if type(label) == "table" then
        opts = label
        label = opts.label
        x = opts.x or x
        y = opts.y or y
        width = opts.width or width
        height = opts.height or height
    else
        opts = opts or {}
    end

    label = label or opts.label
    local icon = opts.icon

    local theme = _theme.get()
    local over, clicked, held = _input.interact(x, y, width, height)

    -- Resolve background color
    local bg = theme.bg_panel
    local style = opts.style
    if style == "primary" then
        bg = theme.accent
    elseif style == "danger" then
        bg = theme.accent3
    end

    if held then
        bg = theme.accent2
    elseif over then
        bg = theme.bg_hover
    end

    if opts.colour or opts.color then
        bg = opts.colour or opts.color
    end

    _draw.set_colour(bg)

    -- Corner radius support
    local radius = opts.radius or 0
    if radius > 0 then
        _draw.rect_rounded(x, y, width, height, radius)
    else
        _draw.rect(x, y, width, height)
    end

    -- Border rendering
    if style or opts.border then
        local border_color = opts.border_colour or opts.border_color or theme.border_dark.color
        _draw.set_colour(border_color)
        if radius > 0 then
            _draw.rect_rounded_lines(x, y, width, height, radius, 0, opts.border_thick or 1)
        else
            _draw.rect_lines(x, y, width, height, opts.border_thick or 1)
        end
    end

    -- Content Rendering (Icon and/or Text)
    local icon_size = opts.icon_size or opts.size or 16
    local font_size = opts.size or 16
    local font_obj = opts.font

    if icon and not label then
        -- Pure icon button mode
        local icon_color = opts.icon_colour or opts.icon_color or (opts.colour or (over and theme.text_primary or theme.text_secondary))
        _draw.set_colour(icon_color)
        _icons.draw(icon, x, y, width, height, icon_size)
    else
        -- Combined or text-only button mode
        if icon then
            local icon_color = opts.icon_colour or opts.icon_color or opts.text_colour or theme.text_primary
            _draw.set_colour(icon_color)
            _icons.draw(icon, x + 8, y + (height - icon_size) / 2, icon_size, icon_size, icon_size)
        end

        if label then
            local text_color = opts.text_colour or opts.text_color or theme.text_primary
            _draw.set_colour(text_color)
            local offset_x = icon and (icon_size + 12) or 0

            if font_obj and type(font_obj) == "table" and font_obj.draw then
                local text_width = font_obj:measure(label)
                local tx = x + offset_x + (width - offset_x - text_width) / 2
                local ty = y + (height - font_obj.size) / 2
                font_obj:draw(label, tx, ty)
            else
                local text_width = _font.width(font_size, label)
                local tx = x + offset_x + (width - offset_x - text_width) / 2
                local ty = y + (height - font_size) / 2
                _draw.text(label, tx, ty, font_size)
            end
        end
    end

    return clicked
end