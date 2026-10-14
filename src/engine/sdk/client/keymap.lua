--- @module keymapping
--- @file src/engine/sdk/client/keymapping.lua
--- @description Maps names to keyboard and mouse bindings.

--- @section Imports

local _keyboard = require("src.engine.sdk.client.keyboard")
local _mouse = require("src.engine.sdk.client.mouse")

--- @section Initialisation

local m = {}

local mappings = {} -- name -> { bindings, owner }
local held = {}     -- name -> seconds held

--- @section Helpers

local function check_binding(binding, check)
    if type(binding) == "string" then
        return _keyboard[check](binding)
    elseif type(binding) == "table" and binding.mouse_button then
        return _mouse[check](binding.mouse_button)
    end
    return false
end

local function check_mapping(name, check)
    local mapping = mappings[name]
    if not mapping then return false end

    for _, binding in ipairs(mapping.bindings) do
        if check_binding(binding, check) then return true end
    end
    return false
end

--- @section Functions

--- Maps a name to a list of input bindings
--- @param name string Unique mapping name
--- @param bindings table Key name strings or { mouse_button = button }
--- @param owner string|nil Owner name, for remove_owner cleanup
function m.map(name, bindings, owner)
    mappings[name] = { bindings = bindings, owner = owner }
    held[name] = nil
end

--- Checks if a mapping was pressed this frame
--- @param name string Mapping name
--- @return boolean is_pressed True if pressed this frame
function m.pressed(name)
    return check_mapping(name, "pressed")
end

--- Checks if a mapping is held down
--- @param name string Mapping name
--- @return boolean is_down True if held
function m.down(name)
    return check_mapping(name, "down")
end

--- Checks if a mapping was released this frame
--- @param name string Mapping name
--- @return boolean is_released True if released this frame
function m.released(name)
    return check_mapping(name, "released")
end

--- Gets how long a mapping has been held
--- @param name string Mapping name
--- @return number seconds Seconds held, 0 if not down
function m.hold_time(name)
    return held[name] or 0
end

--- Removes every mapping made by an owner
--- @param owner string Owner name
function m.remove_owner(owner)
    for name, mapping in pairs(mappings) do
        if mapping.owner == owner then
            mappings[name] = nil
            held[name] = nil
        end
    end
end

--- Removes every mapping
function m.clear()
    mappings = {}
    held = {}
end

--- @section Engine Internal

--- Advances hold timers. Called by the engine once per frame, not by games
--- @param dt number Delta time in seconds
function m.update(dt)
    for name in pairs(mappings) do
        if check_mapping(name, "down") then
            held[name] = (held[name] or 0) + dt
        else
            held[name] = nil
        end
    end
end

return m