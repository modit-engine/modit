--- @module lazy
--- @file src/engine/core/lazy.lua
--- @description Builds a table whose entries are required on first access and cached.

--- @section Functions

local m = {}

--- Creates a lazy module table
--- @param paths table Map of name to module path
--- @return table lazy Table that requires each module on first access
function m.new(paths)
    return setmetatable({}, {
        __index = function(self, name)
            local path = paths[name]
            if not path then
                error(("missing module '%s'"):format(tostring(name)), 2)
            end

            local mod = require(path)
            rawset(self, name, mod)
            return mod
        end,
    })
end

return m