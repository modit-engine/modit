--- @module layout
--- @file src/editor/ui/layout.lua
--- @description Geometry calculations and state storage for editor layout regions including toolbar, sidebars, central viewport, and bottom panel.

--- @section Imports

local _math = require("src.sdk.shared.math")

--- @section Constants

local TOOLBAR_H = 30
local MIN_SIDE = 140
local MIN_BOTTOM = 60
local MIN_CENTRE_W = 240
local MIN_CENTRE_H = 120

--- @section Initialisation

local layout_rects = {
    toolbar = { x = 0, y = 0, w = 0, h = 0 },
    left = { x = 0, y = 0, w = 0, h = 0 },
    right = { x = 0, y = 0, w = 0, h = 0 },
    bottom = { x = 0, y = 0, w = 0, h = 0 },
    viewport = { x = 0, y = 0, w = 0, h = 0 },
}

local m = {
    sizes = {
        left = 220,
        right = 280,
        bottom = 180,
    }
}

--- @section Helpers

--- Updates position and dimensions for a specific layout bounding rectangle
--- @param target table Layout rectangle table to modify { x, y, w, h }
--- @param pos_x number X coordinate
--- @param pos_y number Y coordinate
--- @param width number Rectangle width
--- @param height number Rectangle height
local function set_rect(target, pos_x, pos_y, width, height)
    target.x, target.y, target.w, target.h = pos_x, pos_y, width, height
end

--- @section Functions

--- Computes active editor region layout bounds for current window dimensions and panel visibilities
--- @param window_w number Total window width in pixels
--- @param window_h number Total window height in pixels
--- @param show_left boolean Whether the left panel is visible
--- @param show_right boolean Whether the right panel is visible
--- @param show_bottom boolean Whether the bottom panel is visible
--- @return table layout_rects Dictionary of calculated region rectangles
function m.shell(window_w, window_h, show_left, show_right, show_bottom)
    local sizes = m.sizes
    local body_h = window_h - TOOLBAR_H

    local left_w, right_w, bottom_h = 0, 0, 0

    if show_right then 
        right_w = _math.clamp(sizes.right, MIN_SIDE, window_w - MIN_CENTRE_W - MIN_SIDE) 
    end
    if show_left then 
        left_w = _math.clamp(sizes.left, MIN_SIDE, window_w - right_w - MIN_CENTRE_W) 
    end
    if show_right then 
        right_w = _math.clamp(sizes.right, MIN_SIDE, window_w - left_w - MIN_CENTRE_W) 
    end
    if show_bottom then 
        bottom_h = _math.clamp(sizes.bottom, MIN_BOTTOM, body_h - MIN_CENTRE_H) 
    end

    if show_left then sizes.left = left_w end
    if show_right then sizes.right = right_w end
    if show_bottom then sizes.bottom = bottom_h end

    local centre_w = window_w - left_w - right_w

    set_rect(layout_rects.toolbar, 0, 0, window_w, TOOLBAR_H)
    set_rect(layout_rects.left, 0, TOOLBAR_H, left_w, body_h)
    set_rect(layout_rects.right, window_w - right_w, TOOLBAR_H, right_w, body_h)
    set_rect(layout_rects.viewport, left_w, TOOLBAR_H, centre_w, body_h - bottom_h)
    set_rect(layout_rects.bottom, left_w, window_h - bottom_h, centre_w, bottom_h)

    return layout_rects
end

return m