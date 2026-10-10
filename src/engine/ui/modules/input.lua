--- @module input
--- @file src/editor/ui/input.lua
--- @description Per-frame mouse, keyboard, cursor, and focus interaction state management shared by UI components.

--- @section Imports

local _draw = require("src.engine.modules.draw")
local _mouse = require("src.engine.modules.input.mouse")
local _keyboard = require("src.engine.modules.input.keyboard")
local _font = require("src.engine.modules.font")
local _theme = require("src.engine.ui.modules.theme")

--- @section Constants

local SCROLL_SPEED = 54

--- @section Initialisation

local m = {}

local mouse_x, mouse_y = 0, 0
local is_pressed, is_down, is_released = false, false, false
local wheel_delta = 0

local next_element_id = 0
local hot_id, active_id = nil, nil
local active_cursor = "default"
local drag_origin, drag_value = 0, 0

local is_blocked = false

local typed_chars, char_count = {}, 0
local active_focus = nil

local scroll_stack, scroll_depth = {}, 0

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

--- Returns mouse left button released state for current frame
--- @return boolean is_released True on frame button release
function m.released()
    return is_released
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
    scroll_depth = 0

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

--- @section Text Input

--- Renders interactive single-line text input field
--- @param state table State container table containing `.text` string and optional `.max` length limit
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @param filter string|nil Optional Lua pattern character filter
--- @param placeholder string|nil Optional placeholder text when empty
--- @return boolean submitted True if Enter key was pressed while focused
function m.textfield(state, x, y, w, h, filter, placeholder)
    local theme = _theme.get()

    next_element_id = next_element_id + 1
    local element_id = next_element_id
    local over = m.in_rect(x, y, w, h)

    if over then
        hot_id = element_id
        active_cursor = "text"
    end

    if is_pressed then
        if over then
            active_focus = state
        elseif active_focus == state then
            active_focus = nil
        end
    end

    local focused = active_focus == state
    local submitted = false

    if focused then
        local max_length = state.max or 32
        for i = 1, char_count do
            local char_code = typed_chars[i]
            if char_code >= 32 and char_code < 127 then
                local ch = string.char(char_code)
                if (not filter or ch:match(filter)) and #state.text < max_length then
                    state.text = state.text .. ch
                end
            end
        end

        if _keyboard.pressed("backspace") or _keyboard.pressed_repeat("backspace") then
            state.text = state.text:sub(1, -2)
        end

        if _keyboard.pressed("enter") then
            submitted = true
        end

        if _keyboard.pressed("escape") then
            active_focus = nil
        end
    end

    local bg = theme.bg_input
    if focused or over then
        bg = theme.bg_hover
    end

    _draw.set_colour(bg)
    _draw.rect(x, y, w, h)

    local size, pad = 16, 8
    local inner_w = w - pad * 2
    local text_y = y + (h - size) / 2

    _draw.push_clip(x + pad, y, inner_w, h)
        if state.text == "" and not focused and placeholder then
            _draw.set_colour(theme.text_tertiary)
            m.text(placeholder, x + pad, text_y, size)
        else
            local text_w = m.measure(state.text, size)
            local offset_x = math.max(0, text_w - inner_w + 2)

            _draw.set_colour(theme.text_primary)
            m.text(state.text, x + pad - offset_x, text_y, size)

            if focused and math.floor(os.clock() * 2) % 2 == 0 then
                _draw.set_colour(theme.accent)
                _draw.rect(x + pad - offset_x + text_w + 1, y + 6, 2, h - 12)
            end
        end
    _draw.pop_clip()

    return submitted
end

--- @section Splitter

--- Renders panel resizing interactive splitter handle
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @param axis string Resize movement axis ("x" or "y")
--- @param value number Current dimension value
--- @param dir number Value multiplier direction (1 or -1)
--- @return number new_value Updated dimension value
--- @return boolean is_dragging True if currently being dragged
function m.splitter(x, y, w, h, axis, value, dir)
    next_element_id = next_element_id + 1
    local element_id = next_element_id
    local theme = _theme.get()

    local over = m.in_rect(x, y, w, h)
    if over then
        hot_id = element_id
        if is_pressed then
            active_id = element_id
            drag_origin = axis == "x" and mouse_x or mouse_y
            drag_value = value
        end
    end

    local dragging = active_id == element_id and is_down

    if over or dragging then
        active_cursor = axis == "x" and "resize_h" or "resize_v"
        _draw.set_colour(dragging and theme.accent or theme.accent2)
        if axis == "x" then
            _draw.rect(x + w / 2 - 1, y, 2, h)
        else
            _draw.rect(x, y + h / 2 - 1, w, 2)
        end
    end

    if dragging then
        local current_pos = axis == "x" and mouse_x or mouse_y
        return drag_value + (current_pos - drag_origin) * dir, true
    end

    return value, false
end

--- @section Scroll Region Management

--- Begins a scrollable clipping container region
--- @param state table Scroll region state container with `.y` vertical scroll offset
--- @param x number Container X position
--- @param y number Container Y position
--- @param w number Container visible width
--- @param h number Container visible height
--- @param content_h number Total inner content height
--- @return number max_scroll Maximum scroll offset limit
function m.scroll_begin(state, x, y, w, h, content_h)
    local max_scroll = math.max(0, content_h - h)

    if wheel_delta ~= 0 and m.in_rect(x, y, w, h) then
        state.y = state.y - wheel_delta * SCROLL_SPEED
    end

    if state.y > max_scroll then
        state.y = max_scroll
    end

    if state.y < 0 then
        state.y = 0
    end

    scroll_depth = scroll_depth + 1

    local entry = scroll_stack[scroll_depth]
    if not entry then
        entry = {}
        scroll_stack[scroll_depth] = entry
    end

    entry.state = state
    entry.x, entry.y = x, y
    entry.w, entry.h = w, h
    entry.content = content_h
    entry.max = max_scroll

    _draw.push_clip(x, y, w, h)
    return max_scroll
end

--- Ends active scrollable region and renders scrollbar thumb indicator
function m.scroll_end()
    local entry = scroll_stack[scroll_depth]
    if not entry then return end

    scroll_depth = scroll_depth - 1

    if entry.max > 0 then
        local theme = _theme.get()
        local bar_w = 6
        local bar_x = entry.x + entry.w - bar_w - 2
        local track_h = entry.h - 4
        local thumb_h = math.max(24, track_h * entry.h / entry.content)
        local thumb_y = entry.y + 2 + (track_h - thumb_h) * (entry.state.y / entry.max)

        _draw.set_colour(theme.scrollbar_track)
        _draw.rect(bar_x, entry.y + 2, bar_w, track_h)

        _draw.set_colour(theme.scrollbar_thumb)
        _draw.rect(bar_x, thumb_y, bar_w, thumb_h)
    end

    _draw.pop_clip()
end

return m