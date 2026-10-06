--- @module keyboard
--- @file src/engine/input/keyboard.lua
--- @description Keyboard input state tracking, key code mapping, and OS clipboard interactions.

-- Constants

local KEYMAP = {
    -- Letters
    a = 65, b = 66, c = 67, d = 68, e = 69, f = 70, g = 71, h = 72, i = 73, j = 74,
    k = 75, l = 76, m = 77, n = 78, o = 79, p = 80, q = 81, r = 82, s = 83, t = 84,
    u = 85, v = 86, w = 87, x = 88, y = 89, z = 90,

    -- Numbers
    ["0"] = 48, ["1"] = 49, ["2"] = 50, ["3"] = 51, ["4"] = 52,
    ["5"] = 53, ["6"] = 54, ["7"] = 55, ["8"] = 56, ["9"] = 57,

    -- F Keys
    f1 = 290, f2 = 291, f3 = 292, f4 = 293, f5 = 294, f6 = 295,
    f7 = 296, f8 = 297, f9 = 298, f10 = 299, f11 = 300, f12 = 301,

    -- Special
    space = 32, enter = 257, escape = 256, tab = 258, backspace = 259,
    leftshift = 340, rightshift = 344, leftctrl = 341, rightctrl = 345,
    leftalt = 342, rightalt = 346,
    arrowup = 265, arrowdown = 264, arrowleft = 263, arrowright = 262,
    home = 268, end_key = 269, ["end"] = 269, pageup = 266, pagedown = 267,
    insert = 260, delete = 261,
}

-- Initialisation

local backend = require("src.engine.backend").keyboard

local m = { KEYMAP = KEYMAP }

-- Functions

--- Gets the Unicode character code queued from key input during the frame
--- @return number char_code The character code, or 0 if queue is empty
m.get_char = backend.get_char

--- Retrieves text currently stored on the OS system clipboard
--- @return string text Text string from clipboard
m.get_clipboard = backend.get_clipboard

--- Sets text onto the OS system clipboard
--- @param text string Text to write to the clipboard
m.set_clipboard = backend.set_clipboard

--- Checks if a key is currently held down
--- @param key string|number Key name (e.g., "space", "w") or raw numeric keycode
--- @return boolean True if held down
function m.down(key)
    return backend.down(KEYMAP[key] or key)
end

--- Checks if a key was pressed down during the current frame
--- @param key string|number Key name or raw numeric keycode
--- @return boolean True if pressed this frame
function m.pressed(key)
    return backend.pressed(KEYMAP[key] or key)
end

--- Checks if a key was released during the current frame
--- @param key string|number Key name or raw numeric keycode
--- @return boolean True if released this frame
function m.released(key)
    return backend.released(KEYMAP[key] or key)
end

--- Checks if a key was pressed or repeated due to key-repeat delay
--- @param key string|number Key name or raw numeric keycode
--- @return boolean True if pressed or repeated this frame
function m.pressed_repeat(key)
    return backend.pressed_repeat(KEYMAP[key] or key)
end

return m