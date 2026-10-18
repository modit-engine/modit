--- @module lazy
--- @file src/engine/core/internal/lazy.lua
--- @description Builds a table whose entries are required on first access and cached.

--- @section Initialisation

local m = {}

--- @section Functions

--- Creates a lazy module table
--- @param paths table Map of name to module path or helper function
--- @return table lazy Table that requires each module or returns functions on first access
function m.new(paths)
    return setmetatable({}, {
        __index = function(self, name)
            local path = paths[name]
            if not path then
                error(("missing module '%s'"):format(tostring(name)), 2)
            end

            -- If the entry is a function wrapper, return it directly
            if type(path) == "function" then
                rawset(self, name, path)
                return path
            end

            local mod = require(path)
            rawset(self, name, mod)
            return mod
        end,
    })
end

return m