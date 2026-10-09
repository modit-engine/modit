--- @module projects
--- @file src/editor/core/projects.lua
--- @description Project lifecycle manager for creating, listing, and deleting project workspaces.

--- @section Imports

local _fs = require("src.engine.backend").filesystem
local _bp = require("src.editor.core.boilerplate")

--- @section Constants

local DIR = "projects"
local MAX_NAME = 32

--- @section Initialisation

local m = { dir = DIR }

--- @section Functions

--- Derives the default folder name from a human-readable label.
function m.name_from_label(label)
    return (label:lower():gsub("[^a-z0-9_%-]+", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")):sub(1, MAX_NAME)
end

function m.validate(name, label)
    if not label or not label:find("%S") then return "Enter a project label" end
    if #label > 80 or label:find("[%c]") then return "Use a label of up to 80 printable characters" end
    if name == "" then return "Enter a project name" end
    if #name > MAX_NAME or name:find("[^a-z0-9_%-]") then
        return "Name: up to 32 lowercase letters, numbers, - or _"
    end
    if name == "con" or name == "prn" or name == "aux" or name == "nul"
        or name:match("^com[0-9]$") or name:match("^lpt[0-9]$") then
        return "That project name is reserved by Windows"
    end
end

--- Reads editor metadata without executing it in the engine environment.
function m.label(path)
    local source = _fs.read_file(path .. "/project.lua")
    local chunk = source and loadstring(source, "=project_metadata")
    if chunk then
        setfenv(chunk, {})
        local ok, data = pcall(chunk)
        if ok and type(data) == "table" and type(data.label) == "string" and data.label ~= "" then
            return data.label
        end
    end
    return path:match("([^/\\]+)$") or path
end

--- Any directory counts as a project. A missing game/main.lua is reported by the runner instead
--- @param path string Project folder path
--- @return boolean
function m.is_project(path)
    return _fs.is_dir(path)
end

--- Generates a new project from a template
--- @param name string Target project folder name
--- @param template_id string|nil Template id from boilerplate.templates
--- @return string|nil path Created folder path on success, or nil and error message
function m.create(name, template_id, parent, label)
    label = (label or name):match("^%s*(.-)%s*$")
    local invalid = m.validate(name, label)
    if invalid then return nil, invalid end

    local template = _bp.get(template_id)
    if not template then return nil, "Unknown template" end

    if not parent then _fs.ensure_dir(DIR) end
    parent = (parent or DIR):gsub("\\", "/"):gsub("/+$", "")
    if not _fs.is_dir(parent .. "/") then return nil, "The selected parent folder does not exist" end
    local path = parent .. "/" .. name
    for _, entry in ipairs(_fs.list(parent .. "/")) do
        if entry.name:lower() == name:lower() then return nil, "A file or folder with that name already exists" end
    end
    if not _fs.create_dir(path) then
        return nil, "Could not create the folder"
    end

    -- Creates every folder level in order, so nested paths work
    local function ensure(relative)
        local current = path
        for part in relative:gmatch("[^/]+") do
            current = current .. "/" .. part
            if not _fs.is_dir(current) and not _fs.create_dir(current) then return false end
        end
        return true
    end

    for _, dir in ipairs(template.dirs or {}) do
        if not ensure(dir) then return nil, "Could not create " .. dir end
    end

    for file, content in pairs(template.files) do
        local parent = file:match("^(.*)/[^/]+$")
        if parent and not ensure(parent) then return nil, "Could not create " .. parent end
        if not _fs.write_file(path .. "/" .. file, _bp.render(content, { name = name, label_literal = string.format("%q", label) })) then
            return nil, "Could not write " .. file
        end
    end

    if not _fs.write_file(path .. "/project.lua", ("return { label = %q, name = %q }\n"):format(label, name)) then
        return nil, "Could not save the project label"
    end

    return path
end

--- Retrieves available projects for the editor launcher, prioritizing recent entries
--- @param recent table List of recently opened project paths
--- @return table Array of { name, path } project entries
function m.list(recent)
    local out, seen = {}, {}

    local function add(path)
        local key = path:lower()
        if seen[key] or not m.is_project(path) then return end
        seen[key] = true
        out[#out + 1] = {
            name = m.label(path),
            path = path,
        }
    end

    for _, p in ipairs(recent) do
        add(p)
    end

    for _, n in ipairs(_fs.list_dirs(DIR)) do
        add(DIR .. "/" .. n)
    end

    return out
end

--- Deletes a project directory directly inside projects/
--- @param path string Relative path to project folder
--- @return boolean ok True on success, or false and error message
function m.delete(path)
    if not path:match("^projects/[%w_%-]+$") or not m.is_project(path) then
        return false, "Not a deletable project"
    end
    return _fs.remove_dir(path)
end

return m
