--- @module physics3d
--- @file src/engine/sdk/shared/physics3d/init.lua
--- @description Flattens world, body, shape, query, and rotation modules into a single unified physics3d namespace.

--- @section Constants

local PATH = "src.engine.sdk.shared.physics3d"

--- @section Module

local m = {}


--- Flatten physics modules into single namespace `physics3d`
for _, mod in ipairs({
    require(PATH .. ".world"),
    require(PATH .. ".body"),
    require(PATH .. ".shape"),
    require(PATH .. ".query"),
    require(PATH .. ".rotation")
}) do
    for k, v in pairs(mod) do
        m[k] = v
    end
end

return m