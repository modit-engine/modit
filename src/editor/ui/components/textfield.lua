--- @module textfield
--- @file src/editor/ui/components/textfield.lua
--- @description Interactive single-line text input field component with focus, filtering, and blinking cursor support.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")

--- Editor
local _input = require("src.editor.ui.input")
local keyboard = require("src.engine.modules.keyboard")
local _theme = require("src.editor.ui.style.theme")

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

    local id = _input.new_id()
    local over = _input.in_rect(x, y, w, h)
    if over then
        _input.set_hot(id)
        _input.set_cursor("text")
    end

    if _input.pressed() then
        if over then 
            _input.set_focus(state)
        elseif _input.has_focus(state) then 
            _input.blur() 
        end
    end

    local focused = _input.has_focus(state)
    local submitted = false

    if focused then
        local chars, n = _input.typed()
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

        if keyboard.pressed("backspace") or keyboard.pressed_repeat("backspace") then
            state.text = state.text:sub(1, -2)
        end
        if keyboard.pressed("enter") then 
            submitted = true 
        end
        if keyboard.pressed("escape") then 
            _input.blur() 
        end
    end

    _draw.set_colour((focused or over) and t.bg_hover or t.bg_input)
    _draw.rect(x, y, w, h)

    local size, pad = 16, 8
    local inner = w - pad * 2
    local ty = y + (h - size) / 2

    _draw.push_clip(x + pad, y, inner, h)
    if state.text == "" and not focused and placeholder then
        _draw.set_colour(t.text_tertiary)
        _input.text(placeholder, x + pad, ty, size)
    else
        local tw = _input.measure(state.text, size)
        local off = math.max(0, tw - inner + 2)

        _draw.set_colour(t.text_primary)
        _input.text(state.text, x + pad - off, ty, size)

        if focused and math.floor(os.clock() * 2) % 2 == 0 then
            _draw.set_colour(t.accent)
            _draw.rect(x + pad - off + tw + 1, y + 6, 2, h - 12)
        end
    end
    _draw.pop_clip()

    return submitted
end