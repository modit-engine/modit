--- @module image
--- @file src/sdk/client/image.lua
--- @description Object-oriented image and sprite handle: loading, drawing, and animation frame handling.

--- @section Imports

local _backend = require("src.engine.backend").image
local _log = require("src.engine.core.log")

--- @section Initialisation

local Image = {}
Image.__index = Image

local cache = {}

--- @section Helpers

local function resolve_image_path(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return path, nil, nil
    end

    local game_dir = (rawget(_G, "modit") and rawget(_G, "modit").game_dir) or "game"
    local clean_path = path:gsub("^game/", ""):gsub("^assets/", "")
    
    local candidate_paths = {
        game_dir .. "/" .. path,
        game_dir .. "/assets/" .. clean_path,
        "game/" .. path,
        "game/assets/" .. clean_path
    }

    for _, candidate in ipairs(candidate_paths) do
        file = io.open(candidate, "rb")
        if file then
            file:close()
            return candidate, nil, nil
        end
    end

    local bundled_path = path:gsub("^src/engine/assets/", "game/assets/engine/")
    if bundled_path == path then
        bundled_path = "game/" .. path
    end

    local bundle = rawget(_G, "MODIT_BUNDLE")
    if not bundle or type(bundle.get) ~= "function" then
        return nil, "Image not found: " .. path, nil
    end

    local ok, data = pcall(bundle.get, bundled_path)
    if not ok or type(data) ~= "string" or #data == 0 then
        return nil, "Image missing from bundle: " .. bundled_path, nil
    end

    return nil, nil, data
end

local function tint_values(tint)
    if not tint then return 255, 255, 255, 255 end
    return tint.r or 255, tint.g or 255, tint.b or 255, tint.a or 255
end

local function build_frames(anim_def, frame_width, frame_height)
    local frames = {}
    local count = anim_def.frames or 1
    local start_x = anim_def.x or 0
    local start_y = anim_def.y or 0
    for index = 1, count do
        frames[index] = {
            x = (start_x + index - 1) * frame_width,
            y = start_y * frame_height,
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

--- @section Loading

--- Loads an image or sprite sheet and returns an Image instance
--- @access mod
--- @param opts table|string `{ path, type?, frame_width?, frame_height?, animations? }` or a direct string path
--- @return Image|nil image Loaded image instance or nil on failure
function Image.load(opts)
    if type(opts) == "string" then
        opts = { path = opts }
    end

    if not opts or not opts.path then
        _log.warn("image.load requires a valid path or options table")
        return nil
    end

    if cache[opts.path] then
        return cache[opts.path]
    end

    local resolved_path, err, bundled_data = resolve_image_path(opts.path)
    local texture

    if bundled_data then
        -- Handle binary bundle loading if needed through backend or temp file creation
        -- (Assuming backend supports loading via resolved path or direct data if extended)
        texture = _backend.load(resolved_path)
    else
        if not resolved_path then
            _log.warn("image failed to find: " .. tostring(opts.path) .. " (" .. tostring(err) .. ")")
            return nil
        end
        texture = _backend.load(resolved_path)
    end

    if not texture then
        _log.warn("image failed to load: " .. tostring(opts.path))
        return nil
    end

    local sprite_data = nil
    if opts.type == "sprite" then
        local fw = opts.frame_width or 16
        local fh = opts.frame_height or 16
        sprite_data = {
            frame_width = fw,
            frame_height = fh,
            frames = opts.animations and build_animations(opts.animations, fw, fh) or {},
        }
    end

    local instance = setmetatable({
        path = opts.path,
        handle = texture,
        sprite = sprite_data,
    }, Image)

    cache[opts.path] = instance
    return instance
end

--- @section Methods

--- Gets image dimensions
--- @return number width Width in pixels
--- @return number height Height in pixels
function Image:get_size()
    if not self.handle then return 0, 0 end
    return _backend.get_size(self.handle)
end

--- Draws the whole image (or a specific sub-region if frame dimensions are specified)
--- @param x number Screen X position
--- @param y number Screen Y position
--- @param scale? number Scale multiplier (default 1.0)
--- @param tint? table Color tint `{r, g, b, a}`
function Image:draw(x, y, scale, tint)
    if not self.handle then return end
    scale = scale or 1

    local width, height = self:get_size()
    _backend.draw(self.handle, 0, 0, width, height, x, y, width * scale, height * scale, tint_values(tint))
end

--- Draws a specific rectangular region of the image sheet
--- @param frame_x number Source rectangle X
--- @param frame_y number Source rectangle Y
--- @param frame_w number Source rectangle width
--- @param frame_h number Source rectangle height
--- @param x number Screen X position
--- @param y number Screen Y position
--- @param scale? number Scale multiplier
--- @param tint? table Color tint
function Image:draw_frame(frame_x, frame_y, frame_w, frame_h, x, y, scale, tint)
    if not self.handle then return end
    scale = scale or 1
    _backend.draw(self.handle, frame_x, frame_y, frame_w, frame_h, x, y, frame_w * scale, frame_h * scale, tint_values(tint))
end

--- Draws a named animation frame (frame index is 1-based)
--- @param anim string Animation name
--- @param frame_idx number Frame index
--- @param x number Screen X position
--- @param y number Screen Y position
--- @param scale? number Scale multiplier
--- @param tint? table Color tint
function Image:draw_sprite(anim, frame_idx, x, y, scale, tint)
    if not self.sprite then
        _log.warn("Attempted to call draw_sprite on a non-sprite image instance")
        return
    end

    local anim_frames = self.sprite.frames[anim]
    local frame = anim_frames and anim_frames[frame_idx]
    
    if not frame then
        self:draw(x, y, scale, tint)
        return
    end

    self:draw_frame(
        frame.x, frame.y,
        self.sprite.frame_width, self.sprite.frame_height,
        x, y, scale, tint
    )
end

--- Unloads this specific image from VRAM
function Image:unload()
    if not self.handle then return end
    _backend.free(self.handle)
    if cache[self.path] == self then
        cache[self.path] = nil
    end
    self.handle = nil
    self.sprite = nil
end

--- Unloads every cached image instance
--- @access game
function Image.cleanup()
    for _, img in pairs(cache) do
        if img and img.unload then
            img:unload()
        end
    end
    cache = {}
end

return Image