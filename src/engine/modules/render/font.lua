--- @module font
--- @file src/engine/modules/font.lua
--- @description Font mod loading, glyph caching, text measurement, and rendering facade. 

--- @section Imports

local _backend = require("src.engine.backend").font
local _draw = require("src.engine.modules.render.draw") 

--- @section Initialisation

local m = {
    default_path = "src/assets/fonts/JetBrainsMono-Regular.ttf", 
}

local cache = {} 

--- @section Loading & Caching

--- Loads a font at specified pixel size 
--- @param path string File path to TTF/OTF font 
--- @param size number Font size in pixels 
--- @param codepoints table|nil Optional array of character codepoints to load 
--- @return table|nil font Font handle table `{handle, size, cell_w}` or nil on failure 
--- @return string|nil err Error message if loading failed 
function m.load(path, size, codepoints)
    local file = io.open(path, "rb") 
    if not file then
        return nil, "Font not found: " .. path 
    end
    file:close() 

    local handle = _backend.load(path, size, codepoints)
    if not handle then
        return nil, "Could not load font: " .. path 
    end

    return {
        handle = handle, 
        size = size, 
        cell_w = _backend.measure(handle, "MMMMMMMMMM", size) / 10, 
    }
end

--- Frees a loaded font mod and invalidates cache entries 
--- @param f table Font table instance to unload 
function m.free(f)
    _backend.font_free(f.handle) 

    for _, by_size in pairs(cache) do 
        for size, cached in pairs(by_size) do 
            if cached == f then
                by_size[size] = nil 
            end
        end
    end
end

--- Retrieves cached font instance or loads it on demand 
--- @param size number Font size in pixels 
--- @param path string|nil File path (defaults to `m.default_path`) 
--- @return table|nil font Cached font table or nil if loading failed 
function m.get(size, path)
    path = path or m.default_path 

    local by_size = cache[path] 
    if not by_size then
        by_size = {} 
        cache[path] = by_size 
    end

    local f = by_size[size] 
    if f == nil then
        f = m.load(path, size) or false 
        by_size[size] = f 
    end

    return f or nil 
end

--- @section Rendering & Measurement

--- Draws text string using specified font handle and current drawing color 
--- @param f table Font handle instance 
--- @param text string Text string to draw 
--- @param x number Screen X position 
--- @param y number Screen Y position 
function m.draw(f, text, x, y)
    _backend.text(f.handle, text, x, y, f.size) 
end

--- Measures dimensions of text string for specified font handle 
--- @param f table Font handle instance 
--- @param text string Text string to measure 
--- @return number width Width of text string in pixels 
--- @return number height Height of text string in pixels 
function m.measure(f, text)
    return _backend.measure(f.handle, text, f.size) 
end

--- Measures text width at given size using cached font or default draw module fallback 
--- @param size number Font size in pixels 
--- @param text string Text string to measure 
--- @return number width Text width in pixels 
function m.width(size, text)
    local f = m.get(size) 
    if f then
        return m.measure(f, text) 
    end
    return _draw.measure_text(text, size) 
end

return m 