--- @module scroll
--- @file src/editor/ui/components/scroll.lua
--- @description Stateful clip container and vertical scrollbar rendering component.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")

--- Editor
local _input = require("src.engine.ui.input")
local _theme = require("src.engine.ui.style.theme")

--- @section Constants

local SCROLL_SPEED = 54

--- @section Variables

local stack = {}
local depth = 0

--- @section Initialisation

local m = {}

--- @section Functions

--- Begins a scroll viewport clip area and updates scroll position based on mouse wheel input
--- @param state table Scroll state object containing y offset ({ y = 0 })
--- @param x number X screen coordinate
--- @param y number Y screen coordinate
--- @param w number Viewport width in pixels
--- @param h number Viewport height in pixels
--- @param content_h number Total height of scrollable inner content in pixels
--- @return number max Maximum vertical scroll offset in pixels
function m.begin(state, x, y, w, h, content_h)
    local max = math.max(0, content_h - h)
    local wheel = _input.wheel()

    if wheel ~= 0 and _input.in_rect(x, y, w, h) then
        state.y = state.y - wheel * SCROLL_SPEED
    end
    state.y = math.max(0, math.min(state.y, max))

    depth = depth + 1
    local e = stack[depth]
    if not e then 
        e = {}
        stack[depth] = e 
    end
    e.state, e.x, e.y, e.w, e.h, e.content, e.max = state, x, y, w, h, content_h, max

    _draw.push_clip(x, y, w, h)
    return max
end

--- Closes active scroll viewport, renders scrollbar track and thumb if needed, and restores scissor rect
function m.finish()
    local e = stack[depth]
    depth = depth - 1

    if e.max > 0 then
        local t = _theme.get()
        local bar_w = 6
        local bx = e.x + e.w - bar_w - 2
        local track_h = e.h - 4
        local thumb_h = math.max(24, track_h * e.h / e.content)
        local thumb_y = e.y + 2 + (track_h - thumb_h) * (e.state.y / e.max)

        _draw.set_colour(t.scrollbar_track)
        _draw.rect(bx, e.y + 2, bar_w, track_h)
        _draw.set_colour(t.scrollbar_thumb)
        _draw.rect(bx, thumb_y, bar_w, thumb_h)
    end

    _draw.pop_clip()
end

return m