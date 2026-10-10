local _process = require("src.engine.backend.platform." .. require("ffi").os:lower() .. ".process")

local STATUS_SECONDS = 15
local STATUS_MAX_LENGTH = 90

local TARGETS = {
    windows = {
        client = { "--target", "client" },
        server = { "--target", "server" }
    }
}

local m = {}

local handle = nil
local log_path = nil
local state = "idle" -- idle, building, success or failed
local message = nil
local finished_at = 0

local function quote(text)
    return '"' .. tostring(text) .. '"'
end

local function engine_root()
    return (arg and arg[0] or ""):match("^(.*)[/\\]src[/\\]main%.lua$") or "."
end

local function luajit_path()
    return arg and arg[-1] or "luajit"
end

local function shorten(text)
    text = tostring(text or "")
    if #text > STATUS_MAX_LENGTH then
        return text:sub(1, STATUS_MAX_LENGTH - 3) .. "..."
    end
    return text
end

local function read_result()
    if not log_path then
        return false, "no build log path is set"
    end

    local file = io.open(log_path, "rb")
    if not file then
        return false, "no build log was written"
    end

    local errors, success = {}, nil

    for line in file:lines() do
        line = line:gsub("\r$", "")
        local level, _, text = line:match("^([^\t]*)\t([^\t]*)\t(.*)$")

        if level == "error" or level == "fatal" then
            errors[#errors + 1] = text
        elseif level == "success" then
            success = text
        end
    end

    file:close()

    if #errors > 0 then
        return false, table.concat(errors, " ")
    end

    if success then
        return true, success
    end

    return false, "the build ended without a result"
end

function m.build(target, project)
    local platform_targets = TARGETS.windows
    local extra = platform_targets and platform_targets[target]

    if not extra then
        return false, "unknown build target: " .. tostring(target)
    end

    if type(project) ~= "string" or project == "" then
        return false, "no project path"
    end

    if state == "building" then
        return false, "a build is already running"
    end

    project = project:gsub("[/\\]+$", "")

    local temp = os.getenv("TEMP") or "."
    log_path = temp .. "\\modit_build.log"
    os.remove(log_path)

    local parts = {
        quote(luajit_path()),
        quote(engine_root() .. "/tools/build/build.lua"),
        quote(project),
        "--log",
        quote(log_path)
    }

    for _, argument in ipairs(extra) do
        parts[#parts + 1] = argument
    end

    local started, err = _process.start(table.concat(parts, " "))

    if not started then
        state = "failed"
        message = err or "failed to start the build process"
        finished_at = os.time()
        handle = nil
        return false, message
    end

    handle = started
    state = "building"
    message = nil
    finished_at = 0

    return true
end

function m.update()
    if state ~= "building" or _process.running(handle) then
        return
    end

    _process.kill(handle)
    handle = nil

    local ok, text = read_result()
    state = ok and "success" or "failed"
    message = text
    finished_at = os.time()
end

function m.is_building()
    return state == "building"
end

function m.status_text()
    if state == "building" then
        return "Building..."
    end

    if state == "success" then
        if os.time() - finished_at <= STATUS_SECONDS then
            return shorten(message or "Build succeeded")
        end
        return "Build"
    end

    if state == "failed" then
        if os.time() - finished_at <= STATUS_SECONDS then
            return shorten("Build failed: " .. (message or "unknown error"))
        end
        return "Build"
    end

    return "Build"
end

function m.get_result()
    return state, message
end

function m.get_log_path()
    return log_path
end

return m