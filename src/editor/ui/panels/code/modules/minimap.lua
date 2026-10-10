--- @module minimap
--- @description Compact code overview with readable @section navigation markers.

--- @section Imports

local draw = require("src.engine.modules.render.draw")
local input = require("src.engine.ui.modules.input")
local highlight = require("src.editor.ui.panels.code.modules.highlight")
local state = require("src.editor.ui.panels.code.modules.state")

local m = {}
local dragging, drag_offset
local PAD, CHAR_W, LABEL_H = 6, 1.5, 18

--- @section Preview Cache

-- Compare immutable line strings so edits, undo/redo and renames all invalidate
-- the preview without adding bookkeeping to the editor's editing operations.
local function preview(buffer)
    local cache = buffer.minimap
    local changed = not cache or cache.lua ~= buffer.lua or #cache.lines ~= #buffer.lines
    if not changed then
        for i, line in ipairs(buffer.lines) do
            if cache.lines[i] ~= line then changed = true break end
        end
    end
    if not changed then return cache end

    cache = { lines = {}, rows = {}, sections = {}, lua = buffer.lua }
    if buffer.lua then highlight.update(buffer, #buffer.lines) end
    for i, line in ipairs(buffer.lines) do
        cache.lines[i] = line
        local row = {}
        local tokens = buffer.lua and buffer.hl[i].toks or { { s = 1, e = #line, kind = "text" } }
        for _, token in ipairs(tokens) do
            -- Only the leftmost columns fit; preserve whitespace gaps in comments.
            local text = line:sub(token.s, math.min(token.e, 100))
            for first, word in text:gmatch("()(%S+)") do
                row[#row + 1] = { x = token.s + first - 2, w = #word, kind = token.kind }
            end
        end
        cache.rows[i] = row
        local title = line:match("^%s*%-%-%-%s*@section%s+(.-%S)%s*$")
        -- Ignore marker-shaped text inside Lua multiline strings/comments.
        if title and (not buffer.lua or not buffer.hl[i].state_in) then
            cache.sections[#cache.sections + 1] = { line = i, title = title }
        end
    end
    buffer.minimap = cache
    return cache
end

--- @section Navigation and Drawing

-- Section rows occupy a full label height in the preview only. The same
-- line positions drive drawing, the visible-area highlight and mouse mapping.
local function layout(cache, h)
    if cache.layout and cache.layout.h == h and cache.layout.line_h == state.line_h then
        return cache.layout
    end
    local available = h - PAD * 2
    local total_lines = #cache.lines + math.floor(h / 2) / state.line_h
    local headings, count = {}, 0
    -- On very dense files retain room for code, as well as readable labels.
    local limit = math.max(1, math.floor(available / ((LABEL_H + 2) * 2)))
    local stride = math.max(1, math.ceil(#cache.sections / limit))
    for i = 1, #cache.sections, stride do
        local section = cache.sections[i]
        headings[section.line] = section
        count = count + 1
    end
    local label_h = math.min(LABEL_H + 2, available / 2)
    local step = math.min(3, (available - count * label_h) / (total_lines - count))
    local positions, offset = {}, 0
    for i = 1, #cache.lines do
        positions[i] = offset
        offset = offset + (headings[i] and label_h or step)
    end
    positions[#cache.lines + 1] = offset
    local result = { h = h, line_h = state.line_h, positions = positions, headings = headings, step = step }
    cache.layout = result
    return result
end

local function to_map(map, source_y)
    local line = source_y / state.line_h
    local index = math.max(1, math.min(#map.positions, math.floor(line) + 1))
    local height = map.positions[index + 1] and map.positions[index + 1] - map.positions[index] or map.step
    return map.positions[index] + (line - index + 1) * height
end

local function from_map(map, map_y)
    local low, high = 1, #map.positions
    while low < high do
        local mid = math.ceil((low + high) / 2)
        if map.positions[mid] <= map_y then low = mid else high = mid - 1 end
    end
    local height = map.positions[low + 1] and map.positions[low + 1] - map.positions[low] or map.step
    return (low - 1 + (map_y - map.positions[low]) / height) * state.line_h
end

function m.cancel_drag()
    dragging, drag_offset = nil, nil
end

function m.draw(buffer, x, y, w, h, theme)
    if h <= PAD * 2 then m.cancel_drag() return end
    local cache = preview(buffer)
    local map = layout(cache, h)
    local content_h = #buffer.lines * state.line_h + math.floor(h / 2)
    local step = map.step
    local top = y + PAD
    local max_scroll = math.max(0, content_h - h)
    local over = input.in_rect(x, y, w, h)
    local _, my = input.mouse()
    local view_y = top + to_map(map, buffer.scroll.y)
    local view_h = to_map(map, buffer.scroll.y + h) - to_map(map, buffer.scroll.y)
    local labels = {}
    local hovered_section

    for _, section in ipairs(cache.sections) do
        local sy = top + map.positions[section.line]
        if map.headings[section.line] then
            labels[#labels + 1] = { y = sy, section = section }
            if over and my >= sy and my < sy + LABEL_H then hovered_section = section end
        end
    end

    if dragging ~= buffer or not input.down() then m.cancel_drag() end
    if over then
        input.set_cursor("hand")
        buffer.scroll.y = math.max(0, math.min(max_scroll, buffer.scroll.y - input.wheel() * 54))
        if input.pressed() then
            state.selecting = false
            input.set_focus(state.focus_token)
            buffer.reveal = false
            if hovered_section then
                buffer.scroll.y = math.min(max_scroll, (hovered_section.line - 1) * state.line_h)
            else
                dragging = buffer
                drag_offset = my >= view_y and my <= view_y + view_h and my - view_y or view_h / 2
            end
        end
    end
    if dragging == buffer then
        buffer.scroll.y = math.max(0, math.min(max_scroll, from_map(map, my - top - drag_offset)))
    end

    draw.push_clip(x, y, w, h)
    draw.set_colour(theme.bg_panel)
    draw.rect(x, y, w, h)
    draw.set_colour(theme.border_dark.color)
    draw.rect(x, y, 1, h)

    -- Sample at most one source line per pixel for very long documents.
    local last_pixel = -1
    local syntax = theme.syntax or {}
    for i, row in ipairs(cache.rows) do
        local row_y = math.floor(top + map.positions[i])
        if not map.headings[i] and row_y > last_pixel then
            for _, run in ipairs(row) do
                draw.set_colour(syntax[run.kind] or theme.text_secondary)
                draw.rect(x + PAD + run.x * CHAR_W, row_y, run.w * CHAR_W, math.max(1, math.min(2, step)))
            end
            last_pixel = row_y
        end
    end

    view_y = top + to_map(map, buffer.scroll.y)
    view_h = to_map(map, buffer.scroll.y + h) - to_map(map, buffer.scroll.y)
    draw.set_colour(theme.accent, 28)
    draw.rect(x + 1, view_y, w - 2, view_h)
    draw.set_colour(theme.accent, 110)
    draw.rect(x + 1, view_y, 2, view_h)

    for _, label in ipairs(labels) do
        draw.set_colour(theme.bg_panel, 240)
        draw.rect(x + 3, label.y, w - 6, LABEL_H)
        draw.set_colour(label.section == hovered_section and theme.accent or theme.text_primary)
        input.text(label.section.title, x + PAD, label.y + 1, 14)
    end
    draw.pop_clip()
end

return m
