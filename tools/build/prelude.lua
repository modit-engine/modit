--- @script prelude
--- @file tools/build/prelude.lua
--- @description Runs inside a built game before the engine. Serves the embedded files, then starts the runner.

--- @section Setup

local bundle = MODIT_BUNDLE
local real_loadfile = loadfile

-- Mirrors package.path: project root first, then the game folder
local ROOTS = { "", "game/" }

--- Turns "./game\main.lua" into "game/main.lua"
local function normalise(path)
    path = path:gsub("\\", "/")
    while path:sub(1, 2) == "./" do
        path = path:sub(3)
    end
    return path
end

--- @section Embedded File Access

--- loadfile() that checks the embedded files first, then the disk
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

--- dofile() on top of the loadfile above
function dofile(path)
    local chunk, err = loadfile(path)
    if not chunk then
        error(err, 0)
    end
    return chunk()
end

--- Finds the embedded file for a module name, or nil
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

-- Runs before the normal file searcher, so embedded code wins over loose files
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

--- @section Start

local meta_source = bundle.get("@meta")
local meta = meta_source and loadstring(meta_source)()

MODIT_NAME = meta and meta.name

-- Server builds start headless automatically.
-- The runner recognises --server and selects its headless server path.
if meta and meta.target == "server" then
    local found = false

    for i = 1, #arg do
        if arg[i] == "--server" then
            found = true
            break
        end
    end

    if not found then
        arg[#arg + 1] = "--server"
    end
end

local runner_source = bundle.get("src/engine/runner.lua")
if not runner_source then
    error("the game data has no engine runner", 0)
end

local runner = assert(loadstring(runner_source, "@src/engine/runner.lua"))
runner()