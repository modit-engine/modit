--- @module theme
--- @file src/engine/ui/theme.lua
--- @description Theme registry and active theme state for engine UI. Ships with the default theme.

--- @section Imports

local _default = require("src.sdk.ui.default_theme")

--- @section Initialisation

local themes = { default = _default }
local active_name = "default"
local active_theme = _default
local listeners = {}

local m = {}

--- @section Functions

--- Registers a theme. Missing keys fall back to the default theme (shallow).
--- @param name string Theme key
--- @param theme table Theme palette
function m.register(name, theme)
    if theme ~= _default then
        setmetatable(theme, { __index = _default })
    end
    themes[name] = theme
end

--- Sets the active theme by name
--- @param theme_name string Name of the theme key to activate
--- @return boolean success True if the theme exists and was applied
function m.set(theme_name)
    local t = themes[theme_name]
    if not t then
        print("Warning: Theme '" .. tostring(theme_name) .. "' not found")
        return false
    end

    active_name, active_theme = theme_name, t
    for _, fn in ipairs(listeners) do fn(theme_name, t) end
    return true
end

--- Returns the active theme palette
--- @return table active_theme
function m.get() return active_theme end

--- Returns the active theme's name
--- @return string name
function m.name() return active_name end

--- Retrieves a single value from the active theme
--- @param key string Property key
--- @return any value
function m.get_value(key) return active_theme[key] end

--- Returns a sorted list of registered theme names (for pickers)
--- @return table names
function m.list()
    local names = {}
    for k in pairs(themes) do names[#names + 1] = k end
    table.sort(names)
    return names
end

--- Subscribes to theme changes (e.g. to reload fonts or invalidate caches)
--- @param fn function Called as fn(name, theme)
function m.on_change(fn) listeners[#listeners + 1] = fn end

return m