--- @module world
--- @file src/engine/backend/box3d/world.lua
--- @description Box3D world creation, destruction, fixed stepping and gravity.

--- @section Imports

local _box3d = require("src.engine.backend.box3d.ffi")
local _ffi = _box3d.ffi
local _lib = _box3d.lib

--- @section Initialisation

local m = {}
local scratch_gravity = _ffi.new("b3Vec3")

--- @section Lifecycle

--- Creates a world. Single threaded, sleeping and continuous collision enabled
--- @param gravity_x number Gravity X in m/s^2
--- @param gravity_y number Gravity Y in m/s^2
--- @param gravity_z number Gravity Z in m/s^2
--- @return cdata|nil world_id World id, or nil when no world could be created
function m.create(gravity_x, gravity_y, gravity_z)
    local def = _lib.b3DefaultWorldDef()
    def.gravity.x = gravity_x
    def.gravity.y = gravity_y
    def.gravity.z = gravity_z

    local world_id = _lib.b3CreateWorld(def)
    if not _lib.b3World_IsValid(world_id) then return nil end
    return world_id
end

--- Destroys a world and everything in it
--- @param world_id cdata World id
function m.destroy(world_id)
    _lib.b3DestroyWorld(world_id)
end

--- Checks whether a world id is still valid
--- @param world_id cdata World id
--- @return boolean valid True if the world exists
function m.is_valid(world_id)
    return _lib.b3World_IsValid(world_id)
end

--- @section Simulation

--- Advances the simulation by one fixed step
--- @param world_id cdata World id
--- @param dt number Step length in seconds
--- @param substeps number Solver substeps per step
function m.step(world_id, dt, substeps)
    _lib.b3World_Step(world_id, dt, substeps)
end

--- Sets world gravity
--- @param world_id cdata World id
--- @param x number Gravity X
--- @param y number Gravity Y
--- @param z number Gravity Z
function m.set_gravity(world_id, x, y, z)
    scratch_gravity.x, scratch_gravity.y, scratch_gravity.z = x, y, z
    _lib.b3World_SetGravity(world_id, scratch_gravity)
end

--- Returns world gravity
--- @param world_id cdata World id
--- @return number x Gravity X
--- @return number y Gravity Y
--- @return number z Gravity Z
function m.get_gravity(world_id)
    local gravity = _lib.b3World_GetGravity(world_id)
    return gravity.x, gravity.y, gravity.z
end

--- Returns how many bodies are currently awake
--- @param world_id cdata World id
--- @return number count Awake body count
function m.get_awake_count(world_id)
    return _lib.b3World_GetAwakeBodyCount(world_id)
end

return m