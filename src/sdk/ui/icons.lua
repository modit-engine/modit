--- @module icons
--- @file src/sdk/ui/icons.lua
--- @description Lucide icon font rendering helper for UI controls, matching active theme colors.

--- @section Imports

local _font = require("src.sdk.client.font")

--- @section Constants

local FONT_PATH = "src/engine/assets/fonts/lucide.ttf"

local ICON_CODES = {
    play = 0xE13C,
    pause = 0xE12E,
    stop = 0xE167,
    reload = 0xE145,
    delete = 0xE18E,
    new_file = 0xE0C9,
    new_folder = 0xE0D9,
    close = 0xE1B2,
    fish = 0xE3A6,
    fish_hook = 0xE6E4,
    fish_rod = 0xE6B3,
    store = 0xE3E4,
    wallet = 0xE204,
    hand = 0xE1D7,
}

--- @section Initialisation

local codepoint_list = {}
local known_codepoints = {}
for _, codepoint in pairs(ICON_CODES) do
    codepoint_list[#codepoint_list + 1] = codepoint
    known_codepoints[codepoint] = true
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
local retired = {} -- fonts replaced by a rebuild; freed later by m.flush(), never mid-draw
local code_cache = {} -- normalised hex ("E585") -> glyph string
local warned = {}

local m = {}

--- @section Helpers

--- Turns user input into a normalised 4-digit upper-case hex string, or nil if it is not a code.
--- Accepts "e585", "E585", and the common copy-paste forms "\e585", "0xE585", "U+E585".
--- @param text string Raw icon code text
--- @return string|nil hex Upper-case 4-digit hex, e.g. "E585"
local function parse_code(text)
    local hex = text:gsub("^\\", ""):gsub("^0[xX]", ""):gsub("^[uU]%+", ""):gsub(";$", "")
    if not hex:match("^%x%x%x%x$") then return nil end
    return hex:upper()
end

--- Makes sure a codepoint is part of the icon font. Adding a new one drops the font cache so the
--- font is rebuilt with it on the next draw.
--- @param codepoint number Unicode codepoint integer
local function register_codepoint(codepoint)
    if known_codepoints[codepoint] then return end
    known_codepoints[codepoint] = true
    codepoint_list[#codepoint_list + 1] = codepoint
    for _, old in pairs(font_cache) do
        if old then retired[#retired + 1] = old end
    end
    font_cache = {}
end

--- Resolves a name or hex code to its glyph string. Names win over codes, so an icon called "face" or
--- "dead" still means the named icon.
--- @param name string Icon name key or 4-digit hex code
--- @return string|nil glyph UTF-8 glyph string, or nil when unknown
local function resolve_glyph(name)
    if type(name) ~= "string" then return nil end

    local glyph = glyph_strings[name]
    if glyph then return glyph end

    local hex = parse_code(name)
    if not hex then
        if not warned[name] then
            warned[name] = true
            print("[icons] unknown icon: " .. name)
        end
        return nil
    end

    glyph = code_cache[hex]
    if not glyph then
        local codepoint = tonumber(hex, 16)
        glyph = encode_utf8(codepoint)
        code_cache[hex] = glyph
        register_codepoint(codepoint)
    end
    return glyph
end

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

--- Registers icon codes up front so the font is built once, instead of rebuilding the first time each
--- code is drawn. Call at boot with every code the game uses.
--- @param codes table Array of names or 4-digit hex codes
function m.preload(codes)
    for _, name in ipairs(codes) do resolve_glyph(name) end
    m.flush()
end

--- Frees fonts that a rebuild replaced. Call once per frame from update (outside any draw pass):
--- unloading in the middle of a frame could free a font whose glyphs are still queued to draw.
function m.flush()
    for i = #retired, 1, -1 do
        retired[i]:unload()
        retired[i] = nil
    end
end

--- Draws a Lucide icon centered inside a bounding rectangle using active draw color
--- @param name string Icon name (play | pause | stop | reload | delete | new_file | new_folder | close | fish | fish_hook | fish_rod | store | wallet | hand) or a 4-digit hex code such as "e585"
--- @param rect_x number Box X position
--- @param rect_y number Box Y position
--- @param rect_w number Box width
--- @param rect_h number Box height
--- @param size? number Icon size in pixels (defaults to 16)
function m.draw(name, rect_x, rect_y, rect_w, rect_h, size)
    size = size or 16
    local glyph = resolve_glyph(name) -- before the font lookup: a new code resets the font cache
    if not glyph then return end

    local font_instance = get_icon_font(size)
    if not font_instance then return end

    local text_w = font_instance:measure(glyph)
    font_instance:draw(glyph, math.floor(rect_x + (rect_w - text_w) / 2), math.floor(rect_y + (rect_h - size) / 2))
end

return m