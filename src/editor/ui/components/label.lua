--- @module label
--- @file src/editor/ui/components/label.lua
--- @description Simple UI text label component with color override support.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")

--- Editor
local _input = require("src.editor.ui.input")
local _theme = require("src.editor.ui.style.theme")

--- @section Component

--- Renders a text label string with optional font sizing and color overriding
--- @param str string Text string to render
--- @param x number X screen coordinate
--- @param y number Y screen coordinate
--- @param size number|nil Font size in pixels (defaults to 16)
--- @param c table|number|nil RGBA color table or hex value (defaults to primary text theme color)
return function(str, x, y, size, c)
    _draw.set_colour(c or _theme.get().text_primary)
    _input.text(str, x, y, size or 16)
end