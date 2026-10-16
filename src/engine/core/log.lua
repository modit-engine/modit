--- @module log
--- @file src/engine/core/log.lua
--- @description Color-coded logging subsystem with terminal ANSI formatting, level filtering, history ring buffer, and custom sink callbacks.

--- @section Constants & State

local LOG_LEVELS = { "debug", "info", "success", "warn", "error", "fatal" }
local LEVEL_INDEX = {}
for i, level in ipairs(LOG_LEVELS) do
    LEVEL_INDEX[level] = i
end

local HISTORY_BUFFER = {}
local HISTORY_MAX_CAPACITY = 100

--- @section Initialization

local m = { sink = nil }

local min_level_index = LEVEL_INDEX.debug
local enable_color = true
local cached_palette = nil

--- @section Helper Functions

local function get_palette()
    if cached_palette then
        return cached_palette
    end

    if enable_color then
        cached_palette = {
            debug = "\27[35m",
            info = "\27[36m",
            success = "\27[32m",
            warn = "\27[33m",
            error = "\27[31m",
            fatal = "\27[1;31m",
            reset = "\27[0m",
        }
    else
        cached_palette = setmetatable({}, {
            __index = function()
                return ""
            end,
        })
    end

    return cached_palette
end

local function table_to_string(t, depth, seen)
    depth = depth or 0
    if depth > 3 then
        return "{…}"
    end

    seen = seen or {}
    if seen[t] then
        return "{cycle}"
    end
    seen[t] = true

    local entries = {}
    for k, v in pairs(t) do
        local formatted_val
        if type(v) == "table" then
            formatted_val = table_to_string(v, depth + 1, seen)
        else
            formatted_val = type(v) == "string" and ('"' .. v .. '"') or tostring(v)
        end
        entries[#entries + 1] = tostring(k) .. "=" .. formatted_val
    end

    return "{" .. table.concat(entries, ", ") .. "}"
end

local function serialize(value)
    return type(value) == "table" and table_to_string(value) or tostring(value)
end

local function print_log(level, msg, data)
    local level_idx = LEVEL_INDEX[level]
    if not level_idx then
        level, level_idx = "info", LEVEL_INDEX.info
    end

    if level_idx < min_level_index then
        return false
    end

    local text = tostring(msg)
    if data ~= nil then
        text = text .. " " .. serialize(data)
    end

    local line = ("[%s] [%s]: %s"):format(os.date("%H:%M:%S"), level:upper(), text)

    local palette = get_palette()
    io.write(palette[level], line, palette.reset, "\n")

    HISTORY_BUFFER[#HISTORY_BUFFER + 1] = { level = level, text = text }
    if #HISTORY_BUFFER > HISTORY_MAX_CAPACITY then
        table.remove(HISTORY_BUFFER, 1)
    end

    if m.sink then
        m.sink(level, text, line)
    end

    if level == "fatal" then
        os.exit(1)
    end

    return true
end

--- @section Functions

--- @access mod
function m.get_history()
    return HISTORY_BUFFER
end

--- @access mod
function m.debug(msg, data)
    return print_log("debug", msg, data)
end

--- @access mod
function m.info(msg, data)
    return print_log("info", msg, data)
end

--- @access mod
function m.success(msg, data)
    return print_log("success", msg, data)
end

--- @access mod
function m.warn(msg, data)
    return print_log("warn", msg, data)
end

--- @access mod
function m.error(msg, data)
    return print_log("error", msg, data)
end

--- @access mod
function m.print(level, msg, data)
    return print_log(level, msg, data)
end

--- @access game
function m.fatal(msg, data)
    m.print("fatal", msg, data)
    error(msg or "Fatal error triggered", 2)
end

return m