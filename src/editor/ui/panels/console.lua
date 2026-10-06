--- @module console
--- @file src/editor/ui/panels/console.lua
--- @description Console UI panel for monitoring log output, parsing levels and timestamps, and auto-scrolling log streams.

--- @section Imports

--- Engine
local _font = require("src.engine.modules.font")

--- Editor
local _input = require("src.engine.ui.input")
local _theme = require("src.engine.ui.style.theme")
local _components = require("src.engine.ui.components")

--- @section Constants

local LINE_H = 18
local FONT_SIZE = 16
local PAD = 8
local GAP = 10
local TITLE_H = 31
local MAX_LINES = 2000
local POLL_EVERY = 0.1

local TAGS = {
    print = "PRINT",
    debug = "DEBUG",
    info = "INFO",
    success = "SUCCESS",
    warn = "WARN",
    error = "ERROR",
    fatal = "FATAL",
}

local TINT_TEXT = { warn = true, error = true, fatal = true }

--- @section Initialisation

local log_levels = {}
local log_times = {}
local log_texts = {}
local log_count = 0

local log_path = nil
local read_pos = 0
local partial_line = ""
local last_level = "print"
local poll_timer = 0

local scroll_state = { y = 0 }
local is_stick_bottom = true

local time_column_w = nil
local tag_column_w = nil

local m = {}

--- @section Helpers

--- Resets log buffer arrays and optionally skips existing file contents
--- @param skip_existing boolean If true, sets read position to end of log file
local function reset_log_state(skip_existing)
    log_levels, log_times, log_texts, log_count = {}, {}, {}, 0
    read_pos, partial_line, last_level = 0, "", "print"
    scroll_state.y = 0
    is_stick_bottom = true

    if skip_existing and log_path then
        local file_handle = io.open(log_path, "rb")
        if file_handle then
            read_pos = file_handle:seek("end")
            file_handle:close()
        end
    end
end

--- Pushes a single log entry into memory buffers, removing oldest entry if MAX_LINES exceeded
--- @param level_tag string Log severity level tag key
--- @param timestamp string Timestamp string
--- @param text_content string Message text content
local function add_log_entry(level_tag, timestamp, text_content)
    log_count = log_count + 1
    log_levels[log_count] = level_tag
    log_times[log_count] = timestamp
    log_texts[log_count] = (text_content:gsub("\t", "    "))

    if log_count > MAX_LINES then
        table.remove(log_levels, 1)
        table.remove(log_times, 1)
        table.remove(log_texts, 1)
        log_count = log_count - 1
    end
end

--- Ingests incoming chunk buffer data into line entries
--- @param chunk_data string Raw string chunk read from log file
local function ingest_data(chunk_data)
    chunk_data = partial_line .. chunk_data

    local last_newline = chunk_data:match("^.*()\n")
    if not last_newline then
        partial_line = chunk_data
        return
    end

    partial_line = chunk_data:sub(last_newline + 1)
    local line_block = chunk_data:sub(1, last_newline - 1)

    for current_line in (line_block .. "\n"):gmatch("(.-)\n") do
        current_line = current_line:gsub("\r$", "")

        local level_tag, timestamp, text_content = current_line:match("^(%a+)\t(%d%d:%d%d:%d%d)\t(.*)$")

        if level_tag and TAGS[level_tag] then
            last_level = level_tag
        else
            level_tag, timestamp, text_content = last_level, "", current_line
        end

        add_log_entry(level_tag, timestamp, text_content)
    end
end

--- Polls target log file for new append data
local function poll_log_file()
    if not log_path then return end

    local file_handle = io.open(log_path, "rb")
    if not file_handle then return end

    local current_size = file_handle:seek("end")

    if current_size < read_pos then
        reset_log_state(false)
    end

    if current_size > read_pos then
        file_handle:seek("set", read_pos)

        local new_data = file_handle:read(current_size - read_pos)
        read_pos = current_size

        if new_data then
            ingest_data(new_data)
        end
    end

    file_handle:close()
end

--- @section Functions

--- Sets target log file path and reads existing contents into console
--- @param target_log_path string File path to log file
function m.open(target_log_path)
    log_path = target_log_path
    reset_log_state(false)
end

--- Clears current console output and aligns read position to end of file
function m.clear()
    reset_log_state(true)
end

--- Updates console file polling timer tick
--- @param delta_time number Frame delta time in seconds
function m.update(delta_time)
    poll_timer = poll_timer + delta_time

    if poll_timer >= POLL_EVERY then
        poll_timer = 0
        poll_log_file()
    end
end

--- Renders console UI view within given bounding rectangle
--- @param viewport table Viewport rectangle table { x, y, w, h }
function m.draw(viewport)
    if viewport.w <= 0 or viewport.h <= TITLE_H + 1 then
        return
    end

    local active_theme = _theme.get()
    local log_colors = active_theme.console_logs

    _components.label(log_count .. " lines", viewport.x + 100, viewport.y + 8, FONT_SIZE, active_theme.text_tertiary)

    if _components.button("Clear", viewport.x + viewport.w - 70, viewport.y + 3, 60, 24) then
        m.clear()
    end

    local panel_x = viewport.x
    local panel_y = viewport.y + TITLE_H + 1
    local panel_w = viewport.w
    local panel_h = viewport.h - TITLE_H - 1

    if log_count == 0 then
        _components.label("No output", panel_x + PAD, panel_y + PAD, FONT_SIZE, active_theme.text_tertiary)
        return
    end

    if not time_column_w then
        time_column_w = _font.width(FONT_SIZE, "00:00:00")
        tag_column_w = _font.width(FONT_SIZE, "SUCCESS")
    end

    local total_content_h = log_count * LINE_H + PAD * 2
    local max_scroll_y = math.max(0, total_content_h - panel_h)

    if is_stick_bottom then
        scroll_state.y = max_scroll_y
    end

    _components.scroll_begin(scroll_state, panel_x, panel_y, panel_w, panel_h, total_content_h)
    is_stick_bottom = (scroll_state.y >= max_scroll_y - 1)

    local first_idx = math.max(1, math.floor((scroll_state.y - PAD) / LINE_H) + 1)
    local last_idx = math.min(log_count, math.ceil((scroll_state.y + panel_h - PAD) / LINE_H) + 1)

    local time_col_x = panel_x + PAD
    local tag_col_x = time_col_x + time_column_w + GAP
    local text_col_x = tag_col_x + tag_column_w + GAP

    for index = first_idx, last_idx do
        local level_tag = log_levels[index]
        local tag_color = log_colors[level_tag] or active_theme.text_primary
        local line_y = panel_y + PAD + (index - 1) * LINE_H - scroll_state.y

        _components.label(log_times[index], time_col_x, line_y, FONT_SIZE, active_theme.text_tertiary)
        _components.label(TAGS[level_tag] or "", tag_col_x, line_y, FONT_SIZE, tag_color)
        _components.label(log_texts[index], text_col_x, line_y, FONT_SIZE, TINT_TEXT[level_tag] and tag_color or active_theme.text_primary)
    end

    _components.scroll_end()
end

return m