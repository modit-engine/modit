--- @module find
--- @file src/editor/ui/panels/code/modules/find.lua
--- @description Current-file literal search and undoable replacement module.

--- @section Imports

local _engine = require("src.engine")
local _ui = _engine.ui
local _ui_input = _ui.input
local _input = require("src.sdk.client.input")
local draw = require("src.sdk.client.draw2d")
local state = require("src.editor.ui.panels.code.modules.state")
local buffer = require("src.editor.ui.panels.code.modules.buffer")
local cursor = require("src.editor.ui.panels.code.modules.cursor")
local history = require("src.editor.ui.panels.code.modules.history")

--- @section Initialisation

local m = { 
    visible = false, 
    expanded = false, 
    query = { text = "", pos = 0 }, 
    replacement = { text = "", pos = 0 }, 
    matches = {}, 
    index = 0 
}

local cached_text, cached_query, cached_case, cached_buffer, cached_whole

--- @section Helpers

local function ctrl()
    return (_input.key_down("leftctrl") or _input.key_down("rightctrl")) and not (_input.key_down("leftalt") or _input.key_down("rightalt"))
end

local function get_char_index_at_x(text, local_x, font_size)
    if local_x <= 0 then return 0 end
    local best_pos = 0
    local min_dist = 999999
    for i = 0, #text do
        local sub = text:sub(1, i)
        local w = _ui_input.measure(sub, font_size)
        local dist = math.abs(w - local_x)
        if dist < min_dist then
            min_dist = dist
            best_pos = i
        end
    end
    return best_pos
end

local function nearest(b)
    for i, hit in ipairs(m.matches) do
        if hit.y > b.cy or (hit.y == b.cy and hit.first - 1 >= b.cx) then return i end
    end
    return 1
end

