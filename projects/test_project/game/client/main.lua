--- @file projects/test_project/game/client.lua
--- @description PlanetLua.exe entry point

--- @section Package Path

package.path = "./?.lua;./?/init.lua;" .. package.path

--- @section Imports

local _engine = require("src.engine")
local _client = require("projects.test_project.game.client")

--- @section Initialisation

_engine.window.init(_client.config)
_client.init()

--- @section Main Loop

while not _engine.window.should_close() do
    _client.update(_engine.window.get_dt())

    _engine.window.begin_draw()
    _client.frame()
    _engine.window.end_draw()
end

_client.close()
_engine.window.close()