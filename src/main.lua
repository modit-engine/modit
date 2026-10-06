--- @file src/main.lua
--- @description Main initialisation file

--- @section Package Path

package.path = "./?.lua;./?/init.lua;" .. package.path

--- @section Imports

local engine = require("src.engine")
local editor = require("src.editor")
local conf = require("src.editor.core.config")
local version_check = require("src.engine.core.version_check")
local version = require("src.version")
local window, draw = engine.window, engine.draw
local input = require("src.engine.ui.input")

--- @section Initialisation

version_check.check(version)

window.init(conf)
editor.init()
if arg[1] then editor.open_project(arg[1]) end

--- @section Main Loop

while not window.should_close() do
    editor.update(window.get_dt())

    window.begin_draw()
    draw.set_colour(255, 255, 255, 255)
    input.begin_frame()
    editor.draw()
    input.end_frame()
    draw.reset_clip()
    window.end_draw()
end

editor.close()
window.close()