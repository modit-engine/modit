--- @module boilerplate
--- @file src/editor/core/boilerplate.lua
--- @description Starter project templates. A template is a list of files, so adding one means adding a table.

--- @section Initialisation

local m = {}

local script_dir = (arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local config_chunk = loadfile("src/editor/boilerplates/config.lua")
local CONFIG = config_chunk and config_chunk() or "-- error loading config template"

--- @section Files

local MAIN_STARTER = [[
--- @file game/main.lua
--- @description Game entry. Passes the runner's load, update, draw and quit calls to the client module.

local client = require("client")
if type(client) ~= "table" then client = {} end

local game = {}

function game.load()
    if client.init then client.init() end
end

function game.update(dt)
    if client.update then client.update(dt) end
end

function game.draw()
    if client.frame then client.frame() end
end

function game.quit()
    if client.close then client.close() end
end

return game
]]

local MAIN_EMPTY = [[
--- @file game/main.lua
--- @description Game entry. Passes the runner's load, update, draw and quit calls to the client module.

local game = {}

function game.load()
end

function game.update(dt)
end

function game.draw()
end

return game
]]

local STUB = "-- {{realm}} code runs here\n"

local SERVER_STUB = [[
-- Server code. Only runs when server.enabled = true in game/config.lua
local server = {}

function server.load()
end

-- Called at a fixed rate (server.tick_rate), dt is always the same
function server.update(dt)
end

function server.quit()
end

return server
]]

--- @section Templates

--- Folders every template creates (parents are created automatically)
local BASE_DIRS = { "game/assets", "game/shared", "game/client", "game/server" }

local function base_files(main)
    return {
        ["game/main.lua"] = main,
        ["game/config.lua"] = CONFIG,
        ["game/shared/init.lua"] = (STUB:gsub("{{realm}}", "shared")),
        ["game/client/init.lua"] = (STUB:gsub("{{realm}}", "client")),
        ["game/server/init.lua"] = SERVER_STUB,
    }
end

m.default = "starter"

--- Ordered list shown in the picker. Add new entries here
m.templates = {
    {
        id = "starter",
        name = "Starter",
        description = "Draws the project name with the default font.",
        dirs = BASE_DIRS,
        files = base_files(MAIN_STARTER),
    },
    {
        id = "empty",
        name = "Empty",
        description = "Blank load, update and draw. Full config.",
        dirs = BASE_DIRS,
        files = base_files(MAIN_EMPTY),
    },
}

--- @section Functions

--- Finds a template by id
--- @param id string|nil Template id (falls back to the default)
--- @return table|nil template
function m.get(id)
    for _, template in ipairs(m.templates) do
        if template.id == (id or m.default) then return template end
    end
end

--- Replaces {{key}} placeholders
--- @param text string Template text
--- @param vars table Key to value map
--- @return string
function m.render(text, vars)
    return (text:gsub("{{([%w_]+)}}", function(key) return vars[key] end))
end

return m