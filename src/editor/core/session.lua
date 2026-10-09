--- @module session
--- @file src/editor/core/session.lua
--- @description Manages active project workspace, editor session state, and target game subprocess lifecycle.

--- @section Imports

--- Engine
local _keyboard = require("src.engine.modules.keyboard")
local _process = require("src.engine.backend").process
local _fs = require("src.engine.backend.platform." .. require("ffi").os:lower() .. ".filesystem")

--- Editor
local _input = require("src.engine.ui.modules.input")
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
local POLL_INTERVAL = 0.25

--- @section Variables

local proc
local server_proc
local snapshots = {}
local poll_timer = 0
local change_seen = false

--- @section Initialisation

local m = { project = nil, status = "stopped", version = 0 }

--- @section Helpers

local function read_file(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function scan(dir, out)
    for _, entry in ipairs(_fs.list(dir)) do
        if entry.name:sub(1, 1) ~= "." then
            local path = dir .. "/" .. entry.name
            if entry.dir then
                scan(path, out)
            elseif entry.name:match("%.lua$") then
                out[path] = read_file(path)
            end
        end
    end
end

local function take_snapshot(project_path)
    snapshots = {}
    scan(project_path, snapshots)
    change_seen = false
end

local function has_changed(project_path)
    local current = {}
    scan(project_path, current)
    for path, content in pairs(current) do
        if snapshots[path] ~= content then return true end
    end
    for path in pairs(snapshots) do
        if current[path] == nil then return true end
    end
    return false
end

--- Reads game/config.lua and reports whether the project has its server switched on
--- @param project_path string Project directory
--- @return boolean enabled
local function server_enabled(project_path)
    local chunk = loadfile(project_path .. "/game/config.lua")
    if not chunk then return false end
    local ok, conf = pcall(chunk)
    return ok and type(conf) == "table" and type(conf.server) == "table" and conf.server.enabled == true
end

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

--- Terminates the running server process if active
function m.stop_server()
    if server_proc then
        _process.kill(server_proc)
        server_proc = nil
    end
end

--- Checks if game _process is currently running
--- @return boolean running True if _process handle exists
function m.is_running() 
    return proc ~= nil 
end

--- Checks if the server process is currently running
--- @return boolean running True if the server process handle exists
function m.is_server_running()
    return server_proc ~= nil
end

--- Checks if the open project has its server enabled in game/config.lua
--- @return boolean enabled
function m.has_server()
    return m.project ~= nil and server_enabled(m.project.path)
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
    m.stop_server()
    _code.save_all()
    _code.close_all()

    m.project = {
        path = path,
        name = path:match("([^/]+)$") or path,
        log = path .. "/game.log",
        server_log = path .. "/server.log",
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
    m.stop_server()
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
--- @param template_id string|nil Template id
--- @return string|nil err Error message if creation fails
function m.create(name, template_id)
    local path, err = _projects.create(name, template_id)
    if not path then return err end
    m.open(path)
end

--- Launches or restarts current project in an isolated runner _process
function m.run()
    local project = m.project
    if not project then return end
    m.stop()
    _code.save_all()
    take_snapshot(project.path)

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

--- Launches or restarts the project's headless server in its own process
function m.run_server()
    local project = m.project
    if not project then return end

    if not server_enabled(project.path) then
        print("Server is off. Set server.enabled = true in game/config.lua")
        return
    end

    m.stop_server()
    _code.save_all()
    take_snapshot(project.path)

    local cmd = ('"%s" src/engine/runner.lua "%s" "%s" --server'):format(LUAJIT, project.path, project.server_log)
    local handle, err = _process.start(cmd)
    if not handle then
        print("Server failed to start: " .. err)
        return
    end

    server_proc = handle
end

--- Performs per-frame session checks, subprocess polling, and shortcut handling
--- @param dt number Delta time in seconds
function m.update(dt)
    if proc and not _process.running(proc) then
        _process.kill(proc)
        proc = nil
        m.status = "exited"
    end

    if server_proc and not _process.running(server_proc) then
        _process.kill(server_proc)
        server_proc = nil
        print("Server exited")
    end

    if m.project and (m.status == "running" or server_proc) then
        poll_timer = poll_timer + dt
        if poll_timer >= POLL_INTERVAL then
            poll_timer = 0
            if has_changed(m.project.path) then
                if change_seen then
                    local restart_server = server_proc ~= nil
                    if m.status == "running" then m.run() end   -- run() re-snapshots and clears change_seen
                    if restart_server then m.run_server() end
                else
                    change_seen = true   -- wait one tick so two-step editor saves settle
                end
            else
                change_seen = false
            end
        end
    end

    _console.update(dt)
    _explorer.update(dt)

    if _keyboard.pressed("f5") then m.run() end
    if _keyboard.pressed("f6") then m.run_server() end
end

return m