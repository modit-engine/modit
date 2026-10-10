--- @module console
--- @file src/editor/ui/panels/console.lua
--- @description Console UI panel for monitoring log output, parsing levels and timestamps, and auto-scrolling log streams.

--- @section Imports

--- Engine
local _font = require("src.engine.modules.render.font")

--- Editor
local _input = require("src.engine.ui.modules.input")
local _location = require("src.editor.core.log_location")
local _code = require("src.editor.ui.panels.code")
local _draw = require("src.engine.modules.render.draw")
local _theme = require("src.engine.ui.modules.theme")
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

local function new_stream()
    return {
        log_path = nil,
        log_levels = {}, log_times = {}, log_texts = {}, log_count = 0, locations = {},
        read_pos = 0, partial_line = "", last_level = "print",
        scroll_state = { y = 0 }, is_stick_bottom = true,
    }
end

local streams = {
    client = new_stream(),
    server = new_stream(),
    build = new_stream(),
}

local active_tab = "client"
local poll_timer = 0
local project_path
local notice, notice_until

local time_column_w = nil
local tag_column_w = nil

local m = {}

--- @section Helpers

--- Resets log buffer arrays and optionally skips existing file contents
--- @param skip_existing boolean If true, sets read position to end of log file
local function reset_log_state(stream, skip_existing)
    stream.log_levels, stream.log_times, stream.log_texts, stream.log_count = {}, {}, {}, 0
    stream.locations = {}
    stream.read_pos, stream.partial_line, stream.last_level = 0, "", "print"
    stream.scroll_state.y = 0
    stream.is_stick_bottom = true

    if skip_existing and stream.log_path then
        local file_handle = io.open(stream.log_path, "rb")
        if file_handle then
            stream.read_pos = file_handle:seek("end") or 0
            file_handle:close()
        end
    end
end

--- Pushes a single log entry into memory buffers, removing oldest entry if MAX_LINES exceeded
--- @param level_tag string Log severity level tag key
--- @param timestamp string Timestamp string
--- @param text_content string Message text content
local function add_log_entry(stream, level_tag, timestamp, text_content)
    stream.log_count = stream.log_count + 1
    stream.log_levels[stream.log_count] = level_tag
    stream.log_times[stream.log_count] = timestamp
    stream.log_texts[stream.log_count] = (text_content:gsub("\t", "    "))

    stream.locations[stream.log_count] = _location.parse(text_content) or false

    if stream.log_count > MAX_LINES then
        table.remove(stream.locations, 1)
        table.remove(stream.log_levels, 1)
        table.remove(stream.log_times, 1)
        table.remove(stream.log_texts, 1)
        stream.log_count = stream.log_count - 1
    end
end

--- Ingests incoming chunk buffer data into line entries
--- @param chunk_data string Raw string chunk read from log file
local function ingest_data(stream, chunk_data)
    chunk_data = stream.partial_line .. chunk_data

    local last_newline = chunk_data:match("^.*()\n")
    if not last_newline then
        stream.partial_line = chunk_data
        return
    end

    stream.partial_line = chunk_data:sub(last_newline + 1)
    local line_block = chunk_data:sub(1, last_newline - 1)

    for current_line in (line_block .. "\n"):gmatch("(.-)\n") do
        current_line = current_line:gsub("\r$", "")

        local level_tag, timestamp, text_content =
            current_line:match("^(%a+)\t(%d%d:%d%d:%d%d)\t(.*)$")

        if level_tag and TAGS[level_tag] then
            stream.last_level = level_tag
        else
            level_tag, timestamp, text_content = stream.last_level, "", current_line
        end

        add_log_entry(stream, level_tag, timestamp, text_content)
    end
end

--- Polls target log file for new append data
local function poll_log_file(stream)
    if not stream.log_path then return end

    local file_handle = io.open(stream.log_path, "rb")
    if not file_handle then return end

    local current_size = file_handle:seek("end") or 0

    if current_size < stream.read_pos then
        reset_log_state(stream, false)
    end

    if current_size > stream.read_pos then
        file_handle:seek("set", stream.read_pos)

        local new_data = file_handle:read(current_size - stream.read_pos)
        stream.read_pos = current_size

        if new_data then
            ingest_data(stream, new_data)
        end
    end

    file_handle:close()
end

--- @section Functions

--- Opens project logs, keeping their histories and scroll positions separate.
--- @param client_path string Client log path
--- @param server_path string Server log path
--- @param project string Project path
--- @param build_path string Build log path
function m.open(client_path, server_path, project, build_path)
    project_path = project
    notice = nil

    streams.client.log_path = client_path
    streams.server.log_path = server_path
    streams.build.log_path = build_path or (project and (project .. "/build.log"))

    active_tab = "client"
    poll_timer = 0

    for _, stream in pairs(streams) do
        reset_log_state(stream, false)
    end
end

