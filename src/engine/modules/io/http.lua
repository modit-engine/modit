--- @module http
--- @file src/engine/modules/http.lua
--- @description Engine HTTP module.

--- @section Imports

local _backend = require("src.engine.backend")

--- @section Module

local m = {}

--- @section Functions

function m.get(url, headers)
    return _backend.http.get(url, headers)
end

return m