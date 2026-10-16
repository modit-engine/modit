--- @module new_project
--- @file src/editor/ui/panels/new_project.lua
--- @description New project screen with a name field and template picker.

--- @section Imports

local _draw = require("src.sdk.client.draw2d")
local _engine = require("src.engine")
local _ui = _engine.ui
local _ui_input = _ui.input
local _session = require("src.editor.core.session")
local _bp = require("src.editor.core.boilerplate")
local _projects = require("src.editor.core.projects")
local _picker = require("src.editor.core.folder_picker")

--- @section Constants

local ROW_H = 52
local FIELD_H = 30

--- @section Initialisation

local m = {}

local state = { open = false, label = { text = "", max = 80 }, name = { text = "", max = 32 }, auto_name = true, selected = 1, error = nil }
local scroll = { y = 0 }

--- @section Functions

--- Shows the screen with a clean form
function m.open()
    state.open = true
    state.name.text = ""
    state.label.text = ""
    state.auto_name = true
    scroll.y = 0
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
local function draw_form(viewport, theme)
    local width = math.min(460, viewport.w - 40)
    local x = viewport.x + (viewport.w - width) / 2
    local y = viewport.y + 36

    _ui.label("New Project", x, y, 28, theme.text_primary)
    y = y + 48

    if _session.project then
        _ui.label("This closes the current project.", x, y, 16, theme.text_tertiary)
        y = y + 24
    end

    _ui.label("Project Label", x, y, 16, theme.text_secondary)
    y = y + 24
    local submitted = _ui.textfield(state.label, x, y, width, FIELD_H, nil, "Project Bite")
    if state.auto_name then state.name.text = _projects.name_from_label(state.label.text) end
    y = y + FIELD_H + 16

    _ui.label("Project Name (folder)", x, y, 16, theme.text_secondary)
    y = y + 24
    local previous_name = state.name.text
    local name_submitted = _ui.textfield(state.name, x, y, width, FIELD_H, "[%w_%-]", "project_bite")
    state.name.text = state.name.text:lower()
    if state.name.text ~= previous_name then state.auto_name = false end
    submitted = submitted or name_submitted
    y = y + FIELD_H + 4
    if _ui.button("Use label for name", x, y, 170, 24, { size = 14, style = "outlined" }) then
        state.auto_name = true
        state.name.text = _projects.name_from_label(state.label.text)
    end
    y = y + 28
    _ui.label("Create will ask where to place the project folder.", x, y, 14, theme.text_tertiary)
    y = y + 30

    _ui.label("Template", x, y, 16, theme.text_secondary)
    y = y + 24

    for index, template in ipairs(_bp.templates) do
        local selected = index == state.selected
        local hovered = _ui_input.in_rect(x, y, width, ROW_H - 4)

        _draw.set_colour((selected or hovered) and theme.bg_hover or theme.bg_panel)
        _draw.rect(x, y, width, ROW_H - 4)

        local _, clicked = _ui_input.interact(x, y, width, ROW_H - 4)
        if clicked then state.selected = index end

        _ui.label(template.name, x + 12, y + 6, 16, selected and theme.accent or theme.text_primary)
        _ui.label(template.description, x + 12, y + 26, 14, theme.text_tertiary)
        y = y + ROW_H
    end

    y = y + 8
    if state.error then
        _ui.label(state.error, x, y, 16, theme.accent3)
        y = y + 24
    end

    local button_w = 90
    local create = _ui.button("Create", x + width - button_w, y, button_w, FIELD_H, { size = 16 })
    local cancel = _ui.button("Cancel", x + width - button_w * 2 - 8, y, button_w, FIELD_H, { size = 16, style = "outlined" })

    if cancel then
        m.close()
    elseif create or submitted then
        state.error = _projects.validate(state.name.text, state.label.text)
        if state.error then return end
        local parent, picker_error = _picker.choose()
        if not parent then
            state.error = picker_error
            return
        end
        local err = _session.create(state.name.text, _bp.templates[state.selected].id, parent, state.label.text)
        if err then state.error = err else m.close() end
    end
end

function m.draw(viewport, theme)
    local content_h = 480 + (_session.project and 24 or 0) + (state.error and 24 or 0)
    _ui.scroll_begin(scroll, viewport.x, viewport.y, viewport.w, viewport.h, content_h)
    draw_form({ x = viewport.x, y = viewport.y - scroll.y, w = viewport.w - 12, h = viewport.h }, theme)
    _ui.scroll_finish()
end

return m