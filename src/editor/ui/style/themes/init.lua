--- @module themes
--- @description Discovers editor themes once at startup. Restart to pick up file changes.

local _theme = require("src.sdk.ui.theme")
local _default = require("src.sdk.ui.default_theme")
local _fs = require("src.engine.backend.platform." .. require("ffi").os:lower() .. ".filesystem")

local DIRECTORY = "src/editor/ui/style/themes"
local m = { keys = { "default" }, labels = { "Default" } }

-- Validate supplied values against the default palette and fill missing values,
-- including nested syntax/console colours. Never modify the default theme.
local function complete(values, defaults)
    assert(type(values) == "table", "theme must return a table")
    local result = {}
    local is_colour = (#defaults == 3 or #defaults == 4) and type(defaults[3]) == "number"
        and (defaults[4] == nil or type(defaults[4]) == "number")
    for key, fallback in pairs(defaults) do
        local value = values[key]
        if value == nil then value = fallback end
        assert(type(value) == type(fallback), "invalid theme field: " .. tostring(key))
        if type(fallback) == "table" then
            result[key] = complete(value, fallback)
        else
            if type(value) == "number" then
                assert(value == value and math.abs(value) < math.huge, "invalid number: " .. tostring(key))
                assert(not is_colour or (value >= 0 and value <= 255), "invalid colour: " .. tostring(key))
            elseif type(value) == "string" then
                assert(value ~= "", "empty theme field: " .. tostring(key))
            end
            result[key] = value
        end
    end
    return result
end

local function load_theme(path)
    local values = assert(loadfile(path))()
    assert(type(values) == "table", "theme must return a table")
    local has_palette = false
    for key in pairs(values) do
        if _default[key] ~= nil then has_palette = true end
    end
    assert(has_palette, "no recognised theme fields")
    assert(values.name == nil or (type(values.name) == "string" and values.name:match("%S")),
        "theme name must be non-empty text")
    local palette = complete(values, _default)
    local font = assert(io.open(palette.font, "rb"), "theme font does not exist")
    font:close()
    return palette, values.name
end

for _, entry in ipairs(_fs.list(DIRECTORY)) do
    local key = entry.name:match("^(.-)%.lua$")
    if not entry.dir and key and key ~= "init" and key ~= "default" then
        local ok, palette, name = pcall(load_theme, DIRECTORY .. "/" .. entry.name)
        if ok then
            _theme.register(key, palette)
            m.keys[#m.keys + 1] = key
            m.labels[#m.labels + 1] = name or key:gsub("[_%-]", " "):gsub("%f[%a]%l", string.upper)
        else
            print("Skipping editor theme " .. entry.name .. ": " .. tostring(palette))
        end
    end
end

return m
