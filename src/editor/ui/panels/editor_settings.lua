--- @module editor_settings
--- @file src/editor/ui/panels/editor_settings.lua
--- @description Editor settings modal with category sidebar, toggle switches and theme picker.

--- @section Imports

local _engine = require("src.engine")
local _ui = _engine.ui
local _input = _ui.input
local draw = require("src.sdk.client.draw2d")
local _font = require("src.sdk.client.font")
local theme = _ui.theme
local settings = require("src.editor.core.settings")
local themes = require("src.editor.ui.style.themes")
local images = require("src.editor.ui.panels.image")

--- @section Constants

local SIDEBAR_WIDTH = 120
local SIDEBAR_PAD = 8
local SIDEBAR_BTN_H = 26
local SIDEBAR_BTN_GAP = 6
local ROW_H = 40
local ROW_GAP = 4
local TOGGLE_W, TOGGLE_H = 32, 16
local THEME_BTN_H = 26

--- @section Initialisation

local category = "General"
local m = {}

--- @section Helpers

--- Persists the active theme and settings
local function save()
    settings.set_theme(theme.name())
    settings.save()
end

--- Draws text with the SDK font, falling back to a label
--- @param size number Font size in pixels
--- @param str string Text to draw
--- @param x number X position
--- @param y number Y position
--- @param colour table Text colour
local function draw_text(size, str, x, y, colour)
    local font_obj = _font.get(size)
    if font_obj then
        draw.set_colour(colour)
        font_obj:draw(str, x, y)
    else
        _ui.label(str, x, y, size, colour)
    end
end

--- Draws a clickable settings row with a toggle switch
--- @param key string Settings key to toggle
--- @param label string Row title
--- @param description string Row description
--- @param x number X position
--- @param y number Y position
--- @param w number Row width
--- @param t table Active theme
local function toggle_row(key, label, description, x, y, w, t)
    local over, clicked = _input.interact(x, y, w, ROW_H)

    if over then
        draw.set_colour(t.bg_hover)
        draw.rect(x, y, w, ROW_H)
    end

    draw_text(16, label, x + 8, y + 4, t.text_primary)
    draw_text(14, description, x + 8, y + 22, t.text_secondary)

    _ui.toggle(settings[key] and true or false, x + w - TOGGLE_W - 8, y + (ROW_H - TOGGLE_H) / 2, TOGGLE_W, TOGGLE_H, { passive = true })

    if clicked then
        settings[key] = not settings[key]
        if key == "show_file_previews" and not settings[key] then
            images.clear_thumbnails()
        end
        save()
    end
end

--- @section Rendering

--- Renders the modal contents
--- @param r table Content rectangle { x, y, w, h }
--- @param t table Active theme
local function render(r, t)
    -- Sidebar
    draw.set_colour(t.bg_input)
    draw.rect(r.x, r.y, SIDEBAR_WIDTH, r.h)
    draw.set_colour(t.border_dark.color)
    draw.line(r.x + SIDEBAR_WIDTH, r.y, r.x + SIDEBAR_WIDTH, r.y + r.h)

    local categories = { "General", "View", "Themes" }
    for i, name in ipairs(categories) do
        local btn_y = r.y + SIDEBAR_PAD + (i - 1) * (SIDEBAR_BTN_H + SIDEBAR_BTN_GAP)
        local is_selected = category == name
        if _ui.button(name, r.x + SIDEBAR_PAD, btn_y, SIDEBAR_WIDTH - SIDEBAR_PAD * 2, SIDEBAR_BTN_H, {
            size = 14,
            style = is_selected and "primary" or "outlined",
        }) then
            category = name
        end
    end

    -- Content
    local x = r.x + SIDEBAR_WIDTH + 12
    local y = r.y + 12
    local inner_w = r.w - SIDEBAR_WIDTH - 24

    if category == "General" then
        draw_text(16, "General Preferences", x, y, t.text_primary)
        draw_text(14, "Manage core editor behaviour and session defaults.", x, y + 24, t.text_secondary)

    elseif category == "View" then
        draw_text(16, "View & Layout", x, y, t.text_primary)
        y = y + 28
        toggle_row("show_file_previews", "File Previews", "Small image thumbnails in the Files panel.", x, y, inner_w, t)
        toggle_row("minimap", "Minimap", "Show code overview panel beside editor.", x, y + ROW_H + ROW_GAP, inner_w, t)

    elseif category == "Themes" then
        draw_text(16, "Color Themes", x, y, t.text_primary)
        y = y + 28
        for i, key in ipairs(themes.keys) do
            local is_active = theme.name() == key
            if _ui.button(themes.labels[i], x, y, inner_w, THEME_BTN_H, {
                size = 14,
                style = is_active and "primary" or "outlined",
            }) then
                theme.set(key)
                save()
            end
            y = y + THEME_BTN_H + SIDEBAR_BTN_GAP
        end
    end
end

--- @section Functions

--- Opens the editor settings modal
function m.open()
    _ui.open_modal({
        title = "Editor Settings",
        width = 560,
        height = 340,
        render = render,
    })
end

return m