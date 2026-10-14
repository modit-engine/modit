--- @module camera
--- @file src/engine/modules/camera.lua
--- @description Camera state holder with support for lifecycle event hooks.

local _backend = require("src.engine.backend").camera

--- @section Class Definition

--- @class Camera
--- @field position {x: number, y: number, z: number} 3D world position
--- @field target {x: number, y: number, z: number} 3D look-at target point
--- @field up {x: number, y: number, z: number} 3D up vector
--- @field fov number Field of view in degrees
--- @field offset {x: number, y: number} 2D screen offset
--- @field target_2d {x: number, y: number} 2D world target point
--- @field rotation number 2D rotation angle in degrees
--- @field zoom number 2D zoom factor
--- @field _hooks table Internal table storing lifecycle event callbacks
local camera = {}
camera.__index = camera

--- @section Configuration Tables

--- @class CameraConfig
--- @field x? number Initial position X (default 0)
--- @field y? number Initial position Y (default 0)
--- @field z? number Initial position Z (default 0)
--- @field target_x? number Initial target X (default 0)
--- @field target_y? number Initial target Y (default 0)
--- @field target_z? number Initial target Z (default 0)
--- @field fov? number Field of view in degrees (default 45)
--- @field offset_x? number 2D offset X (default 0)
--- @field offset_y? number 2D offset Y (default 0)
--- @field target_2d_x? number 2D target X (default 0)
--- @field target_2d_y? number 2D target Y (default 0)
--- @field rotation? number 2D rotation angle in degrees (default 0)
--- @field zoom? number 2D zoom level (default 1.0)

--- @section Constructor

--- Creates a new camera instance
--- @param cfg? CameraConfig Optional configuration table for initial values
--- @return Camera
function camera.new(cfg)
    cfg = cfg or {}
    return setmetatable({
        position = { x = cfg.x or 0, y = cfg.y or 0, z = cfg.z or 0 },
        target = { x = cfg.target_x or 0, y = cfg.target_y or 0, z = cfg.target_z or 0 },
        up = { x = 0, y = 1, z = 0 },
        fov = cfg.fov or 45,
        offset = { x = cfg.offset_x or 0, y = cfg.offset_y or 0 },
        target_2d = { x = cfg.target_2d_x or 0, y = cfg.target_2d_y or 0 },
        rotation = cfg.rotation or 0,
        zoom = cfg.zoom or 1.0,
        _hooks = {
            begin_3d = {},
            end_3d = {},
            begin_2d = {},
            end_2d = {},
        }
    }, camera)
end

--- @section Event System

--- Registers a callback function to a camera lifecycle event
--- @param event string Event name ("begin_3d", "end_3d", "begin_2d", "end_2d")
--- @param fn function Function to execute when the event triggers
function camera:on(event, fn)
    if self._hooks[event] then
        table.insert(self._hooks[event], fn)
    end
end

--- Fires all callbacks registered to a specific event
--- @private
--- @param event string Event name
--- @vararg any Additional arguments passed to callbacks
function camera:_trigger(event, ...)
    for _, fn in ipairs(self._hooks[event]) do
        fn(self, ...)
    end
end

--- @section Rendering Passes

--- Begins the 3D rendering mode and triggers registered hooks
function camera:begin_3d()
    local p, t, u = self.position, self.target, self.up
    _backend.begin_3d(p.x, p.y, p.z, t.x, t.y, t.z, u.x, u.y, u.z, self.fov)
    self:_trigger("begin_3d")
end

--- Ends the 3D rendering mode and triggers registered hooks
function camera:end_3d()
    self:_trigger("end_3d")
    _backend.end_3d()
end

--- Begins the 2D rendering mode and triggers registered hooks
function camera:begin_2d()
    _backend.begin_2d(self.offset.x, self.offset.y, self.target_2d.x, self.target_2d.y, self.rotation, self.zoom)
    self:_trigger("begin_2d")
end

--- Ends the 2D rendering mode and triggers registered hooks
function camera:end_2d()
    self:_trigger("end_2d")
    _backend.end_2d()
end

--- @section Setters

--- Sets the 3D position of the camera
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z? number Z coordinate (defaults to current Z if nil)
function camera:set_position(x, y, z)
    self.position.x, self.position.y, self.position.z = x, y, z or self.position.z
end

--- Sets the 3D look-at target of the camera
--- @param x number Target X coordinate
--- @param y number Target Y coordinate
--- @param z? number Target Z coordinate (defaults to current Z if nil)
function camera:set_target(x, y, z)
    self.target.x, self.target.y, self.target.z = x, y, z or self.target.z
end

--- Sets the 2D screen offset
--- @param x number Offset X
--- @param y number Offset Y
function camera:set_offset(x, y)
    self.offset.x, self.offset.y = x, y
end

--- Sets the 2D world target point
--- @param x number Target X
--- @param y number Target Y
function camera:set_target_2d(x, y)
    self.target_2d.x, self.target_2d.y = x, y
end

--- Sets the 2D zoom factor (clamped to a minimum of 0.1)
--- @param zoom number Zoom multiplier
function camera:set_zoom(zoom)
    self.zoom = math.max(0.1, zoom)
end

--- Sets the 2D rotation angle
--- @param angle number Rotation angle in degrees
function camera:set_rotation(angle)
    self.rotation = angle
end

--- Sets the 3D field of view
--- @param fov number Field of view in degrees
function camera:set_fov(fov)
    self.fov = fov
end

return camera