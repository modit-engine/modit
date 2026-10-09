--- @module settings
--- @file src/editor/core/settings.lua
--- @description Persistence manager for editor user preferences, active theme, recent projects, and layout panel dimensions.

--- @section Imports

local _fs = require("src.engine.backend").filesystem

--- @section Constants

local DIR = "src/editor/data"
local PATH = DIR .. "/editor_settings.lua"
local MAX_RECENT = 10
local DEFAULT_THEME = "default"

--- @section Initialisation

local m = { theme = DEFAULT_THEME, recent = {}, sizes = {}, minimap = true }

--- @section Functions

--- Reads editor settings from disk and populates theme, recent projects, and layout sizes in a sandboxed environment
function m.load()
    m.theme = DEFAULT_THEME
    m.minimap = true
    m.recent, m.sizes = {}, {}

    local text = _fs.read_file(PATH)
    if not text then return end

    local chunk = loadstring(text, "=editor_settings")
    if not chunk then return end
    setfenv(chunk, {})

    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then return end

    if type(data.theme) == "string" then
        m.theme = data.theme
    end
    if type(data.minimap) == "boolean" then m.minimap = data.minimap end

    if type(data.recent) == "table" then
        for _, p in ipairs(data.recent) do
            if type(p) == "string" then m.recent[#m.recent + 1] = p end
        end
    end

    if type(data.sizes) == "table" then
        for k, v in pairs(data.sizes) do
            if type(k) == "string" and type(v) == "number" then m.sizes[k] = v end
        end
    end
end

--- Moves a project path to the top of the recent list and enforces maximum list bounds
--- @param path string Disk path to target project directory
function m.add_recent(path)
    for i = #m.recent, 1, -1 do
        if m.recent[i]:lower() == path:lower() then table.remove(m.recent, i) end
    end
    table.insert(m.recent, 1, path)
    while #m.recent > MAX_RECENT do table.remove(m.recent) end
end

--- Updates the active editor theme name
--- @param name string Target theme identifier
function m.set_theme(name)
    if type(name) == "string" and name ~= "" then
        m.theme = name
    end
end

--- Serializes and saves current theme, recent projects, and layout dimensions to editor_settings.lua
function m.save()
    local out = { 
        "return {\n",
        ("    theme = %q,\n"):format(m.theme or DEFAULT_THEME),
        ("    minimap = %s,\n"):format(tostring(m.minimap)),
        "    recent = {\n"
    }

    for _, p in ipairs(m.recent) do
        out[#out + 1] = ("        %q,\n"):format(p)
    end

    out[#out + 1] = "    },\n    sizes = {\n"
    for k, v in pairs(m.sizes) do
        out[#out + 1] = ("        %s = %d,\n"):format(k, math.floor(v))
    end
    out[#out + 1] = "    },\n}\n"

    _fs.ensure_dir(DIR)

    local ok, err = _fs.write_file(PATH, table.concat(out))
    if not ok then
        print("Could not save settings: " .. tostring(err))
    end
end

return m
