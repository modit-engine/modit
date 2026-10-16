--- @module modal
--- @file src/sdk/ui/overlays/modal.lua
--- @description Confirm/cancel modal dialog overlay component with support for custom renders.

local _draw = require("src.sdk.client.draw2d")
local _input = require("src.sdk.client.input")
local _ui_input = require("src.sdk.ui.input")
local _theme = require("src.sdk.ui.theme")
local _button = require("src.sdk.ui.components.button")
local _label = require("src.sdk.ui.components.label")
local _font = require("src.sdk.client.font")

local DEFAULT_WIDTH = 380
local PAD = 20
local HEADER_H = 44
local BTN_W, BTN_H = 90, 30
local INPUT_H = 30

local current = nil
local m = {}

local function confirm(d)
    if d.on_confirm then
        local err = d.on_confirm(d.input and d.input.text)
        if err then 
            d.error = err 
            return 
        end
    end
    if current == d then m.close() end
end

local function cancel(d)
    m.close()
    if d.on_cancel then d.on_cancel() end
end

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
        render = opts.render,
        width = opts.width or DEFAULT_WIDTH,
        height = opts.height or 380,
        error = nil,
    }
end

function m.is_open() 
    return current ~= nil 
end

function m.close() 
    current = nil 
end

function m.draw(w, h)
    if not current then return end
    local t = _theme.get()
    local d = current

    local width = d.width
    local dh = d.height
    local dx = math.floor((w - width) / 2)
    local dy = math.floor((h - dh) / 2)

    -- Backdrop Overlay
    _draw.set_colour(t.bg_overlay)
    _draw.rect(0, 0, w, h)

    -- Modal Window Box
    _draw.set_colour(t.bg_panel)
    _draw.rect(dx, dy, width, dh)
    _draw.set_colour(t.border_dark.color)
    _draw.rect_lines(dx, dy, width, dh, 1)

    -- Header Bar Background
    _draw.set_colour(t.bg_input)
    _draw.rect(dx, dy, width, HEADER_H)
    _draw.set_colour(t.border_light.color)
    _draw.line(dx, dy + HEADER_H, dx + width, dy + HEADER_H)

    -- Header Title Text
    _draw.set_colour(t.text_primary)
    local font_18 = _font.get(18)
    if font_18 then
        font_18:draw(d.title, dx + PAD, dy + math.floor((HEADER_H - font_18.size) / 2))
    else
        _ui_input.text(d.title, dx + PAD, dy + 13, 18)
    end

    -- Close (X) Button in Header (pure icon button: nil label, "close" icon key)
    if _button(nil, dx + width - 34, dy + 10, 24, 24, { icon = "close", style = "outlined", border = false }) then
        cancel(d)
    end

    -- Content Area (strictly below the header line)
    local content_y = dy + HEADER_H + 1
    local footer_h = d.render and 0 or (BTN_H + 36)
    local content_h = dh - HEADER_H - 1 - footer_h

    if d.render then
        _draw.push_clip(dx, content_y, width, content_h)
        d.render({ x = dx, y = content_y, w = width, h = content_h }, t)
        _draw.pop_clip()
    else
        local py = content_y + 16
        if d.message ~= "" then
            _draw.set_colour(t.text_secondary)
            _ui_input.text(d.message, dx + PAD, py, 16)
            py = py + 28
        end

        local submitted = false
        if d.input then
            submitted = _ui_input.textfield(d.input, dx + PAD, py, width - PAD * 2, INPUT_H, d.filter, d.placeholder)
            py = py + INPUT_H
        end

        if d.error then
            _label(d.error, dx + PAD, py + 8, 16, t.accent3)
            py = py + 24
        end

        local footer_y = dy + dh - BTN_H - 18
        local confirm_x = dx + width - PAD - BTN_W
        local cancel_x = confirm_x - BTN_W - 8

        local confirmed = _button(d.confirm_label, confirm_x, footer_y, BTN_W, BTN_H, {
            size = 16,
            style = d.danger and "danger" or "primary"
        })
        local cancelled = _button(d.cancel_label, cancel_x, footer_y, BTN_W, BTN_H, {
            style = "outlined"
        })

        if confirmed or submitted then
            confirm(d)
        elseif cancelled or _input.key_pressed("escape") then
            cancel(d)
        end
        return
    end

    -- Close on Escape for custom rendered modals
    if _input.key_pressed("escape") then
        cancel(d)
    end
end

return m