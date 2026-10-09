--- @module console
--- @file projects/test_project/game/client/ui/console/init.lua
--- @description F8 console overlay: log scrollback and a command line.

--- @section Imports

local _engine = require("src.engine")
local _ui = require("src.engine.ui")
local _log = require("src.engine.core.log")
local _hooks = require("src.engine.modules.hooks")
local _commands = require("src.engine.modules.commands")

--- @section Constants

local LINE_H, FONT_SIZE, PAD, GAP = 18, 16, 8, 10
local INPUT_H = 30
local MAX_LINES = 1000
local HEIGHT_FRACTION = 0.45
local TAGS = { debug = "DEBUG", info = "INFO", success = "SUCCESS", warn = "WARN", error = "ERROR", fatal = "FATAL" }
local TINT_TEXT = { warn = true, error = true, fatal = true }

--- @section Initialisation

local m = {}

local lines, count = {}, 0
local is_open = false
local scroll_state = { y = 0 }
local stick_bottom = true
local input_state = { text = "", max = 256 }
local time_w, tag_w = nil, nil

--- @section Helpers

local function add(level, time, text)
    for segment in (text .. "\n"):gmatch("(.-)\n") do
        if segment ~= "" then
            count = count + 1
            lines[count] = { level = level, time = time, text = (segment:gsub("\t", "    ")) }
            time = ""
        end
    end
    while count > MAX_LINES do
        table.remove(lines, 1)
        count = count - 1
    end
end

--- @section Functions

function m.init()
    for _, entry in ipairs(_log.get_history()) do add(entry.level, "", entry.text) end

    local previous_sink = _log.sink
    _log.sink = function(level, text)
        add(level, os.date("%H:%M:%S"), text)
        if previous_sink then previous_sink(level, text) end
    end

    _commands.register("clear", function()
        lines, count = {}, 0
    end, "Clear the console")
end

--- @return boolean open
function m.is_open() return is_open end

function m.toggle()
    is_open = not is_open
    if is_open then
        _ui.input.set_focus(input_state)
        stick_bottom = true
    else
        _ui.input.blur()
    end
    _hooks.fire("console_toggled", is_open)
end

function m.draw()
    if not is_open then return end

    local theme = _ui.theme.get()
    local window_w, window_h = _engine.window.get_size()
    local panel_h = math.floor(window_h * HEIGHT_FRACTION)
    local log_h = panel_h - INPUT_H - PAD * 2
    local log_colours = theme.console_logs or {}

    _engine.draw.set_colour(theme.bg_panel)
    _engine.draw.rect(0, 0, window_w, panel_h)
    _engine.draw.set_colour(theme.border_dark.color)
    _engine.draw.line(0, panel_h, window_w, panel_h)

    if not time_w then
        time_w = _engine.font.width(FONT_SIZE, "00:00:00")
        tag_w = _engine.font.width(FONT_SIZE, "SUCCESS")
    end

    local content_h = count * LINE_H + PAD * 2
    local max_scroll = math.max(0, content_h - log_h)
    if stick_bottom then scroll_state.y = max_scroll end

    _ui.components.scroll_begin(scroll_state, 0, 0, window_w, log_h, content_h)
    stick_bottom = scroll_state.y >= max_scroll - 1

    local first = math.max(1, math.floor((scroll_state.y - PAD) / LINE_H) + 1)
    local last = math.min(count, math.ceil((scroll_state.y + log_h - PAD) / LINE_H) + 1)
    local time_x = PAD
    local tag_x = time_x + time_w + GAP
    local text_x = tag_x + tag_w + GAP

    for index = first, last do
        local entry = lines[index]
        local colour = log_colours[entry.level] or theme.text_primary
        local y = PAD + (index - 1) * LINE_H - scroll_state.y
        _ui.components.label(entry.time, time_x, y, FONT_SIZE, theme.text_tertiary)
        _ui.components.label(entry.time ~= "" and (TAGS[entry.level] or "") or "", tag_x, y, FONT_SIZE, colour)
        _ui.components.label(entry.text, text_x, y, FONT_SIZE, TINT_TEXT[entry.level] and colour or theme.text_primary)
    end
    _ui.components.scroll_end()

    local submitted = _ui.components.textfield(input_state, PAD, panel_h - INPUT_H - PAD,
        window_w - PAD * 2, INPUT_H, ".", "command (try help)")
    if submitted then
        local line = input_state.text
        input_state.text = ""
        if line:find("%S") then
            _log.print("info", "> " .. line)
            _commands.run(line)
            stick_bottom = true
        end
        _ui.input.set_focus(input_state)
    end
end

return m