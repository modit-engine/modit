--- @module mouse
--- @file src/engine/sdk/client/mouse.lua
--- @description Mouse buttons, position, wheel, cursor style, visibility and lock.

--- @section Imports

local _backend = require("src.engine.backend").mouse

--- @section Constants

local BUTTONS = { left = 0, right = 1, middle = 2 }

local CURSORS = {
    default = 0, arrow = 1, text = 2, crosshair = 3,
    hand = 4, resize_h = 5, resize_v = 6,
}

--- @section Initialisation

local m = {}

--- @section Position & Movement

--- Gets the cursor position in screen space
--- @return number x Screen X position
--- @return number y Screen Y position
function m.get_position()
    return _backend.get_position()
end

--- Gets the cursor X position
--- @return number x Screen X position
function m.get_x()
    return _backend.get_x()
end

--- Gets the cursor Y position
--- @return number y Screen Y position
function m.get_y()
    return _backend.get_y()
end

--- Gets cursor movement since the previous frame
--- @return number dx X displacement in pixels
--- @return number dy Y displacement in pixels
function m.get_delta()
    return _backend.get_delta()
end

--- Gets wheel movement for this frame
--- @return number delta Wheel value (positive up, negative down)
function m.get_wheel()
    return _backend.get_wheel()
end

--- Moves the cursor
--- @param x number Target X position
--- @param y number Target Y position
function m.set_position(x, y)
    _backend.set_position(x, y)
end

--- Checks if the cursor is inside a rectangle
--- @param x number Rectangle X
--- @param y number Rectangle Y
--- @param w number Rectangle width
--- @param h number Rectangle height
--- @return boolean inside True if the cursor is inside
function m.in_rect(x, y, w, h)
    local mx, my = _backend.get_position()
    return mx >= x and mx < x + w and my >= y and my < y + h
end

--- @section Buttons

--- Checks if a button was pressed this frame
--- @param button string|number|nil "left", "right", "middle" or raw code (default "left")
--- @return boolean is_pressed True if pressed this frame
function m.pressed(button)
    button = button or "left"
    return _backend.pressed(BUTTONS[button] or button)
end

--- Checks if a button is held down
--- @param button string|number|nil "left", "right", "middle" or raw code (default "left")
--- @return boolean is_down True if held
function m.down(button)
    button = button or "left"
    return _backend.down(BUTTONS[button] or button)
end

--- Checks if a button was released this frame
--- @param button string|number|nil "left", "right", "middle" or raw code (default "left")
--- @return boolean is_released True if released this frame
function m.released(button)
    button = button or "left"
    return _backend.released(BUTTONS[button] or button)
end

--- @section Cursor

--- Sets the OS cursor icon
--- @param name string "default", "arrow", "text", "crosshair", "hand", "resize_h", "resize_v"
function m.set_cursor(name)
    _backend.set_cursor(CURSORS[name] or 0)
end

--- Shows the system cursor
function m.show()
    _backend.show()
end

--- Hides the system cursor
function m.hide()
    _backend.hide()
end

--- Locks and hides the cursor inside the window for 3D camera control
function m.lock()
    _backend.lock()
end

--- Unlocks the cursor and restores normal behaviour
function m.unlock()
    _backend.unlock()
end

return m