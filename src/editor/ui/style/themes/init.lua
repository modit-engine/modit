--- @module themes
--- @file src/editor/ui/style/themes/init.lua
--- @description Registers editor-only themes with the engine theme manager.

--- @section Imports

local _theme = require("src.engine.ui.style.theme")

--- @section Registration

_theme.register("tokyo_night", require("src.editor.ui.style.themes.tokyo_night"))

return {}