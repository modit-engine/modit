--- @module mods
--- @file src/sdk/shared/mods.lua
--- @description Safe read-only mod querying API for game and mod environments.

--- @section Initialisation

local m = {}

local public_registry = {}

--- @section Functions

--- @access engine
function m.set_registry(reg)
    public_registry = reg
end

--- Returns a list of all known mods and their states.
--- @access mod
function m.list()
    local list = {}
    for name, data in pairs(public_registry) do
        list[#list + 1] = {
            name = name,
            version = data.version,
            author = data.author,
            realm = data.realm,
            state = data.state
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- Checks if a specific mod is currently running.
--- @access mod
function m.is_loaded(name)
    local mod = public_registry[name]
    return mod and mod.state == "started"
end

return m