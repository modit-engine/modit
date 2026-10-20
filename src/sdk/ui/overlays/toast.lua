--- @module toast
--- @file src/sdk/ui/overlays/toast.lua
--- @description Timed floating toast notification overlay component for alerts, build statuses, and system messages.

--- @section Imports

local _draw = require("src.sdk.client.draw2d")
local _font = require("src.sdk.client.font")
local _theme = require("src.sdk.ui.theme")
local _ui_input = require("src.sdk.ui.input")

--- @section Constants

local TOAST_W = 320
local BASE_TOAST_H = 50
local PAD = 16
local SPACING = 10
local DEFAULT_DURATION = 4.0
local FONT_SIZE = 14
local LINE_HEIGHT = 18

--- @section Initialisation

local toasts = {}
local m = {}

--- @section Helpers

local function wrap_text(text, max_w)
    local font_obj = _font.get(FONT_SIZE)
    local lines = {}
    
    local function measure(str)
        if font_obj then return font_obj:measure(str) end
        return #str * 8
    end

    for paragraph in (text .. "\n"):gmatch("(.-)\n") do
        if paragraph == "" then
            lines[#lines + 1] = ""
        else
            local current_line = ""
            for word in paragraph:gmatch("%S+") do
                local test_line = current_line == "" and word or (current_line .. " " .. word)
                if measure(test_line) <= max_w then
                    current_line = test_line
                else
                    if current_line ~= "" then
                        lines[#lines + 1] = current_line
                        current_line = ""
                    end

                    if measure(word) > max_w then
                        local partial = ""
                        for i = 1, #word do
                            local char = word:sub(i, i)
                            if measure(partial .. char) > max_w then
                                if partial ~= "" then
                                    lines[#lines + 1] = partial
                                end
                                partial = char
                            else
                                partial = partial .. char
                            end
                        end
                        current_line = partial
                    else
                        current_line = word
                    end
                end
            end
            if current_line ~= "" then
                lines[#lines + 1] = current_line
            end
        end
    end
    return lines
end

--- @section Functions

--- Push a new toast notification onto the queue.
--- @param message string Notification text.
--- @param type_or_opts string|table|nil Style type ("info", "success", "error") or options table.
function m.push(message, type_or_opts)
    local opts = type(type_or_opts) == "table" and type_or_opts or { type = type_or_opts or "info" }
    
    table.insert(toasts, {
        message = message,
        type = opts.type or "info", -- "info", "success", "error"
        duration = opts.duration or DEFAULT_DURATION,
        time_left = opts.duration or DEFAULT_DURATION,
    })
end

--- Clear all active toast notifications.
function m.clear()
    toasts = {}
end

--- Update active toast timers based on frame delta time.
--- @param dt number Frame delta time in seconds.
function m.update(dt)
    for i = #toasts, 1, -1 do
        toasts[i].time_left = toasts[i].time_left - dt
        if toasts[i].time_left <= 0 then
            table.remove(toasts, i)
        end
    end
end

--- Draw active toast notifications stacked in the bottom-right corner of the screen.
--- @param w number Available screen width.
--- @param h number Available screen height.
function m.draw(w, h)
    if #toasts == 0 then return end
    local theme = _theme.get()
    local font_obj = _font.get(FONT_SIZE)

    local current_y = h - PAD

    for i = #toasts, 1, -1 do
        local toast = toasts[i]
        local max_text_w = TOAST_W - (PAD * 2)
        local lines = wrap_text(toast.message, max_text_w)
        local toast_h = math.max(BASE_TOAST_H, (#lines * LINE_HEIGHT) + (PAD * 1.2))

        current_y = current_y - toast_h
        local current_x = w - TOAST_W - PAD

        -- Background panel
        _draw.set_colour(theme.bg_main)
        _draw.rect(current_x, current_y, TOAST_W, toast_h)

        -- Border
        _draw.set_colour(theme.border_dark.color)
        _draw.rect_lines(current_x, current_y, TOAST_W, toast_h, 1)

        -- Type indicator strip on the left edge
        local accent_color = theme.accent
        if toast.type == "success" then
            accent_color = { 76, 175, 80 }
        elseif toast.type == "error" then
            accent_color = theme.accent3 or { 244, 67, 54 }
        end
        _draw.set_colour(accent_color[1], accent_color[2], accent_color[3])
        _draw.rect(current_x, current_y, 3, toast_h)

        -- Word wrap
        _draw.set_colour(theme.text_primary)
        local text_y = current_y + math.floor((toast_h - (#lines * LINE_HEIGHT)) / 2)
        for line_idx, line in ipairs(lines) do
            local ly = text_y + (line_idx - 1) * LINE_HEIGHT
            if font_obj then
                font_obj:draw(line, current_x + 16, ly)
            else
                _ui_input.text(line, current_x + 16, ly, FONT_SIZE)
            end
        end

        current_y = current_y - SPACING
    end
end

return m