--- @module new_project
--- @file src/editor/ui/panels/new_project.lua
--- @description New project screen with a name field and template picker.

--- @section Imports

local _draw = require("src.engine.modules.draw")
local _input = require("src.engine.ui.modules.input")
local _components = require("src.engine.ui.components")
local _session = require("src.editor.core.session")
local _bp = require("src.editor.core.boilerplate")

--- @section Constants

local ROW_H = 52
local FIELD_H = 30

--- @section Initialisation

local m = {}

local state = { open = false, name = { text = "" }, selected = 1, error = nil }

--- @section Functions

--- Shows the screen with a clean form
function m.open()
    state.open = true
    state.name.text = ""
    state.error = nil
    state.selected = 1
    for index, template in ipairs(_bp.templates) do
        if template.id == _bp.default then state.selected = index end
    end
end

function m.close() state.open = false end

--- @return boolean
function m.is_open() return state.open end

--- Renders the form. Call from the centre panel instead of its normal content
--- @param viewport table { x, y, w, h }
--- @param theme table Active theme
function m.draw(viewport, theme)
    local width = math.min(460, viewport.w - 40)
    local x = viewport.x + (viewport.w - width) / 2
    local y = viewport.y + 36

    _components.label("New Project", x, y, 28, theme.text_primary)
    y = y + 48

    if _session.project then
        _components.label("This closes the current project.", x, y, 16, theme.text_tertiary)
        y = y + 24
    end

    _components.label("Name", x, y, 16, theme.text_secondary)
    y = y + 24
    local submitted = _components.textfield(state.name, x, y, width, FIELD_H, "[%w_%-]", "project_name")
    y = y + FIELD_H + 16

    _components.label("Template", x, y, 16, theme.text_secondary)
    y = y + 24

    for index, template in ipairs(_bp.templates) do
        local selected = index == state.selected
        local hovered = _input.in_rect(x, y, width, ROW_H - 4)

        _draw.set_colour((selected or hovered) and theme.bg_hover or theme.bg_panel)
        _draw.rect(x, y, width, ROW_H - 4)

        local _, clicked = _input.interact(x, y, width, ROW_H - 4)
        if clicked then state.selected = index end

        _components.label(template.name, x + 12, y + 6, 16, selected and theme.accent or theme.text_primary)
        _components.label(template.description, x + 12, y + 26, 14, theme.text_tertiary)
        y = y + ROW_H
    end

    y = y + 8
    if state.error then
        _components.label(state.error, x, y, 16, theme.accent3)
        y = y + 24
    end

    local button_w = 90
    local create = _components.button("Create", x + width - button_w, y, button_w, FIELD_H)
    local cancel = _components.button("Cancel", x + width - button_w * 2 - 8, y, button_w, FIELD_H, 16, nil, "outlined")

    if cancel then
        m.close()
    elseif create or submitted then
        local err = _session.create(state.name.text, _bp.templates[state.selected].id)
        if err then state.error = err else m.close() end
    end
end

return m