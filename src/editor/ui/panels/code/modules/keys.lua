--- @module keys
--- @file src/editor/ui/panels/code/modules/keys.lua
--- @description Keyboard input routing for text editing, navigation shortcuts, and buffer history actions.

--- @section Imports

--- Engine
local _keyboard = require("src.engine.modules.keyboard")

--- Editor
local _input = require("src.editor.ui.input")
local _state = require("src.editor.ui.panels.code.modules.state")
local _buffer = require("src.editor.ui.panels.code.modules.buffer")
local _history = require("src.editor.ui.panels.code.modules.history")
local _edit = require("src.editor.ui.panels.code.modules.edit")
local _cursor = require("src.editor.ui.panels.code.modules.cursor")
local _files = require("src.editor.ui.panels.code.modules.files")

--- @section Initialisation

local m = {}

--- @section Helpers

--- Checks if a key was pressed or repeated in the current frame
--- @param key_code string|number Key identifier string or numeric key code
--- @return boolean active True if pressed or repeat active
local function is_key_pressed(key_code)
    return _keyboard.pressed(key_code) or _keyboard.pressed_repeat(key_code)
end

--- @section Functions

--- Processes active frame keyboard events for the targeted text buffer
--- @param target_buffer table Target text buffer instance
--- @param page_line_count number Number of lines to scroll on PageUp/PageDown
function m.handle(target_buffer, page_line_count)
    local ctrl = _keyboard.down("leftctrl") or _keyboard.down("rightctrl")
    local alt = _keyboard.down("leftalt") or _keyboard.down("rightalt")
    local shift = _keyboard.down("leftshift") or _keyboard.down("rightshift")
    ctrl = ctrl and not alt

    -- Typed text insertion
    if not ctrl then
        local typed_chars, char_count = _input.typed()
        for index = 1, char_count do
            local char_code = typed_chars[index]
            if char_code >= 32 and char_code < 127 then 
                _edit.insert(target_buffer, string.char(char_code), "type") 
            end
        end
    end

    --- Editor shortcuts
    if ctrl and _keyboard.pressed("a") then 
        _cursor.select_all(target_buffer) 
    end
    if ctrl and _keyboard.pressed("c") then 
        _edit.copy(target_buffer) 
    end
    if ctrl and is_key_pressed("x") then 
        _edit.cut(target_buffer) 
    end
    if ctrl and is_key_pressed("v") then 
        _edit.paste(target_buffer) 
    end
    if ctrl and is_key_pressed("z") then
        if shift then 
            _history.restore(target_buffer, target_buffer.redo, target_buffer.undo) 
        else 
            _history.restore(target_buffer, target_buffer.undo, target_buffer.redo) 
        end
    end
    if ctrl and is_key_pressed("y") then 
        _history.restore(target_buffer, target_buffer.redo, target_buffer.undo) 
    end
    if ctrl and _keyboard.pressed("s") then
        if _files.save(target_buffer) then 
            _state.notify("Saved " .. target_buffer.name) 
        end
    end

    -- Cursor movement
    if is_key_pressed("arrowleft") then
        local start_y, start_x = _buffer.selection(target_buffer)
        if start_y and not shift and not ctrl then
            _cursor.move_to(target_buffer, start_y, start_x, false)
        elseif ctrl then
            local line_idx, col_idx = _cursor.word_left(target_buffer)
            _cursor.move_to(target_buffer, line_idx, col_idx, shift)
        elseif target_buffer.cx > 0 then
            _cursor.move_to(target_buffer, target_buffer.cy, target_buffer.cx - 1, shift)
        elseif target_buffer.cy > 1 then
            _cursor.move_to(target_buffer, target_buffer.cy - 1, #target_buffer.lines[target_buffer.cy - 1], shift)
        end
    end

    if is_key_pressed("arrowright") then
        local start_y, _, end_y, end_x = _buffer.selection(target_buffer)
        if start_y and not shift and not ctrl then
            _cursor.move_to(target_buffer, end_y, end_x, false)
        elseif ctrl then
            local line_idx, col_idx = _cursor.word_right(target_buffer)
            _cursor.move_to(target_buffer, line_idx, col_idx, shift)
        elseif target_buffer.cx < #target_buffer.lines[target_buffer.cy] then
            _cursor.move_to(target_buffer, target_buffer.cy, target_buffer.cx + 1, shift)
        elseif target_buffer.cy < #target_buffer.lines then
            _cursor.move_to(target_buffer, target_buffer.cy + 1, 0, shift)
        end
    end

    if is_key_pressed("arrowup") then 
        _cursor.vertical(target_buffer, -1, shift) 
    end
    if is_key_pressed("arrowdown") then 
        _cursor.vertical(target_buffer, 1, shift) 
    end
    if is_key_pressed("pageup") then 
        _cursor.vertical(target_buffer, -page_line_count, shift) 
    end
    if is_key_pressed("pagedown") then 
        _cursor.vertical(target_buffer, page_line_count, shift) 
    end

    if is_key_pressed("home") then
        if ctrl then
            _cursor.move_to(target_buffer, 1, 0, shift)
        else
            local line_indent = #target_buffer.lines[target_buffer.cy]:match("^ *")
            _cursor.move_to(target_buffer, target_buffer.cy, (target_buffer.cx == line_indent) and 0 or line_indent, shift)
        end
    end

    if is_key_pressed("end") then
        if ctrl then
            _cursor.move_to(target_buffer, #target_buffer.lines, #target_buffer.lines[#target_buffer.lines], shift)
        else
            _cursor.move_to(target_buffer, target_buffer.cy, #target_buffer.lines[target_buffer.cy], shift)
        end
    end

    -- Text modifications
    if is_key_pressed("backspace") then 
        _edit.backspace(target_buffer) 
    end
    if is_key_pressed("delete") then 
        _edit.delete(target_buffer) 
    end
    if is_key_pressed("enter") or is_key_pressed(335) then 
        _edit.enter(target_buffer) 
    end
    if is_key_pressed("tab") then
        if shift then 
            _edit.untab(target_buffer) 
        else 
            _edit.tab(target_buffer) 
        end
    end
end

return m