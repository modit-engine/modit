--- @module item
--- @file src/editor/ui/components/item.lua
--- @description Interactive UI list item component with primary label and optional subtext.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")
local _font = require("src.engine.modules.font")

--- Editor
local _input = require("src.engine.ui.modules.input")
local _theme = require("src.engine.ui.modules.theme")

--- @section Component

--- Renders a clickable row component with a main label and optional secondary subtext
--- @param label string Primary display text
--- @param sub string|nil Optional secondary subtext string
--- @param x number X screen coordinate
--- @param y number Y screen coordinate
--- @param w number Width in pixels
--- @param h number Height in pixels
--- @return boolean clicked True if the row item was clicked during the current frame
return function(label, sub, x, y, w, h)
    local t = _theme.get()
    local over, clicked, held = _input.interact(x, y, w, h)

    local bg = t.bg_panel
    if held then 
        bg = t.accent2
    elseif over then 
        bg = t.bg_hover 
    end

    _draw.set_colour(bg)
    _draw.rect(x, y, w, h)

    local size = 16
    local ty = y + (h - size) / 2

    _draw.push_clip(x, y, w, h)
    _draw.set_colour(t.text_primary)
    _input.text(label, x + 12, ty, size)

    if sub then
        local tw = _font.measure(label, size)
        _draw.set_colour(t.text_tertiary)
        _input.text(sub, x + 12 + tw + 14, ty, size)
    end
    _draw.pop_clip()

    return clicked
end