--- @module mod_manager
--- @file src/engine/core/internal/mod_manager.lua
--- @description Mod loader: finds, sandboxes, starts and stops mods.

--- @section Imports

local _log = require("src.engine.core.log")
local _fs = require("src.engine.backend.platform." .. require("ffi").os:lower() .. ".filesystem")
local _sandbox = require("src.engine.core.internal.sandbox")
local _commands = require("src.sdk.shared.command")
local _exports = require("src.sdk.shared.exports")

--- @section Constants

local API_VERSION = "1.0"
local REALMS = { client = true, server = true }
local PATH_LISTS = { "shared", "client", "server", "assets" }
local RESERVED = {
    client = { update = true, draw = true, hud = true, console_toggled = true },
    server = { update = true },
}
local POLL_INTERVAL = 0.25

--- @section Initialisation

local m = {
    root = nil,
    config = {},
}

local last_poll = 0
local pending = {} -- name -> true once a change has been seen (acts as the debounce)

function m.init(config, game_dir)
    m.config = config or {}
    local project_dir = game_dir:gsub("[/\\]$", ""):match("^(.*)[/\\][^/\\]+$")
    m.root = (project_dir or ".") .. "/mods"
end

local mods = {} -- name -> { name, manifest, state, realm, env, cache, loading, stop_handlers }
local snapshots = {} -- path -> source as last loaded

--- @section Helpers

local function sync_public_registry()
    local ok_sdk, _sdk = pcall(require, "src.sdk.shared.mods")
    if ok_sdk and _sdk and _sdk.set_registry then
        local registry = {}
        for name, mod in pairs(mods) do
            registry[name] = {
                version = mod.manifest and mod.manifest.metadata and mod.manifest.metadata.version or "0.0.0",
                author = mod.manifest and mod.manifest.metadata and mod.manifest.metadata.author or "Unknown",
                realm = mod.realm,
                state = mod.state
            }
        end
        _sdk.set_registry(registry)
    end
end

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

