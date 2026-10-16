--- @module textfield
--- @file src/sdk/ui/components/textfield.lua
--- @description Interactive single-line text input field component with focus, filtering, and blinking cursor support.

--- @section Imports

local _draw = require("src.sdk.client.draw2d")
local _font = require("src.sdk.client.font")
local _input = require("src.sdk.client.input")
local _ui_input = require("src.sdk.ui.input")
local _theme = require("src.sdk.ui.theme")

--- @section Helpers

--- Draws text with the SDK font, falling back to the UI input helper
--- @param font_obj Font|nil Font instance
--- @param str string Text to draw
--- @param x number X position
--- @param y number Y position
--- @param size number Font size in pixels
local function draw_text(font_obj, str, x, y, size)
    if font_obj then
        font_obj:draw(str, x, y)
    else
        _ui_input.text(str, x, y, size)
    end
end

--- Measures text with the SDK font, falling back to the UI input helper
--- @param font_obj Font|nil Font instance
--- @param str string Text to measure
--- @param size number Font size in pixels
--- @return number width Width in pixels
local function measure_text(font_obj, str, size)
    if font_obj then
        return font_obj:measure(str)
    end
    return _ui_input.measure(str, size)
end

--- @section Component

--- Renders an interactive textfield input component and handles text editing state
--- @param state table Input state object ({ text = string, max? = number })
--- @param x number X screen coordinate
--- @param y number Y screen coordinate
--- @param w number Width in pixels
--- @param h number Height in pixels
--- @param filter string|nil Optional character filter pattern (e.g., "^[%w_%-]$")
--- @param placeholder string|nil Optional placeholder string displayed when empty and unfocused
--- @return boolean submitted True if the enter key was pressed while focused
return function(state, x, y, w, h, filter, placeholder)
    local t = _theme.get()

    local id = _ui_input.new_id()
    local over = _ui_input.in_rect(x, y, w, h)
    if over then
        _ui_input.set_hot(id)
        _ui_input.set_cursor("text")
    end

    if _ui_input.pressed() then
        if over then 
            _ui_input.set_focus(state)
        elseif _ui_input.has_focus(state) then 
            _ui_input.blur() 
        end
    end

    local focused = _ui_input.has_focus(state)
    local submitted = false

    if focused then
        local chars, n = _ui_input.typed()
        local max = state.max or 32
        for i = 1, n do
            local c = chars[i]
            if c >= 32 and c < 127 then
                local ch = string.char(c)
                if (not filter or ch:match(filter)) and #state.text < max then
                    state.text = state.text .. ch
                end
            end
        end

        if _input.key_pressed("backspace") or _input.key_pressed_repeat("backspace") then
            state.text = state.text:sub(1, -2)
        end
        if _input.key_pressed("enter") then 
            submitted = true 
        end
        if _input.key_pressed("escape") then 
            _ui_input.blur() 
        end
    end

    _draw.set_colour((focused or over) and t.bg_hover or t.bg_input)
    _draw.rect(x, y, w, h)

    local size, pad = 16, 8
    local inner = w - pad * 2
    local ty = y + (h - size) / 2
    local font_obj = _font.get(size)

    _draw.push_clip(x + pad, y, inner, h)
    if state.text == "" and not focused and placeholder then
        _draw.set_colour(t.text_tertiary)
        draw_text(font_obj, placeholder, x + pad, ty, size)
    else
        local tw = measure_text(font_obj, state.text, size)
        local off = math.max(0, tw - inner + 2)

        _draw.set_colour(t.text_primary)
        draw_text(font_obj, state.text, x + pad - off, ty, size)

        if focused and math.floor(os.clock() * 2) % 2 == 0 then
            _draw.set_colour(t.accent)
            _draw.rect(x + pad - off + tw + 1, y + 6, 2, h - 12)
        end
    end
    _draw.pop_clip()

    return submitted
end