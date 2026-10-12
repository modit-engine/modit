--- @module modal
--- @file src/editor/ui/components/modal.lua
--- @description Confirm/cancel modal dialog overlay component with optional text input field.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.render.draw")
local _keyboard = require("src.engine.modules.input.keyboard")

--- Editor
local _input = require("src.engine.ui.modules.input")
local _theme = require("src.engine.ui.modules.theme")
local _button = require("src.engine.ui.components.button")
local _label = require("src.engine.ui.components.label")

--- @section Constants

local WIDTH = 380
local PAD = 20
local HEADER_H = 44
local BTN_W, BTN_H = 90, 30
local INPUT_H = 30

--- @section Variables

local current = nil

--- @section Initialisation

local m = {}

--- @section Helpers

local function confirm(d)
    if d.on_confirm then
        local err = d.on_confirm(d.input and d.input.text)
        if err then 
            d.error = err 
            return 
        end
    end
    if current == d then 
        m.close() 
    end
end

local function cancel(d)
    m.close()
    if d.on_cancel then 
        d.on_cancel() 
    end
end

--- @section Functions

--- Opens a modal dialog with configuration options
--- @param opts table Configuration options { title, message, input, filter, placeholder, confirm_label, cancel_label, on_confirm, on_cancel, danger }
function m.open(opts)
    current = {
        title = opts.title or "Confirm",
        message = opts.message or "",
        input = opts.input,
        filter = opts.filter,
        placeholder = opts.placeholder,
        confirm_label = opts.confirm_label or "OK",
        cancel_label = opts.cancel_label or "Cancel",
        danger = opts.danger,
        on_confirm = opts.on_confirm,
        on_cancel = opts.on_cancel,
        error = nil,
    }
end

--- Checks if a modal dialog is currently active and open
--- @return boolean open True if modal is open
function m.is_open() 
    return current ~= nil 
end

--- Closes the currently active modal dialog
function m.close() 
    current = nil 
end

--- Renders active modal overlay and processes user inputs
--- @param w number Total screen width in pixels
--- @param h number Total screen height in pixels
function m.draw(w, h)
    if not current then return end
    local t = _theme.get()
    local d = current

    local has_msg = d.message ~= ""
    local base_h = HEADER_H + 16
        + (has_msg and 28 or 0)
        + (d.input and INPUT_H or 0)
        + 20 + BTN_H + 16
    local dh = base_h + (d.error and 24 or 0)

    local dx = math.floor((w - WIDTH) / 2)
    local dy = math.floor((h - base_h) / 2)

    -- Backdrop
    _draw.set_colour(t.bg_overlay)
    _draw.rect(0, 0, w, h)

    -- Box
    _draw.set_colour(t.bg_panel)
    _draw.rect(dx, dy, WIDTH, dh)
    _draw.set_colour(t.border_dark.color)
    _draw.rect_lines(dx, dy, WIDTH, dh, 1)

    -- Header
    _draw.set_colour(t.text_primary)
    _input.text(d.title, dx + PAD, dy + 13, 18)

    _draw.set_colour(t.border_light.color)
    _draw.line(dx, dy + HEADER_H, dx + WIDTH, dy + HEADER_H)

    -- Body
    local y = dy + HEADER_H + 16
    if has_msg then
        _draw.set_colour(t.text_secondary)
        _input.text(d.message, dx + PAD, y, 16)
        y = y + 28
    end

    local submitted = false
    if d.input then
        submitted = _input.textfield(d.input, dx + PAD, y, WIDTH - PAD * 2, INPUT_H, d.filter, d.placeholder)
        y = y + INPUT_H
    end

    if d.error then
        _label(d.error, dx + PAD, y + 8, 16, t.accent3)
        y = y + 24
    end

    -- Footer
    y = y + 20
    local confirm_x = dx + WIDTH - PAD - BTN_W
    local cancel_x = confirm_x - BTN_W - 8

    local confirmed = _button(d.confirm_label, confirm_x, y, BTN_W, BTN_H, 16, nil, d.danger and "danger" or "primary")
    local cancelled = _button(d.cancel_label, cancel_x, y, BTN_W, BTN_H, 16, nil, "outlined")

    if confirmed or submitted then
        confirm(d)
    elseif cancelled or _keyboard.pressed("escape") then
        cancel(d)
    end
end

return m