--- @script prelude
--- @file src/editor/builder/prelude.lua
--- @description Runs inside a built game before the engine. Serves the embedded files, then starts the runner.

--- @section Setup

local bundle = MODIT_BUNDLE
local real_loadfile = loadfile
local ROOTS = { "", "game/" }

--- @section Path Helpers

--- Normalise a file path to use forward slashes and remove leading "./" prefixes.
--- @param path string Path to normalise.
--- @return string path Normalised path.
local function normalise(path)
    path = path:gsub("\\", "/")
    while path:sub(1, 2) == "./" do
        path = path:sub(3)
    end
    return path
end

--- @section Embedded File Access

--- Load a file from the embedded bundle, falling back to the filesystem.
--- @param path string File path to load.
--- @return function|nil chunk Compiled file chunk, or nil on failure.
--- @return string|nil err Error message if loading fails.
function loadfile(path, ...)
    if type(path) == "string" then
        local key = normalise(path)
        local source = bundle.get(key)
        if source then
            return loadstring(source, "@" .. key)
        end
    end

    return real_loadfile(path, ...)
end

--- Execute a file using the embedded-aware loadfile implementation.
--- @param path string File path to execute.
--- @return any ... Values returned by the executed chunk.
function dofile(path)
    local chunk, err = loadfile(path)
    if not chunk then
        error(err, 0)
    end
    return chunk()
end

--- @section Module Resolution

--- Find a module's embedded Lua file using the configured search roots.
--- @param name string Dotted Lua module name.
--- @return string|nil path Embedded file path, or nil if not found.
local function find_module(name)
    local base = name:gsub("%.", "/")

    for _, root in ipairs(ROOTS) do
        local file = root .. base .. ".lua"
        if bundle.has(file) then
            return file
        end

        local init = root .. base .. "/init.lua"
        if bundle.has(init) then
            return init
        end
    end
end

--- Register a package loader that prioritises embedded modules over loose files.
table.insert(package.loaders, 2, function(name)
    local file = find_module(name)
    if not file then
        return "\n\tno embedded module '" .. name .. "'"
    end

    local chunk, err = loadstring(bundle.get(file), "@" .. file)
    if not chunk then
        error(
            "error loading embedded module '" .. name .. "':\n" .. tostring(err),
            0
        )
    end

    return chunk
end)

--- @section Console Setup

--- Detach the Windows console when unavailable and redirect output to a log file.
local function setup_console()
    local ok, ffi = pcall(require, "ffi")
    if not ok or ffi.os ~= "Windows" then
        return
    end

    pcall(ffi.cdef, [[
        void* GetConsoleWindow(void);
        void* freopen(const char* path, const char* mode, void* stream);
    ]])
    pcall(ffi.cdef, "int FreeConsole(void);")
    pcall(function() ffi.C.FreeConsole() end)
    pcall(function()
        if ffi.C.GetConsoleWindow() == nil then
            ffi.C.freopen("game_output.log", "w", io.stdout)
            ffi.C.freopen("game_output.log", "a", io.stderr)
            io.stdout:setvbuf("line")
        end
    end)
end

setup_console()

--- @section Build Metadata

local meta_source = bundle.get("@meta")
local meta = meta_source and loadstring(meta_source)()

MODIT_NAME = meta and meta.name

--- @section Server Bootstrap

--- Add the server flag when the embedded build targets the server and it is missing.
local function setup_server_args()
    if not meta or meta.target ~= "server" then
        return
    end

    for i = 1, #arg do
        if arg[i] == "--server" then
            return
        end
    end

    arg[#arg + 1] = "--server"
end

setup_server_args()

--- @section Runner Bootstrap

local runner_source = bundle.get("src/engine/core/internal/runner.lua")
if not runner_source then
    error("the game data has no engine runner", 0)
end

local runner = assert(loadstring(runner_source, "@src/engine/core/internal/runner.lua"))
runner()