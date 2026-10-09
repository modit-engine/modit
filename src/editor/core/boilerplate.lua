--- @module boilerplate
--- @file src/editor/core/boilerplate.lua
--- @description Starter project templates. A template is a list of files, so adding one means adding a table.

--- @section Initialisation

local m = {}

--- @section Files

local CONFIG = [[
return {
    window = {
        title = "{{name}}", -- Window title bar text
        -- icon = "path/to/icon.png", -- Window and taskbar icon path
        size = {
            width = 1280, -- Default width in pixels
            height = 720, -- Default height in pixels
        },
        flags = {
            vsync_hint = true, -- Sync frames with monitor refresh rate
            fullscreen_mode = false, -- Launch directly in full screen
            resizable = true, -- Allow manual window resizing
            undecorated = false, -- Hide title bar and borders
            transparent = false, -- Enable transparent window background
            hidden = false, -- Start window hidden
            minimized = false, -- Start window minimized
            maximized = false, -- Start window maximized
            unfocused = false, -- Avoid stealing focus on launch
            topmost = false, -- Pin window above all other OS windows
            always_run = false, -- Keep updating when alt-tabbed or minimized
            highdpi = false, -- High-DPI scaling support
            mouse_passthrough = false, -- Mouse clicks pass through window
            borderless_windowed_mode = false, -- Borderless windowed mode
            msaa_4x_hint = true, -- 4x anti-aliasing hint
            interlaced_hint = false, -- Interlaced render mode
        },
        console = true, -- Attach debug terminal on launch (set false for releases)
    },

    fps = {
        draw = false, -- Render FPS counter on screen
        target = 144, -- Target FPS cap (or false for uncapped)
    },

    modules = {
        audio = false, -- Init Raylib audio on boot
    },

    server = {
        enabled = false, -- Game has server code (game/server). Runs beside the client while developing
        tick_rate = 30, -- Server updates per second
    },
}
]]

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
local BASE_DIRS = { "game/assets", "game/shared", "game/client", "game/server", "mods" }

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
    return (text:gsub("{{(%w+)}}", function(key) return vars[key] end))
end

return m