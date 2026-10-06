--- @module centre
--- @file src/editor/ui/panels/centre.lua
--- @description Centre viewport panel rendering either the start screen, project overview, or code editor canvas.

--- @section Imports

--- Editor
local _draw = require("src.engine.modules.draw")
local _font = require("src.engine.modules.font")

--- Engine
local _theme = require("src.engine.ui.style.theme")
local _input = require("src.engine.ui.input")
local _components = require("src.engine.ui.components")
local _code = require("src.editor.ui.panels.code")
local _session = require("src.editor.core.session")
local _settings = require("src.editor.core.settings")
local _projects = require("src.editor.core.projects")

--- @section Constants

local ROW_H = 34
local OPEN_W = 60
local DEL_W = 70
local BTN_H = 24

--- @section Initialisation

local entries = {}
local seen_version = nil
local new_project_input = { text = "" }
local create_error_message = nil
local list_scroll_state = { y = 0 }

local m = {}

--- @section Helpers

--- Refreshes recent project list from settings and updates tracking version
local function refresh_project_list()
    entries = _projects.list(_settings.recent)
    seen_version = _session.version
end

--- Renders horizontally centered text string at specified coordinates
--- @param center_x number Horizontal center position coordinate
--- @param text_str string Text string to render
--- @param y_pos number Vertical coordinate
--- @param font_size number Font size in pixels
--- @param color table Color specification table
local function render_centered_text(center_x, text_str, y_pos, font_size, color)
    _draw.set_colour(color)
    _input.text(text_str, center_x - _font.width(font_size, text_str) / 2, y_pos, font_size)
end

--- Prompts modal confirmation dialog for deleting project files
--- @param project_entry table Project metadata entry { name, path }
local function ask_delete_project(project_entry)
    _components.modal.open({
        title = "Delete " .. project_entry.name,
        message = "This permanently deletes its files.",
        confirm_label = "Delete",
        danger = true,
        on_confirm = function()
            local ok, error_msg = _projects.delete(project_entry.path)
            if not ok then 
                return error_msg 
            end
            refresh_project_list()
        end,
    })
end

--- Renders a project list row with name, path, and action buttons
--- @param project_entry table Project metadata entry
--- @param row_x number Row X position
--- @param row_y number Row Y position
--- @param row_w number Row width
--- @param row_h number Row height
--- @param theme table Active theme color mapping
local function draw_project_row(project_entry, row_x, row_y, row_w, row_h, theme)
    local is_deletable = project_entry.path:match("^projects/[%w_%-]+$") ~= nil
    local buttons_width = OPEN_W + 8 + (is_deletable and DEL_W + 8 or 0)
    local button_y = row_y + math.floor((row_h - BTN_H) / 2)
    local text_y = row_y + (row_h - 16) / 2

    _draw.set_colour(_input.in_rect(row_x, row_y, row_w, row_h) and theme.bg_hover or theme.bg_panel)
    _draw.rect(row_x, row_y, row_w, row_h)

    local _, opened = _input.interact(row_x, row_y, row_w - buttons_width, row_h)
    _components.label(project_entry.name, row_x + 12, text_y, 16, theme.text_primary)
    _components.label(project_entry.path, row_x + 24 + _font.width(16, project_entry.name), text_y, 16, theme.text_tertiary)

    local button_x = row_x + row_w - 8
    if is_deletable then
        button_x = button_x - DEL_W
        if _components.button("Delete", button_x, button_y, DEL_W, BTN_H, 16, theme.accent3, "outlined") then
            ask_delete_project(project_entry)
        end
        button_x = button_x - 8
    end
    if _components.button("Open", button_x - OPEN_W, button_y, OPEN_W, BTN_H, 16, nil, "outlined") then
        opened = true
    end

    if opened then 
        _session.open(project_entry.path) 
    end
end

--- @section Views

--- Renders start screen view when no active project is loaded
--- @param viewport table Viewport bounding rectangle { x, y, w, h }
--- @param theme table Active theme color mapping
local function draw_start_screen(viewport, theme)
    if seen_version ~= _session.version then 
        refresh_project_list() 
    end

    local column_width = math.min(460, viewport.w - 40)
    local current_x = viewport.x + (viewport.w - column_width) / 2
    local current_y = viewport.y + 36

    _components.label("Projects", current_x, current_y, 28, theme.text_primary)
    _components.label("New project", current_x, current_y + 48, 16, theme.text_secondary)
    current_y = current_y + 72

    local button_width = 90
    local is_submitted = _components.textfield(new_project_input, current_x, current_y, column_width - button_width - 8, 30, "[%w_%-]", "project_name")
    local is_clicked = _components.button("Create", current_x + column_width - button_width, current_y, button_width, 30)
    if is_submitted or is_clicked then
        create_error_message = _session.create(new_project_input.text)
        if not create_error_message then 
            new_project_input.text = "" 
        end
    end
    current_y = current_y + 38

    if create_error_message then
        _components.label(create_error_message, current_x, current_y, 16, theme.accent3)
        current_y = current_y + 22
    end

    current_y = current_y + 14
    _components.label("Open", current_x, current_y, 16, theme.text_secondary)
    current_y = current_y + 24

    local list_height = viewport.y + viewport.h - current_y - 24
    if list_height < ROW_H then return end

    if #entries == 0 then
        _components.label("No projects yet. Create one above.", current_x, current_y + 4, 16, theme.text_tertiary)
        return
    end

    _components.scroll_begin(list_scroll_state, current_x, current_y, column_width, list_height, #entries * ROW_H)
    for index = 1, #entries do
        draw_project_row(entries[index], current_x, current_y + (index - 1) * ROW_H - list_scroll_state.y, column_width - 12, ROW_H - 4, theme)
    end
    _components.scroll_end()
end

--- Renders default project summary overview when a project is open but no file is loaded
--- @param viewport table Viewport bounding rectangle { x, y, w, h }
--- @param theme table Active theme color mapping
local function draw_project_overview(viewport, theme)
    local center_x = viewport.x + viewport.w / 2
    local center_y = viewport.y + viewport.h / 2
    local active_project = _session.project

    render_centered_text(center_x, active_project.name, center_y - 40, 32, theme.text_primary)
    render_centered_text(center_x, _session.status_text(), center_y + 6, 16, _session.status_colour(theme))
    render_centered_text(center_x, active_project.path, center_y + 30, 16, theme.text_tertiary)
    render_centered_text(center_x, "F5 to run / reload", center_y + 54, 16, theme.text_tertiary)
    render_centered_text(center_x, "Click a file in the Files panel to edit it", center_y + 78, 16, theme.text_tertiary)

    local active_notice = _code.get_notice()
    if active_notice then 
        render_centered_text(center_x, active_notice, center_y + 110, 16, theme.accent3) 
    end
end

--- @section Functions

--- Renders the central panel area depending on current project and buffer state
--- @param viewport table Viewport bounding rectangle { x, y, w, h }
function m.draw(viewport)
    local theme = _theme.get()

    _draw.push_clip(viewport.x, viewport.y, viewport.w, viewport.h)
    if not _session.project then
        draw_start_screen(viewport, theme)
    elseif _code.has_open() then
        _code.draw(viewport)
    else
        draw_project_overview(viewport, theme)
    end
    _draw.pop_clip()
end

return m