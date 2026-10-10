--- @file src/engine/core/input/mouse.lua
--- @description Mouse input, cursor state, positioning, and spatial intersection queries.

--- @section Imports

local backend = require("src.engine.backend").mouse

--- @section Constants

local BUTTONS = { left = 0, right = 1, middle = 2 }

local CURSORS = {
    default = 0, arrow = 1, text = 2, crosshair = 3,
    hand = 4, resize_h = 5, resize_v = 6,
}

--- @section Module

local m = {}

--- @section Functions

--- Retrieves current screen coordinates of the mouse cursor.
--- @return number x Screen X position in pixels.
--- @return number y Screen Y position in pixels.
m.get_position = backend.get_position

--- Retrieves current X position of the mouse cursor.
--- @return number x Screen X position in pixels.
m.get_x = backend.get_x

--- Retrieves current Y position of the mouse cursor.
--- @return number y Screen Y position in pixels.
m.get_y = backend.get_y

--- Retrieves mouse wheel movement delta for the current frame.
--- @return number delta Wheel scroll value (positive up, negative down).
m.get_wheel = backend.get_wheel

--- Retrieves mouse movement delta since the previous frame.
--- @return number dx X displacement in pixels.
--- @return number dy Y displacement in pixels.
m.get_delta = backend.get_delta

--- Repositions the mouse cursor on screen.
--- @param x number Target X coordinate.
--- @param y number Target Y coordinate.
m.set_position = backend.set_position

--- @section Visibility & Lock State

--- Shows the hardware/system mouse cursor.
m.show = backend.show

--- Hides the hardware/system mouse cursor.
m.hide = backend.hide

--- Locks and hides the mouse cursor inside the window for relative 3D camera controls.
m.lock = backend.lock

--- Unlocks and restores normal mouse cursor behavior.
m.unlock = backend.unlock

--- Checks if a mouse button was pressed down during the current frame.
--- @param button string|nil Button name ("left", "right", "middle"). Defaults to "left".
--- @return boolean True if clicked this frame.
function m.pressed(button) 
    return backend.pressed(BUTTONS[button or "left"]) 
end

--- Checks if a mouse button is currently being held down.
--- @param button string|nil Button name ("left", "right", "middle"). Defaults to "left".
--- @return boolean True if held down.
function m.down(button) 
    return backend.down(BUTTONS[button or "left"]) 
end

--- Checks if a mouse button was released during the current frame.
--- @param button string|nil Button name ("left", "right", "middle"). Defaults to "left".
--- @return boolean True if released this frame.
function m.released(button) 
    return backend.released(BUTTONS[button or "left"]) 
end

--- Sets the active OS cursor icon style.
--- @param name string Cursor name ("default", "arrow", "text", "crosshair", "hand", "resize_h", "resize_v").
function m.set_cursor(name) 
    backend.set_cursor(CURSORS[name] or 0) 
end

--- Checks if the current mouse cursor position falls inside a rectangle boundary.
--- @param x number Top-left X coordinate of the rectangle.
--- @param y number Top-left Y coordinate of the rectangle.
--- @param w number Width of the rectangle.
--- @param h number Height of the rectangle.
--- @return boolean True if mouse is hovering over the rectangle.
function m.in_rect(x, y, w, h)
    local mx, my = backend.get_position()
    return mx >= x and mx < x + w and my >= y and my < y + h
end

return m