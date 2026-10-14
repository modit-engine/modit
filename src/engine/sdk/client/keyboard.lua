--- @module keyboard
--- @file src/engine/sdk/client/keyboard.lua
--- @description Keyboard input state, key name mapping, and OS clipboard access.

--- @section Imports

local _backend = require("src.engine.backend").keyboard

--- @section Constants

local KEYMAP = {
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

--- @section Initialisation

local m = {}

--- @section Text & Clipboard

--- Gets the next Unicode character typed this frame
--- @return number char_code Character code, or 0 if the queue is empty
function m.get_char()
    return _backend.get_char()
end

--- Retrieves text from the OS clipboard
--- @return string text Clipboard text, or an empty string
function m.get_clipboard()
    return _backend.get_clipboard()
end

--- Sets text on the OS clipboard
--- @param text string Text to copy
function m.set_clipboard(text)
    _backend.set_clipboard(text)
end

--- @section Key State

--- Checks if a key is currently held down
--- @param key string|number Key name (e.g. "space", "w") or raw keycode
--- @return boolean is_down True if held
function m.down(key)
    return _backend.down(KEYMAP[key] or key)
end

--- Checks if a key was pressed this frame
--- @param key string|number Key name or raw keycode
--- @return boolean is_pressed True if pressed this frame
function m.pressed(key)
    return _backend.pressed(KEYMAP[key] or key)
end

--- Checks if a key was released this frame
--- @param key string|number Key name or raw keycode
--- @return boolean is_released True if released this frame
function m.released(key)
    return _backend.released(KEYMAP[key] or key)
end

--- Checks if a key was pressed or auto-repeated this frame
--- @param key string|number Key name or raw keycode
--- @return boolean is_repeated True if pressed or repeated
function m.pressed_repeat(key)
    return _backend.pressed_repeat(KEYMAP[key] or key)
end

return m