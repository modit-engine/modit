--- @module camera
--- @file src/engine/modules/camera.lua
--- @description Camera state holder for 2D and 3D rendering. The 3D pass is lit and fogged by the lighting module.

local _backend = require("src.engine.backend").camera
local _lighting = require("src.engine.modules.render.lighting")
local _shapes = require("src.engine.modules.render.shapes")

local camera = {}
camera.__index = camera

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
    }, camera)
end

function camera:begin_3d()
    local p, t, u = self.position, self.target, self.up
    _backend.begin_3d(p.x, p.y, p.z, t.x, t.y, t.z, u.x, u.y, u.z, self.fov)
    _shapes.reset()
    _lighting.begin(self)
end

function camera:end_3d()
    _lighting.finish()
    _backend.end_3d()
end

function camera:begin_2d()
    _backend.begin_2d(self.offset.x, self.offset.y, self.target_2d.x, self.target_2d.y, self.rotation, self.zoom)
end

function camera:end_2d() _backend.end_2d() end

function camera:set_position(x, y, z)
    self.position.x, self.position.y, self.position.z = x, y, z or self.position.z
end

function camera:set_target(x, y, z)
    self.target.x, self.target.y, self.target.z = x, y, z or self.target.z
end

function camera:set_offset(x, y) self.offset.x, self.offset.y = x, y end
function camera:set_target_2d(x, y) self.target_2d.x, self.target_2d.y = x, y end
function camera:set_zoom(zoom) self.zoom = math.max(0.1, zoom) end
function camera:set_rotation(angle) self.rotation = angle end
function camera:set_fov(fov) self.fov = fov end

return camera