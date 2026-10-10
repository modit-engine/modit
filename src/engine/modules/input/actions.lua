--- @module actions
--- @file src/engine/modules/actions.lua
--- @description Maps action names to keyboard and mouse bindings.

--- @section Imports

local _keyboard = require("src.engine.modules.input.keyboard")
local _mouse = require("src.engine.modules.input.mouse")

--- @section Initialisation

local m = {}

local _actions = {} -- name -> { bindings, owner }
local _held = {}    -- name -> seconds held

--- @section Helpers

--- Checks one binding against its device
--- @param binding string|table Keyboard key name, or { mouse_button = button }
--- @param check string Device function name: "pressed", "down" or "released"
--- @return boolean
local function check_binding(binding, check)
    if type(binding) == "string" then
        return _keyboard[check](binding)
    elseif type(binding) == "table" and binding.mouse_button then
        return _mouse[check](binding.mouse_button)
    end
    return false
end

--- Checks whether any binding of an action triggers
--- @param name string Action name
--- @param check string Device function name: "pressed", "down" or "released"
--- @return boolean
local function check_action(name, check)
    local action = _actions[name]
    if not action then return false end

    for _, binding in ipairs(action.bindings) do
        if check_binding(binding, check) then return true end
    end
    return false
end

--- @section API

--- Maps an action name to a list of input bindings
--- @param name string Unique name of the action
--- @param bindings table List of bindings: key name strings or { mouse_button = button }
--- @param owner string|nil Owner name, for remove_owner cleanup
function m.map_action(name, bindings, owner)
    _actions[name] = { bindings = bindings, owner = owner }
    _held[name] = nil
end

--- Advances hold timers. Call once per frame (client only)
--- @param dt number Delta time in seconds
function m.update(dt)
    for name in pairs(_actions) do
        if check_action(name, "down") then
            _held[name] = (_held[name] or 0) + dt
        else
            _held[name] = nil
        end
    end
end

--- Checks if an action was pressed this frame
--- @param name string Action name
--- @return boolean
function m.is_action_pressed(name)
    return check_action(name, "pressed")
end

--- Checks if an action is currently held down
--- @param name string Action name
--- @return boolean
function m.is_action_down(name)
    return check_action(name, "down")
end

--- Checks if an action was released this frame
--- @param name string Action name
--- @return boolean
function m.is_action_released(name)
    return check_action(name, "released")
end

--- Gets how long an action has been held, in seconds. Requires update(dt) each frame
--- @param name string Action name
--- @return number seconds 0 if not currently down
function m.hold_time(name)
    return _held[name] or 0
end

--- Removes every action mapped by an owner
--- @param owner string Owner name
function m.remove_owner(owner)
    for name, action in pairs(_actions) do
        if action.owner == owner then
            _actions[name] = nil
            _held[name] = nil
        end
    end
end

--- Clears all action mappings
function m.clear_actions()
    _actions = {}
    _held = {}
end

return m