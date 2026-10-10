--- @module pointer
--- @file src/editor/ui/panels/code/modules/pointer.lua
--- @description Mouse input handler for code editor panel focus, cursor positioning, and click-drag selection.

--- @section Imports

--- Engine
local _mouse = require("src.engine.modules.input.mouse")
local _keyboard = require("src.engine.modules.input.keyboard")
local _maths = require("src.engine.modules.maths")

--- Editor
local _input = require("src.engine.ui.modules.input")
local _config = require("src.editor.ui.panels.code.modules.config")
local _state = require("src.editor.ui.panels.code.modules.state")
local _cursor = require("src.editor.ui.panels.code.modules.cursor")

--- @section Constants

local EDGE = _config.EDGE
local DOUBLE_CLICK_SECONDS = 0.35
local CLICK_DISTANCE = 4

--- @section Initialisation

local m = {}
local last_click
local word_selection

--- @section Functions

--- Updates mouse interactions, handling click focus, cursor repositioning, and drag selection
--- @param target_buffer table Active text buffer instance
--- @param text_x number Editor panel X screen coordinate
--- @param text_y number Editor panel Y screen coordinate
--- @param panel_w number Panel width in pixels
--- @param panel_h number Panel height in pixels
--- @param left_margin number X screen coordinate corresponding to text column 0
--- @param is_focused boolean Current editor focus state
--- @return boolean is_focused Updated editor focus state
function m.update(target_buffer, text_x, text_y, panel_w, panel_h, left_margin, is_focused)
    local cell_width = _state.font.cell_w
    local mouse_x, mouse_y = _mouse.get_position()

    local is_over = _input.in_rect(text_x + EDGE, text_y, panel_w - EDGE * 2, panel_h - EDGE)

    if not _state.selecting then word_selection = nil end

    if _mouse.pressed() then
        if is_over then
            _input.set_focus(_state.focus_token)
            is_focused = true

            local line_idx, col_idx = _cursor.hit_test(target_buffer, mouse_x, mouse_y, left_margin, text_y)
            local shift_down = _keyboard.down("leftshift") or _keyboard.down("rightshift")
            local now = os.clock()
            local double_click = not shift_down and last_click and last_click.buffer == target_buffer
                and now - last_click.time <= DOUBLE_CLICK_SECONDS and line_idx == last_click.line
                and math.abs(mouse_x - last_click.x) <= CLICK_DISTANCE
                and math.abs(mouse_y - last_click.y) <= CLICK_DISTANCE
            word_selection = nil
            if double_click then
                -- Use the character cell, not the rounded caret position.
                local character_column = math.floor((mouse_x - left_margin + target_buffer.sx) / cell_width)
                local first_column, last_column = _cursor.word_range(target_buffer.lines[line_idx], character_column)
                target_buffer.ay, target_buffer.ax = line_idx, first_column
                target_buffer.cy, target_buffer.cx = line_idx, last_column
                word_selection = { buffer = target_buffer, line = line_idx, first = first_column, last = last_column }
                last_click = nil
            elseif shift_down then
                if not target_buffer.ay then 
                    target_buffer.ay, target_buffer.ax = target_buffer.cy, target_buffer.cx 
                end
            else
                target_buffer.ay, target_buffer.ax = line_idx, col_idx
            end
            if not double_click then
                target_buffer.cy, target_buffer.cx = line_idx, col_idx
                last_click = not shift_down and { buffer = target_buffer, line = line_idx, time = now, x = mouse_x, y = mouse_y } or nil
            end
            target_buffer.want, target_buffer.last_kind = nil, nil
            _state.selecting = true
            _state.blink()
        else
            last_click, word_selection = nil, nil
            if is_focused and not _state.tab_clicked then
                _input.set_focus(nil)
                is_focused = false
            end
        end
    end

    if _state.selecting then
        if _mouse.down() then
            if last_click and (math.abs(mouse_x - last_click.x) > CLICK_DISTANCE
                or math.abs(mouse_y - last_click.y) > CLICK_DISTANCE) then last_click = nil end
            local clamped_x = _maths.core.clamp(mouse_x, left_margin - cell_width, text_x + panel_w + cell_width)
            local clamped_y = _maths.core.clamp(mouse_y, text_y - _state.line_h, text_y + panel_h + _state.line_h)
            local line_idx, col_idx = _cursor.hit_test(target_buffer, clamped_x, clamped_y, left_margin, text_y)
            if word_selection and word_selection.buffer == target_buffer then
                local character_column = math.floor((clamped_x - left_margin + target_buffer.sx) / cell_width)
                local first_column, last_column = _cursor.word_range(target_buffer.lines[line_idx], character_column)
                if line_idx < word_selection.line or (line_idx == word_selection.line and first_column < word_selection.first) then
                    target_buffer.ay, target_buffer.ax = word_selection.line, word_selection.last
                    col_idx = first_column
                else
                    target_buffer.ay, target_buffer.ax = word_selection.line, word_selection.first
                    col_idx = last_column
                end
            end
            if line_idx ~= target_buffer.cy or col_idx ~= target_buffer.cx then
                target_buffer.cy, target_buffer.cx, target_buffer.reveal = line_idx, col_idx, true
            end
        else
            _state.selecting = false
            if target_buffer.ay == target_buffer.cy and target_buffer.ax == target_buffer.cx then 
                target_buffer.ay, target_buffer.ax = nil, nil 
            end
        end
    end

    return is_focused
end

return m