--- @module mods
--- @file src/engine/modules/mods.lua
--- @description Mod loader: finds, sandboxes, starts and stops mods.

--- @section Imports

local _log = require("src.engine.core.log")
local _fs = require("src.engine.backend.platform." .. require("ffi").os:lower() .. ".filesystem")
local _sandbox = require("src.engine.core.security.mod_sandbox")
local _commands = require("src.engine.modules.commands")
local _exports = require("src.engine.modules.modding.exports")

--- @section Constants

local API_VERSION = 1
local REALMS = { client = true, server = true }
local PATH_LISTS = { "shared", "client", "server", "assets" }
local KNOWN_KEYS = {
    name = true, version = true, description = true, author = true, license = true,
    api_version = true, depends = true, shared = true, client = true, server = true, assets = true,
}

--- @section Initialisation

local m = {
    root = nil,
    config = {},
}

function m.init(config, game_dir)
    m.config = config or {}
    local project_dir = game_dir:gsub("[/\\]$", ""):match("^(.*)[/\\][^/\\]+$")
    m.root = project_dir .. "/mods"
end

local mods = {} -- name -> { name, manifest, state, realm, env, cache, loading, stop_handlers }
local snapshots = {} -- path -> source as last loaded

--- @section Helpers

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

--- Accepts only relative paths that stay inside the mod folder
local function safe_path(path)
    return type(path) == "string" and path ~= ""
        and not path:find("..", 1, true)
        and not path:find("[:\\]")
        and path:sub(1, 1) ~= "/"
end

--- Reads and validates a manifest in an empty environment, so it can only return data
local function load_manifest(folder_name)
    local path = m.root .. "/" .. folder_name .. "/manifest.lua"
    local source = read_file(path)
    if not source then return nil, "no manifest.lua" end
    if source:byte(1) == 27 then return nil, "bytecode is not allowed" end
    snapshots[path] = source

    local chunk, err = loadstring(source, "@" .. path)
    if not chunk then return nil, err end
    setfenv(chunk, {})

    local ok, manifest = pcall(chunk)
    if not ok then return nil, tostring(manifest) end
    if type(manifest) ~= "table" then return nil, "manifest must return a table" end
    if manifest.name ~= folder_name then return nil, "name must match the folder name" end
    if manifest.api_version ~= API_VERSION then
        return nil, "unsupported api_version " .. tostring(manifest.api_version) .. " (expected " .. API_VERSION .. ")"
    end

    for key in pairs(manifest) do
        if not KNOWN_KEYS[key] then
            _log.print("warn", folder_name, "unknown manifest key '" .. tostring(key) .. "'")
        end
    end
    for _, list_name in ipairs(PATH_LISTS) do
        local list = manifest[list_name]
        if list ~= nil then
            if type(list) ~= "table" then return nil, list_name .. " must be a list" end
            for _, file in ipairs(list) do
                if not safe_path(file) then return nil, "bad path in " .. list_name .. ": " .. tostring(file) end
            end
        end
    end
    return manifest
end

--- Runs a file inside the mod sandbox once and caches its result
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

--- require() inside a mod: "shared.world" -> shared/world.lua in the same folder
local function require_in(mod, module_name)
    if type(module_name) ~= "string" or not module_name:match("^[%w_%.]+$")
        or module_name:find("..", 1, true) or module_name:sub(1, 1) == "." then
        error("invalid module name: " .. tostring(module_name), 2)
    end
    return load_file(mod, (module_name:gsub("%.", "/")) .. ".lua")
end

--- Builds the sandbox environment. Whitelist only, nothing from the editor or engine internals
local function make_env(mod)
    local env = {
        math = copy(math), string = copy(string), table = copy(table),
        ipairs = ipairs, pairs = pairs, next = next, select = select, type = type,
        tostring = tostring, tonumber = tonumber, pcall = pcall, xpcall = xpcall,
        error = error, assert = assert, unpack = unpack, setmetatable = setmetatable,
        os = { time = os.time, clock = os.clock, date = os.date, difftime = os.difftime },
    }
    env.string.dump = nil -- would allow bytecode
    env._G = env

    env.print = function(...)
        local parts = {}
        for index = 1, select("#", ...) do parts[index] = tostring((select(index, ...))) end
        _log.print("info", mod.name, table.concat(parts, "\t"))
    end
    env.require = function(module_name) return require_in(mod, module_name) end

    local handle = {
        name = mod.name,
        realm = mod.realm,
        persist = mod.persist,
        dir = m.root .. "/" .. mod.name,
        on_stop = function(callback) mod.stop_handlers[#mod.stop_handlers + 1] = callback end,
    }
    env.mod = handle
    env.exports = _exports.api(mod.name)

    env.modit = _sandbox.build(handle, m.config.modules or {})

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
                    -- keep an existing record (and its persist table); a broken manifest isn't a deleted mod
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
        list[#list + 1] = { name = name, version = mod.manifest.version, state = mod.state, realm = mod.realm }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local POLL_INTERVAL = 0.25
local last_poll = 0
local pending = {} -- name -> true once a change has been seen (acts as the debounce)

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
            snapshots[path] = content -- never loaded (e.g. after a failure): baseline only
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
                pending[name] = true -- wait one more tick so two-step editor saves settle
            end
        else
            pending[name] = nil
        end
    end
end

return m