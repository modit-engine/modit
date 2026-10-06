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

local m = {
    sink = nil,
}

local min_level_index = LEVEL_INDEX.debug
local enable_color = true
local cached_palette = nil

--- @section Helper Functions

--- Generates or returns cached ANSI terminal color palette mapping
--- @return table palette Color code lookup table
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

--- Recursively converts table structure into formatted key-value string
--- @param t table Target table to format
--- @param depth number|nil Recursion depth tracker (max 3)
--- @param seen table|nil Visited table reference map for cycle detection
--- @return string formatted Formatted table string representation
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

--- Serializes arbitrary input value to string
--- @param value any Value to serialize
--- @return string serialized Serialized string representation
local function serialize(value)
    return type(value) == "table" and table_to_string(value) or tostring(value)
end

--- Sets minimum log level threshold for output filtering
--- @param level string Target minimum log level ("debug", "info", "success", "warn", "error", "fatal")
function m.set_level(level)
    assert(LEVEL_INDEX[level], "log.set_level: invalid level '" .. tostring(level) .. "'")
    min_level_index = LEVEL_INDEX[level]
end

--- Enables or disables ANSI terminal color formatting
--- @param enabled boolean True to enable color formatting, false to disable
function m.use_colour(enabled)
    enable_color = enabled ~= false
    cached_palette = nil
end

--- Retrieves history of recorded log entries
--- @return table history Array of recorded log entries `{ level = string, text = string }`
function m.get_history()
    return HISTORY_BUFFER
end

--- Writes formatted log message to stdout and records entry
--- @param level string Severity level ("debug", "info", "success", "warn", "error", "fatal")
--- @param msg any Primary message payload
--- @param data any|nil Optional metadata payload attached to message
--- @return boolean logged True if log message met threshold and was printed
function m.print(level, msg, data)
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

    local palette = get_palette()
    io.write(("%s[%s] [%s]: %s%s\n"):format(
        palette[level],
        os.date("%Y-%m-%d %H:%M:%S"),
        level:upper(),
        text,
        palette.reset
    ))

    HISTORY_BUFFER[#HISTORY_BUFFER + 1] = { level = level, text = text }
    if #HISTORY_BUFFER > HISTORY_MAX_CAPACITY then
        table.remove(HISTORY_BUFFER, 1)
    end

    if m.sink then
        m.sink(level, text)
    end

    if level == "fatal" then
        os.exit(1)
    end

    return true
end

--- @section Shorthand Methods

for _, level in ipairs(LOG_LEVELS) do
    m[level] = function(msg, data)
        return m.print(level, msg, data)
    end
end

return m