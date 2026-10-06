--- @module ui
--- @file src/engine/ui/init.lua
--- @description Core user interface framework managing frame lifecycle, input routing, focus state, widgets, splitters, and scroll areas.

--- @section Imports

local _draw = require("src.engine.modules.draw")
local _mouse = require("src.engine.modules.mouse")
local _keyboard = require("src.engine.modules.keyboard")
local _theme = require("src.engine.ui.style.theme")
local _font = require("src.engine.modules.font")

--- @section Constants & State

local SCROLL_SPEED = 54

local mx, my = 0, 0
local pressed, down, released = false, false, false
local wheel = 0
local next_id = 0
local hot, active = nil, nil
local cursor = "default"
local drag_origin, drag_value = 0, 0

local chars, nchars = {}, 0
local focus = nil

local scroll_stack, scroll_depth = {}, 0

--- @section Module Initialization

local m = {
    theme = _theme,
}

--- @section Helper Functions

--- Renders text using the active UI font at integer pixel positions
--- @param str string Text string to draw
--- @param x number Canvas X coordinate
--- @param y number Canvas Y coordinate
--- @param size number Pixel font size
local function text(str, x, y, size)
    local active_font = _font.get(size)
    if active_font then
        _font.draw(active_font, str, math.floor(x), math.floor(y))
    else
        _draw.text(str, x, y, size)
    end
end

--- Measures string width in pixels using active UI font
--- @param str string Text string to measure
--- @param size number Pixel font size
--- @return number width Width in pixels
local function measure(str, size)
    local active_font = _font.get(size)
    if active_font then
        return _font.measure(active_font, str)
    end
    return _draw.measure_text(str, size)
end

--- Converts pixel radius to Raylib normalized roundness factor
--- @param radius number Corner radius in pixels
--- @param w number Bounding width
--- @param h number Bounding height
--- @return number roundness Normalized roundness factor (0.0 to 1.0)
local function roundness(radius, w, h)
    return math.min(1, (radius * 2) / math.min(w, h))
end

--- Checks if mouse position is within bounding box and active clip rect
--- @param x number Region X coordinate
--- @param y number Region Y coordinate
--- @param w number Region width
--- @param h number Region height
--- @return boolean in_bounds True if mouse is within interactive region
local function in_rect(x, y, w, h)
    if not (mx >= x and mx < x + w and my >= y and my < y + h) then
        return false
    end
    local cx, cy, cw, ch = _draw.get_clip()
    if cx and not (mx >= cx and mx < cx + cw and my >= cy and my < cy + ch) then
        return false
    end
    return true
end

--- Calculates widget interaction state
--- @param x number Region X coordinate
--- @param y number Region Y coordinate
--- @param w number Region width
--- @param h number Region height
--- @return boolean is_over Mouse is hovering region
--- @return boolean is_clicked Widget was clicked (released inside)
--- @return boolean is_held Widget is currently being held
local function interact(x, y, w, h)
    next_id = next_id + 1
    local id = next_id

    local over = in_rect(x, y, w, h)
    if over then
        hot = id
        cursor = "hand"
        if pressed then
            active = id
        end
    end

    return over, over and released and active == id, over and active == id
end

m.colour = colour
m.text = text
m.measure = measure
m.in_rect = in_rect
m.interact = interact

--- @section Frame Lifecycle

--- Begins frame input evaluation and resets temporary UI state
function m.begin_frame()
    mx, my = _mouse.get_position()
    pressed, down, released = _mouse.pressed(), _mouse.down(), _mouse.released()
    wheel = _mouse.get_wheel()
    next_id = 0
    hot = nil
    cursor = "default"

    nchars = 0
    while true do
        local char_code = _keyboard.get_char()
        if char_code == 0 then
            break
        end
        nchars = nchars + 1
        chars[nchars] = char_code
    end
end

--- Finalizes frame interaction state and sets OS cursor shape
function m.end_frame()
    if released or not down then
        active = nil
    end
    _mouse.set_cursor(cursor)
end

--- Checks if any widget is currently hovered
--- @return boolean hovered True if hot widget exists
function m.is_hovered()
    return hot ~= nil
end

--- @section Focus Management

--- Clears current keyboard focus token
function m.blur()
    focus = nil
end

--- Sets current keyboard focus token
--- @param token table State object or unique widget reference
function m.set_focus(token)
    focus = token
end

