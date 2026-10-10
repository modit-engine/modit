--- @module image
--- @file src/engine/modules/image.lua
--- @description Image and sprite registry: loading, drawing, and animation frame lookup.

--- @section Imports

local _backend = require("src.engine.backend").image
local _log = require("src.engine.core.log")

--- @section Initialisation

local m = {}

local images = {}  -- key -> texture
local sprites = {} -- key -> { frame_width, frame_height, frames }

--- @section Helpers

local function build_frames(anim_def, frame_width, frame_height)
    local frames = {}
    for index = 1, anim_def.frames do
        frames[index] = {
            x = (anim_def.x + index - 1) * frame_width,
            y = anim_def.y * frame_height,
        }
    end
    return frames
end

local function build_animations(animations, frame_width, frame_height)
    local result = {}
    for name, def in pairs(animations) do
        result[name] = build_frames(def, frame_width, frame_height)
    end
    return result
end

local function tint_values(tint)
    if not tint then return 255, 255, 255, 255 end
    return tint.r or 255, tint.g or 255, tint.b or 255, tint.a or 255
end

--- @section Functions

--- Loads an image or sprite sheet
--- @param opts table `{ type?, key, path, frame_width?, frame_height?, animations? }`
--- @return boolean ok True if loaded (or already loaded)
function m.load(opts)
    opts = opts or {}
    if not opts.key or not opts.path then
        _log.warn("image.load needs key and path")
        return false
    end
    if images[opts.key] then return true end

    local texture = _backend.load(opts.path)
    if not texture then
        _log.warn("image failed to load: " .. tostring(opts.path))
        return false
    end
    images[opts.key] = texture

    if opts.type == "sprite" then
        sprites[opts.key] = {
            frame_width = opts.frame_width,
            frame_height = opts.frame_height,
            frames = opts.animations
                and build_animations(opts.animations, opts.frame_width, opts.frame_height) or {},
        }
    end
    return true
end

--- Gets image dimensions
--- @param key string Image identifier
--- @return number|nil width
--- @return number|nil height
function m.get_size(key)
    local texture = images[key]
    if not texture then return nil end
    return _backend.get_size(texture)
end

--- Draws a whole image
--- @param opts table `{ key, x, y, scale?, tint? }`
function m.draw(opts)
    local texture = images[opts.key]
    if not texture then return end

    local width, height = _backend.get_size(texture)
    local scale = opts.scale or 1
    _backend.draw(texture, 0, 0, width, height,
        opts.x, opts.y, width * scale, height * scale, tint_values(opts.tint))
end

--- Draws a region of a sprite sheet
--- @param opts table `{ key, x, y, frame_width, frame_height, frame_x?, frame_y?, scale?, tint? }`
function m.draw_frame(opts)
    local texture = images[opts.key]
    if not texture then return end

    local scale = opts.scale or 1
    _backend.draw(texture, opts.frame_x or 0, opts.frame_y or 0, opts.frame_width, opts.frame_height,
        opts.x, opts.y, opts.frame_width * scale, opts.frame_height * scale, tint_values(opts.tint))
end

--- Draws a named animation frame (frame is 1-based)
--- @param opts table `{ key, anim, frame, x, y, scale?, tint? }`
function m.draw_sprite(opts)
    local sprite = sprites[opts.key]
    if not sprite then return end

    local frames = sprite.frames[opts.anim]
    local frame = frames and frames[opts.frame]
    if not frame then return end

    m.draw_frame({
        key = opts.key, x = opts.x, y = opts.y,
        frame_width = sprite.frame_width, frame_height = sprite.frame_height,
        frame_x = frame.x, frame_y = frame.y,
        scale = opts.scale, tint = opts.tint,
    })
end

--- Unloads an image
--- @param key string Image identifier
function m.unload(key)
    local texture = images[key]
    if not texture then return end
    _backend.free(texture)
    images[key] = nil
    sprites[key] = nil
end

--- Unloads every image
function m.cleanup()
    for key in pairs(images) do m.unload(key) end
end

return m