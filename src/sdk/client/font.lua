--- @module font
--- @file src/sdk/client/font.lua
--- @description Object-oriented font handle: loading, glyph caching, text measurement, and rendering.

local _backend = require("src.engine.backend").font
local _draw = require("src.sdk.client.draw2d")

--- @class Font
--- @field handle cdata Raylib font handle
--- @field size number Font size in pixels
--- @field cell_w number Average character cell width
local Font = {}
Font.__index = Font
Font.default_path = "src/engine/assets/fonts/JetBrainsMono-Regular.ttf"

--- Internal cache mapping path -> size -> Font instance
local cache = {}

--- @section Helpers

local function resolve_font_path(path)
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
        return nil, "Font not found: " .. path, nil
    end

    local ok, data = pcall(bundle.get, bundled_path)
    if not ok or type(data) ~= "string" or #data == 0 then
        return nil, "Font missing from bundle: " .. bundled_path, nil
    end

    return nil, nil, data
end

--- @section Loading & Caching

--- Loads a font at specified pixel size and returns a Font instance
--- @access mod
--- @param path string File path to TTF/OTF font
--- @param size number Font size in pixels
--- @param codepoints table|nil Optional array of character codepoints to load
--- @return Font|nil font Loaded Font instance or nil on failure
--- @return string|nil err Error message if loading failed

function Font.load(path, size, codepoints)
    local resolved_path, err, bundled_data = resolve_font_path(path)

    if not resolved_path and not bundled_data then
        return nil, err
    end

    local temp_path

    if bundled_data then
        local temp_name = string.format("modit_font_%d_%d.ttf", os.time(), math.random(100000, 999999))

        local temp_file, open_err = io.open(temp_name, "wb")
        if not temp_file then
            return nil, "Could not create temporary font file '" .. temp_name .. "': " .. tostring(open_err)
        end

        local write_ok, write_err = temp_file:write(bundled_data)
        temp_file:close()

        if not write_ok then
            os.remove(temp_name)
            return nil, "Could not write temporary font file: " .. tostring(write_err)
        end

        temp_path = temp_name
        resolved_path = temp_path
        print("[font] extracted bundled font to: " .. temp_path)
    end

    local handle, load_err = _backend.load(resolved_path, size, codepoints)

    if temp_path then
        os.remove(temp_path)
    end

    if not handle then
        return nil, load_err or ("Could not load font: " .. path)
    end

    return setmetatable({
        handle = handle,
        size = size,
        cell_w = _backend.measure(handle, "MMMMMMMMMM", size) / 10,
        path = path,
    }, Font)
end


--- Retrieves cached font instance or loads it on demand
--- @access mod
--- @param size number Font size in pixels
--- @param path string|nil File path (defaults to Font.default_path)
--- @return Font|nil font Cached Font instance or nil if loading failed
function Font.get(size, path)
    path = path or Font.default_path

    local by_size = cache[path]
    if not by_size then
        by_size = {}
        cache[path] = by_size
    end

    local f = by_size[size]
    if f == nil then
        f = Font.load(path, size) or false
        by_size[size] = f
    end

    return f or nil
end

--- @section Methods

--- Draws text string using this font instance and current drawing color
--- @param text string Text string to draw
--- @param x number Screen X position
--- @param y number Screen Y position
function Font:draw(text, x, y)
    if not self.handle then return end
    _backend.text(self.handle, text, x, y, self.size)
end

--- Measures dimensions/width of text string for this font instance
--- @param text string Text string to measure
--- @return number width Width of text string in pixels
function Font:measure(text)
    if not self.handle then return 0 end
    return _backend.measure(self.handle, text, self.size)
end

--- Unloads this font instance from VRAM and clears cache references
function Font:unload()
    if not self.handle then return end
    _backend.free(self.handle)

    for _, by_size in pairs(cache) do
        for size, cached in pairs(by_size) do
            if cached == self then
                by_size[size] = nil
            end
        end
    end
    self.handle = nil
end

--- @section Static Helpers

--- Measures text width at given size using cached font or default draw module fallback
--- @access mod
--- @param size number Font size in pixels
--- @param text string Text string to measure
--- @return number width Text width in pixels
function Font.width(size, text)
    local f = Font.get(size)
    if f then
        return f:measure(text)
    end
    return _draw.measure_text(text, size)
end

--- Unloads all cached fonts
--- @access game
function Font.cleanup()
    for _, by_size in pairs(cache) do
        for _, f in pairs(by_size) do
            if f and f.unload then
                f:unload()
            end
        end
    end
    cache = {}
end

return Font