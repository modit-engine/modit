--- @module editor
--- @file src/editor/init.lua
--- @description Editor main module entry point managing window layout, dock panels, resize splitters, lifecycle updates, and global modal overlays.

--- @section Imports

local _engine = require("src.engine")
local _ui = require("src.editor.ui")
local _session = require("src.editor.core.session")
local _settings = require("src.editor.core.settings")

--- @section Engine UI

local _components = _engine.ui.components
local _input = _engine.ui.input
local _theme = _engine.ui.theme

--- @section Constants

local SPLIT_HANDLE_SIZE = 6

--- @section Initialisation

local m = {}

--- @section Helpers

--- Draws dock panel container background and title bar
--- @param rect table Bounding rectangle { x, y, w, h }
--- @param title string Panel title string
local function draw_dock_panel(rect, title)
    _components.panel(rect.x, rect.y, rect.w, rect.h, title)
end

--- @section Functions

--- Initializes editor settings, panel sizes, and file explorer callbacks
function m.init()
    _settings.load()
     _theme.set(_settings.theme)

    for _, panel_key in ipairs({ "left", "right", "bottom" }) do
        local saved_size = _settings.sizes[panel_key]
        if saved_size then
            _ui.style.layout.sizes[panel_key] = saved_size
        end
    end

    _ui.panels.explorer.on_open = function(path)
        _ui.panels.code.open(path)
    end
    _ui.panels.explorer.on_delete = function(path, is_dir)
        _ui.panels.code.close_path(path, is_dir)
    end
    _ui.panels.explorer.on_rename = function(old_path, new_path)
        _ui.panels.code.rename_path(old_path, new_path)
    end
end

--- Opens project directory session at given filesystem path
--- @param path string Target project root directory path
--- @return boolean ok True if project loaded successfully
function m.open_project(path)
    return _session.open(path)
end

--- Updates active project execution session state
--- @param delta_time number Delta time in seconds
function m.update(delta_time)
    _session.update(delta_time)
end

--- Stops running sessions and persists open files and panel layout configuration
function m.close()
    _session.stop()
    _ui.panels.code.save_all()
    _settings.set_theme(_theme.name())
    for panel_key, size_value in pairs(_ui.style.layout.sizes) do
        _settings.sizes[panel_key] = size_value
    end
    _settings.save()
end

--- Renders complete editor UI layout, dock panels, central viewport, splitters, toolbar, and modal dialogs
function m.draw()
    local active_theme = _theme.get()
    local window_w, window_h = _engine.window.get_size()
    local show_flags = _ui.panels.toolbar.show
    local regions = _ui.style.layout.shell(window_w, window_h, show_flags.left, show_flags.right, show_flags.bottom)
    local panel_sizes = _ui.style.layout.sizes

    _input.set_blocked(_components.modal.is_open())

    _engine.draw.set_colour(active_theme.bg_main)
    _engine.draw.rect(0, 0, window_w, window_h)

    _ui.panels.centre.draw(regions.viewport)

    draw_dock_panel(regions.left, "Files")
    _ui.panels.explorer.draw(regions.left)

    draw_dock_panel(regions.right, "Properties")

    draw_dock_panel(regions.bottom, "Console")
    _ui.panels.console.draw(regions.bottom)

    if regions.right.w > 0 then
        local text_x, text_y = regions.right.x + 12, regions.right.y + 42
        _components.label("FPS: " .. _engine.window.get_fps(), text_x, text_y, 16)
        _components.label(("Window: %d x %d"):format(window_w, window_h), text_x, text_y + 24, 16)
    end

    -- Resize splitters
    if regions.left.w > 0 then
        panel_sizes.left = _components.splitter(regions.left.x + regions.left.w - SPLIT_HANDLE_SIZE / 2, regions.left.y, SPLIT_HANDLE_SIZE, regions.left.h, "x", panel_sizes.left, 1)
    end
    if regions.right.w > 0 then
        panel_sizes.right = _components.splitter(regions.right.x - SPLIT_HANDLE_SIZE / 2, regions.right.y, SPLIT_HANDLE_SIZE, regions.right.h, "x", panel_sizes.right, -1)
    end
    if regions.bottom.h > 0 then
        panel_sizes.bottom = _components.splitter(regions.bottom.x, regions.bottom.y - SPLIT_HANDLE_SIZE / 2, regions.bottom.w, SPLIT_HANDLE_SIZE, "y", panel_sizes.bottom, -1)
    end

    _ui.panels.toolbar.draw(regions.toolbar, active_theme)

    _input.set_blocked(false)
    _components.modal.draw(window_w, window_h)
end

return m