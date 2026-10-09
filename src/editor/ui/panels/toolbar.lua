--- @module toolbar
--- @file src/editor/ui/panels/toolbar.lua
--- @description Top navigation and action toolbar managing menus, layout panel visibility, theme switching, and session execution controls.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")
local _font = require("src.engine.modules.font")
local _window = require("src.engine.core.window")

--- Editor
local _theme = require("src.engine.ui.modules.theme")
local _components = require("src.engine.ui.components")
local _session = require("src.editor.core.session")
local _new_project = require("src.editor.ui.panels.new_project")
local _settings = require("src.editor.core.settings")
local _menu = require("src.editor.ui.components.menu")
local _editor_settings = require("src.editor.ui.panels.editor_settings")
local _themes = require("src.editor.ui.style.themes")

--- @section Constants

local BUTTON_HEIGHT = 20

local FILE_MENU_ITEMS_OPEN = { "New Project", "Close Project", "Exit" }
local FILE_MENU_ITEMS_CLOSED = { "New Project", "Exit" }

local VIEW_MENU_ITEMS = {
    { label = "Toggle Panels", keep_open = true, items = { "Files", "Props", "Console", "Minimap" } },
    { label = "Theme", items = _themes.labels },
    "Editor Settings",
}

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
    local choice, sub = _menu.dropdown(menu_id, label, cursor_x, toolbar_bounds.y, menu_w, toolbar_bounds.h, items)
    cursor_x = cursor_x + menu_w
    return choice, sub
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
        _new_project.open()
    elseif picked_option == "Close Project" then
        _session.close_project()
    elseif picked_option == "Exit" then
        _window.close()
    end

    -- View Menu
    local view_choice, sub_choice = render_menu_dropdown("view_menu", "View", VIEW_MENU_ITEMS, toolbar_bounds)
    if view_choice == 1 and sub_choice then
        if sub_choice == 4 then
            _settings.minimap = not _settings.minimap
            _settings.save()
        else
            local panel_key = PANEL_KEYS[sub_choice]
            m.show[panel_key] = not m.show[panel_key]
        end
    elseif view_choice == 2 and sub_choice then
        _theme.set(_themes.keys[sub_choice])
    elseif view_choice == 3 then
        _editor_settings.open()
    end

    cursor_x = cursor_x + 12

    -- Execution Controls
    if _session.project then
        -- Client Controls
        if _session.is_running() then
            if render_action_button("Reload Client", toolbar_bounds) then
                _session.run()
            end

            if render_action_button("Stop Client", toolbar_bounds) then
                _session.stop()
            end
        else
            if render_action_button("Run Client", toolbar_bounds) then
                _session.run()
            end
        end

        -- Server Controls
        if _session.has_server() then
            if _session.is_server_running() then
                if render_action_button("Reload Server", toolbar_bounds) then
                    _session.run_server()
                end

                if render_action_button("Stop Server", toolbar_bounds) then
                    _session.stop_server()
                end
            else
                if render_action_button("Run Server", toolbar_bounds) then
                    _session.run_server()
                end
            end
        end

        -- Session Status
        local client_status = "Client: " .. _session.status_text()
        local server_status = _session.has_server() and (" | Server: " .. (_session.is_server_running() and "Running" or "Stopped")) or ""

        local status_label = client_status .. server_status
        local label_y = toolbar_bounds.y + math.floor((toolbar_bounds.h - 16) / 2)

        _components.label(
            status_label,
            toolbar_bounds.x + toolbar_bounds.w - _font.width(16, status_label) - 14,
            label_y,
            16,
            _session.status_colour(active_theme)
        )
    end

end

return m
