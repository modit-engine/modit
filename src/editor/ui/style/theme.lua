--- @module theme
--- @file src/editor/ui/style/theme.lua
--- @description Manages color schemes and styling themes across editor panels and UI components.

--- @section Imports

local _themes = require("src.editor.ui.style.themes")

--- @section Initialisation

local active_theme = _themes.default

local m = {}

--- @section Functions

--- Sets the active editor theme by name
--- @param theme_name string Name of the theme key to activate
--- @return boolean success True if the theme exists and was applied, false otherwise
function m.set(theme_name)
    if _themes[theme_name] then
        active_theme = _themes[theme_name]
        return true
    end

    print("Warning: Theme '" .. theme_name .. "' not found")
    return false
end

--- Returns the currently active theme palette
--- @return table active_theme Active theme object
function m.get()
    return active_theme
end

--- Retrieves a specific property value from the active theme palette
--- @param key string Property key name in theme
--- @return any value Property value associated with given key
function m.get_value(key)
    return active_theme[key]
end

return m