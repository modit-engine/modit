--- @module toolbar
--- @file src/editor/ui/panels/toolbar.lua
--- @description Top navigation and action toolbar managing menus, layout panel visibility, theme switching, and session execution controls.

--- @section Imports

--- Engine
local _draw = require("src.sdk.client.draw2d")
local _font = require("src.sdk.client.font")
local _window = require("src.engine.core.window")
local _engine = require("src.engine")
local _ui = _engine.ui
local _ui_input = _ui.input

--- Editor
local _theme = _ui.theme
local _session = require("src.editor.core.session")
local _builder = require("src.editor.core.builder")
local _new_project = require("src.editor.ui.panels.new_project")
local _settings = require("src.editor.core.settings")
local _editor_settings = require("src.editor.ui.panels.editor_settings")
local _plugins_panel = require("src.editor.ui.panels.plugins")
local _themes = require("src.editor.ui.style.themes")
local _picker = require("src.editor.core.folder_picker")

--- Safe lazy reference to console panel
local function get_console()
    return package.loaded["src.editor.ui.panels.console"] or require("src.editor.ui.panels.console")
end

--- @section Constants

local BUTTON_HEIGHT = 20

local FILE_MENU_ITEMS_OPEN = { "New Project", "Load Project", "Plugins", "Close Project", "Exit" }
local FILE_MENU_ITEMS_CLOSED = { "New Project", "Load Project", "Plugins", "Exit" }

local VIEW_MENU_ITEMS = {
    { label = "Toggle Panels", keep_open = true, items = { "Files", "Props", "Console", "Minimap" } },
    { label = "Theme", items = _themes.labels },
    "Editor Settings",
}

local BUILD_MENU_ITEMS = {
    {
        label = "Windows",
        items = { "Client", "Server" },
    },
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

--- Renders a toolbar action button and returns click state, spanning the full toolbar height.
local function render_action_button(label, toolbar_bounds)
    local button_w = _font.width(16, label) + 16
    local button_y = toolbar_bounds.y
    local button_h = toolbar_bounds.h
    local is_clicked = _ui.button(label, cursor_x, button_y, button_w, button_h, { size = 16 })
    cursor_x = cursor_x + button_w + 4
    return is_clicked
end

--- Renders a toolbar dropdown menu and returns selected indices using unified SDK.
local function render_menu_dropdown(menu_id, label, items, toolbar_bounds)
    local menu_w = _font.width(16, label) + 20
    local choice, sub = _ui.build_dropdown(
        menu_id,
        label,
        cursor_x,
        toolbar_bounds.y,
        menu_w,
        toolbar_bounds.h,
        items
    )
    cursor_x = cursor_x + menu_w
    return choice, sub
end

--- Folder path of the open project (session.project is either the path or a table holding it)
local function project_path()
    local project = _session.project
    if type(project) == "string" then
        return project
    end
    if type(project) == "table" then
        return project.path or project.dir or project.root
    end
end

--- @section Functions

--- Renders toolbar menus, execution controls, and session status.
function m.draw(toolbar_bounds, active_theme)
    _draw.set_colour(active_theme.bg_panel)
    _draw.rect(toolbar_bounds.x, toolbar_bounds.y, toolbar_bounds.w, toolbar_bounds.h)
    _draw.set_colour(active_theme.border_dark.color)
    _draw.line(
        toolbar_bounds.x,
        toolbar_bounds.y + toolbar_bounds.h - 1,
        toolbar_bounds.x + toolbar_bounds.w,
        toolbar_bounds.y + toolbar_bounds.h - 1
    )

    cursor_x = toolbar_bounds.x

    -- File Menu
    local file_items = _session.project and FILE_MENU_ITEMS_OPEN or FILE_MENU_ITEMS_CLOSED
    local file_choice = render_menu_dropdown("file_menu", "File", file_items, toolbar_bounds)
    local picked_option = file_choice and file_items[file_choice]

    if picked_option == "New Project" then
        _new_project.open()
    elseif picked_option == "Load Project" then
        local path, err = _picker.choose()
        if path then
            _session.open(path)
        elseif err then
            print("Load project cancelled or failed: " .. err)
        end
    elseif picked_option == "Plugins" then
        _plugins_panel.open()
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
            if panel_key then
                m.show[panel_key] = not m.show[panel_key]
            end
        end
    elseif view_choice == 2 and sub_choice then
        _theme.set(_themes.keys[sub_choice])
    elseif view_choice == 3 then
        _editor_settings.open()
    end

    if _session.project then
        -- Build Menu
        local build_choice, target_choice = render_menu_dropdown("build_menu", "Build", BUILD_MENU_ITEMS, toolbar_bounds)

        if build_choice == 1 and target_choice then
            local target

            if target_choice == 1 then
                target = "client"
            elseif target_choice == 2 and _session.has_server() then
                target = "server"
            end

            if target then
                get_console().clear("build")

                local started, err = _builder.build(target, project_path())
                if not started then
                    print("Build not started: " .. tostring(err))
                end
            end
        end
    end

    cursor_x = cursor_x + 8
    _draw.set_colour(active_theme.border_light.color)
    _draw.line(cursor_x, toolbar_bounds.y, cursor_x, toolbar_bounds.y + toolbar_bounds.h)
    cursor_x = cursor_x + 12

    if _session.project then
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

        local client_status = "Client: " .. _session.status_text()
        local server_status = _session.has_server() and (" | Server: " .. (_session.is_server_running() and "Running" or "Stopped")) or ""
        local build_text = _builder.status_text()
        local build_status = build_text and (" | " .. build_text) or ""
        local status_label = client_status .. server_status .. build_status
        local label_y = toolbar_bounds.y + math.floor((toolbar_bounds.h - 16) / 2)

        _ui.label(
            status_label,
            toolbar_bounds.x + toolbar_bounds.w - _font.width(16, status_label) - 14,
            label_y,
            16,
            _session.status_colour(active_theme)
        )
    end
end

return m