--- Checks if target token currently holds keyboard focus
--- @param token table State object or unique widget reference
--- @return boolean focused True if token holds focus
function m.has_focus(token)
    return token ~= nil and focus == token
end

--- Returns character codepoints typed during current frame
--- @return table codepoints Array of character codepoints
--- @return number count Number of characters typed
function m.typed()
    return chars, nchars
end

--- @section Widgets & Controls

--- Draws a styled UI container panel
--- @param x number Top-left X position
--- @param y number Top-left Y position
--- @param w number Panel width
--- @param h number Panel height
--- @param bg table|nil Optional custom background color
function m.panel(x, y, w, h, bg)
    local theme = _theme.get()

    _draw.set_colour(bg or theme.bg_panel)
    _draw.rect(x, y, w, h)

    local border = theme.border_light
    _draw.set_colour(border.color)
    _draw.rect_lines(x, y, w, h)
end

--- Renders text label
--- @param str string Text string
--- @param x number X position
--- @param y number Y position
--- @param size number|nil Font size (defaults to 16)
--- @param c table|nil Text color (defaults to primary text color)
function m.label(str, x, y, size, c)
    _draw.set_colour(c or _theme.get().text_primary)
    text(str, x, y, size or 16)
end

--- Renders clickable list item row with optional secondary text
--- @param label string Primary row title
--- @param sub string|nil Secondary subtitle text
--- @param x number X position
--- @param y number Y position
--- @param w number Row width
--- @param h number Row height
--- @return boolean clicked True if item was clicked
function m.item(label, sub, x, y, w, h)
    local theme = _theme.get()
    local over, clicked, held = interact(x, y, w, h)

    local bg = theme.bg_panel
    if held then
        bg = theme.accent2
    elseif over then
        bg = theme.bg_hover
    end

    _draw.set_colour(bg)
    _draw.rect(x, y, w, h)

    local size = 16
    local text_y = y + (h - size) / 2

    _draw.push_clip(x, y, w, h)
        _draw.set_colour(theme.text_primary)
        text(label, x + 12, text_y, size)
        if sub then
            local title_w = measure(label, size)
            _draw.set_colour(theme.text_tertiary)
            text(sub, x + 12 + title_w + 14, text_y, size)
        end
    _draw.pop_clip()

    return clicked
end

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

    next_id = next_id + 1
    local over = in_rect(x, y, w, h)
    if over then
        hot = next_id
        cursor = "text"
    end

    if pressed then
        if over then
            focus = state
        elseif focus == state then
            focus = nil
        end
    end

    local focused = focus == state
    local submitted = false

    if focused then
        local max_length = state.max or 32
        for i = 1, nchars do
            local char_code = chars[i]
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
            focus = nil
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
            text(placeholder, x + pad, text_y, size)
        else
            local text_w = measure(state.text, size)
            local offset_x = math.max(0, text_w - inner_w + 2)

            _draw.set_colour(theme.text_primary)
            text(state.text, x + pad - offset_x, text_y, size)

            if focused and math.floor(os.clock() * 2) % 2 == 0 then
                _draw.set_colour(theme.accent)
                _draw.rect(x + pad - offset_x + text_w + 1, y + 6, 2, h - 12)
            end
        end
    _draw.pop_clip()

    return submitted
end

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
    next_id = next_id + 1
    local id = next_id
    local theme = _theme.get()

    local over = in_rect(x, y, w, h)
    if over then
        hot = id
        if pressed then
            active = id
            drag_origin = axis == "x" and mx or my
            drag_value = value
        end
    end

    local dragging = active == id and down

    if over or dragging then
        cursor = axis == "x" and "resize_h" or "resize_v"
        _draw.set_colour(dragging and theme.accent or theme.accent2)
        if axis == "x" then
            _draw.rect(x + w / 2 - 1, y, 2, h)
        else
            _draw.rect(x, y + h / 2 - 1, w, 2)
        end
    end

    if dragging then
        local current_pos = axis == "x" and mx or my
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

    if wheel ~= 0 and in_rect(x, y, w, h) then
        state.y = state.y - wheel * SCROLL_SPEED
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

--- @section Lazy Submodules

local LAZY = {
    components = "src.engine.ui.components",
    input = "src.engine.ui.input",
}

setmetatable(m, {
    __index = function(t, key)
        local path = LAZY[key]
        if path then
            local value = require(path)
            rawset(t, key, value)
            return value
        end
    end,
})

return m