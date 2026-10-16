--- @module input
--- @file src/sdk/client/input.lua
--- @description Keyboard, mouse and named action bindings in one flat API.

--- @section Imports

local _keyboard = require("src.engine.backend").keyboard
local _mouse = require("src.engine.backend").mouse

--- @section Constants

local KEY_CODES = {
    -- Letters
    a = 65, b = 66, c = 67, d = 68, e = 69, f = 70, g = 71, h = 72, i = 73, j = 74,
    k = 75, l = 76, m = 77, n = 78, o = 79, p = 80, q = 81, r = 82, s = 83, t = 84,
    u = 85, v = 86, w = 87, x = 88, y = 89, z = 90,

    -- Numbers
    ["0"] = 48, ["1"] = 49, ["2"] = 50, ["3"] = 51, ["4"] = 52,
    ["5"] = 53, ["6"] = 54, ["7"] = 55, ["8"] = 56, ["9"] = 57,

    -- F keys
    f1 = 290, f2 = 291, f3 = 292, f4 = 293, f5 = 294, f6 = 295,
    f7 = 296, f8 = 297, f9 = 298, f10 = 299, f11 = 300, f12 = 301,

    -- Special
    space = 32, enter = 257, escape = 256, tab = 258, backspace = 259,
    leftshift = 340, rightshift = 344, leftctrl = 341, rightctrl = 345,
    leftalt = 342, rightalt = 346,
    arrowup = 265, arrowdown = 264, arrowleft = 263, arrowright = 262,
    home = 268, ["end"] = 269, pageup = 266, pagedown = 267,
    insert = 260, delete = 261,
}

local BUTTONS = { left = 0, right = 1, middle = 2 }

local CURSORS = {
    default = 0, arrow = 1, text = 2, crosshair = 3,
    hand = 4, resize_h = 5, resize_v = 6,
}

--- @section Initialisation

local m = {}

--- @section Keyboard

--- Checks if a key is currently held down
--- @access mod
--- @param key string|number Key name (e.g. "space", "w") or raw keycode
--- @return boolean is_down True if held
function m.key_down(key)
    return _keyboard.down(KEY_CODES[key] or key)
end

--- Checks if a key was pressed this frame
--- @access mod
--- @param key string|number Key name or raw keycode
--- @return boolean is_pressed True if pressed this frame
function m.key_pressed(key)
    return _keyboard.pressed(KEY_CODES[key] or key)
end

--- Checks if a key was released this frame
--- @access mod
--- @param key string|number Key name or raw keycode
--- @return boolean is_released True if released this frame
function m.key_released(key)
    return _keyboard.released(KEY_CODES[key] or key)
end

--- Checks if a key was pressed or auto-repeated this frame
--- @access mod
--- @param key string|number Key name or raw keycode
--- @return boolean is_repeated True if pressed or repeated
function m.key_pressed_repeat(key)
    return _keyboard.pressed_repeat(KEY_CODES[key] or key)
end

--- Gets the next Unicode character typed this frame
--- @access mod
--- @return number char_code Character code, or 0 if the queue is empty
function m.get_char()
    return _keyboard.get_char()
end

--- @section Clipboard

--- Retrieves text from the OS clipboard
--- @access game
--- @return string text Clipboard text, or an empty string
function m.get_clipboard()
    return _keyboard.get_clipboard()
end

--- Sets text on the OS clipboard
--- @access game
--- @param text string Text to copy
function m.set_clipboard(text)
    _keyboard.set_clipboard(text)
end

--- @section Mouse Position

--- Gets the cursor position in screen space
--- @access mod
--- @return number x Screen X position
--- @return number y Screen Y position
function m.get_mouse_position()
    return _mouse.get_position()
end

--- Gets the cursor X position
--- @access mod
--- @return number x Screen X position
function m.get_mouse_x()
    return _mouse.get_x()
end

--- Gets the cursor Y position
--- @access mod
--- @return number y Screen Y position
function m.get_mouse_y()
    return _mouse.get_y()
end

--- Gets cursor movement since the previous frame
--- @access mod
--- @return number dx X displacement in pixels
--- @return number dy Y displacement in pixels
function m.get_mouse_delta()
    return _mouse.get_delta()
end

--- Gets wheel movement for this frame
--- @access mod
--- @return number delta Wheel value (positive up, negative down)
function m.get_mouse_wheel()
    return _mouse.get_wheel()
end

--- Moves the cursor
--- @access game
--- @param x number Target X position
--- @param y number Target Y position
function m.set_mouse_position(x, y)
    _mouse.set_position(x, y)
end

