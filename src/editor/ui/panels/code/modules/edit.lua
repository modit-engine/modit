--- @module edit
--- @file src/editor/ui/panels/code/modules/edit.lua
--- @description Code editor editing commands for text insertion, deletion, indentation, and clipboard operations.

--- @section Imports

--- Engine
local _keyboard = require("src.engine.modules.keyboard")

--- Editor
local _config = require("src.editor.ui.panels.code.modules.config")
local _buffer = require("src.editor.ui.panels.code.modules.buffer")
local history = require("src.editor.ui.panels.code.modules.history")
local highlight = require("src.editor.ui.panels.code.modules.highlight")

--- @section Constants

local INDENT = _config.INDENT

--- @section Initialisation

local m = {}

--- @section Helpers

--- Checks if a string line end token opens a new block needing auto-indentation
--- @param statement string Line text preceding cursor
--- @return boolean opens True if line ending opens a block
local function opens_block(statement)
    return statement:match("%f[%w_]then%f[^%w_]") 
        or statement:match("%f[%w_]do%f[^%w_]") 
        or statement:match("%f[%w_]else$") 
        or statement:match("%f[%w_]repeat%f[^%w_]") 
        or statement:match("{%s*$")
        or statement:match("function%s*[%w_.:]*%s*%b()$") ~= nil
end