local function read_file(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function safe_path(path)
    return type(path) == "string" and path ~= "" and not path:find("..", 1, true) and not path:find("[:\\]") and path:sub(1, 1) ~= "/"
end

local function make_manifest_env()
    local manifest = {
        sdk_version = nil,
        metadata = nil,
        depends = {},
        provides = {},
        assets = {},
        shared = {},
        client = {},
        server = {},
    }

    local declared = {}
    local env = {}

    local function declare_once(name, value)
        if declared[name] then
            error(name .. " declared more than once", 2)
        end
        declared[name] = true
        manifest[name] = value
    end

    env.sdk_version = function(value)
        declare_once("sdk_version", value)
    end

    env.metadata = function(value)
        declare_once("metadata", value)
    end

    env.depends = function(value)
        declare_once("depends", value)
    end

    env.provides = function(value)
        declare_once("provides", value)
    end

    env.assets = function(value)
        declare_once("assets", value)
    end

    env.shared = function(value)
        declare_once("shared", value)
    end

    env.client = function(value)
        declare_once("client", value)
    end

    env.server = function(value)
        declare_once("server", value)
    end

    return env, manifest
end

local function load_manifest(folder_name)
    local path = m.root .. "/" .. folder_name .. "/manifest.lua"
    local source = read_file(path)
    if not source then return nil, "no manifest.lua" end
    if source:byte(1) == 27 then return nil, "bytecode is not allowed" end
    snapshots[path] = source

    local chunk, err = loadstring(source, "@" .. path)
    if not chunk then return nil, err end

    local env, manifest = make_manifest_env()
    setfenv(chunk, env)

    local ok, result = pcall(chunk)
    if not ok then return nil, tostring(result) end
    if result ~= nil then
        return nil, "manifest must use declaration functions and must not return a value"
    end

    if type(manifest.sdk_version) ~= "string" then
        return nil, "missing or invalid sdk_version"
    end

    if manifest.sdk_version ~= API_VERSION then
        return nil, "unsupported sdk_version " .. tostring(manifest.sdk_version)
            .. " (expected " .. API_VERSION .. ")"
    end

    if type(manifest.metadata) ~= "table" then
        return nil, "missing or invalid metadata section"
    end

    local metadata = manifest.metadata
    if type(metadata.name) ~= "string" or metadata.name == "" then
        return nil, "metadata.name must be a non-empty string"
    end
    if type(metadata.version) ~= "string" or metadata.version == "" then
        return nil, "metadata.version must be a non-empty string"
    end

    for _, section_name in ipairs({ "depends", "provides" }) do
        local list = manifest[section_name]
        if type(list) ~= "table" then
            return nil, section_name .. " must be a list"
        end
        for index, item in ipairs(list) do
            if type(item) ~= "string" or item == "" then
                return nil, section_name .. "[" .. index .. "] must be a non-empty string"
            end
        end
    end

    for _, list_name in ipairs(PATH_LISTS) do
        local list = manifest[list_name]
        if type(list) ~= "table" then
            return nil, list_name .. " must be a list"
        end

        for _, file in ipairs(list) do
            if not safe_path(file) then
                return nil, "bad path in " .. list_name .. ": " .. tostring(file)
            end
        end
    end

    return manifest
end

local function load_file(mod, relative_path)
    if mod.cache[relative_path] ~= nil then return mod.cache[relative_path] end
    if mod.loading[relative_path] then error("circular require: " .. relative_path, 0) end

    local full_path = m.root .. "/" .. mod.name .. "/" .. relative_path
    local source = read_file(full_path)
    if not source then error("file not found: " .. relative_path, 0) end
    if source:byte(1) == 27 then error("bytecode is not allowed: " .. relative_path, 0) end
    snapshots[full_path] = source

    local chunk, err = loadstring(source, "@" .. full_path)
    if not chunk then error(err, 0) end
    setfenv(chunk, mod.env)

    mod.loading[relative_path] = true
    local result = chunk()
    mod.loading[relative_path] = nil

    if result == nil then result = true end
    mod.cache[relative_path] = result
    return result
end

local function require_in(mod, module_name)
    if type(module_name) ~= "string" or not module_name:match("^[%w_%.]+$")
        or module_name:find("..", 1, true) or module_name:sub(1, 1) == "." then
        error("invalid module name: " .. tostring(module_name), 2)
    end
    return load_file(mod, (module_name:gsub("%.", "/")) .. ".lua")
end

local function make_env(mod)
    local env = {
        math = copy(math), string = copy(string), table = copy(table),
        ipairs = ipairs, pairs = pairs, next = next, select = select, type = type,
        tostring = tostring, tonumber = tonumber, pcall = pcall, xpcall = xpcall,
        error = error, assert = assert, unpack = unpack, setmetatable = setmetatable,
        os = { time = os.time, clock = os.clock, date = os.date, difftime = os.difftime },
    }
    env.string.dump = nil
    env._G = env

    env.print = function(...)
        local parts = {}
        for index = 1, select("#", ...) do parts[index] = tostring((select(index, ...)) ) end
        _log.info("[" .. mod.name .. "] " .. table.concat(parts, "\t"))
    end
    env.require = function(module_name) return require_in(mod, module_name) end

    local handle = {
        name = mod.name,
        realm = mod.realm,
        persist = mod.persist,
        dir = m.root .. "/" .. mod.name,
        version = mod.manifest.metadata.version,
        description = mod.manifest.metadata.description,
        author = mod.manifest.metadata.author,
        license = mod.manifest.metadata.license,
        manifest = _sandbox.deep_copy(mod.manifest),
        on_stop = function(callback) mod.stop_handlers[#mod.stop_handlers + 1] = callback end,
    }

    handle.on_stop(function()
        local ok_hooks, _hooks = pcall(require, "src.sdk.shared.hook")
        if ok_hooks and _hooks.remove_owner then _hooks.remove_owner(mod.name) end
        
        local ok_exports, _exp = pcall(require, "src.sdk.shared.exports")
        if ok_exports and _exp.remove_owner then _exp.remove_owner(mod.name) end
        
        if _commands and _commands.remove_owner then _commands.remove_owner(mod.name) end
    end)

    env.mod = handle
    env.exports = _exports.api(mod.name)

    local _, mod_modules = _sandbox.create_env(mod.realm, "mod", m.config)
    env.modit = mod_modules

    if env.modit and env.modit.hook and env.modit.hook.fire then
        local original_fire = env.modit.hook.fire
        local realm_reserved = RESERVED[mod.realm] or {}
        
        env.modit.hook.fire = function(name, ...)
            if realm_reserved[name] then
                error("event '" .. tostring(name) .. "' is reserved", 2)
            end
            return original_fire(name, ...)
        end
    end

    return env
end

--- @section Functions

--- Finds mods and reads their manifests. Running mods are left alone
function m.scan()
    if not _fs.is_dir(m.root) then
        _log.print("error", "mods", "folder not found: " .. m.root)
        return
    end
    for _, entry in ipairs(_fs.list(m.root)) do
        if entry.dir and entry.name:sub(1, 1) ~= "." then
            local existing = mods[entry.name]
            if not existing or existing.state ~= "started" then
                local manifest, err = load_manifest(entry.name)
                if manifest then
                    if existing then
                        existing.manifest = manifest
                    else
                        mods[entry.name] = { name = entry.name, manifest = manifest, state = "stopped", persist = {} }
                    end
                else
                    _log.print("warn", entry.name, "skipped: " .. tostring(err))
                end
            end
        end
    end
end

--- Starts a mod (and its dependencies) for one realm
--- @param name string mod name
--- @param realm string "client" or "server"
--- @return boolean ok True if the mod is running
--- @return string|nil error Error text on failure
function m.start(name, realm)
    local mod = mods[name]
    if not mod then return false, "unknown mod" end
    if not REALMS[realm] then return false, "realm must be client or server" end
    if mod.state == "started" then return true end
    if mod.state == "starting" then return false, "dependency cycle" end

    mod.state = "starting"
    for _, dependency in ipairs(mod.manifest.depends or {}) do
        local ok, err = m.start(dependency, realm)
        if not ok then
            mod.state = "stopped"
            _log.print("error", name, "dependency '" .. dependency .. "' failed: " .. tostring(err))
            return false, "dependency " .. dependency .. ": " .. tostring(err)
        end
    end

    mod.realm, mod.cache, mod.loading, mod.stop_handlers = realm, {}, {}, {}
    mod.env = make_env(mod)

    local files = {}
    for _, file in ipairs(mod.manifest.shared or {}) do files[#files + 1] = file end
    for _, file in ipairs(mod.manifest[realm] or {}) do files[#files + 1] = file end

    for _, file in ipairs(files) do
        local ok, err = pcall(load_file, mod, file)
        if not ok then
            _log.print("error", name, tostring(err))
            m.stop(name)
            mod.state = "failed"
            return false, tostring(err)
        end
    end

    mod.state = "started"
    _log.print("success", name, "started (" .. realm .. ")")
    sync_public_registry()
    return true
end

--- Stops a mod and runs its cleanup handlers, newest first
--- @param name string mod name
function m.stop(name)
    local mod = mods[name]
    if not mod or (mod.state ~= "started" and mod.state ~= "starting") then return end

    for index = #(mod.stop_handlers or {}), 1, -1 do
        local ok, err = pcall(mod.stop_handlers[index])
        if not ok then _log.print("error", name, "stop handler failed: " .. tostring(err)) end
    end
    mod.env, mod.cache, mod.loading, mod.stop_handlers = nil, nil, nil, nil
    mod.state = "stopped"
    _commands.remove_owner(name)
    
    sync_public_registry()
    _log.print("info", name, "stopped")
end

--- Stops, re-reads the manifest, and starts again in the same realm
--- @param name string mod name
--- @return boolean ok
--- @return string|nil error
function m.restart(name)
    local mod = mods[name]
    if not mod then return false, "unknown mod" end
    local realm = mod.realm or "client"
    m.stop(name)

    local manifest, err = load_manifest(name)
    if not manifest then
        _log.print("error", name, "restart failed: " .. tostring(err))
        return false, err
    end
    mod.manifest = manifest
    return m.start(name, realm)
end

--- Starts every known mod in name order
--- @param realm string "client" or "server"
function m.start_all(realm)
    local names = {}
    for name in pairs(mods) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do m.start(name, realm) end
end

--- Stops every mod
function m.stop_all()
    for name in pairs(mods) do m.stop(name) end
end

--- Lists known mods
--- @return table list Array of { name, version, state, realm }
function m.list()
    local list = {}
    for name, mod in pairs(mods) do
        list[#list + 1] = {
            name = name,
            version = mod.manifest.metadata.version,
            state = mod.state,
            realm = mod.realm
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function is_dirty(mod)
    local files = { "manifest.lua" }
    for _, list_name in ipairs(PATH_LISTS) do
        for _, file in ipairs(mod.manifest[list_name] or {}) do files[#files + 1] = file end
    end
    local dirty = false
    for _, file in ipairs(files) do
        local path = m.root .. "/" .. mod.name .. "/" .. file
        local content = read_file(path)
        if snapshots[path] == nil then
            snapshots[path] = content
        elseif content ~= snapshots[path] then
            dirty = true
        end
    end
    return dirty
end

--- Call once per frame in dev mode. Restarts mods whose files changed on disk
function m.poll()
    local now = os.clock()
    if now - last_poll < POLL_INTERVAL then return end
    last_poll = now

    local names = {}
    for name, mod in pairs(mods) do
        if mod.state == "started" or mod.state == "failed" then names[#names + 1] = name end
    end
    for _, name in ipairs(names) do
        if is_dirty(mods[name]) then
            if pending[name] then
                pending[name] = nil
                _log.print("info", name, "files changed, reloading")
                m.restart(name)
            else
                pending[name] = true
            end
        else
            pending[name] = nil
        end
    end
end

return m