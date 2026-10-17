--- @module sandbox
--- @file src/engine/core/internal/sandbox.lua
--- @description Access-tag driven API surfaces. Loads each module ONCE per realm, then hands out per-role views and sandboxed script environments.

--- @section Constants

local MANIFEST = {
    shared = {
        json = "src/engine/core/json.lua",
        log = "src/engine/core/log.lua",
        command = "src/sdk/shared/command.lua",
        filesystem = "src/sdk/shared/filesystem.lua",
        hook = "src/sdk/shared/hook.lua",
        mat4 = "src/sdk/shared/mat4.lua",
        math = "src/sdk/shared/math.lua",
        vector = "src/sdk/shared/vector.lua",
        runtime = "src/sdk/shared/runtime.lua",
        physics = "src/sdk/shared/physics.lua",
        mods = "src/engine/core/internal/mod_manager.lua"
    },
    server = {
        server_console = "src/sdk/server/console.lua",
        network = "src/sdk/server/network.lua"
    },
    client = {
        audio = "src/sdk/client/audio.lua",
        canvas = "src/sdk/client/canvas.lua",
        draw2d = "src/sdk/client/draw2d.lua",
        draw3d = "src/sdk/client/draw3d.lua",
        font = "src/sdk/client/font.lua",
        image = "src/sdk/client/image.lua",
        environment = "src/sdk/client/environment.lua",
        model = "src/sdk/client/model.lua",
        camera = "src/sdk/client/camera.lua",
        input = "src/sdk/client/input.lua",
        ui = "src/sdk/ui/init.lua",
        window = "src/engine/core/window.lua",
    },
}

local ROLE_RANK = { mod = 1, game = 2, engine = 3 }

local SAFE_GLOBALS = { "assert", "error", "ipairs", "pairs", "next", "pcall", "xpcall", "select", "tonumber", "tostring", "type", "unpack", "setmetatable", "rawget", "rawset", "rawequal" }

local ALWAYS_ON = { window = true, log = true, json = true }

--- @section Initialisation

local m = {}
local realm_cache = {}

m.manifest = MANIFEST

local real_getmetatable = getmetatable

--- @section Helper Functions

local function rank_of(role)
    local rank = ROLE_RANK[role]
    if not rank then
        error(("sandbox: unknown role '%s' (expected mod, game or engine)"):format(tostring(role)), 3)
    end
    return rank
end

