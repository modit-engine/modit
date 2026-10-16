--- @module dropdown
--- @file src/engine/sdk/client/ui/overlays/dropdown.lua
--- @description Stateful dropdown menu header and popup overlay component with submenu support.

--- @section Imports

local _draw = require("src.sdk.client.draw2d")
local _font = require("src.sdk.client.font")
local _theme = require("src.sdk.ui.theme")
local _input = require("src.sdk.ui.input")

--- @section Variables

local active_menu_id = nil
local open_sub = nil
local just_opened = false

--- @section Initialisation

local m = {}

--- @section Helpers

local function label_of(item)
    return type(item) == "table" and item.label or item
end

local function children_of(item)
    return type(item) == "table" and item.items or nil
end

local function keep_open_of(item)
    return type(item) == "table" and item.keep_open == true
end

--- @section Functions

function m.close_all()
    active_menu_id = nil
    open_sub = nil
    just_opened = false
end

function m.build(menu_id, label_text, x_pos, y_pos, width, height, items)
    local active_theme = _theme.get()
    
    local is_hovered = _input.in_rect(x_pos, y_pos, width, height)
    local is_clicked = is_hovered and _input.pressed()
    
    local is_open = (active_menu_id == menu_id)

    if is_clicked then
        if is_open then
            m.close_all()
        else
            active_menu_id = menu_id
            open_sub = nil
            just_opened = true
        end
        is_open = (active_menu_id == menu_id)
    end

    local header_bg = (is_hovered or is_open) and active_theme.bg_hover or active_theme.bg_panel
    _draw.set_colour(header_bg)
    _draw.rect(x_pos, y_pos, width, height)

    local font_size = 16
    local text_width = _font.width(font_size, label_text)
    _draw.set_colour(active_theme.text_primary)
    
    -- Ensure correct text rendering position with proper vertical alignment
    _input.text(label_text, x_pos + (width - text_width) / 2, y_pos + (height - font_size) / 2, font_size)

    local selected_index, selected_sub = nil, nil

    if is_open then
        local item_height = 28
        local popup_width = 160
        local popup_height = #items * item_height
        local popup_x = x_pos
        local popup_y = y_pos + height

        local sub_items = open_sub and children_of(items[open_sub]) or nil
        local sub_x = popup_x + popup_width
        local sub_y = popup_y + ((open_sub or 1) - 1) * item_height
        local sub_w = popup_width
        local sub_h = sub_items and #sub_items * item_height or 0

        if _input.pressed() and not just_opened then
            local in_header = _input.in_rect(x_pos, y_pos, width, height)
            local in_popup = _input.in_rect(popup_x, popup_y, popup_width, popup_height)
            local in_sub = sub_items and _input.in_rect(sub_x, sub_y, sub_w, sub_h)

            if not in_header and not in_popup and not in_sub then
                m.close_all()
                return nil
            end
        end
        just_opened = false

        _draw.set_colour(active_theme.bg_panel)
        _draw.rect(popup_x, popup_y, popup_width, popup_height)
        _draw.set_colour(active_theme.border_dark.color)
        _draw.rect_lines(popup_x, popup_y, popup_width, popup_height, 1)

        for index, item in ipairs(items) do
            local item_y = popup_y + (index - 1) * item_height
            local item_hovered = _input.in_rect(popup_x, item_y, popup_width, item_height)
            local item_clicked = item_hovered and _input.pressed()
            local has_children = children_of(item) ~= nil

            if item_hovered then
                open_sub = has_children and index or nil
            end

            if item_hovered or open_sub == index then
                _draw.set_colour(active_theme.bg_hover)
                _draw.rect(popup_x, item_y, popup_width, item_height)
            end

            _draw.set_colour(active_theme.text_primary)
            _input.text(label_of(item), popup_x + 12, item_y + (item_height - font_size) / 2, font_size)
            if has_children then
                _input.text(">", popup_x + popup_width - 20, item_y + (item_height - font_size) / 2, font_size)
            end

            if item_clicked and not has_children then
                selected_index = index
                if not keep_open_of(item) then m.close_all() end
            end
        end

        sub_items = open_sub and children_of(items[open_sub]) or nil
        if sub_items and active_menu_id == menu_id then
            sub_y = popup_y + (open_sub - 1) * item_height
            sub_h = #sub_items * item_height

            _draw.set_colour(active_theme.bg_panel)
            _draw.rect(sub_x, sub_y, sub_w, sub_h)
            _draw.set_colour(active_theme.border_dark.color)
            _draw.rect_lines(sub_x, sub_y, sub_w, sub_h, 1)

            for si, sub_label in ipairs(sub_items) do
                local sy = sub_y + (si - 1) * item_height
                local hovered = _input.in_rect(sub_x, sy, sub_w, item_height)
                local clicked = hovered and _input.pressed()

                if hovered then
                    _draw.set_colour(active_theme.bg_hover)
                    _draw.rect(sub_x, sy, sub_w, item_height)
                end

                _draw.set_colour(active_theme.text_primary)
                _input.text(sub_label, sub_x + 12, sy + (item_height - font_size) / 2, font_size)

                if clicked then
                    selected_index, selected_sub = open_sub, si
                    if not keep_open_of(items[open_sub]) then m.close_all() end
                end
            end
        end
    end

    return selected_index, selected_sub
end

return m