--- @module icons
--- @file src/sdk/ui/icons.lua
--- @description Lucide icon font rendering helper for UI controls, matching active theme colors.

--- @section Imports

local _font = require("src.sdk.client.font")

--- @section Constants

local FONT_PATH = "src/engine/assets/fonts/lucide.ttf"

local ICON_CODES = {
    play = 0xE13C,       -- icon-play
    pause = 0xE12E,      -- icon-pause
    stop = 0xE167,       -- icon-square
    reload = 0xE145,     -- icon-refresh-cw
    delete = 0xE18E,     -- icon-trash-2
    new_file = 0xE0C9,   -- icon-file-plus
    new_folder = 0xE0D9, -- icon-folder-plus
    close = 0xE1B2,      -- icon-x
}

--- @section Initialisation

local codepoint_list = {}
for _, codepoint in pairs(ICON_CODES) do
    codepoint_list[#codepoint_list + 1] = codepoint
end

--- Encodes a Unicode codepoint into UTF-8 character string bytes
--- @param codepoint number Unicode codepoint integer
--- @return string byte_str Encoded UTF-8 byte string
local function encode_utf8(codepoint)
    if codepoint < 0x80 then
        return string.char(codepoint)
    elseif codepoint < 0x800 then
        return string.char(0xC0 + math.floor(codepoint / 64), 0x80 + codepoint % 64)
    else
        return string.char(0xE0 + math.floor(codepoint / 4096), 0x80 + math.floor(codepoint / 64) % 64, 0x80 + codepoint % 64)
    end
end

local glyph_strings = {}
for name, codepoint in pairs(ICON_CODES) do
    glyph_strings[name] = encode_utf8(codepoint)
end

local font_cache = {}

local m = {}

--- @section Helpers

--- Loads or retrieves cached icon font instance for requested pixel size
--- @param size number Pixel height/size of requested font
--- @return Font|boolean font_instance Loaded Font object or false if failed
local function get_icon_font(size)
    local cached_font = font_cache[size]
    if cached_font == nil then
        local loaded, err = _font.load(FONT_PATH, size, codepoint_list)
        if not loaded then
            print("[icons] " .. tostring(err))
        end
        cached_font = loaded or false
        font_cache[size] = cached_font
    end
    return cached_font
end

--- @section Functions

--- Draws a Lucide icon centered inside a bounding rectangle using active draw color
--- @param name string Icon name key (play | pause | stop | reload | delete | new_file | new_folder | close)
--- @param rect_x number Box X position
--- @param rect_y number Box Y position
--- @param rect_w number Box width
--- @param rect_h number Box height
--- @param size? number Icon size in pixels (defaults to 16)
function m.draw(name, rect_x, rect_y, rect_w, rect_h, size)
    size = size or 16
    local font_instance = get_icon_font(size)
    local glyph = glyph_strings[name]
    if not font_instance or not glyph then return end

    local text_w = font_instance:measure(glyph)
    font_instance:draw(glyph, math.floor(rect_x + (rect_w - text_w) / 2), math.floor(rect_y + (rect_h - size) / 2))
end

return m