--- @module history
--- @file src/editor/ui/panels/code/modules/history.lua
--- @description Undo and redo history stack management for text buffer state snapshots.

--- @section Imports

local _config = require("src.editor.ui.panels.code.modules.config")
local _state = require("src.editor.ui.panels.code.modules.state")
local _buffer = require("src.editor.ui.panels.code.modules.buffer")

--- @section Constants

local UNDO_MAX = _config.UNDO_MAX

--- @section Initialisation

local m = {}

--- @section Helpers

--- Creates a shallow copy array of line strings
--- @param line_list table Array of line strings
--- @return table copy Shallow copy of the line strings array
local function copy_lines(line_list)
    local output = {}
    for index = 1, #line_list do 
        output[index] = line_list[index] 
    end
    return output
end

--- Pushes a buffer state snapshot onto the specified undo/redo stack table
--- @param target_stack table Stack array table to push state into
--- @param target_buffer table Target text buffer instance
local function push_state(target_stack, target_buffer)
    target_stack[#target_stack + 1] = { 
        lines = copy_lines(target_buffer.lines), 
        cy = target_buffer.cy, 
        cx = target_buffer.cx 
    }
    if #target_stack > UNDO_MAX then 
        table.remove(target_stack, 1) 
    end
end

--- @section Functions

--- Records an edit state snapshot before modifying text, grouping consecutive edits of the same kind
--- @param target_buffer table Target text buffer instance
--- @param edit_kind string Identifier key for grouping rapid consecutive edits (e.g., "edit", "delete")
function m.begin_edit(target_buffer, edit_kind)
    local current_time = os.clock()
    if not (edit_kind == target_buffer.last_kind and current_time - (target_buffer.last_time or 0) < 1) then
        push_state(target_buffer.undo, target_buffer)
        target_buffer.redo = {}
    end
    target_buffer.last_kind, target_buffer.last_time = edit_kind, current_time
    if not _buffer.selection(target_buffer) then 
        target_buffer.ay, target_buffer.ax = nil, nil 
    end
    target_buffer.dirty = true
    target_buffer.want, target_buffer.reveal = nil, true
    _state.blink()
end

--- Restores buffer state from one stack and pushes current state onto recipient stack (undo/redo action)
--- @param target_buffer table Target text buffer instance
--- @param from_stack table Stack array to pop snapshot state from (e.g., buffer.undo)
--- @param to_stack table Stack array to push current state into (e.g., buffer.redo)
function m.restore(target_buffer, from_stack, to_stack)
    local snapshot = table.remove(from_stack)
    if not snapshot then return end

    push_state(to_stack, target_buffer)
    target_buffer.lines = snapshot.lines
    target_buffer.cy = snapshot.cy
    target_buffer.cx = snapshot.cx
    target_buffer.ay, target_buffer.ax = nil, nil
    target_buffer.last_kind, target_buffer.want, target_buffer.reveal = nil, nil, true
    target_buffer.dirty = true
    _state.blink()
end

return m