--- Checks if the cursor is inside a rectangle
--- @access mod
--- @param x number Rectangle X
--- @param y number Rectangle Y
--- @param w number Rectangle width
--- @param h number Rectangle height
--- @return boolean inside True if the cursor is inside
function m.mouse_in_rect(x, y, w, h)
    local mx, my = _mouse.get_position()
    return mx >= x and mx < x + w and my >= y and my < y + h
end

--- @section Mouse Buttons

--- Checks if a button was pressed this frame
--- @access mod
--- @param button string|number|nil "left", "right", "middle" or raw code (default "left")
--- @return boolean is_pressed True if pressed this frame
function m.mouse_pressed(button)
    button = button or "left"
    return _mouse.pressed(BUTTONS[button] or button)
end

--- Checks if a button is held down
--- @access mod
--- @param button string|number|nil "left", "right", "middle" or raw code (default "left")
--- @return boolean is_down True if held
function m.mouse_down(button)
    button = button or "left"
    return _mouse.down(BUTTONS[button] or button)
end

--- Checks if a button was released this frame
--- @access mod
--- @param button string|number|nil "left", "right", "middle" or raw code (default "left")
--- @return boolean is_released True if released this frame
function m.mouse_released(button)
    button = button or "left"
    return _mouse.released(BUTTONS[button] or button)
end

--- @section Cursor

--- Sets the OS cursor icon
--- @access mod
--- @param name string "default", "arrow", "text", "crosshair", "hand", "resize_h", "resize_v"
function m.set_cursor(name)
    _mouse.set_cursor(CURSORS[name] or 0)
end

--- Shows the system cursor
--- @access game
function m.show_cursor()
    _mouse.show()
end

--- Hides the system cursor
--- @access game
function m.hide_cursor()
    _mouse.hide()
end

--- Locks and hides the cursor inside the window for 3D camera control
--- @access game
function m.lock_mouse()
    _mouse.lock()
end

--- Unlocks the cursor and restores normal behaviour
--- @access game
function m.unlock_mouse()
    _mouse.unlock()
end

--- @section Actions

local actions = {} -- name -> { bindings, owner }
local held = {}    -- name -> seconds held

local KEY_CHECKS = { pressed = m.key_pressed, down = m.key_down, released = m.key_released }
local MOUSE_CHECKS = { pressed = m.mouse_pressed, down = m.mouse_down, released = m.mouse_released }

local function check_binding(binding, check)
    if type(binding) == "string" then
        return KEY_CHECKS[check](binding)
    elseif type(binding) == "table" and binding.mouse_button then
        return MOUSE_CHECKS[check](binding.mouse_button)
    end
    return false
end

local function check_action(name, check)
    local action = actions[name]
    if not action then return false end

    for _, binding in ipairs(action.bindings) do
        if check_binding(binding, check) then return true end
    end
    return false
end

--- Maps an action name to a list of input bindings
--- @access mod
--- @param name string Unique action name
--- @param bindings table Key name strings or { mouse_button = button }
--- @param owner string|nil Owner name, for clear_owner_actions cleanup
function m.map_action(name, bindings, owner)
    actions[name] = { bindings = bindings, owner = owner }
    held[name] = nil
end

--- Checks if an action was pressed this frame
--- @access mod
--- @param name string Action name
--- @return boolean is_pressed True if pressed this frame
function m.action_pressed(name)
    return check_action(name, "pressed")
end

--- Checks if an action is held down
--- @access mod
--- @param name string Action name
--- @return boolean is_down True if held
function m.action_down(name)
    return check_action(name, "down")
end

--- Checks if an action was released this frame
--- @access mod
--- @param name string Action name
--- @return boolean is_released True if released this frame
function m.action_released(name)
    return check_action(name, "released")
end

--- Gets how long an action has been held
--- @access mod
--- @param name string Action name
--- @return number seconds Seconds held, 0 if not down
function m.get_action_hold_time(name)
    return held[name] or 0
end

--- Removes every action made by an owner
--- @access mod
--- @param owner string Owner name
function m.clear_owner_actions(owner)
    for name, action in pairs(actions) do
        if action.owner == owner then
            actions[name] = nil
            held[name] = nil
        end
    end
end

--- Removes every action
--- @access game
function m.clear_actions()
    actions = {}
    held = {}
end

--- @section Engine Internal

--- Advances action hold timers. Called by the engine once per frame, not by games
--- @param dt number Delta time in seconds
function m.update(dt)
    for name in pairs(actions) do
        if check_action(name, "down") then
            held[name] = (held[name] or 0) + dt
        else
            held[name] = nil
        end
    end
end

return m