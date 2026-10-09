--- @module explorer
--- @file src/editor/ui/panels/explorer.lua
--- @description File explorer panel for navigating project directory hierarchy, inline renaming, folder/file creation, and deletions.

--- @section Imports

--- Engine
local _draw = require("src.engine.modules.draw")
local _keyboard = require("src.engine.modules.keyboard")
local _backend = require("src.engine.backend")
local _fs = _backend.filesystem

--- Editor
local _components = require("src.engine.ui.components")
local _input = require("src.engine.ui.modules.input")
local _ffi = require("ffi")
local _ray = require("src.engine.backend.raylib.ffi").lib
local _import = require("src.editor.core.import_files")
local _settings = require("src.editor.core.settings")
local _image = require("src.editor.ui.panels.image")
local _theme = require("src.engine.ui.modules.theme")

--- @section Constants

local ROW_H = 24
local INDENT = 16
local PAD = 6
local TITLE_H = 31
local RESCAN_EVERY = 1
local HDR_BTN = 22
local NAME_FILTER = "[%w_%-%.]"

--- @section Initialisation

local m = { 
    on_open = nil, 
    on_delete = nil, 
    on_rename = nil 
}

local root_path = nil
local selected_path = nil
local is_selected_dir = false
local scan_timer = 0
local is_dirty = false
local expanded_paths = {}
local scroll_state = { y = 0 }
local tree_rows = {}
local tree_row_count = 0

local edit_state = nil
local import_notice, import_until

--- @section Helpers

--- Returns parent directory path of given file or directory path
--- @param target_path string Path to evaluate
--- @return string parent Parent directory path
local function parent_of(target_path)
    return target_path:match("^(.*)/[^/]+$") or root_path
end

--- Recursively builds tree row hierarchy for directory path and depth
--- @param dir_path string Directory path to walk
--- @param depth_level number Tree nesting depth
local function walk_tree(dir_path, depth_level)
    if edit_state and edit_state.mode ~= "rename" and edit_state.dir == dir_path then
        tree_row_count = tree_row_count + 1
        tree_rows[tree_row_count] = { edit = true, depth = depth_level }
    end

    for _, entry in ipairs(_fs.list(dir_path)) do
        local full_path = dir_path .. "/" .. entry.name
        tree_row_count = tree_row_count + 1
        tree_rows[tree_row_count] = { path = full_path, name = entry.name, depth = depth_level, dir = entry.dir }

        if entry.dir and expanded_paths[full_path] then
            walk_tree(full_path, depth_level + 1)
        end
    end
end

--- Rescans and rebuilds filesystem row representation
local function rescan_tree()
    tree_rows, tree_row_count = {}, 0
    if root_path then 
        walk_tree(root_path, 0) 
    end
    is_dirty = false
end

--- Identifies target parent directory for new items
--- @return string dir Path of destination directory
local function get_target_dir()
    if not selected_path then 
        return root_path 
    end
    if is_selected_dir then 
        return selected_path 
    end
    return parent_of(selected_path)
end

--- Cancels active inline editing and refreshes tree
local function cancel_edit()
    edit_state = nil
    _input.blur()
    rescan_tree()
end

--- Initiates new file or directory creation input field
--- @param is_folder boolean True to create folder, false for file
local function begin_new_item(is_folder)
    local destination_dir = get_target_dir()
    expanded_paths[destination_dir] = true
    edit_state = {
        mode = is_folder and "new_folder" or "new_file",
        dir = destination_dir,
        state = { text = "", max = 64 },
    }
    _input.set_focus(edit_state.state)
    rescan_tree()
end

--- Initiates inline renaming for currently selected file or directory
local function begin_rename()
    if not selected_path then return end
    local item_name = selected_path:match("[^/]+$")
    edit_state = {
        mode = "rename",
        path = selected_path,
        state = { text = item_name, max = 64 },
    }
    _input.set_focus(edit_state.state)
    rescan_tree()
end

--- Commits active inline editing action (creation or rename)
local function commit_edit()
    local edit_info = edit_state
    local new_name = edit_info.state.text

    if new_name == "" then 
        edit_info.error = "Enter a name"
        return 
    end
    if new_name:find("^%.+$") then 
        edit_info.error = "Invalid name"
        return 
    end

    if edit_info.mode == "rename" then
        local old_name = edit_info.path:match("[^/]+$")
        if new_name == old_name then 
            cancel_edit()
            return 
        end

        local new_full_path = parent_of(edit_info.path) .. "/" .. new_name
        local ok, err_msg = _fs.rename(edit_info.path, new_full_path)
        if not ok then 
            edit_info.error = err_msg
            return 
        end
        if m.on_rename then 
            m.on_rename(edit_info.path, new_full_path) 
        end

        if expanded_paths[edit_info.path] then 
            expanded_paths[new_full_path], expanded_paths[edit_info.path] = true, nil 
        end
        selected_path = new_full_path
        cancel_edit()
        return
    end

    local item_path = edit_info.dir .. "/" .. new_name
    if _fs.exists(item_path) then 
        edit_info.error = "Already exists"
        return 
    end

    local is_folder_mode = (edit_info.mode == "new_folder")
    local ok, err_msg
    if is_folder_mode then
        ok = _fs.create_dir(item_path)
        err_msg = "Could not create the folder"
    else
        ok, err_msg = _fs.create_file(item_path)
    end
    if not ok then 
        edit_info.error = err_msg
        return 
    end

    selected_path, is_selected_dir = item_path, is_folder_mode
    cancel_edit()
    if not is_folder_mode and m.on_open then 
        m.on_open(item_path) 
    end
