--- @module box3d
--- @file src/engine/backend/box3d/init.lua
--- @description Box3D backend entry point aggregating world, body, shape, query and event wrappers. Independent of raylib so a dedicated server can load it.

--- @section Constants

local BOX3D_PATH = "src.engine.backend.box3d"

--- @section Modules

return {
    world = require(BOX3D_PATH .. ".world"),
    body = require(BOX3D_PATH .. ".body"),
    shape = require(BOX3D_PATH .. ".shape"),
    query = require(BOX3D_PATH .. ".query"),
    events = require(BOX3D_PATH .. ".events"),
    joint = require(BOX3D_PATH .. ".joint"),
}