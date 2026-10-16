--- @module exports
--- @file src/engine/modules/exports.lua
--- @description Cross-mod function exports. Calls go through here, never through another mod's environment.

--- @section Initialisation

local m = {}

local registry = {} -- provider name -> { export name -> function }

--- @section Helpers

--- Rethrows a failed export call with the provider named, or returns the results
local function pass(provider, name, ok, ...)
    if not ok then
        error(("export '%s.%s' failed: %s"):format(provider, name, tostring((...))), 0)
    end
    return ...
end

--- @section Functions

--- Registers an export for a mod
--- @param owner string Mod name
--- @param name string Export name
--- @param fn function Function to expose
function m.set(owner, name, fn)
    if type(name) ~= "string" or name == "" then error("export name must be a string", 3) end
    if type(fn) ~= "function" then error("export '" .. name .. "' must be a function", 3) end
    registry[owner] = registry[owner] or {}
    registry[owner][name] = fn
end

--- Removes every export belonging to a mod
--- @param owner string Mod name
function m.remove_owner(owner)
    registry[owner] = nil
end

--- Calls an export by provider and name
--- @param provider string Mod that exported it
--- @param name string Export name
--- @return any ... Whatever the export returns
function m.call(provider, name, ...)
    local provider_exports = registry[provider]
    local fn = provider_exports and provider_exports[name]
    if not fn then
        error(("mod '%s' has no export '%s' (not running, or not exported)"):format(provider, name), 0)
    end
    return pass(provider, name, pcall(fn, ...))
end

--- Builds the `exports` object for one mod.
--- exports("name", fn) registers. exports.other_resource.name(...) calls
--- @param owner string Mod name
--- @return table exports
function m.api(owner)
    local function view_of(provider)
        return setmetatable({}, {
            __index = function(_, name)
                return function(...) return m.call(provider, name, ...) end
            end,
        })
    end

    return setmetatable({}, {
        __call = function(_, name, fn) m.set(owner, name, fn) end,
        __index = function(_, provider) return view_of(provider) end,
    })
end

return m