local function field(f, x, y, w, label, theme)
    local offset = math.max(0, _ui_input.measure(f.text:sub(1, f.pos), 16) - w + 18)
    local over = _ui_input.in_rect(x, y, w, 26)

    if over then
        _ui_input.set_cursor("text")
    end

    if _ui_input.pressed() then
        if over then
            _ui_input.set_focus(f)
            local mx, _ = _ui_input.mouse()
            local local_x = mx - (x + 6 - offset)
            f.pos = get_char_index_at_x(f.text, local_x, 16)
            f.selected = false
        elseif _ui_input.has_focus(f) then
            _ui_input.set_focus(nil)
        end
    end

    if _ui_input.has_focus(f) then
        local function insert(text)
            text = text:gsub("[\r\n]", " ")
            if f.selected then f.text, f.pos, f.selected = "", 0, false end
            f.text = f.text:sub(1, f.pos) .. text .. f.text:sub(f.pos + 1)
            f.pos = f.pos + #text
        end

        if ctrl() then
            if _input.key_pressed("a") then f.selected = true end
            if f.selected and (_input.key_pressed("c") or _input.key_pressed("x")) then
                _input.set_clipboard(f.text)
                if _input.key_pressed("x") then insert("") end
            end
            if _input.key_pressed("v") then insert(_input.get_clipboard() or "") end
        else
            local chars, count = _ui_input.typed()
            for i = 1, count do
                local char_code = chars[i]
                if char_code >= 32 and char_code < 127 then
                    insert(string.char(char_code))
                end
            end
            for _, key in ipairs({"backspace", "delete", "arrowleft", "arrowright", "home", "end"}) do
                if _input.key_pressed(key) or _input.key_pressed_repeat(key) then
                    if key == "backspace" or key == "delete" then
                        if f.selected then 
                            insert("")
                        elseif key == "backspace" and f.pos > 0 then
                            f.text = f.text:sub(1, f.pos - 1) .. f.text:sub(f.pos + 1) 
                            f.pos = f.pos - 1
                        elseif key == "delete" then 
                            f.text = f.text:sub(1, f.pos) .. f.text:sub(f.pos + 2) 
                        end
                    else
                        f.selected = false
                        if key == "home" then 
                            f.pos = 0 
                        elseif key == "end" then 
                            f.pos = #f.text
                        else 
                            f.pos = math.max(0, math.min(#f.text, f.pos + (key == "arrowleft" and -1 or 1))) 
                        end
                    end
                end
            end
        end
    end

    draw.set_colour(theme.bg_input)
    draw.rect(x, y, w, 26)
    draw.push_clip(x + 6, y, w - 12, 26)
    
    offset = math.max(0, _ui_input.measure(f.text:sub(1, f.pos), 16) - w + 18)
    if f.selected and _ui_input.has_focus(f) then
        draw.set_colour(theme.bg_hover)
        draw.rect(x + 6 - offset, y, _ui_input.measure(f.text, 16), 26)
    end
    
    _ui.label(f.text == "" and label or f.text, x + 6 - offset, y + 5, 16, f.text == "" and theme.text_tertiary or theme.text_primary)
    
    if _ui_input.has_focus(f) then
        draw.set_colour(theme.accent)
        draw.rect(x + 6 - offset + _ui_input.measure(f.text:sub(1, f.pos), 16), y + 4, 1, 18)
    end
    
    draw.pop_clip()
end

--- @section Functions

--- Refreshes search matches across the given buffer content
--- @param b table Buffer instance
--- @return boolean updated True if matches were recalculated
function m.refresh(b)
    local text = table.concat(b.lines, "\n")
    if cached_text == text and cached_query == m.query.text and cached_case == m.case and cached_buffer == b and cached_whole == m.whole then 
        return false 
    end
    cached_text, cached_query, cached_case, cached_buffer, cached_whole = text, m.query.text, m.case, b, m.whole
    m.matches, m.index = {}, 0
    local needle = m.case and m.query.text or m.query.text:lower()
    if needle == "" then return true end
    for y, line in ipairs(b.lines) do
        local source, start = m.case and line or line:lower(), 1
        while true do
            local first, last = source:find(needle, start, true)
            if not first then break end
            local before, after = source:sub(first - 1, first - 1), source:sub(last + 1, last + 1)
            if not m.whole or (not before:match("[%w_]") and not after:match("[%w_]")) then
                m.matches[#m.matches + 1] = { y = y, first = first, last = last }
            end
            start = last + 1
        end
    end
    return true
end

--- Selects and navigates to a specific match index in the buffer
--- @param b table Buffer instance
--- @param index number Match index target
function m.select(b, index)
    if #m.matches == 0 then m.index = 0; return end
    m.index = (index - 1) % #m.matches + 1
    local hit = m.matches[m.index]
    cursor.move_to(b, hit.y, hit.last, false)
    b.ay, b.ax = hit.y, hit.first - 1
end

--- Performs text replacement for current match or all matches
--- @param b table Buffer instance
--- @param all boolean True to replace all matches
function m.replace(b, all)
    m.refresh(b)
    if #m.matches == 0 then return end
    local index = m.index > 0 and m.index or nearest(b)
    local hit = m.matches[index]
    b.last_kind = nil
    history.begin_edit(b, "replace")
    for i = all and #m.matches or index, all and 1 or index, -1 do
        local match = m.matches[i]
        local line = b.lines[match.y]
        b.lines[match.y] = line:sub(1, match.first - 1) .. m.replacement.text .. line:sub(match.last + 1)
    end
    b.hl, b.auto_end = {}, nil
    cursor.move_to(b, hit.y, hit.first - 1 + #m.replacement.text, false)
    b.cx = math.min(b.cx, #b.lines[b.cy])
    m.refresh(b)
    if not all then m.select(b, nearest(b)) end
end

--- Closes the find/replace panel and restores editor focus
function m.close()
    m.visible = false
    _ui_input.set_focus(state.focus_token)
end

--- Draws the find/replace panel interface and handles user interaction
--- @param b table Buffer instance
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param theme table Theme configuration table
--- @return number height Total panel height rendered
function m.draw(b, x, y, w, theme)
    if _ui.is_modal_open() then return m.visible and (m.expanded and 70 or 36) or 0 end
    if ctrl() and (_input.key_pressed("f") or _input.key_pressed("h")) then
        m.visible = true
        if _input.key_pressed("h") then m.expanded = true end
        local selected = buffer.selected_text(b)
        if selected and selected ~= "" and not selected:find("\n", 1, true) then m.query.text = selected end
        m.query.pos, m.query.selected = #m.query.text, true
        _ui_input.set_focus(m.query)
    end
    if not m.visible then return 0 end
    if _input.key_pressed("escape") then m.close(); return 0 end
    
    local height = m.expanded and 70 or 36
    draw.set_colour(theme.bg_panel)
    draw.rect(x, y, w, height)
    draw.push_clip(x, y, w, height)
    
    local fw = math.max(60, w - 382)
    field(m.query, x + 8, y + 5, fw, "Find", theme)
    
    local refreshed = m.refresh(b)
    if refreshed then m.select(b, nearest(b)) end
    
    local bx = x + fw + 14
    local count = #m.matches == 0 and "No results" or (m.index > 0 and (m.index .. " / " .. #m.matches) or (#m.matches .. " matches"))
    _ui.label(count, bx, y + 10, 14, theme.text_secondary)
    
    bx = bx + 90
    if _ui.button("<", bx, y + 5, 28, 26, { style = "outlined" }) then m.select(b, m.index - 1) end
    if _ui.button(">", bx + 30, y + 5, 28, 26, { style = "outlined" }) then m.select(b, m.index + 1) end
    if _ui.button("Aa", bx + 62, y + 5, 32, 26, { size = 16, style = m.case and "primary" or "outlined" }) then
        m.case = not m.case
        m.refresh(b)
        m.select(b, nearest(b))
    end
    if _ui.button("|ab|", bx + 98, y + 5, 40, 26, { size = 14, style = m.whole and "primary" or "outlined" }) then
        m.whole = not m.whole
        m.refresh(b)
        m.select(b, nearest(b))
    end
    if _ui.button(m.expanded and "Hide" or "Replace", bx + 142, y + 5, 72, 26, { style = "outlined" }) then
        m.expanded = not m.expanded
        if not m.expanded and _ui_input.has_focus(m.replacement) then _ui_input.set_focus(m.query) end
    end
    if _ui.button("x", bx + 220, y + 5, 26, 26, { style = "outlined" }) then m.close() end
    
    if m.expanded then
        field(m.replacement, x + 8, y + 39, fw, "Replace with", theme)
        if _ui.button("Replace", x + fw + 14, y + 39, 90, 26, { style = "outlined" }) then m.replace(b, false) end
        if _ui.button("Replace All", x + fw + 110, y + 39, 120, 26, { style = "outlined" }) then m.replace(b, true) end
    end
    
    if _ui_input.has_focus(m.query) or _ui_input.has_focus(m.replacement) then
        if _input.key_pressed("enter") then
            if _ui_input.has_focus(m.replacement) then 
                m.replace(b, false)
            else 
                m.select(b, m.index + ((_input.key_down("leftshift") or _input.key_down("rightshift")) and -1 or 1)) 
            end
        end
        if _input.key_pressed("tab") and m.expanded then 
            _ui_input.set_focus(_ui_input.has_focus(m.query) and m.replacement or m.query) 
        end
    end
    
    draw.pop_clip()
    return height
end

--- Renders search match highlights inside the code editor buffer view
--- @param b table Buffer instance
--- @param x number X position
--- @param y number Y position
--- @param first number First visible line
--- @param last number Last visible line
--- @param cell_w number Character cell width
--- @param line_h number Line height
--- @param theme table Theme configuration table
function m.highlight(b, x, y, first, last, cell_w, line_h, theme)
    if not m.visible then return end
    m.refresh(b)
    draw.set_colour(theme.accent[1], theme.accent[2], theme.accent[3], 45)
    for _, hit in ipairs(m.matches) do
        if hit.y > last then break end
        if hit.y >= first then 
            draw.rect(x + (hit.first - 1) * cell_w, y + (hit.y - 1) * line_h, (hit.last - hit.first + 1) * cell_w, line_h) 
        end
    end
end

return m