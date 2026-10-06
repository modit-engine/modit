--- @module keyboard
--- @file src/engine/backend/raylib/input/keyboard.lua
--- @description Keyboard input state queries and OS clipboard text interaction.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _lib, _ffi = _raylib.lib, _raylib.ffi

--- @section Initialisation

local m = {}

--- @section Keyboard Input

--- Gets next character queue code typed during current frame
--- @return number char_code Character Unicode code point or 0 if queue is empty
function m.get_char()
    return _lib.GetCharPressed()
end

--- Checks if a key is currently held down
--- @param key_code number Raylib key code constant
--- @return boolean is_down True if key is currently down
function m.down(key_code)
    return _lib.IsKeyDown(key_code)
end

--- Checks if a key was pressed during current frame
--- @param key_code number Raylib key code constant
--- @return boolean is_pressed True if key was pressed
function m.pressed(key_code)
    return _lib.IsKeyPressed(key_code)
end

--- Checks if a key was released during current frame
--- @param key_code number Raylib key code constant
--- @return boolean is_released True if key was released
function m.released(key_code)
    return _lib.IsKeyReleased(key_code)
end

--- Checks if a key press repeated during current frame (key hold auto-repeat)
--- @param key_code number Raylib key code constant
--- @return boolean is_repeated True if key repeat event triggered
function m.pressed_repeat(key_code)
    return _lib.IsKeyPressedRepeat(key_code)
end

--- @section Clipboard

--- Retrieves current operating system clipboard text string
--- @return string text Clipboard text or empty string if empty / non-text
function m.get_clipboard()
    local str_ptr = _lib.GetClipboardText()
    if str_ptr == nil then
        return ""
    end
    return _ffi.string(str_ptr)
end

--- Sets operating system clipboard text
--- @param text string Text string to copy to clipboard
function m.set_clipboard(text)
    _lib.SetClipboardText(text)
end

return m