local function split_lines(code)
    code = code:gsub("\194\160", " "):gsub("\r", "")
    local lines = {}
    for line in (code .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function lowest_role(spec, where)
    local best
    for token in spec:gmatch("[^,%s]+") do
        local rank = ROLE_RANK[token]
        if not rank then
            error(("sandbox: %s: unknown access role '%s'"):format(where, token), 0)
        end
        if not best or rank < ROLE_RANK[best] then best = token end
    end
    if not best then error(("sandbox: %s: empty @access tag"):format(where), 0) end
    return best
end

local function parse_metadata(code, source)
    local lines = split_lines(code)
    local members, warnings = {}, {}

    local module_name
    for i = #lines, 1, -1 do
        local name = lines[i]:match("^return%s+([%a_][%w_]*)%s*$")
        if name then module_name = name break end
    end

    local pending, pending_line, default_role

    local function warn(line_no, text)
        warnings[#warnings + 1] = ("%s:%d: %s"):format(source, line_no, text)
    end

    for i, line in ipairs(lines) do
        local where = source .. ":" .. i
        local default_spec = line:match("^%s*%-%-+%s*@default_access%s+(.-)%s*$")
        local access_spec = line:match("^%s*%-%-+%s*@access%s+(.-)%s*$")

        if default_spec then
            default_role = lowest_role(default_spec, where)
        elseif access_spec then
            if pending then warn(pending_line, "@access tag replaced before reaching a definition") end
            pending, pending_line = lowest_role(access_spec, where), i
        else
            local obj, key = line:match("^function%s+([%a_][%w_]*)[%.:]([%a_][%w_]*)")
            if not obj then
                local o, k, rest = line:match("^([%a_][%w_]*)%.([%a_][%w_]*)%s*=(.?)")
                if o and rest ~= "=" then obj, key = o, k end
            end

            if obj and (not module_name or obj == module_name) then
                local role = pending or default_role
                members[key] = { role = role or "engine", tagged = role ~= nil, line = i }
                pending = nil
            elseif not line:match("^%s*%-%-") and not line:match("^%s*$") then
                if pending then warn(pending_line, "@access tag not followed by a module member") end
                pending = nil
            end
        end
    end

    return members, warnings, default_role
end

local function module_name_of(path)
    return (path:gsub("%.lua$", ""):gsub("[/\\]", "."))
end

local function read_source(path)
    local code = m.read_file(path)
    if code then return code end

    local rel = module_name_of(path):gsub("%.", "/")
    for template in package.path:gmatch("[^;]+") do
        local candidate = template:gsub("%?", function() return rel end)
        code = m.read_file(candidate)
        if code then return code end
    end
    error("sandbox: failed to open module source -> " .. tostring(path), 0)
end

local function load_module(mod_name, path_or_paths)
    local paths = type(path_or_paths) == "table" and path_or_paths or { path_or_paths }
    local exports, meta = {}, {}

    for _, path in ipairs(paths) do
        local members, warnings, default_role = parse_metadata(read_source(path), path)
        for _, w in ipairs(warnings) do m.warn(w) end

        local part = require(module_name_of(path))
        if type(part) ~= "table" then
            error(("sandbox: module '%s' (%s) must return a table"):format(mod_name, path), 0)
        end

        for key, value in pairs(part) do
            if exports[key] ~= nil then
                m.warn(("%s: '%s.%s' overrides an export"):format(path, mod_name, key))
            end
            exports[key] = value
            meta[key] = members[key] or { role = default_role or "engine", tagged = default_role ~= nil }
        end
    end

    return { exports = exports, meta = meta }
end

local function load_realm(realm)
    if realm_cache[realm] then return realm_cache[realm] end
    if realm ~= "client" and realm ~= "server" then
        error(("sandbox: unknown realm '%s'"):format(tostring(realm)), 3)
    end

    local modules = {}
    local function batch(section)
        for name, paths in pairs(section) do
            assert(modules[name] == nil, "sandbox: duplicate module -> " .. name)
            modules[name] = load_module(name, paths)
        end
    end
    batch(MANIFEST.shared)
    batch(MANIFEST[realm])

    realm_cache[realm] = modules
    return modules
end

local function build_view(mod, caller_rank)
    local view = {}
    for key, value in pairs(mod.exports) do
        if caller_rank >= ROLE_RANK[mod.meta[key].role] then
            view[key] = value
        end
    end
    return view
end

local function shallow_copy(src, skip)
    local out = {}
    for k, v in pairs(src) do
        if not (skip and skip[k]) then out[k] = v end
    end
    return out
end

local function pick(src, keys)
    local out = {}
    for _, k in ipairs(keys) do out[k] = src[k] end
    return out
end

local function valid_module_name(name)
    if type(name) ~= "string" or name == "" then return false end
    for segment in (name .. "."):gmatch("([^%.]*)%.") do
        if not segment:match("^[%a_][%w_]*$") then return false end
    end
    return true
end

local function make_require(root, env)
    local loaded = {}
    local LOADING = {}

    return function(name)
        if not valid_module_name(name) then error(("require: invalid name '%s'"):format(tostring(name)), 2) end
        if loaded[name] == LOADING then error(("require: circular dependency on '%s'"):format(name), 2) end
        if loaded[name] ~= nil then return loaded[name] end

        local rel = name:gsub("%.", "/")
        local chunk
        for _, path in ipairs({ root .. "/" .. rel .. ".lua", root .. "/" .. rel .. "/init.lua" }) do
            chunk = loadfile(path)
            if chunk then break end
        end
        if not chunk then error(("require: module '%s' not found"):format(name), 2) end

        setfenv(chunk, env)
        loaded[name] = LOADING
        local result = chunk(name)
        if result == nil then result = true end
        loaded[name] = result
        return result
    end
end

--- @section Functions

function m.read_file(path)
    local bundle = rawget(_G, "MODIT_BUNDLE")
    if bundle then
        local normalized = path:gsub("\\", "/")
        local key = normalized:gsub("^%./", "")
        if bundle.has(key) then return bundle.get(key) end
        
        key = normalized:match(".*/(src/.-)$") or normalized:match(".*/(game/.-)$") 
              or normalized:match("^(src/.-)$") or normalized:match("^(game/.-)$")
        if key and bundle.has(key) then return bundle.get(key) end
    end

    local file = io.open(path, "rb")
    if not file then return nil end
    local code = file:read("*a")
    file:close()
    return code
end

function m.warn(message)
    print("[sandbox] " .. message)
end

function m.reset()
    realm_cache = {}
end

function m.load_environment(realm, role, opts)
    local caller_rank = rank_of(role)
    local enabled_map = opts and opts.enabled
    local env = {}

    for name, mod in pairs(load_realm(realm)) do
        if ALWAYS_ON[name] or not enabled_map or enabled_map[name] == true then
            local view = build_view(mod, caller_rank)
            if next(view) ~= nil then env[name] = view end
        end
    end
    return env
end

function m.deep_copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[m.deep_copy(k, seen)] = m.deep_copy(v, seen)
    end
    return out
end

function m.make_env(role, modules, opts)
    if role == "engine" then error("sandbox: engine runs unsandboxed", 2) end
    rank_of(role)
    opts = opts or {}

    local env = {}
    for _, name in ipairs(SAFE_GLOBALS) do env[name] = _G[name] end

    env.print = opts.print or print
    env.getmetatable = function(value)
        if type(value) == "string" then return nil end
        return real_getmetatable(value)
    end

    env.string = shallow_copy(string, { dump = true })
    env.table = shallow_copy(table)
    env.math = shallow_copy(math)
    env.coroutine = shallow_copy(coroutine)
    env.os = pick(os, { "time", "clock", "date", "difftime" })
    if bit then env.bit = shallow_copy(bit) end

    env._G = env
    env[opts.global_name or "modit"] = modules
    if opts.root then env.require = make_require(opts.root, env) end

    return env
end

function m.create_env(realm, role, conf, opts)
    opts = opts or {}
    conf = conf or {}

    if role == "mod" then
        local modding = conf.modding
        if type(modding) ~= "table" or modding.enabled ~= true then
            return nil, "modding is disabled"
        end
    end

    local enabled_modules = {}
    if conf.modules then
        for k, v in pairs(conf.modules) do
            if v == true then enabled_modules[k] = true end
        end
    end

    if role == "mod" and conf.modding and conf.modding.blacklisted_modules then
        local blacklisted = conf.modding.blacklisted_modules
        for i = 1, #blacklisted do
            enabled_modules[blacklisted[i]] = nil
        end
    end

    local modules = m.load_environment(realm, role, { enabled = enabled_modules })
    for key, value in pairs(opts.extra or {}) do
        modules[key] = value
    end

    return m.make_env(role, modules, opts), modules
end

return m