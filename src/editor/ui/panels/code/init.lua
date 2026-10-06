--- @module code
--- @file src/editor/ui/panels/code/init.lua
--- @description Code editor UI panel module for rendering tab bars, text editor canvas, gutter, status bar, and managing buffer lifecycle.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")
local _font = require("src.engine.modules.font")
local _mouse = require("src.engine.modules.mouse")

--- Editor
local _components = require("src.engine.ui.components")
local _input = require("src.engine.ui.input")
local _theme = require("src.engine.ui.style.theme")
local _highlight = require("src.editor.ui.panels.code.modules.highlight")
local _config = require("src.editor.ui.panels.code.modules.config")
local _state = require("src.editor.ui.panels.code.modules.state")
local _buffer = require("src.editor.ui.panels.code.modules.buffer")
local _cursor = require("src.editor.ui.panels.code.modules.cursor")
local _files = require("src.editor.ui.panels.code.modules.files")
local _keys = require("src.editor.ui.panels.code.modules.keys")
local _pointer = require("src.editor.ui.panels.code.modules.pointer")

--- @section Constants

local TAB_H = _config.TAB_H
local STATUS_H = _config.STATUS_H
local GUTTER_PAD = _config.GUTTER_PAD
local TEXT_PAD = _config.TEXT_PAD
local INDENT = _config.INDENT
local MAX_BYTES = _config.MAX_BYTES

--- @section Initialisation

local m = {}

--- @section Helpers

--- Returns leading space indentation level for line, or nil if blank
--- @param target_buffer table Target text buffer instance
--- @param line_index number Line index to evaluate
--- @return number|nil indent Space character count, or nil if empty line
local function indent_of(target_buffer, line_index)
    local line = target_buffer.lines[line_index]
    if line:find("%S") then 
        return #line:match("^ *") 
    end
    return nil
end

