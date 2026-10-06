--- @module input
--- @file src/editor/ui/input.lua
--- @description Per-frame mouse, keyboard, cursor, and focus interaction state management shared by UI components.

--- @section Imports

local _draw = require("src.engine.modules.draw")
local _mouse = require("src.engine.modules.mouse")
local _keyboard = require("src.engine.modules.keyboard")
local _font = require("src.engine.modules.font")

--- @section Initialisation

local m = {}

local mouse_x, mouse_y = 0, 0
local is_pressed, is_down, is_released = false, false, false
local wheel_delta = 0

local next_element_id = 0
local hot_id, active_id = nil, nil
local active_cursor = "default"
local is_blocked = false

local typed_chars, char_count = {}, 0
local active_focus = nil

--- @section Text Helpers

--- Draws text using active font or falls back to engine draw module
--- @param str string Text string to render
--- @param pos_x number X position
--- @param pos_y number Y position
--- @param font_size number Font size in pixels
function m.text(str, pos_x, pos_y, font_size)
    local font_instance = _font.get(font_size)
    if font_instance then
        _font.draw(font_instance, str, math.floor(pos_x), math.floor(pos_y))
    else
        _draw.text(str, pos_x, pos_y, font_size)
    end
end

--- Measures text width using active font or falls back to engine draw module
--- @param str string Text string to measure
--- @param font_size number Font size in pixels
--- @return number width Measured text width in pixels
function m.measure(str, font_size)
    local font_instance = _font.get(font_size)
    if font_instance then
        return _font.measure(font_instance, str)
    end
    return _draw.measure_text(str, font_size)
end

--- @section Interaction State

--- Sets global input block status
--- @param blocked boolean True to block input interactions
function m.set_blocked(blocked)
    is_blocked = blocked
end

--- Checks if current mouse coordinate sits inside bounding rectangle considering active scissor clip
--- @param rect_x number Box X position
--- @param rect_y number Box Y position
--- @param rect_w number Box width
--- @param rect_h number Box height
--- @return boolean is_inside True if mouse is within box and current scissor area
function m.in_rect(rect_x, rect_y, rect_w, rect_h)
    if is_blocked then return false end
    if not (mouse_x >= rect_x and mouse_x < rect_x + rect_w and mouse_y >= rect_y and mouse_y < rect_y + rect_h) then
        return false
    end
    local clip_x, clip_y, clip_w, clip_h = _draw.get_clip()
    if clip_x and not (mouse_x >= clip_x and mouse_x < clip_x + clip_w and mouse_y >= clip_y and mouse_y < clip_y + clip_h) then
        return false
    end
    return true
end

--- Processes element interaction state for mouse hover, click release, and hold states
--- @param rect_x number Box X position
--- @param rect_y number Box Y position
--- @param rect_w number Box width
--- @param rect_h number Box height
--- @return boolean is_hovered True if mouse is hovering over bounding box
--- @return boolean is_clicked True if mouse released over element while active
--- @return boolean is_held True if mouse is held down over element
function m.interact(rect_x, rect_y, rect_w, rect_h)
    next_element_id = next_element_id + 1
    local element_id = next_element_id

    local is_hovered = m.in_rect(rect_x, rect_y, rect_w, rect_h)
    if is_hovered then
        hot_id = element_id
        active_cursor = "hand"
        if is_pressed then
            active_id = element_id
        end
    end

    local is_clicked = is_hovered and is_released and (active_id == element_id)
    local is_held = is_hovered and (active_id == element_id)
    return is_hovered, is_clicked, is_held
end

--- Returns current mouse coordinates
--- @return number x Mouse X position
--- @return number y Mouse Y position
function m.mouse()
    return mouse_x, mouse_y
end

--- Returns scroll wheel movement delta
--- @return number wheel_delta Mouse wheel change
function m.wheel()
    return wheel_delta
end

--- Returns mouse left button pressed state for current frame
--- @return boolean is_pressed True on frame button was pressed
function m.pressed()
    return is_pressed
end

--- Returns mouse left button down state
--- @return boolean is_down True while mouse button is held
function m.down()
    return is_down
end

--- Generates a unique UI element identifier
--- @return number id Generated unique ID
function m.new_id()
    next_element_id = next_element_id + 1
    return next_element_id
end

--- Sets current hot UI element identifier
--- @param id number Element ID
function m.set_hot(id)
    hot_id = id
end

--- Checks if specified element ID is currently active
--- @param id number Element ID
--- @return boolean is_active True if element is active
function m.is_active(id)
    return active_id == id
end

--- Sets active UI element identifier
--- @param id number Element ID
function m.set_active(id)
    active_id = id
end

--- Sets current mouse cursor icon name
--- @param cursor_name string Cursor style identifier
function m.set_cursor(cursor_name)
    active_cursor = cursor_name
end

--- Checks if any UI element is currently hovered
--- @return boolean is_hovered True if hot element exists
function m.is_hovered()
    return hot_id ~= nil
end

--- @section Frame Lifecycle

--- Prepares input state at start of frame
function m.begin_frame()
    mouse_x, mouse_y = _mouse.get_position()
    is_pressed, is_down, is_released = _mouse.pressed(), _mouse.down(), _mouse.released()
    wheel_delta = _mouse.get_wheel()
    next_element_id = 0
    hot_id = nil
    active_cursor = "default"

    char_count = 0
    while true do
        local character_code = _keyboard.get_char()
        if character_code == 0 then break end
        char_count = char_count + 1
        typed_chars[char_count] = character_code
    end
end

--- Finalizes input state and updates hardware cursor at end of frame
function m.end_frame()
    if is_released or not is_down then
        active_id = nil
    end
    _mouse.set_cursor(active_cursor)
end

--- @section Focus Management

--- Clears active keyboard focus
function m.blur()
    active_focus = nil
end

--- Assigns keyboard focus to given focus token
--- @param token any Focus token or component state reference
function m.set_focus(token)
    active_focus = token
end

--- Checks if given focus token currently holds focus
--- @param token any Focus token reference
--- @return boolean has_focus True if token currently holds focus
function m.has_focus(token)
    return token ~= nil and active_focus == token
end

--- Returns buffer of characters typed during current frame
--- @return table typed_chars List of character code integers
--- @return number char_count Count of character codes in list
function m.typed()
    return typed_chars, char_count
end

return m