--- Clears only the selected tab (or named stream), without changing the log file.
function m.clear(realm)
    local stream = streams[realm or active_tab]
    if not stream then return false end

    reset_log_state(stream, true)
    return true
end

--- Poll all logs even when their tab or the console panel is hidden.
function m.update(delta_time)
    poll_timer = poll_timer + delta_time

    if poll_timer >= POLL_EVERY then
        poll_timer = 0

        for _, stream in pairs(streams) do
            poll_log_file(stream)
        end
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

    local tabs = {
        { id = "client", title = "Client" },
        { id = "server", title = "Server" },
        { id = "build", title = "Build" },
    }

    for index, tab in ipairs(tabs) do
        local tab_x = viewport.x + 80 + (index - 1) * 72
        local selected = active_tab == tab.id

        if _components.button(tab.title, tab_x, viewport.y + 3, 70, 26, FONT_SIZE,
            selected and active_theme.accent or active_theme.text_primary) then
            active_tab = tab.id
        end

        if selected then
            _draw.set_colour(active_theme.accent)
            _draw.rect(tab_x, viewport.y + TITLE_H - 2, 70, 2)
        end
    end

    local stream = streams[active_tab]

    if viewport.w >= 430 then
        _components.label(stream.log_count .. " lines", viewport.x + 302, viewport.y + 8,
            FONT_SIZE, active_theme.text_tertiary)
    end

    if _components.button("Clear", viewport.x + viewport.w - 70, viewport.y + 3, 60, 24) then
        m.clear()
    end

    local panel_x = viewport.x
    local panel_y = viewport.y + TITLE_H + 1
    local panel_w = viewport.w
    local panel_h = viewport.h - TITLE_H - 1

    if notice and os.clock() < notice_until then
        _components.label(notice, panel_x + PAD, panel_y + PAD, FONT_SIZE, active_theme.accent3)
        panel_y = panel_y + LINE_H + PAD
        panel_h = panel_h - LINE_H - PAD
    end

    if stream.log_count == 0 then
        _components.label("No output", panel_x + PAD, panel_y + PAD, FONT_SIZE, active_theme.text_tertiary)
        return
    end

    if not time_column_w then
        time_column_w = _font.width(FONT_SIZE, "00:00:00")
        tag_column_w = _font.width(FONT_SIZE, "SUCCESS")
    end

    local total_content_h = stream.log_count * LINE_H + PAD * 2
    local max_scroll_y = math.max(0, total_content_h - panel_h)

    if stream.is_stick_bottom then
        stream.scroll_state.y = max_scroll_y
    end

    _components.scroll_begin(stream.scroll_state, panel_x, panel_y, panel_w, panel_h, total_content_h)
    stream.is_stick_bottom = (stream.scroll_state.y >= max_scroll_y - 1)

    local first_idx = math.max(1, math.floor((stream.scroll_state.y - PAD) / LINE_H) + 1)
    local last_idx = math.min(stream.log_count, math.ceil((stream.scroll_state.y + panel_h - PAD) / LINE_H) + 1)

    local time_col_x = panel_x + PAD
    local tag_col_x = time_col_x + time_column_w + GAP
    local text_col_x = tag_col_x + tag_column_w + GAP

    for index = first_idx, last_idx do
        local level_tag = stream.log_levels[index]
        local tag_color = log_colors[level_tag] or active_theme.text_primary
        local line_y = panel_y + PAD + (index - 1) * LINE_H - stream.scroll_state.y

        local location = stream.locations[index]

        if location then
            local width = math.max(0, math.min(
                _font.width(FONT_SIZE, stream.log_texts[index]),
                panel_x + panel_w - 14 - text_col_x
            ))

            local over, clicked = _input.interact(text_col_x, line_y, width, LINE_H)

            if over then
                _draw.set_colour(active_theme.accent)
                _draw.line(text_col_x, line_y + FONT_SIZE, text_col_x + width, line_y + FONT_SIZE)
            end

            if clicked then
                local path, resolve_error = _location.resolve(location, project_path)

                if path and _code.open_at(path, location.line) then
                    notice = nil
                else
                    notice = path and (_code.get_notice() or "Could not open file")
                        or resolve_error or ("File not found: " .. location.path)
                    notice_until = os.clock() + 5
                end
            end
        end

        _components.label(stream.log_times[index], time_col_x, line_y, FONT_SIZE, active_theme.text_tertiary)
        _components.label(TAGS[level_tag] or "", tag_col_x, line_y, FONT_SIZE, tag_color)
        _components.label(stream.log_texts[index], text_col_x, line_y, FONT_SIZE,
            TINT_TEXT[level_tag] and tag_color or active_theme.text_primary)
    end

    _components.scroll_end()
end

function m.status_text()
    if state == "building" then
        return "Building..."
    end

    if state == "success" then
        return message or "Build succeeded"
    end

    if state == "failed" then
        return message or "Build failed"
    end

    return "Ready"
end

return m