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

--- @section Initialisation

local m = {}

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

    if _mouse.pressed() then
        if is_over then
            _input.set_focus(_state.focus_token)
            is_focused = true

            local line_idx, col_idx = _cursor.hit_test(target_buffer, mouse_x, mouse_y, left_margin, text_y)
            if _keyboard.down("leftshift") or _keyboard.down("rightshift") then
                if not target_buffer.ay then 
                    target_buffer.ay, target_buffer.ax = target_buffer.cy, target_buffer.cx 
                end
            else
                target_buffer.ay, target_buffer.ax = line_idx, col_idx
            end
            target_buffer.cy, target_buffer.cx = line_idx, col_idx
            target_buffer.want, target_buffer.last_kind = nil, nil
            _state.selecting = true
            _state.blink()
        elseif is_focused and not _state.tab_clicked then
            _input.set_focus(nil)
            is_focused = false
        end
    end

    if _state.selecting then
        if _mouse.down() then
            local clamped_x = _maths.core.clamp(mouse_x, left_margin - cell_width, text_x + panel_w + cell_width)
            local clamped_y = _maths.core.clamp(mouse_y, text_y - _state.line_h, text_y + panel_h + _state.line_h)
            local line_idx, col_idx = _cursor.hit_test(target_buffer, clamped_x, clamped_y, left_margin, text_y)
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