--- Aligns a standalone Lua end with its unmatched opening block. Reuse the
--- highlighter so keywords inside comments and strings never affect nesting.
local function align_end(buffer)
    if not buffer.lua then return end
    local line = buffer.lines[buffer.cy]
    local spaces = line:match("^( *)end%s*$")
    if not spaces or buffer.cx ~= #spaces + 3 then return end

    highlight.update(buffer, buffer.cy)
    if buffer.hl[buffer.cy].state_in then return end
    local stack = {}
    for i = 1, buffer.cy - 1 do
        local source = buffer.lines[i]
        for _, token in ipairs(buffer.hl[i].toks) do
            if token.kind == "control" then
                local word = source:sub(token.s, token.e)
                local top = stack[#stack]
                if word == "if" or word == "function" or word == "for" or word == "while" or word == "repeat" then
                    stack[#stack + 1] = {
                        kind = word, indent = #source:match("^ *"),
                        awaiting_do = word == "for" or word == "while",
                    }
                elseif word == "do" then
                    if top and top.awaiting_do then
                        top.awaiting_do = false
                    else
                        stack[#stack + 1] = { kind = "do", indent = #source:match("^ *") }
                    end
                elseif word == "end" or word == "until" then
                    if top and ((word == "until") == (top.kind == "repeat")) then
                        table.remove(stack)
                    end
                end
            end
        end
    end

    local opener = stack[#stack]
    if not opener or opener.kind == "repeat" or opener.indent >= #spaces then return end
    local aligned = string.rep(" ", opener.indent) .. line:sub(#spaces + 1)
    buffer.lines[buffer.cy] = aligned
    buffer.cx = buffer.cx - (#spaces - opener.indent)
    buffer.auto_end = { line = buffer.cy, before = line, after = aligned, cx = buffer.cx }
end

--- @section Functions

--- Inserts arbitrary text at current cursor location or replaces selection
--- @param target_buffer table Target text buffer instance
--- @param text string Text content to insert
--- @param edit_kind string|nil Optional undo history transaction kind (defaults to "edit")
function m.insert(target_buffer, text, edit_kind)
    history.begin_edit(target_buffer, edit_kind or "edit")
    -- Typing "endpoint" must not leave the temporary "end" prefix dedented.
    local pending = target_buffer.auto_end
    target_buffer.auto_end = nil
    if pending and edit_kind == "type" and text:match("^[%w_]")
        and not _buffer.selection(target_buffer) and target_buffer.cy == pending.line
        and target_buffer.cx == pending.cx and target_buffer.lines[pending.line] == pending.after then
        target_buffer.lines[pending.line] = pending.before
        target_buffer.cx = target_buffer.cx + #pending.before - #pending.after
    end
    _buffer.delete_selection(target_buffer)
    _buffer.insert_text(target_buffer, text)
    if edit_kind == "type" then align_end(target_buffer) end
end

--- Removes character behind cursor or deletes current selection
--- @param target_buffer table Target text buffer instance
function m.backspace(target_buffer)
    if not _buffer.selection(target_buffer) and target_buffer.cx == 0 and target_buffer.cy == 1 then 
        return 
    end

    history.begin_edit(target_buffer, "delete")
    if _buffer.delete_selection(target_buffer) then return end

    if target_buffer.cx > 0 then
        local current_line = target_buffer.lines[target_buffer.cy]
        target_buffer.lines[target_buffer.cy] = current_line:sub(1, target_buffer.cx - 1) .. current_line:sub(target_buffer.cx + 1)
        target_buffer.cx = target_buffer.cx - 1
    else
        local previous_line = target_buffer.lines[target_buffer.cy - 1]
        target_buffer.lines[target_buffer.cy - 1] = previous_line .. target_buffer.lines[target_buffer.cy]
        table.remove(target_buffer.lines, target_buffer.cy)
        target_buffer.cy = target_buffer.cy - 1
        target_buffer.cx = #previous_line
    end
end

--- Removes character in front of cursor or deletes current selection
--- @param target_buffer table Target text buffer instance
function m.delete(target_buffer)
    if not _buffer.selection(target_buffer) and target_buffer.cx >= #target_buffer.lines[target_buffer.cy] and target_buffer.cy >= #target_buffer.lines then 
        return 
    end

    history.begin_edit(target_buffer, "delete")
    if _buffer.delete_selection(target_buffer) then return end

    local current_line = target_buffer.lines[target_buffer.cy]
    if target_buffer.cx < #current_line then
        target_buffer.lines[target_buffer.cy] = current_line:sub(1, target_buffer.cx) .. current_line:sub(target_buffer.cx + 2)
    else
        target_buffer.lines[target_buffer.cy] = current_line .. target_buffer.lines[target_buffer.cy + 1]
        table.remove(target_buffer.lines, target_buffer.cy + 1)
    end
end

--- Inserts a newline with automatic indentation matching current block context
--- @param target_buffer table Target text buffer instance
function m.enter(target_buffer)
    history.begin_edit(target_buffer, "edit")
    _buffer.delete_selection(target_buffer)

    local text_before = target_buffer.lines[target_buffer.cy]:sub(1, target_buffer.cx)
    local line_indent = text_before:match("^%s*")
    local trimmed_text = text_before:gsub("%s+$", "")

    if opens_block(trimmed_text) then 
        line_indent = line_indent .. string.rep(" ", INDENT) 
    end

    _buffer.insert_text(target_buffer, "\n" .. line_indent)
end

--- Inserts spaces up to the next tab stop at cursor location
--- @param target_buffer table Target text buffer instance
function m.tab(target_buffer)
    history.begin_edit(target_buffer, "edit")
    _buffer.delete_selection(target_buffer)
    _buffer.insert_text(target_buffer, string.rep(" ", INDENT - (target_buffer.cx % INDENT)))
end

--- Unindents current line by up to one tab stop level
--- @param target_buffer table Target text buffer instance
function m.untab(target_buffer)
    local current_line = target_buffer.lines[target_buffer.cy]
    local indent_spaces = math.min(#current_line:match("^ *"), INDENT)
    if indent_spaces == 0 then return end

    history.begin_edit(target_buffer, "edit")
    target_buffer.ay, target_buffer.ax = nil, nil
    target_buffer.lines[target_buffer.cy] = current_line:sub(indent_spaces + 1)
    target_buffer.cx = math.max(0, target_buffer.cx - indent_spaces)
end

--- Copies active text selection to system clipboard
--- @param target_buffer table Target text buffer instance
function m.copy(target_buffer)
    local text = _buffer.selected_text(target_buffer)
    if text then 
        _keyboard.set_clipboard(text) 
    end
end

--- Cuts active text selection to system clipboard
--- @param target_buffer table Target text buffer instance
function m.cut(target_buffer)
    local text = _buffer.selected_text(target_buffer)
    if not text then return end

    _keyboard.set_clipboard(text)
    history.begin_edit(target_buffer, "edit")
    _buffer.delete_selection(target_buffer)
end

--- Pastes system clipboard text at cursor position
--- @param target_buffer table Target text buffer instance
function m.paste(target_buffer)
    local text = _keyboard.get_clipboard()
    if text == "" then return end

    text = text:gsub("[^\9\10\13\32-\126]", "?")

    history.begin_edit(target_buffer, "edit")
    _buffer.delete_selection(target_buffer)
    _buffer.insert_text(target_buffer, text)
end

return m