end

--- Opens confirmation dialog to delete selected item or folder
local function ask_delete_selected()
    if not selected_path then return end

    local target_path, is_dir_item = selected_path, is_selected_dir
    local item_name = target_path:match("[^/]+$")

    _components.modal.open({
        title = "Delete " .. item_name,
        message = is_dir_item and "Deletes the folder and everything in it." or "This can't be undone.",
        confirm_label = "Delete",
        danger = true,
        on_confirm = function()
            local ok, err_msg
            if is_dir_item then 
                ok, err_msg = _fs.remove_dir(target_path)
            else 
                ok, err_msg = _fs.remove_file(target_path) 
            end
            if not ok then return err_msg end

            selected_path, is_selected_dir = nil, false
            if m.on_delete then 
                m.on_delete(target_path, is_dir_item) 
            end
            rescan_tree()
        end,
    })
end

--- Renders panel header action buttons (new file, new folder, delete)
--- @param viewport table Viewport rectangle table { x, y, w, h }
--- @param theme table Active theme color mapping
local function draw_header_actions(viewport, theme)
    local button_y = viewport.y + math.floor((TITLE_H - HDR_BTN) / 2)
    local button_x = viewport.x + viewport.w - HDR_BTN - 6

    local delete_icon_color = selected_path and theme.accent3 or theme.text_tertiary
    if _components.icon_button("delete", button_x, button_y, HDR_BTN, HDR_BTN, delete_icon_color) and selected_path then
        ask_delete_selected()
    end
    button_x = button_x - HDR_BTN - 2

    if _components.icon_button("new_folder", button_x, button_y, HDR_BTN, HDR_BTN) then 
        begin_new_item(true) 
    end
    button_x = button_x - HDR_BTN - 2

    if _components.icon_button("new_file", button_x, button_y, HDR_BTN, HDR_BTN) then 
        begin_new_item(false) 
    end
end

--- @section Functions

--- Opens file explorer targeting specified root directory path
--- @param dir_path string Directory path to load as tree root
function m.open(dir_path)
    _image.clear_thumbnails()
    import_notice = nil
    root_path = dir_path
    expanded_paths = {}
    selected_path, is_selected_dir = nil, false
    edit_state = nil
    scroll_state.y = 0
    rescan_tree()
end

--- Closes explorer and clears active directory state
function m.close()
    _image.clear_thumbnails()
    root_path = nil
    selected_path, is_selected_dir = nil, false
    edit_state = nil
    tree_rows, tree_row_count = {}, 0
end

--- Updates periodic filesystem rescanning and keyboard shortcuts
--- @param delta_time number Frame delta time in seconds
function m.update(delta_time)
    if not root_path then return end

    scan_timer = scan_timer + delta_time
    if scan_timer >= RESCAN_EVERY then
        scan_timer = 0
        rescan_tree()
    end

    if not edit_state and not _components.modal.is_open() then
        if _keyboard.pressed("f2") then 
            begin_rename() 
        end
    end
end

