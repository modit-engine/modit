--- @file game/main.lua
--- @description Game entry. Passes the runner's load, update, draw and quit calls to the client module.

local client = require("projects.test_project.game.client")
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