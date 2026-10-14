--- @module font
--- @file src/engine/modules/font.lua
--- @description Object-oriented font handle: loading, glyph caching, text measurement, and rendering.

local _backend = require("src.engine.backend").font
local _draw = require("src.engine.sdk.client.draw")

--- @class Font
--- @field handle cdata Raylib font handle
--- @field size number Font size in pixels
--- @field cell_w number Average character cell width
local Font = {}
Font.__index = Font

--- Default fallback font path
Font.default_path = "src/engine/assets/fonts/JetBrainsMono-Regular.ttf"

--- Internal cache mapping path -> size -> Font instance
local cache = {}

--- @section Loading & Caching

--- Loads a font at specified pixel size and returns a Font instance
--- @param path string File path to TTF/OTF font
--- @param size number Font size in pixels
--- @param codepoints table|nil Optional array of character codepoints to load
--- @return Font|nil font Loaded Font instance or nil on failure
--- @return string|nil err Error message if loading failed
function Font.load(path, size, codepoints)
    local file = io.open(path, "rb")
    if not file then
        return nil, "Font not found: " .. path
    end
    file:close()

    local handle = _backend.load(path, size, codepoints)
    if not handle then
        return nil, "Could not load font: " .. path
    end

    return setmetatable({
        handle = handle,
        size = size,
        cell_w = _backend.measure(handle, "MMMMMMMMMM", size) / 10,
        path = path,
    }, Font)
end

--- Retrieves cached font instance or loads it on demand
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
    _backend.font_free(self.handle)

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