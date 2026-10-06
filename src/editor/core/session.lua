--- @module session
--- @file src/editor/core/session.lua
--- @description Manages active project workspace, editor session state, and target game subprocess lifecycle.

--- @section Imports

--- Engine
local _keyboard = require("src.engine.modules.keyboard")
local _process = require("src.engine.backend").process

--- Editor
local _input = require("src.editor.ui.input")
local _console = require("src.editor.ui.panels.console")
local _explorer = require("src.editor.ui.panels.explorer")
local _code = require("src.editor.ui.panels.code")
local _settings = require("src.editor.core.settings")
local _projects = require("src.editor.core.projects")

--- @section Constants

local LUAJIT = (arg and arg[-1]) or "luajit"

local STATUS_TEXT = {
    stopped = "Stopped",
    running = "Running",
    exited = "Exited",
    failed = "Failed to start",
}

--- @section Variables

local proc

--- @section Initialisation

local m = { project = nil, status = "stopped", version = 0 }

--- @section Functions

--- Returns human-readable display string for current session execution state
--- @return string status Text representation of session state
function m.status_text() 
    return STATUS_TEXT[m.status] 
end

--- Retrieves theme color corresponding to active session state
--- @param t table Active color theme table
--- @return table color RGBA color table
function m.status_colour(t)
    if m.status == "running" then return t.accent end
    if m.status == "failed" then return t.accent3 end
    return t.text_tertiary
end

--- Terminates running game _process if active and updates status to stopped
function m.stop()
    if proc then
        _process.kill(proc)
        proc = nil
    end
    m.status = "stopped"
end

--- Checks if game _process is currently running
--- @return boolean running True if _process handle exists
function m.is_running() 
    return proc ~= nil 
end

--- Loads a project directory into the active editor workspace session
--- @param path string Disk path to target project directory
--- @return boolean ok True on successful load
function m.open(path)
    path = path:gsub("\\", "/"):gsub("^%./", ""):gsub("/+$", "")

    if not _projects.is_project(path) then
        print("Not a project (no main.lua): " .. path)
        return false
    end

    m.stop()
    _code.save_all()
    _code.close_all()

    m.project = {
        path = path,
        name = path:match("([^/]+)$") or path,
        log = path .. "/game.log",
    }
    m.version = m.version + 1

    _settings.add_recent(path)
    _settings.save()

    _console.open(m.project.log)
    _explorer.open(path)
    _input.blur()
    return true
end

--- Closes active project workspace and returns editor to launcher screen
function m.close_project()
    m.stop()
    _code.save_all()
    _code.close_all()

    m.project = nil
    m.version = m.version + 1
    _console.open(nil)
    _explorer.close()
    _input.blur()
end

--- Creates a new project and immediately opens it in the workspace
--- @param name string Target project folder name
--- @return string|nil err Error message if creation fails
function m.create(name)
    local path, err = _projects.create(name)
    if not path then return err end
    m.open(path)
end

--- Launches or restarts current project in an isolated runner _process
function m.run()
    local project = m.project
    if not project then return end
    m.stop()
    _code.save_all()

    local lf = io.open(project.log, "w")
    if lf then lf:close() end
    _console.clear()

    local cmd = ('"%s" src/engine/runner.lua "%s" "%s"'):format(LUAJIT, project.path, project.log)
    local handle, err = _process.start(cmd)
    if not handle then
        print("Run failed: " .. err)
        m.status = "failed"
        return
    end

    proc = handle
    m.status = "running"
end

--- Performs per-frame session checks, subprocess polling, and shortcut handling
--- @param dt number Delta time in seconds
function m.update(dt)
    if proc and not _process.running(proc) then
        _process.kill(proc)
        proc = nil
        m.status = "exited"
    end

    _console.update(dt)
    _explorer.update(dt)

    if _keyboard.pressed("f5") then m.run() end
end

return m