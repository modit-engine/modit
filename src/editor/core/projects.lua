--- @module projects
--- @file src/editor/core/projects.lua
--- @description Project lifecycle manager for creating, listing, and deleting project workspaces.

--- @section Imports

local _fs = require("src.engine.backend").filesystem
local _bp = require("src.editor.core.boilerplate")

--- @section Constants

local DIR = "projects"
local MAX_NAME = 32

local STUB = "-- %s code runs here\n"

--- @section Initialisation

local m = { dir = DIR }

--- @section Functions

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
function m.create(name, template_id)
    if name == "" then return nil, "Enter a project name" end
    if #name > MAX_NAME or name:find("[^%w_%-]") then
        return nil, "Use letters, numbers, - and _ only"
    end

    local template = _bp.get(template_id)
    if not template then return nil, "Unknown template" end

    local lower = name:lower()
    for _, existing in ipairs(_fs.list_dirs(DIR)) do
        if existing:lower() == lower then
            return nil, "A project with that name already exists"
        end
    end

    _fs.ensure_dir(DIR)

    local path = DIR .. "/" .. name
    if not _fs.create_dir(path) then
        return nil, "Could not create the folder"
    end

    -- Creates every folder level in order, so nested paths work
    local function ensure(relative)
        local current = path
        for part in relative:gmatch("[^/]+") do
            current = current .. "/" .. part
            _fs.ensure_dir(current)
        end
    end

    for _, dir in ipairs(template.dirs or {}) do ensure(dir) end

    for file, content in pairs(template.files) do
        local parent = file:match("^(.*)/[^/]+$")
        if parent then ensure(parent) end
        if not _fs.write_file(path .. "/" .. file, _bp.render(content, { name = name })) then
            return nil, "Could not write " .. file
        end
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
            name = path:match("([^/]+)$") or path,
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