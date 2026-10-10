--- @module files
--- @file src/editor/ui/panels/code/modules/files.lua
--- @description Text editor file persistence operations and buffer tab lifecycle management.

--- @section Imports

local _buffer = require("src.editor.ui.panels.code.modules.buffer")
local _state = require("src.editor.ui.panels.code.modules.state")

--- @section Initialisation

local m = {}

--- @section Functions

--- Saves target buffer to disk and displays a notification on failure
--- @param target_buffer table Buffer instance to save
--- @return boolean ok True if save succeeded
function m.save(target_buffer)
    if target_buffer.image or target_buffer.audio then return true end
    if _buffer.save(target_buffer) then 
        return true 
    end
    _state.notify("Could not save " .. target_buffer.name)
    return false
end

--- Closes target buffer tab and shifts active selection to adjacent buffer if needed
--- @param target_buffer table Buffer instance to close
function m.close_buffer(target_buffer)
    if target_buffer.asset then
        local preview = target_buffer.audio and "audio" or "image"
        require("src.editor.ui.panels." .. preview).release(target_buffer.asset)
    end
    for index, current_buffer in ipairs(_state.buffers) do
        if current_buffer == target_buffer then
            table.remove(_state.buffers, index)
            if _state.active == target_buffer then 
                _state.active = _state.buffers[math.min(index, #_state.buffers)] 
            end
            break
        end
    end
    _state.selecting = false
end

return m
