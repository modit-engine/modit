--- @module mouse
--- @file src/engine/backend/raylib/input/mouse.lua
--- @description Mouse input position, button state queries, wheel movement delta, and hardware cursor control.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _lib = _raylib.lib

--- @section Initialisation

local m = {}

--- @section Position & Movement

--- Returns current mouse coordinates in screen space
--- @return number x Screen X position
--- @return number y Screen Y position
function m.get_position()
    return _lib.GetMouseX(), _lib.GetMouseY()
end

--- Returns current mouse X coordinate in screen space
--- @return number x Screen X position
function m.get_x()
    return _lib.GetMouseX()
end

--- Returns current mouse Y coordinate in screen space
--- @return number y Screen Y position
function m.get_y()
    return _lib.GetMouseY()
end

--- Returns mouse movement delta for current frame
--- @return number delta_x Mouse movement delta along X axis
--- @return number delta_y Mouse movement delta along Y axis
function m.get_delta()
    local delta_vec = _lib.GetMouseDelta()
    return delta_vec.x, delta_vec.y
end

--- Sets current mouse position in screen space
--- @param pos_x number Target X position
--- @param pos_y number Target Y position
function m.set_position(pos_x, pos_y)
    _lib.SetMousePosition(pos_x, pos_y)
end

--- @section Button Input

--- Checks if a mouse button was pressed during current frame
--- @param button_code number Raylib mouse button code
--- @return boolean is_pressed True if mouse button was pressed
function m.pressed(button_code)
    return _lib.IsMouseButtonPressed(button_code)
end

--- Checks if a mouse button is currently held down
--- @param button_code number Raylib mouse button code
--- @return boolean is_down True if mouse button is currently down
function m.down(button_code)
    return _lib.IsMouseButtonDown(button_code)
end

--- Checks if a mouse button was released during current frame
--- @param button_code number Raylib mouse button code
--- @return boolean is_released True if mouse button was released
function m.released(button_code)
    return _lib.IsMouseButtonReleased(button_code)
end

--- @section Wheel & Cursor Style

--- Returns mouse wheel movement delta for current frame
--- @return number wheel_delta Mouse wheel movement delta
function m.get_wheel()
    return _lib.GetMouseWheelMove()
end

--- Sets active hardware cursor icon/style
--- @param cursor_style number Raylib mouse cursor identifier
function m.set_cursor(cursor_style)
    _lib.SetMouseCursor(cursor_style)
end

--- @section Visibility & Lock

--- Shows the hardware mouse cursor
function m.show()
    _lib.ShowCursor()
end

--- Hides the hardware mouse cursor
function m.hide()
    _lib.HideCursor()
end

--- Disables and locks the mouse cursor to the window frame
function m.lock()
    _lib.DisableCursor()
end

--- Enables and unlocks the mouse cursor
function m.unlock()
    _lib.EnableCursor()
end

return m