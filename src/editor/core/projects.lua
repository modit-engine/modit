
--- @module projects
--- @file src/editor/core/projects.lua
--- @description Project lifecycle manager for creating, discovering, opening, and deleting project workspaces.

--- @section Imports

local _fs = require("src.engine.backend").filesystem
local _bp = require("src.editor.core.boilerplate")

--- @section Constants

local DIR = "projects"
local MAX_NAME = 32
local MANIFEST = "project.modit"

--- @section Initialisation

local m = { dir = DIR }

--- @section Path Helpers

--- Normalises path separators without restricting absolute paths.
--- @param path string Filesystem path
--- @return string path Normalised path
local function normalise_path(path)
    path = path:gsub("\\", "/")

    while #path > 1 and path:sub(-1) == "/" do
        if #path == 3 and path:sub(2, 2) == ":" then
            break
        end

        path = path:sub(1, -2)
    end

    return path
end

--- Reads and validates plain-text project metadata.
--- @param path string Project directory
--- @return table|nil metadata Project metadata, or nil if invalid
--- @return string|nil err Error message on failure
local function read_manifest(path)
    local source = _fs.read_file(normalise_path(path) .. "/" .. MANIFEST)

    if not source then
        return nil, "Missing " .. MANIFEST
    end

    local data = {}

    for line in (source .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("\r$", ""):match("^%s*(.-)%s*$")

        if line ~= "" and not line:match("^#") then
            local key, value = line:match("^([%w_%-]+)%s*=%s*(.-)%s*$")

            if key then
                data[key] = value
            end
        end
    end

    if data.engine ~= "modit" then
        return nil, "Not a valid Modit project: expected engine=modit"
    end

    if type(data.name) ~= "string" or data.name == "" or #data.name > MAX_NAME or data.name:find("[^a-z0-9_%-]") then
        return nil, "Invalid project name"
    end

    if type(data.label) ~= "string" or data.label == "" or #data.label > 80 or data.label:find("[%c]") then
        return nil, "Invalid project label"
    end

    return data
end

--- Reads and validates project metadata.
--- @param path string Project directory
--- @return table|nil metadata Project metadata, or nil if invalid
--- @return string|nil err Error message on failure
local function read_metadata(path)
    path = normalise_path(path)

    if not _fs.is_dir(path) then
        return nil, "Project folder does not exist"
    end

    return read_manifest(path)
end

--- @section Project Identification

--- Checks whether a directory contains valid Modit project metadata.
--- @param path string Project folder path, absolute or relative
--- @return boolean is_project Whether the directory is a Modit project
--- @return string|nil err Error message if invalid
function m.is_project(path)
    if type(path) ~= "string" or path == "" then
        return false, "Select a project folder"
    end

    path = normalise_path(path)

    if not _fs.is_dir(path) then
        return false, "Project folder does not exist"
    end

    local metadata, err = read_metadata(path)

    if not metadata then
        return false, err
    end

    return true
end

--- Reads the project label, falling back to the folder name.
--- @param path string Project folder path
--- @return string label Display label
function m.label(path)
    local metadata = read_metadata(path)

    if metadata then
        return metadata.label
    end

    return normalise_path(path):match("([^/]+)$") or path
end

--- Opens a project by validating its directory and metadata.
--- Does not change the process working directory or copy project files.
--- @param path string Absolute or relative project folder path
--- @return table|nil project Project information, or nil on failure
--- @return string|nil err Error message on failure
function m.open(path)
    if type(path) ~= "string" or not path:find("%S") then
        return nil, "Select a project folder"
    end

    path = normalise_path(path:match("^%s*(.-)%s*$"))

    if not _fs.is_dir(path) then
        return nil, "The selected folder does not exist"
    end

    local metadata, err = read_metadata(path)

    if not metadata then
        return nil, err or "This folder is not a valid Modit project"
    end

    return {
        name = metadata.label,
        label = metadata.label,
        id = metadata.name,
        path = path,
        metadata = metadata,
    }
end

--- @section Project Naming

--- Derives the default folder name from a human-readable label.
--- @param label string Display label
--- @return string name Generated project name
function m.name_from_label(label)
    return (label:lower():gsub("[^a-z0-9_%-]+", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")):sub(1, MAX_NAME)
end

--- Validates project name and label.
--- @param name string Project folder name
--- @param label string Project display label
--- @return string|nil err Validation error, or nil if valid
function m.validate(name, label)
    if not label or not label:find("%S") then
        return "Enter a project label"
    end

    if #label > 80 or label:find("[%c]") then
        return "Use a label of up to 80 printable characters"
    end

    if not name or name == "" then
        return "Enter a project name"
    end

    if #name > MAX_NAME or name:find("[^a-z0-9_%-]") then
        return "Name: up to 32 lowercase letters, numbers, - or _"
    end

    if name == "con" or name == "prn" or name == "aux" or name == "nul" or name:match("^com[0-9]$") or name:match("^lpt[0-9]$") then
        return "That project name is reserved by Windows"
    end
end

--- @section Project Creation

--- Creates a new project from a template.
--- @param name string Target project folder name
--- @param template_id string|nil Template id
--- @param parent string|nil Parent directory
--- @param label string|nil Display label
--- @return string|nil path Created folder path
--- @return string|nil err Error message on failure
function m.create(name, template_id, parent, label)
    label = (label or name or ""):match("^%s*(.-)%s*$")

    local invalid = m.validate(name, label)

    if invalid then
        return nil, invalid
    end

    local template = _bp.get(template_id)

    if not template then
        return nil, "Unknown template"
    end

    if not parent then
        _fs.ensure_dir(DIR)
        parent = DIR
    end

    parent = normalise_path(parent)

    if not _fs.is_dir(parent) then
        return nil, "The selected parent folder does not exist"
    end

    local path = parent .. "/" .. name

    for _, entry in ipairs(_fs.list(parent)) do
        if entry.name:lower() == name:lower() then
            return nil, "A file or folder with that name already exists"
        end
    end

    if not _fs.create_dir(path) then
        return nil, "Could not create the folder"
    end

    local function ensure(relative)
        local current = path

        for part in relative:gmatch("[^/\\]+") do
            current = current .. "/" .. part

            if not _fs.is_dir(current) and not _fs.create_dir(current) then
                return false
            end
        end

        return true
    end

    for _, dir in ipairs(template.dirs or {}) do
        if not ensure(dir) then
            return nil, "Could not create " .. dir
        end
    end

    for file, content in pairs(template.files or {}) do
        local parent_dir = file:match("^(.*)/[^/]+$")

        if parent_dir and not ensure(parent_dir) then
            return nil, "Could not create " .. parent_dir
        end

        local ok = _fs.write_file(path .. "/" .. file, _bp.render(content, { name = name, label_literal = string.format("%q", label) }))

        if not ok then
            return nil, "Could not write " .. file
        end
    end

    local metadata = ("engine=modit\nname=%s\nlabel=%s\n"):format(name, label)

    if not _fs.write_file(path .. "/" .. MANIFEST, metadata) then
        return nil, "Could not save the project metadata"
    end

    return path
end

--- @section Project Discovery

--- Lists recent projects and project folders inside the managed projects directory.
--- Candidate folders remain visible when their metadata is invalid.
--- @param recent table|nil Recently opened project paths
--- @return table projects Discovered project folders
function m.list(recent)
    local out, seen = {}, {}

    local function add(path)
        if type(path) ~= "string" or not path:find("%S") then
            return
        end

        path = normalise_path(path)

        local key = path:lower()

        if seen[key] or not _fs.is_dir(path) then
            return
        end

        local has_manifest = _fs.read_file(path .. "/" .. MANIFEST) ~= nil

        if not has_manifest then
            return
        end

        seen[key] = true

        local metadata = read_metadata(path)

        out[#out + 1] = {
            name = metadata and metadata.label or m.label(path),
            path = path,
            valid = metadata ~= nil,
            error = metadata and nil or select(2, read_metadata(path)),
        }
    end

    for _, path in ipairs(recent or {}) do
        add(path)
    end

    if _fs.is_dir(DIR) then
        for _, name in ipairs(_fs.list_dirs(DIR)) do
            add(DIR .. "/" .. name)
        end
    end

    return out
end

--- @section Project Deletion

--- Deletes a project directly inside the managed projects directory.
--- Projects opened from arbitrary locations cannot be deleted through this function.
--- @param path string Project folder path relative to the application directory
--- @return boolean ok Whether deletion succeeded
--- @return string|nil err Error message on failure
function m.delete(path)
    if type(path) ~= "string" then
        return false, "Invalid project path"
    end

    path = normalise_path(path)

    if not path:match("^projects/[%w_%-]+$") then
        return false, "Only projects inside projects/ can be deleted"
    end

    if not _fs.is_dir(path) then
        return false, "Project folder does not exist"
    end

    return _fs.remove_dir(path)
end

return m