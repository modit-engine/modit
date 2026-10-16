--- @module buffer
--- @file src/editor/ui/panels/code/buffer.lua
--- @description Pure text buffer data model for editor line operations, selection state, and disk I/O.

--- @section Initialisation

local m = {}

--- @section Functions

--- Splits raw text into an array of lines, normalizing line endings and expanding tabs
--- @param text string Raw text input
--- @return table Array of line strings
function m.split_lines(text)
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\t", "    ")
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do 
        lines[#lines + 1] = line 
    end
    return lines
end

--- Calculates selection bounds as (start_line, start_column, end_line, end_column) or nil if empty
--- @param buffer table Text buffer instance
--- @return number|nil start_line Start line (1-based)
--- @return number|nil start_column Start column (0-based)
--- @return number|nil end_line End line (1-based)
--- @return number|nil end_column End column (0-based)
function m.selection(buffer)
    if not buffer.ay then return nil end
    local anchor_y, anchor_x = buffer.ay, buffer.ax
    local cursor_y, cursor_x = buffer.cy, buffer.cx

    if anchor_y == cursor_y and anchor_x == cursor_x then return nil end

    if anchor_y < cursor_y or (anchor_y == cursor_y and anchor_x < cursor_x) then 
        return anchor_y, anchor_x, cursor_y, cursor_x 
    end

    return cursor_y, cursor_x, anchor_y, anchor_x
end

--- Retrieves currently selected text from the buffer
--- @param buffer table Text buffer instance
--- @return string|nil text Selected text string or nil if selection is empty
function m.selected_text(buffer)
    local start_line, start_column, end_line, end_column = m.selection(buffer)
    if not start_line then return nil end

    if start_line == end_line then 
        return buffer.lines[start_line]:sub(start_column + 1, end_column) 
    end

    local output = { buffer.lines[start_line]:sub(start_column + 1) }
    for line_index = start_line + 1, end_line - 1 do 
        output[#output + 1] = buffer.lines[line_index] 
    end
    output[#output + 1] = buffer.lines[end_line]:sub(1, end_column)

    return table.concat(output, "\n")
end

--- Removes active selection range from the text buffer
--- @param buffer table Text buffer instance
--- @return boolean deleted True if a selection was deleted
function m.delete_selection(buffer)
    local start_line, start_column, end_line, end_column = m.selection(buffer)
    if not start_line then return false end

    buffer.lines[start_line] = buffer.lines[start_line]:sub(1, start_column) .. buffer.lines[end_line]:sub(end_column + 1)
    for line_index = end_line, start_line + 1, -1 do 
        table.remove(buffer.lines, line_index) 
    end

    buffer.cy, buffer.cx = start_line, start_column
    buffer.ay, buffer.ax = nil, nil
    return true
end

--- Inserts string text at cursor position (assumes active selection was already deleted)
--- @param buffer table Text buffer instance
--- @param text string Text to insert
function m.insert_text(buffer, text)
    local current_line = buffer.lines[buffer.cy]
    local text_before = current_line:sub(1, buffer.cx)
    local text_after = current_line:sub(buffer.cx + 1)
    local text_parts = m.split_lines(text)

    if #text_parts == 1 then
        buffer.lines[buffer.cy] = text_before .. text_parts[1] .. text_after
        buffer.cx = buffer.cx + #text_parts[1]
    else
        buffer.lines[buffer.cy] = text_before .. text_parts[1]
        for index = 2, #text_parts - 1 do 
            table.insert(buffer.lines, buffer.cy + index - 1, text_parts[index]) 
        end
        table.insert(buffer.lines, buffer.cy + #text_parts - 1, text_parts[#text_parts] .. text_after)
        buffer.cy = buffer.cy + #text_parts - 1
        buffer.cx = #text_parts[#text_parts]
    end
end

--- Instantiates a new text buffer instance from path and raw data string
--- @param path string File disk path
--- @param data string Raw file contents string
--- @return table buffer Buffer object instance
function m.new(path, data)
    return {
        path = path,
        name = path:match("([^/]+)$") or path,
        lines = m.split_lines(data),
        crlf = data:find("\r\n", 1, true) ~= nil,
        cy = 1, 
        cx = 0,
        undo = {}, 
        redo = {},
        dirty = false,
        scroll = { y = 0 }, 
        sx = 0,
        hl = {},
        lua = path:lower():match("%.lua$") ~= nil,
    }
end

--- Writes buffer lines to disk
--- @param buffer table Text buffer instance
--- @return boolean ok True if save succeeded
function m.save(buffer)
    local file = io.open(buffer.path, "wb")
    if not file then
        return false
    end
    file:write(table.concat(buffer.lines, buffer.crlf and "\r\n" or "\n"))
    file:close()
    buffer.dirty = false
    buffer.confirm = false
    return true
end

return m