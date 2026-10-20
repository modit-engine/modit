--- @module plugins_panel
--- @file src/editor/ui/panels/plugins.lua
--- @description Modal dialog for enabling, removing, adding and inspecting editor plugins.

--- @section Imports

local _engine = require("src.engine")
local _ui = _engine.ui
local _input = _ui.input
local _draw2d = require("src.sdk.client.draw2d")
local _font = require("src.sdk.client.font")
local _plugins = require("src.editor.core.plugins")

--- @section Constants

local CARD_H = 50
local CARD_GAP = 6
local PER_PAGE = 4
local TOGGLE_W, TOGGLE_H = 32, 16
local REMOVE_W = 72
local FOOTER_H = 44

--- @section Initialisation

local m = {}

local page = 1
local pending_remove = nil

--- @section Helpers

local function draw_text(size, str, x, y, colour)
    local font_obj = _font.get(size)
    if font_obj then
        _draw2d.set_colour(colour)
        font_obj:draw(str, x, y)
    else
        _ui.label(str, x, y, size, colour)
    end
end

local function truncate(text, max)
    text = tostring(text)
    if #text > max then return text:sub(1, max - 3) .. "..." end
    return text
end

local function add_from_folder()
    local ok, picker = pcall(require, "src.editor.core.folder_picker")
    if not ok then
        _ui.push_toast("Folder picker is unavailable", "error")
        return
    end

    local folder, err = picker.choose("Choose a plugin folder")
    if not folder then
        if err then _ui.push_toast(err, "error") end
        return
    end

    local name, install_err = _plugins.install(folder)
    if name and not install_err then
        _ui.push_toast("Installed plugin: " .. name, "success")
    elseif name then
        _ui.push_toast("Installed, but it failed to load: " .. install_err, "error")
    else
        _ui.push_toast("Install failed: " .. tostring(install_err), "error")
    end
end

local function draw_card(entry, x, y, w, t)
    _draw2d.set_colour(t.bg_input)
    _draw2d.rect(x, y, w, CARD_H)
    _draw2d.set_colour(t.border_dark.color)
    _draw2d.rect_lines(x, y, w, CARD_H, 1)

    local config = entry.config
    local title = config and ((config.label or config.name) .. " (v" .. (config.version or "1.0") .. ")") or entry.name
    local right = x + w - 8

    local remove_x = right - REMOVE_W
    local confirming = pending_remove == entry.name
    if _ui.button(confirming and "Confirm?" or "Remove", remove_x, y + (CARD_H - 26) / 2, REMOVE_W, 26, {
        size = 14,
        style = confirming and "primary" or "outlined",
    }) then
        if confirming then
            pending_remove = nil
            local ok, err = _plugins.remove(entry.name)
            if ok then
                _ui.push_toast("Removed plugin: " .. entry.name, "success")
            else
                _ui.push_toast("Could not remove: " .. tostring(err), "error")
            end
        else
            pending_remove = entry.name
        end
    end

    local text_limit = 52
    if config then
        local toggle_x = remove_x - TOGGLE_W - 12
        local toggle_y = y + (CARD_H - TOGGLE_H) / 2
        local _, clicked = _input.interact(toggle_x, toggle_y, TOGGLE_W, TOGGLE_H)
        _ui.toggle(entry.enabled, toggle_x, toggle_y, TOGGLE_W, TOGGLE_H, { passive = true })
        if clicked then
            local ok, err = _plugins.set_enabled(entry.name, not entry.enabled)
            if not ok then
                _ui.push_toast("Plugin error: " .. tostring(err), "error")
            end
        end
        text_limit = math.max(20, math.floor((toggle_x - x - 24) / 7))
    else
        text_limit = math.max(20, math.floor((remove_x - x - 24) / 7))
    end

    draw_text(14, truncate(title, text_limit), x + 12, y + 7, t.text_primary)

    local sub, colour
    if not config then
        sub, colour = "Invalid: " .. tostring(entry.error), t.accent3
    elseif entry.error then
        sub, colour = "Failed: " .. entry.error, t.accent3
    elseif not entry.enabled then
        sub, colour = "Disabled - " .. (config.author or "Unknown author"), t.text_tertiary
    else
        sub, colour = (config.author or "Unknown author") .. " - " .. entry.name, t.text_secondary
    end
    draw_text(12, truncate(sub, text_limit + 4), x + 12, y + 28, colour)
end

local function render(r, t)
    local x = r.x + 16
    local y = r.y + 16
    local inner_w = r.w - 32

    draw_text(16, "Manage Plugins", x, y, t.text_primary)
    draw_text(14, "Toggle, remove or add extensions in the plugins folder.", x, y + 22, t.text_secondary)
    y = y + 54

    local list = _plugins.list()
    local pages = math.max(1, math.ceil(#list / PER_PAGE))
    page = math.max(1, math.min(page, pages))

    if #list == 0 then
        draw_text(14, "No plugins installed.", x, y + 10, t.text_tertiary)
    else
        local first = (page - 1) * PER_PAGE + 1
        for i = first, math.min(#list, first + PER_PAGE - 1) do
            draw_card(list[i], x, y, inner_w, t)
            y = y + CARD_H + CARD_GAP
        end
    end

    -- Footer
    local fy = r.y + r.h - FOOTER_H
    if _ui.button("Add Plugin...", x, fy, 120, 30, { size = 14, style = "primary" }) then
        add_from_folder()
    end
    if _ui.button("Reload All", x + 128, fy, 100, 30, { size = 14, style = "outlined" }) then
        _plugins.load_all()
        _ui.push_toast("Plugins reloaded", "success")
    end

    if pages > 1 then
        local px = r.x + r.w - 16 - 150
        if _ui.button("<", px, fy, 30, 30, { size = 14, style = "outlined" }) and page > 1 then
            page = page - 1
        end
        draw_text(14, page .. " / " .. pages, px + 46, fy + 7, t.text_secondary)
        if _ui.button(">", px + 120, fy, 30, 30, { size = 14, style = "outlined" }) and page < pages then
            page = page + 1
        end
    end
end

--- @section Functions

--- Opens the plugins manager modal dialog.
function m.open()
    pending_remove = nil
    page = 1
    _ui.open_modal({
        title = "Plugins",
        width = 540,
        height = 400,
        render = render,
    })
end

return m