--- @module themes
--- @file src/engine/ui/themes/init.lua
--- @description Provides the themes available to the engine UI.

--- @section Module

return {
    default = require("src.editor.ui.style.themes.default"),
    tokyo_night = require("src.editor.ui.style.themes.tokyo_night")
}