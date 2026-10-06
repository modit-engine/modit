--- @module icon_button
--- @file src/editor/ui/components/icon_button.lua
--- @description Square button showing an icon. Background only appears on hover/press.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")

--- Editor
local _input = require("src.editor.ui.input")
local _icons = require("src.editor.ui.style.icons")
local _theme = require("src.editor.ui.style.theme")

--- @section Function

--- Returns true when clicked.
--- @param name string: icon name (see icons.lua)
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param colour? table: icon colour (default text_secondary, text_primary on hover)
--- @param size? number: icon size (default 16)
return function(name, x, y, w, h, colour, size)
    local t = _theme.get()
    local over, clicked, held = _input.interact(x, y, w, h)

    if held then
        _draw.set_colour(t.accent2)
        _draw.rect(x, y, w, h)
    elseif over then
        _draw.set_colour(t.bg_hover)
        _draw.rect(x, y, w, h)
    end

    _draw.set_colour(colour or (over and t.text_primary or t.text_secondary))
    _icons.draw(name, x, y, w, h, size)

    return clicked
end