--- @module toolbar
--- @file src/editor/ui/panels/toolbar.lua
--- @description Top navigation and action toolbar managing menus, layout panel visibility, theme switching, and session execution controls.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")
local _font = require("src.engine.modules.font")
local _window = require("src.engine.core.window")

--- Editor
local _theme = require("src.engine.ui.style.theme")
local _components = require("src.engine.ui.components")
local _session = require("src.editor.core.session")

--- @section Constants

local BUTTON_HEIGHT = 20

local FILE_MENU_ITEMS_OPEN = { "New Project", "Close Project", "Exit" }
local FILE_MENU_ITEMS_CLOSED = { "New Project", "Exit" }

local VIEW_MENU_ITEMS = {
    { label = "Toggle Panels", keep_open = true, items = { "Files", "Props", "Console" } },
    { label = "Theme", items = { "Default", "Tokyo Night" } },
}

local THEME_KEYS = { "default", "tokyo_night" }
local PANEL_KEYS = { "left", "right", "bottom" }

--- @section Initialisation

local cursor_x = 0

local m = {
    show = {
        left = true,
        right = true,
        bottom = true,
    },
}

--- @section Helpers

--- Renders a toolbar action button and returns click state
--- @param label string Button display text label
--- @param toolbar_bounds table Bounding rectangle for toolbar { x, y, w, h }
--- @return boolean is_clicked True if the button was clicked
local function render_action_button(label, toolbar_bounds)
    local button_w = _font.width(16, label) + 16
    local button_y = toolbar_bounds.y + math.floor((toolbar_bounds.h - BUTTON_HEIGHT) / 2)
    local is_clicked = _components.button(label, cursor_x, button_y, button_w, BUTTON_HEIGHT)
    cursor_x = cursor_x + button_w + 4
    return is_clicked
end

--- Renders a toolbar dropdown menu and returns selected indices
--- @param menu_id string Unique dropdown identifier
--- @param label string Menu display text label
--- @param items table List of menu items or submenus
--- @param toolbar_bounds table Bounding rectangle for toolbar { x, y, w, h }
--- @return number|nil choice Selected top-level item index
--- @return number|nil sub Selected sub-level item index
local function render_menu_dropdown(menu_id, label, items, toolbar_bounds)
    local menu_w = _font.width(16, label) + 20
    local choice, sub = _components.dropdown(menu_id, label, cursor_x, toolbar_bounds.y, menu_w, toolbar_bounds.h, items)
    cursor_x = cursor_x + menu_w
    return choice, sub
end

--- Opens modal confirmation dialog to create a new project
local function open_new_project_dialog()
    _components.modal.open({
        title = "New Project",
        message = _session.project and "Project name (closes current one):" or "Project name:",
        input = { text = "" },
        filter = "[%w_%-]",
        placeholder = "project_name",
        confirm_label = "Create",
        on_confirm = _session.create,
    })
end

--- @section Functions

--- Renders top toolbar UI including menus, execution actions, and session status label
--- @param toolbar_bounds table Bounding rectangle for toolbar { x, y, w, h }
--- @param active_theme table Active theme color mapping
function m.draw(toolbar_bounds, active_theme)
    _draw.set_colour(active_theme.bg_panel)
    _draw.rect(toolbar_bounds.x, toolbar_bounds.y, toolbar_bounds.w, toolbar_bounds.h)
    _draw.set_colour(active_theme.border_dark.color)
    _draw.line(toolbar_bounds.x, toolbar_bounds.y + toolbar_bounds.h - 1, toolbar_bounds.x + toolbar_bounds.w, toolbar_bounds.y + toolbar_bounds.h - 1)

    cursor_x = toolbar_bounds.x

    -- File Menu
    local file_items = _session.project and FILE_MENU_ITEMS_OPEN or FILE_MENU_ITEMS_CLOSED
    local file_choice = render_menu_dropdown("file_menu", "File", file_items, toolbar_bounds)
    local picked_option = file_choice and file_items[file_choice]

    if picked_option == "New Project" then
        open_new_project_dialog()
    elseif picked_option == "Close Project" then
        _session.close_project()
    elseif picked_option == "Exit" then
        _window.close()
    end

    -- View Menu
    local view_choice, sub_choice = render_menu_dropdown("view_menu", "View", VIEW_MENU_ITEMS, toolbar_bounds)
    if view_choice == 1 and sub_choice then
        local panel_key = PANEL_KEYS[sub_choice]
        m.show[panel_key] = not m.show[panel_key]
    elseif view_choice == 2 and sub_choice then
        _theme.set(THEME_KEYS[sub_choice])
    end

    cursor_x = cursor_x + 12

    -- Execution Controls & Status
    if _session.project then
        if _session.is_running() then
            if render_action_button("Reload", toolbar_bounds) then
                _session.run()
            end
            if render_action_button("Stop", toolbar_bounds) then
                _session.stop()
            end
        else
            if render_action_button("Run", toolbar_bounds) then
                _session.run()
            end
        end

        local status_label = _session.status_text()
        local label_y = toolbar_bounds.y + math.floor((toolbar_bounds.h - 16) / 2)
        _components.label(status_label, toolbar_bounds.x + toolbar_bounds.w - _font.width(16, status_label) - 14, label_y, 16, _session.status_colour(active_theme))
    end
end

return m