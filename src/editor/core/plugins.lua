--- @module plugins
--- @file src/editor/core/plugins.lua
--- @description Discovers, loads, enables/disables, installs and removes editor plugins.

--- @section IMports

local _fs = require("src.engine.backend.platform." .. require("ffi").os:lower() .. ".filesystem")
local _settings = require("src.editor.core.settings")

--- @section Constants

local DIR = "plugins"
local MANIFEST = "plugin.modit"

--- @section Initialisation

local m = { dir = DIR }
local loaded_plugins = {}
local load_errors = {}

--- @section Helpers

local function safe_name(name)
    return type(name) == "string" and name ~= "" and name ~= "." and name ~= ".."
        and not name:find("[/\\:]")
end

local function normalise(path)
    return (path:gsub("\\", "/"):gsub("/+$", ""))
end

local function parse_modit_config(path)
    local source = _fs.read_file(path)
    if not source then return nil, "Missing " .. MANIFEST end

    local data = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("\r$", ""):match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            local key, value = line:match("^([%w_%-]+)%s*=%s*(.-)%s*$")
            if key then data[key] = value end
        end
    end

    if data.engine ~= "modit" then
        return nil, "Not a valid Modit plugin: expected engine=modit"
    end
    if type(data.name) ~= "string" or data.name == "" then
        return nil, "Invalid plugin name"
    end
    if type(data.entry) ~= "string" or data.entry == "" then
        return nil, "Missing plugin entry script"
    end
    return data
end

local function unload_one(name)
    local plugin = loaded_plugins[name]
    if not plugin then return end
    if plugin.mod and plugin.mod.unload then pcall(plugin.mod.unload) end
    loaded_plugins[name] = nil
end

local function load_one(name, path, config)
    unload_one(name)
    load_errors[name] = nil

    local function fail(msg)
        load_errors[name] = msg
        print("[Plugins] " .. name .. ": " .. msg)
        return false, msg
    end

    local chunk, load_err = loadfile(path .. "/" .. config.entry)
    if not chunk then return fail("Could not load entry script: " .. tostring(load_err)) end

    local env = setmetatable({ modit = require("src.engine") }, { __index = _G })
    setfenv(chunk, env)

    local ok, plugin_mod = pcall(chunk)
    if not ok then return fail("Entry script error: " .. tostring(plugin_mod)) end
    if type(plugin_mod) ~= "table" or not plugin_mod.load then
        return fail("Invalid plugin module structure (needs a load function)")
    end

    local load_ok, run_err = pcall(plugin_mod.load)
    if not load_ok then return fail("load() failed: " .. tostring(run_err)) end

    loaded_plugins[name] = { mod = plugin_mod, config = config, path = path }
    print("[Plugins] Loaded plugin: " .. (config.label or name))
    return true
end

--- @section Queries

--- Whether the plugin is switched on in editor settings
--- @param name string Plugin folder name
--- @return boolean
function m.is_enabled(name)
    return not (_settings.disabled_plugins and _settings.disabled_plugins[name])
end

--- Returns a table of currently loaded plugins.
function m.get_loaded()
    return loaded_plugins
end

--- Lists every plugin folder (loaded, disabled or broken), sorted by name.
--- @return table entries { name, path, config, error, enabled, loaded }
function m.list()
    local out = {}
    if not _fs.is_dir(DIR) then return out end

    local names = _fs.list_dirs(DIR)
    table.sort(names, function(a, b) return a:lower() < b:lower() end)

    for _, name in ipairs(names) do
        local path = DIR .. "/" .. name
        if _fs.read_file(path .. "/" .. MANIFEST) then
            local config, err = parse_modit_config(path .. "/" .. MANIFEST)
            out[#out + 1] = {
                name = name,
                path = path,
                config = config,
                error = err or load_errors[name],
                enabled = m.is_enabled(name),
                loaded = loaded_plugins[name] ~= nil,
            }
        end
    end
    return out
end

--- @section Lifecycle

--- Scans the plugins directory and loads every enabled, valid plugin.
function m.load_all()
    m.unload_all()
    for _, entry in ipairs(m.list()) do
        if entry.config and entry.enabled then
            load_one(entry.name, entry.path, entry.config)
        end
    end
end

--- Unloads all active plugins safely.
function m.unload_all()
    for name in pairs(loaded_plugins) do unload_one(name) end
    loaded_plugins = {}
end

--- Turns a plugin on or off and persists the choice.
--- @param name string Plugin folder name
--- @param enabled boolean
--- @return boolean ok
--- @return string|nil err
function m.set_enabled(name, enabled)
    if not safe_name(name) then return false, "Invalid plugin name" end

    _settings.disabled_plugins = _settings.disabled_plugins or {}
    _settings.disabled_plugins[name] = (not enabled) or nil
    _settings.save()

    if not enabled then
        unload_one(name)
        load_errors[name] = nil
        return true
    end

    local path = DIR .. "/" .. name
    local config, err = parse_modit_config(path .. "/" .. MANIFEST)
    if not config then return false, err end
    return load_one(name, path, config)
end

--- Deletes a plugin from the internal plugins folder.
--- @param name string Plugin folder name
--- @return boolean ok
--- @return string|nil err
function m.remove(name)
    if not safe_name(name) then return false, "Invalid plugin name" end

    local path = DIR .. "/" .. name
    if not _fs.is_dir(path) then return false, "Plugin folder does not exist" end

    unload_one(name)
    load_errors[name] = nil

    local ok, err = _fs.remove_dir(path)
    if not ok then return false, err or "Could not delete the plugin folder" end

    if _settings.disabled_plugins and _settings.disabled_plugins[name] then
        _settings.disabled_plugins[name] = nil
        _settings.save()
    end
    return true
end

--- Installs a plugin from any folder on disk by copying it into plugins/.
--- @param source string Folder containing plugin.modit
--- @return string|nil name Installed folder name
--- @return string|nil err
function m.install(source)
    if type(source) ~= "string" or not source:find("%S") then
        return nil, "Select a plugin folder"
    end
    source = normalise(source)

    local config, err = parse_modit_config(source .. "/" .. MANIFEST)
    if not config then return nil, err end

    local name = source:match("([^/]+)$")
    if not safe_name(name) then return nil, "Invalid plugin folder name" end

    _fs.ensure_dir(DIR)
    for _, entry in ipairs(_fs.list(DIR)) do
        if entry.name:lower() == name:lower() then
            return nil, "A plugin named '" .. name .. "' is already installed"
        end
    end

    local ok, import = pcall(require, "src.editor.core.import_files")
    if not ok then return nil, "File import is unavailable" end

    local copied, copy_err = import.copy({ source }, DIR, DIR)
    if not copied or copied < 1 then
        if _fs.is_dir(DIR .. "/" .. name) then _fs.remove_dir(DIR .. "/" .. name) end
        return nil, copy_err or "Could not copy the plugin"
    end

    if _settings.disabled_plugins then _settings.disabled_plugins[name] = nil end
    _settings.save()

    local loaded, load_err = load_one(name, DIR .. "/" .. name, config)
    if not loaded then return name, load_err end
    return name
end

return m