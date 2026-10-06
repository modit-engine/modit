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

--- Checks if a directory path contains a main.lua project entry point
function m.is_project(path)
    return _fs.is_file(path .. "/main.lua")
end

--- Generates a new project directory with _bp main.lua, config.lua, and assets/
--- @param name string Target project folder name
--- @return string|nil path Created folder path on success, or nil and error message
function m.create(name)
    if name == "" then return nil, "Enter a project name" end
    if #name > MAX_NAME or name:find("[^%w_%-]") then
        return nil, "Use letters, numbers, - and _ only"
    end

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

    _fs.ensure_dir(path .. "/assets")

    if not _fs.write_file(path .. "/main.lua", _bp.main:format(name, name, name))
        or not _fs.write_file(path .. "/config.lua", _bp.config:format(name)) then
        return nil, "Could not write project files"
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