--- Renders file explorer tree UI panel within given bounding rectangle
--- @param viewport table Viewport rectangle table { x, y, w, h }
function m.draw(viewport)
    if not root_path or viewport.w <= 0 or viewport.h <= TITLE_H + 1 then return end

    local active_theme = _theme.get()
    local panel_x, panel_y = viewport.x, viewport.y + TITLE_H + 1
    local panel_w, panel_h = viewport.w, viewport.h - TITLE_H - 1

    draw_header_actions(viewport, active_theme)

    local dropped
    local drop_target = root_path
    if _ray.IsFileDropped() then
        local list = _ray.LoadDroppedFiles()
        dropped = {}
        for i=0,tonumber(list.count)-1 do dropped[#dropped+1]=_ffi.string(list.paths[i]) end
        _ray.UnloadDroppedFiles(list)
        if edit_state or _components.modal.is_open() or not _input.in_rect(panel_x,panel_y,panel_w,panel_h) then
            dropped = nil
            import_notice, import_until = "Drop onto a folder in Files.", os.clock()+6
        end
    end

    if tree_row_count == 0 then
        _components.label("Empty folder", panel_x + PAD + 4, panel_y + PAD + 2, 16, active_theme.text_tertiary)
    end

    local is_pressed = _input.pressed()
    local hit_row = false
    local pending_action = nil

    _components.scroll_begin(scroll_state, panel_x, panel_y, panel_w, panel_h, tree_row_count * ROW_H + PAD * 2)

    local first_idx = math.max(1, math.floor((scroll_state.y - PAD) / ROW_H) + 1)
    local last_idx = math.min(tree_row_count, math.ceil((scroll_state.y + panel_h - PAD) / ROW_H) + 1)

    for index = first_idx, last_idx do
        local tree_row = tree_rows[index]
        local row_y = panel_y + PAD + (index - 1) * ROW_H - scroll_state.y
        local text_x = panel_x + PAD + tree_row.depth * INDENT
        local text_y = row_y + (ROW_H - 16) / 2

        if tree_row.edit then
            local hint_text = (edit_state.mode == "new_folder") and "folder_name" or "file_name.lua"
            local field_x = text_x + 16
            local is_submitted = _components.textfield(edit_state.state, field_x, row_y + 2,
                panel_w - (field_x - panel_x) - PAD, ROW_H - 4, NAME_FILTER, hint_text)

            if is_submitted then 
                pending_action = "commit"
            elseif not _input.has_focus(edit_state.state) then 
                pending_action = "cancel" 
            end
            hit_row = true
        else
            local is_hovered = _input.in_rect(panel_x, row_y, panel_w, ROW_H)
            if is_hovered then 
                if dropped then drop_target = tree_row.dir and tree_row.path or parent_of(tree_row.path) end
                hit_row = true 
            end

            local is_renaming = edit_state and edit_state.mode == "rename" and edit_state.path == tree_row.path

            if selected_path == tree_row.path then
                _draw.set_colour(active_theme.accent, 50)
                _draw.rect(panel_x, row_y, panel_w, ROW_H)
            elseif is_hovered then
                _draw.set_colour(active_theme.bg_hover)
                _draw.rect(panel_x, row_y, panel_w, ROW_H)
            end

            if tree_row.dir then
                _draw.set_colour(active_theme.text_secondary)
                _input.text(expanded_paths[tree_row.path] and "v" or ">", text_x, text_y, 16)
            end

            if is_renaming then
                local field_x = text_x + 16
                local is_submitted = _components.textfield(edit_state.state, field_x, row_y + 2,
                    panel_w - (field_x - panel_x) - PAD, ROW_H - 4, NAME_FILTER)

                if is_submitted then 
                    pending_action = "commit"
                elseif not _input.has_focus(edit_state.state) then 
                    pending_action = "cancel" 
                end
            else
                local name_x = text_x + 16
                if _settings.show_file_previews and not tree_row.dir and _image.supports(tree_row.path) then
                    _image.thumbnail(tree_row.path, name_x, row_y + 3, 18, active_theme)
                    name_x = name_x + 24
                end
                _draw.set_colour(active_theme.text_primary)
                _input.text(tree_row.name, name_x, text_y, 16)

                if is_hovered and is_pressed then
                    selected_path, is_selected_dir = tree_row.path, tree_row.dir
                    if tree_row.dir then
                        expanded_paths[tree_row.path] = not expanded_paths[tree_row.path] or nil
                        is_dirty = true
                    elseif m.on_open then
                        m.on_open(tree_row.path)
                    end
                end
            end
        end
    end

    if is_pressed and not hit_row and not edit_state and _input.in_rect(panel_x, panel_y, panel_w, panel_h) then
        selected_path, is_selected_dir = nil, false
    end

    _components.scroll_end()

    if dropped and #dropped>0 then
        local count, err, completed = _import.copy(dropped,drop_target,root_path)
        if count then
            import_notice = ("Imported %d item(s) into %s"):format(count,drop_target:match("[^/]+$"))
        else
            import_notice = ("Import stopped (%d completed). %s"):format(completed or 0,err)
            print(import_notice)
        end
        import_until = os.clock()+8
        expanded_paths[drop_target] = true
        rescan_tree()
    end
    if import_notice and os.clock()<import_until then
        _draw.push_clip(panel_x,viewport.y+viewport.h-28,panel_w,28)
        _draw.set_colour(active_theme.bg_panel)
        _draw.rect(panel_x,viewport.y+viewport.h-28,panel_w,28)
        _components.label(import_notice,panel_x+PAD,viewport.y+viewport.h-22,14,active_theme.text_secondary)
        _draw.pop_clip()
    end

    if edit_state and edit_state.error then
        _components.label(edit_state.error, panel_x + PAD + 4, viewport.y + viewport.h - 24, 16, active_theme.accent3)
    end

    if pending_action == "commit" then 
        commit_edit()
    elseif pending_action == "cancel" then 
        cancel_edit()
    elseif is_dirty then 
        rescan_tree() 
    end
end

return m