--- Determines indentation level for rendering indent guide lines on blank lines
--- @param target_buffer table Target text buffer instance
--- @param line_index number Line index to evaluate
--- @return number indent Effective indent level
local function guide_indent(target_buffer, line_index)
    local indent = indent_of(target_buffer, line_index)
    if indent then 
        return indent 
    end

    local up_indent, down_indent
    for previous_index = line_index - 1, math.max(1, line_index - 50), -1 do
        up_indent = indent_of(target_buffer, previous_index)
        if up_indent then break end
    end
    for next_index = line_index + 1, math.min(#target_buffer.lines, line_index + 50) do
        down_indent = indent_of(target_buffer, next_index)
        if down_indent then break end
    end
    return math.min(up_indent or 0, down_indent or 0)
end

--- Renders tab headers for open text buffers
--- @param viewport table Viewport bounding rectangle { x, y, w, h }
--- @param theme table Active theme color mapping
local function draw_tabs(viewport, theme)
    _draw.set_colour(theme.bg_panel)
    _draw.rect(viewport.x, viewport.y, viewport.w, TAB_H)

    _draw.push_clip(viewport.x, viewport.y, viewport.w, TAB_H)

    local current_x = viewport.x
    local is_pressed = _mouse.pressed()
    local buffer_to_close = nil

    for _, current_buffer in ipairs(_state.buffers) do
        local label = current_buffer.confirm and "Discard changes?" or (current_buffer.name .. (current_buffer.dirty and " *" or ""))
        local tab_width = #label * _state.font.cell_w + 48
        local is_active = (current_buffer == _state.active)
        local over_tab = _input.in_rect(current_x, viewport.y, tab_width - 26, TAB_H)
        local over_close = _input.in_rect(current_x + tab_width - 26, viewport.y, 26, TAB_H)

        if is_active then
            _draw.set_colour(theme.bg_main)
            _draw.rect(current_x, viewport.y, tab_width, TAB_H)
            _draw.set_colour(theme.accent)
            _draw.rect(current_x, viewport.y + TAB_H - 2, tab_width, 2)
        elseif over_tab or over_close then
            _draw.set_colour(theme.bg_hover)
            _draw.rect(current_x, viewport.y, tab_width, TAB_H)
        end

        _draw.set_colour(current_buffer.confirm and theme.accent3 or (is_active and theme.text_primary or theme.text_secondary))
        _font.draw(_state.font, label, current_x + 12, viewport.y + 5)

        _draw.set_colour(over_close and theme.text_primary or theme.text_tertiary)
        _font.draw(_state.font, "x", current_x + tab_width - 18, viewport.y + 5)

        if is_pressed then
            if over_close then
                _state.tab_clicked = true
                if current_buffer.dirty and not current_buffer.confirm then 
                    current_buffer.confirm = true 
                else 
                    buffer_to_close = current_buffer 
                end
            elseif over_tab then
                _state.tab_clicked = true
                _state.active, _state.selecting = current_buffer, false
                current_buffer.confirm = false
                _input.set_focus(_state.focus_token)
            end
        end

        current_x = current_x + tab_width
    end

    _draw.pop_clip()
    if buffer_to_close then 
        _files.close_buffer(buffer_to_close) 
    end
end

--- Renders status bar showing cursor position, encoding, and active file info
--- @param target_buffer table Active text buffer instance
--- @param viewport table Viewport bounding rectangle { x, y, w, h }
--- @param theme table Active theme color mapping
local function draw_status(target_buffer, viewport, theme)
    local status_y = viewport.y + viewport.h - STATUS_H

    _draw.set_colour(theme.bg_panel)
    _draw.rect(viewport.x, status_y, viewport.w, STATUS_H)
    _draw.set_colour(theme.border_dark.color)
    _draw.line(viewport.x, status_y, viewport.x + viewport.w, status_y)

    _draw.set_colour(theme.text_secondary)
    _font.draw(_state.font, ("Ln %d, Col %d    %s"):format(target_buffer.cy, target_buffer.cx + 1, target_buffer.crlf and "CRLF" or "LF"), viewport.x + 10, status_y + 3)

    if viewport.w < 300 then return end

    local path_text, text_color = target_buffer.path, theme.text_tertiary
    if _state.notice and os.clock() < _state.notice_until then 
        path_text, text_color = _state.notice, theme.accent3 
    end

    _draw.push_clip(viewport.x + 240, status_y, viewport.w - 250, STATUS_H)
        _draw.set_colour(text_color)
        _font.draw(_state.font, path_text, viewport.x + viewport.w - #path_text * _state.font.cell_w - 10, status_y + 3)
    _draw.pop_clip()
end

--- Identifies the word token currently under or touching the cursor
--- @param target_buffer table Target text buffer instance
--- @return string|nil word Identifier text under cursor, or nil
local function word_at(target_buffer)
    local line_text = target_buffer.lines[target_buffer.cy]
    for start_pos, identifier in line_text:gmatch("()([%a_][%w_]*)") do
        if target_buffer.cx >= start_pos - 1 and target_buffer.cx <= start_pos - 1 + #identifier then 
            return identifier 
        end
    end
end

--- Finds start and end line range of the function enclosing the given line index
--- @param target_buffer table Target text buffer instance
--- @param line_index number Target line index
--- @return number start_line First line index of function
--- @return number end_line Last line index of function
local function function_range(target_buffer, line_index)
    for start_idx = line_index, 1, -1 do
        local line_text = target_buffer.lines[start_idx]
        if line_text:find("^%s*local%s+function%s") or line_text:find("^%s*function%s") then
            local indent_level = #line_text:match("^ *")
            for end_idx = start_idx + 1, #target_buffer.lines do
                local current_line = target_buffer.lines[end_idx]
                if current_line:find("^%s*end%f[^%w_]") and #current_line:match("^ *") == indent_level then
                    if end_idx >= line_index then 
                        return start_idx, end_idx 
                    end
                    break
                end
            end
        end
    end
    return 1, #target_buffer.lines
end

--- Renders text editor canvas including gutter, line numbers, selections, and syntax text
--- @param target_buffer table Active text buffer instance
--- @param panel_x number Panel X position
--- @param panel_y number Panel Y position
--- @param panel_w number Panel width
--- @param panel_h number Panel height
--- @param theme table Active theme color mapping
local function draw_editor(target_buffer, panel_x, panel_y, panel_w, panel_h, theme)
    local cell_w = _state.font.cell_w
    local digit_count = math.max(3, #tostring(#target_buffer.lines))
    local gutter_w = math.floor(digit_count * cell_w) + GUTTER_PAD * 2
    if panel_w < gutter_w + 80 or panel_h < _state.line_h then return end

    local text_left_margin = panel_x + gutter_w + TEXT_PAD
    local text_w = panel_w - gutter_w - TEXT_PAD - 12
    local is_focused = _input.has_focus(_state.focus_token)
    local syntax_theme = theme.syntax or {}

    -- Keyboard and mouse event processing
    if is_focused then 
        _keys.handle(target_buffer, math.max(1, math.floor(panel_h / _state.line_h) - 1)) 
    end
    is_focused = _pointer.update(target_buffer, panel_x, panel_y, panel_w, panel_h, text_left_margin, is_focused)

    if target_buffer.reveal then
        _cursor.reveal(target_buffer, panel_h, text_w)
        target_buffer.reveal = false
    end

    -- Canvas Background
    _draw.set_colour(theme.bg_main)
    _draw.rect(panel_x, panel_y, panel_w, panel_h)

    local scroll_y_max = #target_buffer.lines * _state.line_h + math.floor(panel_h / 2)
    _components.scroll_begin(target_buffer.scroll, panel_x, panel_y, panel_w, panel_h, scroll_y_max)

    local scroll_y = target_buffer.scroll.y
    local first_line = math.max(1, math.floor(scroll_y / _state.line_h) + 1)
    local last_line = math.min(#target_buffer.lines, math.floor((scroll_y + panel_h) / _state.line_h) + 1)

    -- Line number gutter
    for line_idx = first_line, last_line do
        local line_str = tostring(line_idx)
        _draw.set_colour(line_idx == target_buffer.cy and (syntax_theme.gutter_active or theme.text_secondary) or (syntax_theme.gutter or theme.text_tertiary))
        _font.draw(_state.font, line_str, math.floor(panel_x + gutter_w - GUTTER_PAD - #line_str * cell_w), math.floor(panel_y + (line_idx - 1) * _state.line_h - scroll_y + 2))
    end

    -- Text editor region
    _draw.push_clip(panel_x + gutter_w, panel_y, panel_w - gutter_w, panel_h)

    local offset_x = text_left_margin - target_buffer.sx
    local sel_start_y, sel_start_x, sel_end_y, sel_end_x = _buffer.selection(target_buffer)

    -- Active selection rendering
    if sel_start_y then
        local sel_color = syntax_theme.selection or { 70, 120, 200, 90 }
        _draw.set_colour(sel_color[1], sel_color[2], sel_color[3], sel_color[4])

        for line_idx = math.max(sel_start_y, first_line), math.min(sel_end_y, last_line) do
            local col0 = (line_idx == sel_start_y) and sel_start_x or 0
            local col1 = (line_idx == sel_end_y) and sel_end_x or (#target_buffer.lines[line_idx] + 1)
            if col1 > col0 then
                local line_y = panel_y + (line_idx - 1) * _state.line_h - scroll_y
                _draw.rect(math.floor(offset_x + col0 * cell_w), line_y, (col1 - col0) * cell_w, _state.line_h)
            end
        end
    end

    -- Occurrence highlighting
    if not sel_start_y then
        local current_word = word_at(target_buffer)
        if current_word then
            local range_min, range_max = first_line, last_line
            if current_word == "self" then
                local func_start, func_end = function_range(target_buffer, target_buffer.cy)
                range_min, range_max = math.max(first_line, func_start), math.min(last_line, func_end)
            end

            local occ_color = syntax_theme.occurrence or { 255, 255, 255, 28 }
            _draw.set_colour(occ_color[1], occ_color[2], occ_color[3], occ_color[4])

            for line_idx = range_min, range_max do
                local line_y = panel_y + (line_idx - 1) * _state.line_h - scroll_y
                for start_pos, word_name in target_buffer.lines[line_idx]:gmatch("()([%a_][%w_]*)") do
                    if word_name == current_word then
                        _draw.rect(math.floor(offset_x + (start_pos - 1) * cell_w), line_y, #word_name * cell_w, _state.line_h)
                    end
                end
            end
        end
    end

    -- Indent guides
    _draw.set_colour(theme.border_light.color)
    for line_idx = first_line, last_line do
        local indent_levels = math.floor(guide_indent(target_buffer, line_idx) / INDENT)
        local line_y = panel_y + (line_idx - 1) * _state.line_h - scroll_y
        for level = 0, indent_levels - 1 do
            _draw.rect(math.floor(offset_x + level * INDENT * cell_w), line_y, 1, _state.line_h)
        end
    end

    -- Syntax highlighted or plain text lines
    if target_buffer.lua then
        _highlight.update(target_buffer, last_line)

        for line_idx = first_line, last_line do
            local line_text = target_buffer.lines[line_idx]
            local line_tokens = target_buffer.hl[line_idx].toks
            local line_y = math.floor(panel_y + (line_idx - 1) * _state.line_h - scroll_y + 2)
            local current_kind = nil

            for token_idx = 1, #line_tokens do
                local token = line_tokens[token_idx]
                if token.kind ~= current_kind then
                    current_kind = token.kind
                    _draw.set_colour(syntax_theme[current_kind] or theme.text_primary)
                end
                _font.draw(_state.font, line_text:sub(token.s, token.e), math.floor(offset_x + (token.s - 1) * cell_w), line_y)
            end
        end
    else
        _draw.set_colour(theme.text_primary)
        for line_idx = first_line, last_line do
            _font.draw(_state.font, target_buffer.lines[line_idx], math.floor(offset_x), math.floor(panel_y + (line_idx - 1) * _state.line_h - scroll_y + 2))
        end
    end

    -- Cursor Caret
    if is_focused and math.floor((os.clock() - _state.blink_from) * 2) % 2 == 0 then
        _draw.set_colour(theme.accent)
        _draw.rect(math.floor(offset_x + target_buffer.cx * cell_w), math.floor(panel_y + (target_buffer.cy - 1) * _state.line_h - scroll_y + 2), 2, _state.line_h - 4)
    end

    _draw.pop_clip()
    _components.scroll_end()
end

--- @section Functions

--- Opens a file path in a editor tab or switches focus to it if already open
--- @param file_path string Target file path to open
--- @return boolean ok True if file opened or activated successfully
function m.open(file_path)
    for _, current_buffer in ipairs(_state.buffers) do
        if current_buffer.path == file_path then
            _state.active = current_buffer
            _input.set_focus(_state.focus_token)
            return true
        end
    end

    if not _state.ensure_font() then
        _state.notify(_state.font_err)
        return false
    end

    local handle = io.open(file_path, "rb")
    if not handle then
        _state.notify("Could not open file")
        return false
    end

    local file_size = handle:seek("end")
    if file_size > MAX_BYTES then
        handle:close()
        _state.notify("File is too large to edit")
        return false
    end

    handle:seek("set", 0)
    local content = handle:read("*a")
    handle:close()

    if content:find("\0", 1, true) then
        _state.notify("Can't edit a binary file")
        return false
    end

    local new_buffer = _buffer.new(file_path, content)
    _state.buffers[#_state.buffers + 1] = new_buffer
    _state.active = new_buffer
    _state.selecting = false
    _input.set_focus(_state.focus_token)
    return true
end

--- Checks if any files are currently open in the editor
--- @return boolean open True if at least one buffer tab is open
function m.has_open()
    return #_state.buffers > 0
end

--- Saves all dirty modified open text buffers
function m.save_all()
    for _, current_buffer in ipairs(_state.buffers) do
        if current_buffer.dirty then 
            _files.save(current_buffer) 
        end
    end
end

--- Closes all open editor buffer tabs and drops keyboard focus
function m.close_all()
    _state.buffers, _state.active, _state.selecting = {}, nil, false
    if _input.has_focus(_state.focus_token) then 
        _input.set_focus(nil) 
    end
end

--- Retrieves the active status notification message text if present and unexpired
--- @return string|nil notice Active notice text or nil
function m.get_notice()
    if _state.notice and os.clock() < _state.notice_until then 
        return _state.notice 
    end
end

--- Renders the complete editor panel view inside the target viewport rectangle
--- @param viewport table Viewport bounding rectangle { x, y, w, h }
function m.draw(viewport)
    if not _state.ensure_font() then return end

    local theme = _theme.get()
    _state.tab_clicked = false

    draw_tabs(viewport, theme)

    local active_buffer = _state.active
    if not active_buffer then return end

    draw_editor(active_buffer, viewport.x, viewport.y + TAB_H, viewport.w, viewport.h - TAB_H - STATUS_H, theme)
    draw_status(active_buffer, viewport, theme)
end

--- Closes tabs corresponding to a deleted file or folder path
--- @param target_path string Path to close
--- @param is_directory boolean True if path represents a directory
function m.close_path(target_path, is_directory)
    local dir_prefix = target_path .. "/"
    local buffers_to_close = {}

    for _, current_buffer in ipairs(_state.buffers) do
        if current_buffer.path == target_path or (is_directory and current_buffer.path:sub(1, #dir_prefix) == dir_prefix) then
            buffers_to_close[#buffers_to_close + 1] = current_buffer
        end
    end

    for _, current_buffer in ipairs(buffers_to_close) do
        _files.close_buffer(current_buffer)
    end
end

--- Updates buffer path bindings following a file or directory rename
--- @param old_path string Original file or directory path
--- @param new_path string New file or directory path
function m.rename_path(old_path, new_path)
    local dir_prefix = old_path .. "/"

    for _, current_buffer in ipairs(_state.buffers) do
        if current_buffer.path == old_path then
            current_buffer.path = new_path
            current_buffer.name = new_path:match("([^/]+)$") or new_path
            current_buffer.lua = new_path:lower():match("%.lua$") ~= nil
            current_buffer.hl = {}
        elseif current_buffer.path:sub(1, #dir_prefix) == dir_prefix then
            current_buffer.path = new_path .. "/" .. current_buffer.path:sub(#dir_prefix + 1)
        end
    end
end

return m