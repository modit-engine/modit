--- @module filesystem
--- @file src/sdk/shared/filesystem.lua
--- @description Saves and loads Lua data tables inside the project's save folder.

--- @default_access game

--- @section Imports

local _fs = require("src.engine.backend.platform." .. require("ffi").os:lower() .. ".filesystem")

--- @section Constants

local NOT_READY = "filesystem not initialised, call filesystem.init(game_dir) first"

local LUA_KEYWORDS = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,
    ["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["goto"] = true,
    ["if"] = true, ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true,
    ["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true, ["while"] = true,
}

--- @section Initialisation

local m = {}

local base_dir = nil -- "<save root>/", set by m.init
local bundle = nil   -- MODIT_BUNDLE when running from a packed exe

local BUNDLE_SAVE_PREFIX = "game/save/"

--- @section Helpers

local function safe_path(path)
    return type(path) == "string" and path ~= "" and not path:find("..", 1, true) and not path:find("[:\\]") and path:sub(1, 1) ~= "/"
end

local function ensure_dir(relative_dir)
    local root = base_dir:sub(1, -2)
    if not _fs.ensure_dir(root) then
        return false, "could not create save folder: " .. root
    end

    local current = root
    for part in relative_dir:gmatch("[^/]+") do
        current = current .. "/" .. part
        if not _fs.is_dir(current) and not _fs.create_dir(current) then
            return false, "could not create folder: " .. current
        end
    end
    return true
end

-- Returns the embedded copy of a save file, or nil
local function bundle_read(path)
    if not bundle then return nil end
    local key = BUNDLE_SAVE_PREFIX .. path
    if not bundle.has(key) then return nil end
    local reader = bundle.read or bundle.get -- <-- match your prelude's API
    return reader and reader(key) or nil
end

-- Disk first (player progress), then the embedded default
local function read_source(path)
    local file = io.open(base_dir .. path, "rb")
    if file then
        local content = file:read("*a")
        file:close()
        return content
    end
    return bundle_read(path)
end

local function key_order(a, b)
    local type_a, type_b = type(a), type(b)
    if type_a ~= type_b then return type_a < type_b end
    if type_a == "number" or type_a == "string" then return a < b end
    return tostring(a) < tostring(b)
end

local function format_number(value)
    if value ~= value or value == math.huge or value == -math.huge then
        error("cannot save nan or infinite numbers", 0)
    end
    if value == math.floor(value) and math.abs(value) < 1e15 then
        return ("%d"):format(value)
    end
    return ("%.17g"):format(value)
end

local function format_key(key)
    local kind = type(key)
    if kind == "string" then
        if key:match("^[%a_][%w_]*$") and not LUA_KEYWORDS[key] then return key end
        return ("[%q]"):format(key)
    elseif kind == "number" then
        return "[" .. format_number(key) .. "]"
    elseif kind == "boolean" then
        return "[" .. tostring(key) .. "]"
    end
    error("cannot save a table with a " .. kind .. " key", 0)
end

local function serialize_value(value, indent, seen)
    local kind = type(value)

    if kind == "number" then return format_number(value) end
    if kind == "string" then return ("%q"):format(value) end
    if kind == "boolean" then return tostring(value) end

    if kind == "table" then
        if seen[value] then error("cannot save a table that contains itself", 0) end

        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        if #keys == 0 then return "{}" end
        table.sort(keys, key_order)

        seen[value] = true
        local inner = indent .. "    "
        local lines = {}
        for _, key in ipairs(keys) do
            lines[#lines + 1] = inner .. format_key(key) .. " = " .. serialize_value(value[key], inner, seen) .. ","
        end
        seen[value] = nil

        return "{\n" .. table.concat(lines, "\n") .. "\n" .. indent .. "}"
    end

    error("cannot save a " .. kind .. " value", 0)
end

--- @section Functions

--- Sets the save folder. Call once at boot
--- @param game_dir string Game folder (dev mode saves go in <game_dir>/save/)
--- @param bundle_api table|nil MODIT_BUNDLE when running from a packed exe
function m.init(game_dir, bundle_api)
    bundle = bundle_api
    if bundle then
        local exe_dir = _fs.exe_dir() or "."
        base_dir = exe_dir .. "/save/"
    else
        base_dir = (game_dir:gsub("[/\\]$", "")) .. "/save/"
    end
end

--- Serializes a table to Lua source (sorted keys, so output is stable)
--- @param tbl table Table to serialize
--- @return string source
function m.serialize(tbl)
    return serialize_value(tbl, "", {})
end

--- Checks if a file or folder exists in the save folder
--- @param path string Path relative to the save folder
--- @return boolean exists
function m.exists(path)
    if not base_dir or not safe_path(path) then return false end

    local full_path = base_dir .. path
    if _fs.is_dir(full_path) then return true end

    local file = io.open(full_path, "rb")
    if file then
        file:close()
        return true
    end
    return bundle ~= nil and bundle.has(BUNDLE_SAVE_PREFIX .. path)
end

--- Creates a folder inside the save folder
--- @param path string Folder path relative to the save folder
--- @return boolean ok
--- @return string|nil error
function m.create_directory(path)
    if not base_dir then return false, NOT_READY end
    if not safe_path(path) then return false, "invalid save path: " .. tostring(path) end
    return ensure_dir(path)
end

--- Saves a table to a file in the save folder
--- @param path string Path relative to the save folder (e.g. "player.lua" or "profiles/one.lua")
--- @param data table Data to save
--- @return boolean ok
--- @return string|nil error
function m.save(path, data)
    if not base_dir then return false, NOT_READY end
    if not safe_path(path) then return false, "invalid save path: " .. tostring(path) end
    if type(data) ~= "table" then return false, "data must be a table" end

    local serialised, text = pcall(serialize_value, data, "", {})
    if not serialised then return false, text end

    local ready, dir_err = ensure_dir(path:match("^(.*)/[^/]*$") or "")
    if not ready then return false, dir_err end

    -- write_file writes a .tmp then MoveFileEx(REPLACE_EXISTING): atomic overwrite
    local ok, err = _fs.write_file(base_dir .. path, "return " .. text)
    if not ok then return false, "failed to save file: " .. tostring(err) end
    return true
end

--- Loads a table from a file in the save folder
--- @param path string Path relative to the save folder
--- @return table|nil data
--- @return string|nil error
function m.load(path)
    if not base_dir then return nil, NOT_READY end
    if not safe_path(path) then return nil, "invalid save path: " .. tostring(path) end

    local content = read_source(path)
    if not content then return nil, "file not found: " .. path end

    if content:byte(1) == 27 then return nil, "bytecode is not allowed" end

    local chunk, parse_err = loadstring(content, "@" .. path)
    if not chunk then return nil, "failed to parse save file: " .. tostring(parse_err) end

    setfenv(chunk, {})

    local ok, result = pcall(chunk)
    if not ok then return nil, "failed to load save file: " .. tostring(result) end
    if type(result) ~= "table" then return nil, "save file must return a table" end

    return result
end

--- Deletes a file in the save folder
--- @param path string Path relative to the save folder
--- @return boolean ok
--- @return string|nil error
function m.delete(path)
    if not base_dir then return false, NOT_READY end
    if not safe_path(path) then return false, "invalid save path: " .. tostring(path) end

    local ok, err = os.remove(base_dir .. path)
    if not ok then return false, "failed to delete file: " .. tostring(err) end
    return true
end

return m