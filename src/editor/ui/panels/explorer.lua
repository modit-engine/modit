--- @module explorer
--- @file src/editor/ui/panels/explorer.lua
--- @description File explorer panel for navigating project directory hierarchy, inline renaming, folder/file creation, deletions, and drag-and-drop moves.

--- @section Imports

--- Engine
local _draw = require("src.sdk.client.draw2d")
local _font = require("src.sdk.client.font")
local _input = require("src.sdk.client.input")
local _backend = require("src.engine.backend")
local _fs = _backend.filesystem

--- Editor / UI SDK
local _engine = require("src.engine")
local _ui = _engine.ui
local _theme = _ui.theme
local _ui_input = _ui.input

local _ffi = require("ffi")
local _ray = require("src.engine.backend.raylib.ffi").lib
local _import = require("src.editor.core.import_files")
local _settings = require("src.editor.core.settings")
local _image = require("src.editor.ui.panels.image")

--- @section Constants

local ROW_H = 24
local INDENT = 16
local PAD = 6
local TITLE_H = 31
local RESCAN_EVERY = 1
local HDR_BTN = 22
local NAME_FILTER = "[%w_%-%.]"
local DRAG_THRESHOLD = 4
local DOUBLE_CLICK_TIME = 0.3

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
local drag = nil
local last_click_path = nil
local last_click_time = 0

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
    _ui_input.blur()
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
    _ui_input.set_focus(edit_state.state)
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
    _ui_input.set_focus(edit_state.state)
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

    _ui.open_modal({
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

--- Checks whether an item can be moved into a target directory
--- @param src_path string Path of the dragged item
--- @param target_dir string Destination directory path
--- @return boolean ok True if the move is meaningful and not into itself
local function can_move_into(src_path, target_dir)
    if target_dir == src_path or target_dir == parent_of(src_path) then
        return false
    end
    return target_dir:sub(1, #src_path + 1) ~= src_path .. "/"
end

--- Moves a file or folder into a target directory and updates explorer state
--- @param src_path string Path of the item to move
--- @param target_dir string Destination directory path
local function move_item(src_path, target_dir)
    local item_name = src_path:match("[^/]+$")
    local dest_path = target_dir .. "/" .. item_name

    if _fs.exists(dest_path) then
        import_notice, import_until = "Already exists in " .. (target_dir:match("[^/]+$") or target_dir), os.clock() + 4
        return
    end

    local ok, err_msg = _fs.rename(src_path, dest_path)
    if not ok then
        import_notice, import_until = err_msg or "Could not move", os.clock() + 4
        return
    end

    if m.on_rename then
        m.on_rename(src_path, dest_path)
    end

    local remapped = {}
    local dir_prefix = src_path .. "/"
    for expanded_path, value in pairs(expanded_paths) do
        if expanded_path == src_path then
            remapped[dest_path] = value
        elseif expanded_path:sub(1, #dir_prefix) == dir_prefix then
            remapped[dest_path .. "/" .. expanded_path:sub(#dir_prefix + 1)] = value
        else
            remapped[expanded_path] = value
        end
    end
    expanded_paths = remapped
    expanded_paths[target_dir] = true

    selected_path = dest_path
    rescan_tree()
end

--- Renders panel header action buttons (new file, new folder, delete)
--- @param viewport table Viewport rectangle table { x, y, w, h }
--- @param theme table Active theme color mapping
local function draw_header_actions(viewport, theme)
    local button_y = viewport.y + math.floor((TITLE_H - HDR_BTN) / 2)
    local button_x = viewport.x + viewport.w - HDR_BTN - 6

    local delete_icon_color = selected_path and theme.accent3 or theme.text_tertiary
    if _ui.button(nil, button_x, button_y, HDR_BTN, HDR_BTN, { icon = "delete", icon_colour = delete_icon_color, style = "outlined" }) and selected_path then
        ask_delete_selected()
    end
    button_x = button_x - HDR_BTN - 2

    if _ui.button(nil, button_x, button_y, HDR_BTN, HDR_BTN, { icon = "new_folder", style = "outlined" }) then 
        begin_new_item(true) 
    end
    button_x = button_x - HDR_BTN - 2

    if _ui.button(nil, button_x, button_y, HDR_BTN, HDR_BTN, { icon = "new_file", style = "outlined" }) then 
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

    if not edit_state and not _ui.is_modal_open() then
        if _input.key_pressed("f2") then 
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

    local font_16 = _font.get(16)
    local font_14 = _font.get(14)

    local dropped
    local drop_target = root_path
    if _ray.IsFileDropped() then
        local list = _ray.LoadDroppedFiles()
        dropped = {}
        for i=0,tonumber(list.count)-1 do dropped[#dropped+1]=_ffi.string(list.paths[i]) end
        _ray.UnloadDroppedFiles(list)
        if edit_state or _ui.is_modal_open() or not _ui_input.in_rect(panel_x,panel_y,panel_w,panel_h) then
            dropped = nil
            import_notice, import_until = "Drop onto a folder in Files.", os.clock()+6
        end
    end

    if tree_row_count == 0 then
        _draw.set_colour(active_theme.text_tertiary)
        if font_16 then
            font_16:draw("Empty folder", panel_x + PAD + 4, panel_y + PAD + 2)
        end
    end

    local is_pressed = _ui_input.pressed()
    local hit_row = false
    local pending_action = nil

    local mouse_x, mouse_y = _ui_input.mouse()
    if drag and not drag.active and _ui_input.down()
        and (math.abs(mouse_x - drag.sx) > DRAG_THRESHOLD or math.abs(mouse_y - drag.sy) > DRAG_THRESHOLD) then
        drag.active = true
    end
    local move_target = nil

    _ui.scroll_begin(scroll_state, panel_x, panel_y, panel_w, panel_h, tree_row_count * ROW_H + PAD * 2)

    local first_idx = math.max(1, math.floor((scroll_state.y - PAD) / ROW_H) + 1)
    local last_idx = math.min(tree_row_count, math.ceil((scroll_state.y + panel_h - PAD) / ROW_H) + 1)

    for index = first_idx, last_idx do
        local tree_row = tree_rows[index]
        local row_y = panel_y + PAD + (index - 1) * ROW_H - scroll_state.y
        local text_x = panel_x + PAD + tree_row.depth * INDENT
        local text_y = row_y + math.floor((ROW_H - 16) / 2)

        if tree_row.edit then
            local hint_text = (edit_state.mode == "new_folder") and "folder_name" or "file_name.lua"
            local field_x = text_x + 16
            local is_submitted = _ui.textfield(edit_state.state, field_x, row_y + 2,
                panel_w - (field_x - panel_x) - PAD, ROW_H - 4, NAME_FILTER, hint_text)

            if is_submitted then 
                pending_action = "commit"
            elseif not _ui_input.has_focus(edit_state.state) then 
                pending_action = "cancel" 
            end
            hit_row = true
        else
            local is_hovered = _ui_input.in_rect(panel_x, row_y, panel_w, ROW_H)
            if is_hovered then 
                if dropped then drop_target = tree_row.dir and tree_row.path or parent_of(tree_row.path) end
                if drag and drag.active then move_target = tree_row.dir and tree_row.path or parent_of(tree_row.path) end
                hit_row = true 
            end

            local is_renaming = edit_state and edit_state.mode == "rename" and edit_state.path == tree_row.path

            if drag and drag.active and is_hovered and tree_row.dir and can_move_into(drag.path, tree_row.path) then
                _draw.set_colour(active_theme.accent, 90)
                _draw.rect(panel_x, row_y, panel_w, ROW_H)
            elseif selected_path == tree_row.path then
                _draw.set_colour(active_theme.accent, 50)
                _draw.rect(panel_x, row_y, panel_w, ROW_H)
            elseif is_hovered then
                _draw.set_colour(active_theme.bg_hover)
                _draw.rect(panel_x, row_y, panel_w, ROW_H)
            end

            if tree_row.dir then
                _draw.set_colour(active_theme.text_secondary)
                local arrow_text = expanded_paths[tree_row.path] and "v" or ">"
                if font_16 then
                    font_16:draw(arrow_text, text_x, text_y)
                end
            end

            if is_renaming then
                local field_x = text_x + 16
                local is_submitted = _ui.textfield(edit_state.state, field_x, row_y + 2,
                    panel_w - (field_x - panel_x) - PAD, ROW_H - 4, NAME_FILTER)

                if is_submitted then 
                    pending_action = "commit"
                elseif not _ui_input.has_focus(edit_state.state) then 
                    pending_action = "cancel" 
                end
            else
                local name_x = text_x + 16
                if _settings.show_file_previews and not tree_row.dir and _image.supports(tree_row.path) then
                    _image.thumbnail(tree_row.path, name_x, row_y + 3, 18, active_theme)
                    name_x = name_x + 24
                end
                _draw.set_colour(active_theme.text_primary)
                if font_16 then
                    font_16:draw(tree_row.name, name_x, text_y)
                end

                if is_hovered and is_pressed then
                    local current_time = os.clock()
                    if selected_path == tree_row.path and last_click_path == tree_row.path and (current_time - last_click_time) <= DOUBLE_CLICK_TIME then
                        begin_rename()
                        last_click_path = nil
                        last_click_time = 0
                        drag = nil
                    else
                        selected_path, is_selected_dir = tree_row.path, tree_row.dir
                        last_click_path = tree_row.path
                        last_click_time = current_time
                        drag = { path = tree_row.path, name = tree_row.name, dir = tree_row.dir, sx = mouse_x, sy = mouse_y, active = false }
                    end
                end
            end
        end
    end

    if is_pressed and not hit_row and not edit_state and _ui_input.in_rect(panel_x, panel_y, panel_w, panel_h) then
        selected_path, is_selected_dir = nil, false
        last_click_path = nil
    end

    _ui.scroll_finish()

    if drag and drag.active and not move_target and _ui_input.in_rect(panel_x, panel_y, panel_w, panel_h) then
        move_target = root_path
    end

    if drag and _ui_input.released() then
        local finished = drag
        drag = nil
        if finished.active then
            if move_target and can_move_into(finished.path, move_target) then
                move_item(finished.path, move_target)
            end
        elseif finished.dir then
            expanded_paths[finished.path] = not expanded_paths[finished.path] or nil
            is_dirty = true
        elseif m.on_open then
            m.on_open(finished.path)
        end
    elseif drag and not _ui_input.down() then
        drag = nil
    end

    if drag and drag.active and font_16 then
        local label_w = font_16:measure(drag.name)
        local ghost_x, ghost_y = mouse_x + 12, mouse_y + 8
        _draw.set_colour(active_theme.bg_hover)
        _draw.rect(ghost_x, ghost_y, label_w + 16, ROW_H)
        _draw.set_colour(active_theme.border_dark.color)
        _draw.rect_lines(ghost_x, ghost_y, label_w + 16, ROW_H, 1)
        _draw.set_colour(active_theme.text_primary)
        font_16:draw(drag.name, ghost_x + 8, ghost_y + math.floor((ROW_H - 16) / 2))
    end

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
        _draw.set_colour(active_theme.text_secondary)
        if font_14 then
            font_14:draw(import_notice, panel_x + PAD, viewport.y + viewport.h - 22)
        end
        _draw.pop_clip()
    end

    if edit_state and edit_state.error then
        _draw.set_colour(active_theme.accent3)
        if font_16 then
            font_16:draw(edit_state.error, panel_x + PAD + 4, viewport.y + viewport.h - 24)
        end
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