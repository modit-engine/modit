--- @module cursor
--- @file src/editor/ui/panels/code/modules/cursor.lua
--- @description Text editor cursor navigation, selection management, and viewport visibility utility functions.

--- @section Imports

--- Engine
local _maths = require("src.engine.modules.maths")

--- Editor
local _state = require("src.editor.ui.panels.code.modules.state")

--- @section Initialisation

local m = {}

--- @section Functions

--- Repositions the cursor in the text buffer, updating selection anchors if requested
--- @param buffer table Target text buffer instance
--- @param line_index number Target 1-based line number
--- @param column_index number Target 0-based column index
--- @param extend_selection boolean|nil True to maintain or create selection anchor
function m.move_to(buffer, line_index, column_index, extend_selection)
    if extend_selection then
        if not buffer.ay then
            buffer.ay, buffer.ax = buffer.cy, buffer.cx
        end
    else
        buffer.ay, buffer.ax = nil, nil
    end

    buffer.cy, buffer.cx = line_index, column_index
    buffer.want, buffer.last_kind, buffer.reveal = nil, nil, true
    _state.blink()
end

--- Moves the cursor vertically by line delta, preserving column preference across line lengths
--- @param buffer table Target text buffer instance
--- @param line_delta number Relative line offset (positive for down, negative for up)
--- @param extend_selection boolean|nil True to extend active selection range
function m.vertical(buffer, line_delta, extend_selection)
    local target_column = buffer.want or buffer.cx
    local target_line = buffer.cy + line_delta

    if target_line < 1 then
        m.move_to(buffer, 1, 0, extend_selection)
    elseif target_line > #buffer.lines then
        m.move_to(buffer, #buffer.lines, #buffer.lines[#buffer.lines], extend_selection)
    else
        m.move_to(buffer, target_line, math.min(target_column, #buffer.lines[target_line]), extend_selection)
        buffer.want = target_column
    end
end

--- Calculates target (line, column) coordinate for jumping left by one word without moving the cursor
--- @param buffer table Target text buffer instance
--- @return number line_index Calculated line number
--- @return number column_index Calculated column index
function m.word_left(buffer)
    local line_index, column_index = buffer.cy, buffer.cx
    if column_index == 0 then
        if line_index > 1 then 
            return line_index - 1, #buffer.lines[line_index - 1] 
        end
        return line_index, 0
    end

    local line_text = buffer.lines[line_index]
    while column_index > 0 and not line_text:sub(column_index, column_index):match("[%w_]") do 
        column_index = column_index - 1 
    end
    while column_index > 0 and line_text:sub(column_index, column_index):match("[%w_]") do 
        column_index = column_index - 1 
    end
    return line_index, column_index
end

--- Calculates target (line, column) coordinate for jumping right by one word without moving the cursor
--- @param buffer table Target text buffer instance
--- @return number line_index Calculated line number
--- @return number column_index Calculated column index
function m.word_right(buffer)
    local line_index, column_index = buffer.cy, buffer.cx
    local line_text = buffer.lines[line_index]

    if column_index >= #line_text then
        if line_index < #buffer.lines then 
            return line_index + 1, 0 
        end
        return line_index, column_index
    end

    while column_index < #line_text and not line_text:sub(column_index + 1, column_index + 1):match("[%w_]") do 
        column_index = column_index + 1 
    end
    while column_index < #line_text and line_text:sub(column_index + 1, column_index + 1):match("[%w_]") do 
        column_index = column_index + 1 
    end
    return line_index, column_index
end

--- Selects all text content within the buffer and positions cursor at the end
--- @param buffer table Target text buffer instance
function m.select_all(buffer)
    buffer.ay, buffer.ax = 1, 0
    buffer.cy, buffer.cx = #buffer.lines, #buffer.lines[#buffer.lines]
    buffer.last_kind = nil
    _state.blink()
end

--- Converts screen pixel coordinates to buffer line and column indices clamped to buffer boundaries
--- @param buffer table Target text buffer instance
--- @param pixel_x number Screen X coordinate
--- @param pixel_y number Screen Y coordinate
--- @param left_margin number Panel left margin inset offset
--- @param top_margin number Panel top margin inset offset
--- @return number line_index Clamped line index (1-based)
--- @return number column_index Clamped column index (0-based)
function m.hit_test(buffer, pixel_x, pixel_y, left_margin, top_margin)
    local line_index = _maths.core.clamp(math.floor((pixel_y - top_margin + buffer.scroll.y) / _state.line_h) + 1, 1, #buffer.lines)
    local column_index = _maths.core.clamp(math.floor((pixel_x - left_margin + buffer.sx) / _state.font.cell_w + 0.5), 0, #buffer.lines[line_index])
    return line_index, column_index
end

--- Adjusts buffer scroll state ensuring active cursor position is visible in viewport
--- @param buffer table Target text buffer instance
--- @param view_height number Viewport height in pixels
--- @param text_width number Viewport text rendering area width in pixels
function m.reveal(buffer, view_height, text_width)
    local top_offset = (buffer.cy - 1) * _state.line_h
    if top_offset < buffer.scroll.y then 
        buffer.scroll.y = top_offset 
    end
    if top_offset + _state.line_h > buffer.scroll.y + view_height then 
        buffer.scroll.y = top_offset + _state.line_h - view_height 
    end

    local cursor_x = buffer.cx * _state.font.cell_w
    if cursor_x < buffer.sx then 
        buffer.sx = cursor_x 
    end
    if cursor_x + _state.font.cell_w > buffer.sx + text_width then 
        buffer.sx = cursor_x + _state.font.cell_w - text_width 
    end
    buffer.sx = math.max(0, buffer.sx)
end

return m