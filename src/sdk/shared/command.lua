--- @module command
--- @file src/sdk/shared/command.lua
--- @description Console command registry with engine, game, and mod layers, plus optional built-ins.

--- @section Imports

local _log = require("src.engine.core.log")

--- @section Initialisation

local m = {}
local registry = {} -- name -> { fn, help, layer, owner }

--- @section Helpers

local function describe(command)
    if command.layer == "mod" then return "mod " + command.owner end
    return command.layer
end

local function add(layer, owner, name, fn, help)
    if type(name) ~= "string" or not name:match("^[%w_%-]+$") then error("invalid command name", 3) end
    if type(fn) ~= "function" then error("command handler must be a function", 3) end
    name = name:lower()

    local existing = registry[name]
    if existing and (existing.layer ~= layer or existing.owner ~= owner) then
        error(("command '%s' already exists (%s)"):format(name, describe(existing)), 3)
    end

    registry[name] = { fn = fn, help = help or "", layer = layer, owner = owner }
end

--- @section Functions

--- Registers an engine builtin. Only engine code should call this; do not expose it to mod sandboxes
--- @param name string Command name, no spaces
--- @param fn function Handler: fn(args) -> string|nil
--- @param help string|nil One-line description
function m.register_engine(name, fn, help)
    add("engine", nil, name, fn, help)
end

--- Registers a game command (no owner) or a mod command (owner = mod name)
--- @param name string Command name, no spaces
--- @param fn function Handler: fn(args) -> string|nil
--- @param help string|nil One-line description
--- @param owner string|nil Mod name. Leave nil for game command
function m.register(name, fn, help, owner)
    add(owner and "mod" or "game", owner, name, fn, help)
end

--- Removes every command registered by a mod. Engine and game command are never touched
--- @param owner string Mod name
function m.remove_owner(owner)
    if owner == nil then return end
    for name, command in pairs(registry) do
        if command.layer == "mod" and command.owner == owner then registry[name] = nil end
    end
end

--- Parses and runs one line of input
--- @param line string Raw text, for example "restart default_world"
function m.run(line)
    local args = {}
    for word in line:gmatch("%S+") do args[#args + 1] = word end
    if #args == 0 then return end

    local name = table.remove(args, 1):lower()
    local command = registry[name]
    if not command then
        _log.print("warn", "unknown command '" .. name .. "' (try 'help')")
        return
    end

    local ok, result = pcall(command.fn, args)
    if not ok then
        _log.print("error", "command '" .. name .. "' failed: " .. tostring(result))
    elseif result ~= nil then
        _log.print("info", tostring(result))
    end
end

--- Returns list of registered command
--- @return table list Sorted array of { name, help, layer, owner }
function m.list()
    local list = {}
    for name, command in pairs(registry) do
        list[#list + 1] = { name = name, help = command.help, layer = command.layer, owner = command.owner }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- @section Built-ins Registration

local function print_section(title, items)
    if #items == 0 then return end
    _log.print("info", title)
    for _, command in ipairs(items) do
        _log.print("info", ("  %-12s %s"):format(command.name, command.help))
    end
end

--- Registers built-in command conditionally based on configuration
--- @param realm string "client" or "server"
--- @param opts table|nil { help = true, mods = true } configuration flags
function m.register_builtins(realm, opts)
    opts = opts or {}
    
    -- Standard help command (enabled by default)
    if opts.help ~= false then
        m.register_engine("help", function()
            local engine, game, by_mod, mod_names = {}, {}, {}, {}

            for _, command in ipairs(m.list()) do
                if command.layer == "engine" then
                    engine[#engine + 1] = command
                elseif command.layer == "game" then
                    game[#game + 1] = command
                else
                    if not by_mod[command.owner] then
                        by_mod[command.owner] = {}
                        mod_names[#mod_names + 1] = command.owner
                    end
                    local items = by_mod[command.owner]
                    items[#items + 1] = command
                end
            end

            table.sort(mod_names)

            print_section("Engine", engine)
            print_section("Game", game)
            for _, name in ipairs(mod_names) do print_section("Mod: " .. name, by_mod[name]) end
        end, "List command")
    end

    -- Mod management engine command (opt-in if modding is supported)
    if opts.mods == true then
        local _engine = rawget(_G, "engine")
        local _mods = _engine and _engine.mods

        if _mods then
            m.register_engine("mods", function()
                for _, info in ipairs(_mods.list()) do
                    _log.print("info", ("%-16s %-8s %s"):format(info.name, info.state, info.version or ""))
                end
            end, "List mods")

            m.register_engine("start", function(args)
                if not args[1] then return "usage: start <mod>" end
                local ok, err = _mods.start(args[1], realm)
                if not ok then return err end
            end, "Start a mod")

            m.register_engine("stop", function(args)
                if not args[1] then return "usage: stop <mod>" end
                _mods.stop(args[1])
            end, "Stop a mod")

            m.register_engine("restart", function(args)
                if not args[1] then return "usage: restart <mod>" end
                local ok, err = _mods.restart(args[1])
                if not ok then return err end
            end, "Restart a mod")
        end
    end
end

return m